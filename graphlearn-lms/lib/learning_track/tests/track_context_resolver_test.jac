"""Feature 34 authoritative track-context resolver tests."""

import from lib.learning_track.context_resolver {
    ResolveTrackContextInput, TrackContext, resolve_track_context, track_response_meta
}
import from lib.learning_track.service { seed_builtin_tracks }
import from nodes.learner { Learner }
import from nodes.roadmap { Roadmap, RoadmapStatus }

test "explicit and legacy context resolve to normalized metadata" {
    _ = seed_builtin_tracks();
    explicit = resolve_track_context(ResolveTrackContextInput(
        track_id="trk_builtin_python",
        track_version_id="trv_builtin_python_v1",
        language="python"
    ));
    assert explicit.ok and explicit.value is not None;
    context = explicit.value as TrackContext;
    assert context.resolution_source == "EXPLICIT_TRACK_AND_VERSION";
    assert context.is_published;
    meta = track_response_meta(context);
    assert meta.track_id == "trk_builtin_python";
    assert meta.track_version_id == "trv_builtin_python_v1";

    legacy = resolve_track_context(ResolveTrackContextInput(language="Jac"));
    assert legacy.ok and legacy.value is not None;
    assert (legacy.value as TrackContext).resolution_source == "LEGACY_LANGUAGE";
}

test "parent entity is authoritative and conflicts are rejected" {
    _ = seed_builtin_tracks();
    learner_id = "resolver-learner";
    root ++> Learner(id=learner_id, name="Resolver", createdAt="now", updatedAt="now");
    root ++> Roadmap(
        id="resolver-roadmap",
        learner_id=learner_id,
        language="python",
        title="Python",
        description="",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="now",
        assessment_id="assessment",
        assessment_attempt_id="attempt",
        assessment_evaluation_id="evaluation",
        track_id="trk_builtin_python",
        track_version_id="trv_builtin_python_v1"
    );
    resolved = resolve_track_context(ResolveTrackContextInput(
        learner_id=learner_id,
        roadmap_id="resolver-roadmap"
    ));
    assert resolved.ok and resolved.value is not None;
    assert (resolved.value as TrackContext).resolution_source == "PARENT_ENTITY";

    conflict = resolve_track_context(ResolveTrackContextInput(
        learner_id=learner_id,
        roadmap_id="resolver-roadmap",
        track_id="trk_builtin_jaseci",
        track_version_id="trv_builtin_jaseci_v1"
    ));
    assert not conflict.ok and conflict.error is not None;
    assert conflict.error.code == "TRACK_CONTEXT_CONFLICT";
}

test "parent entity rejects learner spoofing" {
    _ = seed_builtin_tracks();
    root ++> Roadmap(
        id="owned-roadmap",
        learner_id="owner-learner",
        language="python",
        title="Python",
        description="",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="now",
        assessment_id="assessment",
        assessment_attempt_id="attempt",
        assessment_evaluation_id="evaluation",
        track_id="trk_builtin_python",
        track_version_id="trv_builtin_python_v1"
    );
    result = resolve_track_context(ResolveTrackContextInput(
        learner_id="attacker",
        roadmap_id="owned-roadmap"
    ));
    assert not result.ok and result.error is not None;
    assert result.error.code == "LEARNER_CONTEXT_MISMATCH";
}
