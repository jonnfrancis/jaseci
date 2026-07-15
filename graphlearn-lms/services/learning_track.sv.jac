"""Thin typed read API for the shared learning-track catalogue."""

import from lib.learning_track.service {
    find_track,
    list_discoverable_tracks,
    resolve_learning_track,
    seed_builtin_tracks,
    track_detail
}
import from nodes.learning_track {
    LearningTrackDetail,
    LearningTrackError,
    LearningTrackMigrationReport,
    LearningTrackResult,
    LearningTrackSummary
}

obj LearningTrackResolutionView {
    has ok: bool;
    has track: LearningTrackSummary | None = None;
    has error: LearningTrackError | None = None;
}

def:pub list_learning_tracks -> list[LearningTrackSummary] {
    _ = seed_builtin_tracks();
    return list_discoverable_tracks();
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
    return seed_builtin_tracks();
}
