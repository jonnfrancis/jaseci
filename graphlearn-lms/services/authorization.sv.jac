"""Authenticated, policy-filtered lecturer authorization API."""

import from lib.authorization.actor { resolve_authorization_actor }
import from lib.authorization.policy { AuthorizationPolicyService }
import from lib.authorization.repositories { migrate_current_lecturer_ownership, track_resource_context }
import from lib.learning_track.repositories { repository_list_owned }
import from lib.learning_track.repository_types { PageRequest }
import from nodes.authorization { AuthorizationDecisionType, LecturerPermission, OwnershipMigrationReport }
import from nodes.learning_track { LearningTrack, LearningTrackSummary }

def _track_summary(track: LearningTrack) -> LearningTrackSummary {
    return LearningTrackSummary(
        track_id=track.track_id, slug=track.slug, title=track.title,
        short_description=track.short_description, track_type=track.track_type,
        status=track.status, visibility=track.visibility, course_code=track.course_code,
        subject_area=track.subject_area, active_version_id=track.active_version_id,
        is_enrollment_open=track.is_enrollment_open
    );
}

def:priv list_my_authorized_tracks(limit: int = 50, cursor: str | None = None) -> list[LearningTrackSummary] {
    actor = resolve_authorization_actor(); policy = AuthorizationPolicyService();
    list_decision = policy.authorize_lecturer_action(actor, LecturerPermission.LIST_OWN_TRACKS, None);
    if list_decision.decision == AuthorizationDecisionType.DENY or actor.lecturer_id is None { return []; }
    page = repository_list_owned(actor.lecturer_id, PageRequest(limit=limit, cursor=cursor));
    visible: list[LearningTrackSummary] = [];
    for item in page.items {
        if isinstance(item, LearningTrack) {
            context = track_resource_context(item.track_id, actor.lecturer_id);
            if context is not None {
                decision = policy.authorize_lecturer_action(actor, LecturerPermission.VIEW_TRACK, context);
                if decision.decision == AuthorizationDecisionType.ALLOW { visible.append(_track_summary(item)); }
            }
        }
    }
    return visible;
}

def:priv migrate_my_lecturer_track_ownership -> OwnershipMigrationReport {
    actor = resolve_authorization_actor();
    decision = AuthorizationPolicyService().authorize_lecturer_action(actor, LecturerPermission.LIST_OWN_TRACKS, None);
    if decision.decision == AuthorizationDecisionType.DENY { return OwnershipMigrationReport(skipped=1); }
    return migrate_current_lecturer_ownership();
}
