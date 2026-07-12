"""Authenticated learner identity and persistent-root binding."""

import from nodes.learner { Learner }

obj LearnerIdentityView {
    has learner_id: str;
    has auth_user_id: str;
    has auth_root_id: str;
    has name: str;
    has email: str;
}

def _identity_view(learner: Learner) -> LearnerIdentityView {
    return LearnerIdentityView(
        learner_id=learner.id,
        auth_user_id=learner.auth_user_id,
        auth_root_id=learner.auth_root_id,
        name=learner.name,
        email=learner.email
    );
}

def _matches_legacy_identity(
    learner: Learner,
    auth_user_id: str,
    legacy_learner_id: str,
    email: str
) -> bool {
    if learner.auth_user_id != "" and learner.auth_user_id == auth_user_id {
        return True;
    }
    if legacy_learner_id != "" and learner.id == legacy_learner_id {
        return True;
    }
    if email != "" and learner.id.lower() == email.lower() {
        return True;
    }
    return False;
}

"""Resolve one learner on the authenticated root and bind legacy data."""
def:priv resolve_current_learner(
    auth_user_id: str,
    legacy_learner_id: str = "",
    name: str = "",
    email: str = ""
) -> LearnerIdentityView {
    auth_root_id = jid(root);
    learners = [root -->][?:Learner];

    for learner in learners {
        if learner.auth_root_id == auth_root_id {
            if learner.auth_user_id != "" and auth_user_id != "" and learner.auth_user_id != auth_user_id {
                raise Exception("Authenticated learner identity does not match this root.");
            }
            if learner.auth_user_id == "" {
                learner.auth_user_id = auth_user_id;
            }
            if learner.email == "" {
                learner.email = email;
            }
            if name != "" {
                learner.name = name;
            } elif learner.name == "" {
                learner.name = email;
            }
            learner.auth_root_id = auth_root_id;
            return _identity_view(learner);
        }
    }

    candidates: list[Learner] = [];
    for learner in learners {
        if _matches_legacy_identity(learner, auth_user_id, legacy_learner_id, email) {
            candidates = candidates + [learner];
        }
    }
    if len(candidates) > 1 {
        raise Exception("Multiple legacy learner records match the authenticated account.");
    }
    if len(candidates) == 1 {
        learner = candidates[0];
        learner.auth_user_id = auth_user_id;
        learner.auth_root_id = auth_root_id;
        learner.email = email;
        if name != "" {
            learner.name = name;
        }
        return _identity_view(learner);
    }
    if len(learners) > 0 {
        raise Exception("Existing learner data on this root cannot be bound unambiguously.");
    }

    learner_name = name if name != "" else (email if email != "" else "Learner");
    learner = (root ++> Learner(
        id=auth_root_id,
        name=learner_name,
        createdAt="identity-created",
        updatedAt="identity-created",
        auth_user_id=auth_user_id,
        auth_root_id=auth_root_id,
        email=email
    ))[0];
    return _identity_view(learner);
}
