"""Learning-track domain, lifecycle, catalogue, seed, and compatibility tests."""

import from edges.domain_edges { HAS_LEARNING_TRACK }
import from lib.learning_track.service {
    activate_published_version,
    can_discover,
    can_enroll,
    create_initial_version,
    create_track,
    default_catalogue,
    find_track,
    resolve_learning_track,
    seed_builtin_tracks,
    track_configuration,
    track_versions,
    transition_track_status,
    transition_version_status
}
import from nodes.learning_track {
    CreateLearningTrackInput,
    LearningTrack,
    LearningTrackStatus,
    LearningTrackType,
    LearningTrackVisibility,
    TrackOwnershipType,
    TrackVersionStatus
}

def _lecturer_input(title: str, duration: int | None = 10) -> CreateLearningTrackInput {
    return CreateLearningTrackInput(
        title=title,
        short_description="Lecturer-authored course notes.",
        track_type=LearningTrackType.LECTURER_COURSE,
        ownership_type=TrackOwnershipType.LECTURER,
        estimated_duration_weeks=duration
    );
}

test "creates a draft lecturer track with catalogue configuration" {
    result = create_track(_lecturer_input("Database Management Systems"), "lecturer-domain-test");
    assert result.ok and result.track is not None;
    track = result.track;
    assert track.track_id.startswith("trk_");
    assert track.slug.startswith("database-management-systems");
    assert track.status == LearningTrackStatus.DRAFT;
    assert track.visibility == LearningTrackVisibility.PRIVATE;
    assert not track.is_enrollment_open;
    assert track.owner_id == "lecturer-domain-test";
    assert track in [default_catalogue() ->:HAS_LEARNING_TRACK:->][?:LearningTrack];
    assert track_configuration(track) is not None;
}

test "rejects invalid lecturer track input" {
    empty = create_track(_lecturer_input("   "), "lecturer-validation-test");
    invalid_duration = create_track(_lecturer_input("Invalid Duration Course", 0), "lecturer-validation-test");
    invalid_owner = create_track(
        CreateLearningTrackInput(
            title="Invalid Owner Course",
            track_type=LearningTrackType.LECTURER_COURSE,
            ownership_type=TrackOwnershipType.SYSTEM
        ),
        "lecturer-validation-test"
    );
    assert not empty.ok and empty.error is not None and empty.error.code == "TRACK_VALIDATION_FAILED";
    assert not invalid_duration.ok and invalid_duration.error is not None and invalid_duration.error.code == "TRACK_VALIDATION_FAILED";
    assert not invalid_owner.ok and invalid_owner.error is not None and invalid_owner.error.code == "INVALID_TRACK_OWNER";
}

test "version lifecycle activates immutable published snapshot" {
    created = create_track(_lecturer_input("Version Lifecycle Course"), "lecturer-version-test");
    assert created.ok and created.track is not None;
    track = created.track;
    version_result = create_initial_version(track.track_id, "lecturer-version-test");
    assert version_result.ok and version_result.version is not None;
    version = version_result.version;
    assert version.version_number == 1 and track.current_version_number == 1;
    assert transition_version_status(track.track_id, version.track_version_id, TrackVersionStatus.REVIEW_REQUIRED, "lecturer-version-test").ok;
    assert transition_version_status(track.track_id, version.track_version_id, TrackVersionStatus.APPROVED, "lecturer-version-test").ok;
    assert transition_track_status(track.track_id, LearningTrackStatus.REVIEW_REQUIRED, "lecturer-version-test").ok;
    assert activate_published_version(track.track_id, version.track_version_id, "lecturer-version-test").ok;
    assert transition_track_status(track.track_id, LearningTrackStatus.PUBLISHED, "lecturer-version-test").ok;
    assert track.active_version_id == version.track_version_id;
    assert version.status == TrackVersionStatus.PUBLISHED;
    immutable = transition_version_status(track.track_id, version.track_version_id, TrackVersionStatus.REVIEW_REQUIRED, "lecturer-version-test");
    assert not immutable.ok and immutable.error is not None and immutable.error.code == "TRACK_VERSION_IMMUTABLE";
}

test "draft and archived tracks are not discoverable or enrollable" {
    created = create_track(_lecturer_input("Private Lifecycle Course"), "lecturer-private-test");
    assert created.ok and created.track is not None;
    track = created.track;
    assert not can_discover(track, "ordinary-learner");
    assert not can_enroll(track, "ordinary-learner");
    archived = transition_track_status(track.track_id, LearningTrackStatus.ARCHIVED, "lecturer-private-test");
    assert archived.ok and track.status == LearningTrackStatus.ARCHIVED;
    assert not can_enroll(track, "lecturer-private-test");
}

test "built in seeding is deterministic and idempotent" {
    first = seed_builtin_tracks();
    second = seed_builtin_tracks();
    python = find_track("trk_builtin_python");
    jaseci = find_track("trk_builtin_jaseci");
    assert python is not None and jaseci is not None;
    assert python.active_version_id == "trv_builtin_python_v1";
    assert jaseci.active_version_id == "trv_builtin_jaseci_v1";
    assert len(track_versions(python)) == 1;
    assert len(track_versions(jaseci)) == 1;
    assert second.tracks_existing == 2;
    assert second.tracks_created == 0 and second.versions_created == 0;
    assert first.records_failed == 0 and second.records_failed == 0;
}

test "legacy resolver normalizes aliases and prefers track id" {
    _ = seed_builtin_tracks();
    python = resolve_learning_track(None, "  Python  ");
    jac = resolve_learning_track(None, "JAC");
    jaseci = resolve_learning_track(None, "jaseci");
    precedence = resolve_learning_track("trk_builtin_python", "unknown");
    unknown = resolve_learning_track(None, "rust");
    missing = resolve_learning_track(None, None);
    assert python.ok and python.track is not None and python.track.track_id == "trk_builtin_python";
    assert jac.ok and jac.track is not None and jac.track.track_id == "trk_builtin_jaseci";
    assert jaseci.ok and jaseci.track is not None and jaseci.track.track_id == "trk_builtin_jaseci";
    assert precedence.ok and precedence.track is not None and precedence.track.track_id == "trk_builtin_python";
    assert not unknown.ok and not missing.ok;
}
