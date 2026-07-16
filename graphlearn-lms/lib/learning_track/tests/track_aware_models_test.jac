"""Feature 31 model compatibility and shared track validation tests."""

import from lib.learning_track.service { seed_builtin_programming_tracks }
import from lib.learning_track.validation {
    copy_track_context_from_parent,
    validate_parent_child_track_match,
    validate_version_belongs_to_track
}
import from nodes.learner { Learner }
import from nodes.skill { Skill }
import from nodes.track_context { DashboardSnapshot, Recommendation, SkillMapSnapshot }

test "legacy models load with safe optional track defaults" {
    learner = Learner(id="legacy-learner", name="Legacy", createdAt="now", updatedAt="now");
    skill = Skill(id="legacy-skill", name="Variables", description="", category="fundamentals");
    assert learner.active_track_id is None and learner.track_id is None;
    assert skill.track_id is None and skill.track_version_id is None;
}

test "track version must belong to track" {
    _ = seed_builtin_programming_tracks();
    valid = validate_version_belongs_to_track("trk_builtin_python", "trv_builtin_python_v1");
    mismatch = validate_version_belongs_to_track("trk_builtin_python", "trv_builtin_jaseci_v1");
    assert valid.valid;
    assert not mismatch.valid and mismatch.error_code == "TRACK_VERSION_MISMATCH";
}

test "parent context is copied and cross-track children are rejected" {
    _ = seed_builtin_programming_tracks();
    copied = copy_track_context_from_parent("trk_builtin_python", "trv_builtin_python_v1");
    mismatch = validate_parent_child_track_match(
        "trk_builtin_python", "trv_builtin_python_v1",
        "trk_builtin_jaseci", "trv_builtin_jaseci_v1"
    );
    assert copied.valid and copied.track_id == "trk_builtin_python";
    assert not mismatch.valid and mismatch.error_code == "PARENT_TRACK_MISMATCH";
}

test "optional persisted projections carry isolated track context" {
    recommendation = Recommendation("rec-1", "learner-1", "NEXT_LESSON", "Continue", "ACTIVE", "now", "trk_builtin_python", "trv_builtin_python_v1");
    skill_map = SkillMapSnapshot("map-1", "learner-1", "{}", "now", "trk_builtin_python", "trv_builtin_python_v1");
    dashboard = DashboardSnapshot("dash-1", "learner-1", "{}", "now", "trk_builtin_jaseci", "trv_builtin_jaseci_v1");
    assert recommendation.track_version_id != dashboard.track_version_id;
    assert skill_map.track_id == recommendation.track_id;
}
