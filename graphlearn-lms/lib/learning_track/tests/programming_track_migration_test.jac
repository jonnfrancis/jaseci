"""Feature 30 registry, compatibility, seed, backfill, dry-run, and rollback tests."""

import from lib.learning_track.migration { rollback_programming_track_migration, run_programming_track_migration }
import from lib.learning_track.registry {
    BUILTIN_PROGRAMMING_TRACKS,
    builtin_track_by_language,
    normalize_legacy_language,
    registry_is_valid
}
import from lib.learning_track.service {
    find_track,
    resolve_legacy_programming_track,
    seed_builtin_programming_tracks,
    track_configuration,
    track_versions
}
import from nodes.assessment { Assessment, AssessmentStatus }
import from nodes.programming_track_migration { ProgrammingTrackMigrationLedger }
import from nodes.roadmap { Roadmap, RoadmapStatus }

test "canonical registry has unique deterministic identities and aliases" {
    assert registry_is_valid();
    assert len(BUILTIN_PROGRAMMING_TRACKS) == 2;
    assert BUILTIN_PROGRAMMING_TRACKS[0].track_id == "trk_builtin_python";
    assert BUILTIN_PROGRAMMING_TRACKS[1].track_id == "trk_builtin_jaseci";
    assert builtin_track_by_language("py") is not None;
    assert builtin_track_by_language("python3") is not None;
    assert builtin_track_by_language("jaclang") is not None;
}

test "normalizer and resolver use exact aliases without guessing" {
    _ = seed_builtin_programming_tracks();
    assert normalize_legacy_language(" Python ") == "python";
    assert normalize_legacy_language("  ") is None;
    python = resolve_legacy_programming_track(None, None, "PY");
    jaseci = resolve_legacy_programming_track(None, None, "JacLang");
    unknown = resolve_legacy_programming_track(None, None, "pythn");
    java = resolve_legacy_programming_track(None, None, "java");
    missing = resolve_legacy_programming_track(None, None, None);
    conflict = resolve_legacy_programming_track("trk_builtin_python", "trv_builtin_python_v1", "jac");
    assert python.resolved and python.track_id == "trk_builtin_python" and python.resolution_type == "ALIAS";
    assert jaseci.resolved and jaseci.track_id == "trk_builtin_jaseci";
    assert not unknown.resolved and unknown.resolution_type == "UNRESOLVED";
    assert not java.resolved and not missing.resolved and missing.resolution_type == "MISSING";
    assert not conflict.resolved and conflict.resolution_type == "CONFLICT";
}

test "seed creates complete deterministic graphs and reruns unchanged" {
    first = seed_builtin_programming_tracks();
    second = seed_builtin_programming_tracks();
    python = find_track("trk_builtin_python");
    jaseci = find_track("trk_builtin_jaseci");
    assert first.failed == 0 and second.failed == 0;
    assert second.unchanged == 2;
    assert python is not None and jaseci is not None;
    assert len(track_versions(python)) == 1 and len(track_versions(jaseci)) == 1;
    python_configuration = track_configuration(python);
    jaseci_configuration = track_configuration(jaseci);
    assert python_configuration is not None and python_configuration.configuration_id == "cfg_builtin_python";
    assert jaseci_configuration is not None and jaseci_configuration.configuration_id == "cfg_builtin_jaseci";
    assert python.active_version_id == "trv_builtin_python_v1" and python.is_enrollment_open;
}

test "dry run proposes historical roadmap backfill without mutation or markers" {
    assessment = (root ++> Assessment(
        id="migration-dry-assessment",
        learner_id="migration-dry-learner",
        title="Python historical assessment",
        description="Historical record",
        status=AssessmentStatus.completed,
        created_at="historical"
    ))[0];
    roadmap = (root ++> Roadmap(
        id="migration-dry-roadmap",
        learner_id="migration-dry-learner",
        language="python",
        title="Historical Python roadmap",
        description="Historical record",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="historical",
        assessment_id=assessment.id,
        assessment_attempt_id="migration-dry-attempt",
        assessment_evaluation_id="migration-dry-evaluation"
    ))[0];
    result = run_programming_track_migration("dry_run", 100, "migration-dry-learner");
    assert result.records_migrated >= 2;
    assert roadmap.track_id is None and assessment.track_id is None;
    assert len([root -->][?:ProgrammingTrackMigrationLedger]) == 0;
}

test "apply backfills related context idempotently and rollback restores fields" {
    _ = seed_builtin_programming_tracks();
    assessment = (root ++> Assessment(
        id="migration-apply-assessment",
        learner_id="migration-apply-learner",
        title="Jac historical assessment",
        description="Historical record",
        status=AssessmentStatus.completed,
        created_at="historical"
    ))[0];
    roadmap = (root ++> Roadmap(
        id="migration-apply-roadmap",
        learner_id="migration-apply-learner",
        language="jac",
        title="Historical Jac roadmap",
        description="Historical record",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="historical",
        assessment_id=assessment.id,
        assessment_attempt_id="migration-apply-attempt",
        assessment_evaluation_id="migration-apply-evaluation"
    ))[0];
    applied = run_programming_track_migration("apply", 100, "migration-apply-learner");
    assert applied.records_failed == 0;
    assert roadmap.track_id == "trk_builtin_jaseci" and roadmap.track_version_id == "trv_builtin_jaseci_v1";
    assert assessment.track_id == "trk_builtin_jaseci";
    rerun = run_programming_track_migration("apply", 100, "migration-apply-learner");
    assert rerun.records_failed == 0 and roadmap.track_id == "trk_builtin_jaseci";
    rolled_back = rollback_programming_track_migration();
    assert rolled_back.records_failed == 0;
    assert roadmap.track_id is None and roadmap.language == "jac";
    assert assessment.track_id is None;
}

test "dry run preserves conflicting historical identity" {
    _ = seed_builtin_programming_tracks();
    roadmap = (root ++> Roadmap(
        id="migration-conflict-roadmap",
        learner_id="migration-conflict-learner",
        language="jac",
        title="Conflicting roadmap",
        description="Historical conflict",
        estimated_weeks=1,
        status=RoadmapStatus.active,
        created_at="historical",
        assessment_id="migration-conflict-assessment",
        assessment_attempt_id="migration-conflict-attempt",
        assessment_evaluation_id="migration-conflict-evaluation",
        track_id="trk_builtin_python",
        track_version_id="trv_builtin_python_v1"
    ))[0];
    result = run_programming_track_migration("dry_run", 100, "migration-conflict-learner");
    assert result.records_conflicts >= 1;
    assert roadmap.track_id == "trk_builtin_python" and roadmap.language == "jac";
}
