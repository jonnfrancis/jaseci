"""Typed catalogue and guarded programming-track migration API."""

import os;

import from lib.authorization.actor { resolve_authorization_actor }
import from lib.authorization.policy { AuthorizationPolicyService }

import from lib.learning_track.service {
    find_track,
    list_discoverable_tracks,
    resolve_learning_track,
    seed_builtin_tracks,
    track_detail
}
import from lib.learning_track.registry { BUILTIN_PROGRAMMING_TRACKS }
import from lib.learning_track.migration { rollback_programming_track_migration, run_programming_track_migration }
import from nodes.learning_track {
    LearningTrackDetail,
    LearningTrackError,
    LearningTrackMigrationReport,
    LearningTrackResult,
    LearningTrackSummary
}
import from nodes.programming_track_migration { ProgrammingTrackMigrationReport }
import from nodes.authorization { AdministrativePermission, AuthorizationDecisionType }

obj LearningTrackResolutionView {
    has ok: bool;
    has track: LearningTrackSummary | None = None;
    has error: LearningTrackError | None = None;
}

obj ProgrammingTrackOptionView {
    has track_id: str;
    has track_version_id: str;
    has slug: str;
    has title: str;
    has track_type: str;
    has legacy_language: str;
}

obj SupportedProgrammingTracksView {
    has languages: list[str];
    has tracks: list[ProgrammingTrackOptionView];
}

def:pub list_learning_tracks -> list[LearningTrackSummary] {
    _ = seed_builtin_tracks();
    return list_discoverable_tracks();
}

def:pub supported_programming_tracks -> SupportedProgrammingTracksView {
    _ = seed_builtin_tracks();
    languages: list[str] = [];
    tracks: list[ProgrammingTrackOptionView] = [];
    for definition in BUILTIN_PROGRAMMING_TRACKS {
        if definition.enabled {
            languages.append(definition.canonical_language);
            tracks.append(ProgrammingTrackOptionView(
                track_id=definition.track_id,
                track_version_id=definition.track_version_id,
                slug=definition.slug,
                title=definition.title,
                track_type="PROGRAMMING_LANGUAGE",
                legacy_language=definition.canonical_language
            ));
        }
    }
    return SupportedProgrammingTracksView(languages=languages, tracks=tracks);
}

def:pub get_learning_track(track_id: str) -> LearningTrackDetail | None {
    _ = seed_builtin_tracks();
    track = find_track(track_id.strip());
    if track is None { return None; }
    for summary in list_discoverable_tracks() {
        if summary.track_id == track.track_id { return track_detail(track); }
    }
    return None;
}

def:priv resolve_legacy_learning_track(track_id: str | None = None, language: str | None = None) -> LearningTrackResolutionView {
    _ = seed_builtin_tracks();
    result: LearningTrackResult = resolve_learning_track(track_id, language);
    if not result.ok or result.track is None {
        return LearningTrackResolutionView(ok=False, error=result.error);
    }
    track = result.track;
    return LearningTrackResolutionView(
        ok=True,
        track=LearningTrackSummary(
            track_id=track.track_id,
            slug=track.slug,
            title=track.title,
            short_description=track.short_description,
            track_type=track.track_type,
            status=track.status,
            visibility=track.visibility,
            course_code=track.course_code,
            subject_area=track.subject_area,
            active_version_id=track.active_version_id,
            is_enrollment_open=track.is_enrollment_open
        )
    );
}

def:priv migrate_learning_tracks -> LearningTrackMigrationReport {
    decision = AuthorizationPolicyService().authorize_admin_action(
        resolve_authorization_actor(), AdministrativePermission.REPAIR_RESOURCE_OWNERSHIP, None
    );
    if decision.decision == AuthorizationDecisionType.DENY { raise PermissionError("FORBIDDEN"); }
    return seed_builtin_tracks();
}

def:priv execute_programming_track_migration(mode: str = "dry_run", batch_size: int = 100, scope_learner_id: str = "") -> ProgrammingTrackMigrationReport {
    decision = AuthorizationPolicyService().authorize_admin_action(
        resolve_authorization_actor(), AdministrativePermission.REPAIR_RESOURCE_OWNERSHIP, None
    );
    if decision.decision == AuthorizationDecisionType.DENY { raise PermissionError("FORBIDDEN"); }
    if os.getenv("PROGRAMMING_TRACK_MIGRATION_ENABLED", "false").strip().lower() not in ["1", "true", "yes", "on"] {
        raise Exception("Programming-track migration is disabled.");
    }
    return run_programming_track_migration(mode, batch_size, scope_learner_id);
}

def:priv rollback_programming_track_migration_v1() -> ProgrammingTrackMigrationReport {
    decision = AuthorizationPolicyService().authorize_admin_action(
        resolve_authorization_actor(), AdministrativePermission.REPAIR_RESOURCE_OWNERSHIP, None
    );
    if decision.decision == AuthorizationDecisionType.DENY { raise PermissionError("FORBIDDEN"); }
    if os.getenv("PROGRAMMING_TRACK_MIGRATION_ENABLED", "false").strip().lower() not in ["1", "true", "yes", "on"] {
        raise Exception("Programming-track migration is disabled.");
    }
    return rollback_programming_track_migration();
}
