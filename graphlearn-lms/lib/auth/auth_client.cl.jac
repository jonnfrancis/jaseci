"""Thin wrapper around Jac runtime auth helpers."""

import from "@jac/runtime" { __getApiBaseUrl, jacIsLoggedIn, jacLogin,  jacLogout, jacSignup, jacSetToken }
import from .auth_storage { clear_auth_session, read_auth_session, save_auth_session }
sv import from ...services.identity { resolve_current_learner }

def _auth_token_from_storage() -> str {
    # Jac runtime owns the authenticated session. Prefer the token most
    # recently written by jacLogin over GraphLearn's compatibility cache;
    # the latter may reference a user from a previously selected backend.
    for key in ["jac_token", "jac_access_token", "access_token", "token", "JAC_AUTH_TOKEN"] {
        candidate = localStorage.getItem(key); # jac:ignore[W2001,E1030,W6002]
        if candidate {
            return str(candidate);
        }
    }
    token = localStorage.getItem("graphlearn.auth.token"); # jac:ignore[W2001,E1030,W6002]
    if token {
        return str(token);
    }
    return "";
}

def _normalize_learner_id(raw_id: str, email: str) -> str {
    if raw_id.strip() != "" {
        return raw_id.strip();
    }
    return email.strip().lower();
}

def _first_auth_envelope(raw: any) -> dict {
    if isinstance(raw, list) and len(raw) > 0 {
        return raw[0] as dict;
    }
    return raw as dict;
}

def _auth_data(envelope: dict) -> dict {
    data = envelope["data"];
    if data {
        return data as dict;
    }
    return {};
}

async def _load_auth_profile() -> dict {
    token: str = _auth_token_from_storage();
    headers: dict[str, str] = {};
    if token != "" {
        headers = {"Authorization": "Bearer " + token};
    }
    response: any = None;
    raw: any = None;
    body_text: str = "";
    response = await fetch(__getApiBaseUrl() + "/user/me", { # jac:ignore[W2001,W6002]
        "method": "GET",
        "headers": headers,
        "credentials": "include"
    });
    body_text = (await response.text()) as str;
    raw = JSON.parse(body_text); # jac:ignore[W2001,W6002]
    envelope = _first_auth_envelope(raw);
    if not response.ok or not envelope["ok"] {
        raise Exception("Unable to resolve the authenticated account.");
    }
    return _auth_data(envelope);
}

def _profile_identity(profile: dict, identity_type: str) -> str {
    raw_identities: any = profile?["identities"];
    if isinstance(raw_identities, list) {
        for raw_identity in raw_identities {
            identity = raw_identity as dict;
            if str(identity["type"] or "") == identity_type {
                return str(identity["value"] or "");
            }
        }
    }
    return "";
}

async def _resolve_learner_session(email: str, username: str, legacy_learner_id: str = "") -> dict {
    profile: dict = {};
    identity: any = None;
    auth_user_id: str = "";
    profile = await _load_auth_profile();
    auth_user_id = str(profile["user_id"] or "");
    if auth_user_id == "" {
        raise Exception("Authenticated account has no stable user id.");
    }
    resolved_email = email if email != "" else _profile_identity(profile, "email");
    resolved_username = username if username != "" else _profile_identity(profile, "username");
    identity = await resolve_current_learner(
        auth_user_id,
        legacy_learner_id,
        resolved_username,
        resolved_email
    );
    return {
        "authenticated": True,
        "token": _auth_token_from_storage(),
        "learner_id": identity.learner_id,
        "username": resolved_username if resolved_username != "" else resolved_email,
        "email": resolved_email
    };
}

async def _post_auth(path: str, body: dict) -> dict {
    response: any = None;
    raw: any = None;
    body_text: str = "";
    response = await fetch(__getApiBaseUrl() + path, { # jac:ignore[W2001,W6002]
        "method": "POST",
        "headers": {"Content-Type": "application/json"},
        "body": JSON.stringify(body) # jac:ignore[W2001,W6002]
    });
    body_text = (await response.text()) as str;
    raw = JSON.parse(body_text); # jac:ignore[W2001,W6002]
    envelope = _first_auth_envelope(raw);
    if not response.ok or not envelope["ok"] {
        raise Exception("Authentication request failed.");
    }
    return envelope;
}

def:pub current_auth_session() -> dict {
    stored: dict = {};
    authenticated_value: bool = False;
    token_value: str = "";
    learner_id_value: str = "";
    username_value: str = "";
    email_value: str = "";

    stored = read_auth_session();

    authenticated_value = jacIsLoggedIn();

    if stored["authenticated"] {
        authenticated_value = True;
    }

    token_value = _auth_token_from_storage();
    learner_id_value = str(stored["learner_id"] or "");
    username_value = str(stored["username"] or "");
    email_value = str(stored["email"] or "");

    return {
        "authenticated": authenticated_value,
        "token": token_value,
        "learner_id": learner_id_value,
        "username": username_value,
        "email": email_value
    };
}

def:pub is_authenticated() -> bool {
    stored = read_auth_session();
    return jacIsLoggedIn() or (stored["authenticated"] as bool);
}

def:pub get_current_token() -> str {
    return _auth_token_from_storage();
}

def:pub get_current_learner_id() -> str {
    stored = read_auth_session();
    return str(stored["learner_id"] or "");
}

async def:pub restore_auth_session() -> dict {
    stored = read_auth_session();
    if not jacIsLoggedIn() {
        return stored;
    }
    session = await _resolve_learner_session(
        str(stored["email"] or ""),
        str(stored["username"] or ""),
        str(stored["learner_id"] or "")
    );
    save_auth_session(session);
    return session;
}

async def:pub register_user(username: str, email: str, password: str) -> dict {
    signup_result: dict | None = None;
    login_session: dict = {};

    signup_result = await jacSignup(email, password);

    if not signup_result["success"] {
        return {
            "authenticated": False,
            "token": "",
            "learner_id": "",
            "username": username,
            "email": email
        };
    }

    login_session = await login_user(email, password);

    if login_session["authenticated"] as bool {
        success_session = await _resolve_learner_session(
            email.strip().lower(),
            username,
            email.strip().lower()
        );

        save_auth_session(success_session);

        return success_session;
    }

    session = {
        "authenticated": False,
        "token": "",
        "learner_id": "",
        "username": username,
        "email": email
    };

    return session;
}

async def:pub login_user(email: str, password: str) -> dict {
    ok: bool = False;

    ok = await jacLogin(email, password);

    if not ok {
        return {
            "authenticated": False,
            "token": "",
            "learner_id": "",
            "username": "",
            "email": email
        };
    }

    session = await _resolve_learner_session(
        email.strip().lower(),
        "",
        email.strip().lower()
    );

    save_auth_session(session);

    return session;
}

def:pub logout_user() {
    jacLogout();
    clear_auth_session();
}
