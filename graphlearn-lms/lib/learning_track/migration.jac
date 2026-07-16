"""Dry-run, apply, report, and rollback for programming-track references."""

import from datetime { datetime, timezone }
import from edges.domain_edges { HAS_TRACK_CONFIGURATION, HAS_TRACK_VERSION }
import from lib.learning_track.registry { builtin_track_by_language, normalize_legacy_language }
import from lib.learning_track.service {
    find_track_readonly,
    resolve_track_context,
    seed_builtin_programming_tracks,
    track_configuration,
    track_versions
}
import from lib.observability.events { ObservabilityEvent }
import from lib.observability.logger { emit_event }
import from nodes.assessment { Assessment, AssessmentAttempt, AssessmentEvaluation }
import from nodes.challenge { ChallengeSubmission, GeneratedChallenge, SubmissionEvaluation }
import from nodes.learner { Learner }
import from nodes.lesson { GeneratedLesson }
import from nodes.mastery { MasteryEvidence, MasteryUpdateResult, SkillMastery }
import from nodes.programming_track_migration {
    HAS_MIGRATION_RECORD,
    ProgrammingTrackMigrationLedger,
    ProgrammingTrackMigrationRecord,
    ProgrammingTrackMigrationReport,
    TrackContext
}
import from nodes.progression { LessonProgress, ProgressionEvent, RoadmapProgress }
import from nodes.roadmap { Roadmap, RoadmapLesson, RoadmapMilestone, RoadmapWeek }

glob PROGRAMMING_TRACK_MIGRATION_VERSION: int = 1;
glob PROGRAMMING_TRACK_MIGRATION_NAME: str = "programming-track-migration";

def _now -> str {
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z");
}

def _event(name: str, status: str, attributes: dict[str, object] | None = None) {
    safe_attributes: dict[str, object] = {} if attributes is None else attributes;
    emit_event(ObservabilityEvent(
        timestamp=_now(), level="info", event=name, status=status,
        message=name, request_id="", correlation_id="", attributes=safe_attributes
    ));
}

def _empty_report(mode: str) -> ProgrammingTrackMigrationReport {
    timestamp = _now();
    return ProgrammingTrackMigrationReport(
        migration=PROGRAMMING_TRACK_MIGRATION_NAME,
        version=PROGRAMMING_TRACK_MIGRATION_VERSION,
        mode=mode,
        status="running",
        started_at=timestamp,
        completed_at=""
    );
}

def _ledger(create: bool) -> ProgrammingTrackMigrationLedger | None {
    for ledger in [root -->][?:ProgrammingTrackMigrationLedger] {
        if ledger.migration_name == PROGRAMMING_TRACK_MIGRATION_NAME and ledger.migration_version == PROGRAMMING_TRACK_MIGRATION_VERSION {
            return ledger;
        }
    }
    if not create { return None; }
    timestamp = _now();
    return (root ++> ProgrammingTrackMigrationLedger(created_at=timestamp, updated_at=timestamp))[0];
}

def _existing_record(entity_type: str, entity_id: str) -> ProgrammingTrackMigrationRecord | None {
    ledger = _ledger(False);
    if ledger is None { return None; }
    for record in [ledger ->:HAS_MIGRATION_RECORD:->][?:ProgrammingTrackMigrationRecord] {
        if record.entity_type == entity_type and record.entity_id == entity_id { return record; }
    }
    return None;
}

def _write_record(
    entity_type: str,
    entity_id: str,
    status: str,
    previous_language: str | None,
    previous_track_id: str | None,
    previous_track_version_id: str | None,
    context: TrackContext | None,
    message: str
) {
    existing = _existing_record(entity_type, entity_id);
    if existing is not None and existing.status != "ROLLED_BACK" { return; }
    ledger = _ledger(True);
    if ledger is None { return; }
    assigned_track_id = context.track_id if context is not None else None;
    assigned_version_id = context.track_version_id if context is not None else None;
    timestamp = _now();
    if existing is not None {
        existing.status = status;
        existing.message = message;
        existing.previous_language = previous_language;
        existing.previous_track_id = previous_track_id;
        existing.previous_track_version_id = previous_track_version_id;
        existing.assigned_track_id = assigned_track_id;
        existing.assigned_track_version_id = assigned_version_id;
        existing.migrated_at = timestamp;
        return;
    }
    ledger +>:HAS_MIGRATION_RECORD:+> ProgrammingTrackMigrationRecord(
        migration_id=f"ptm-v1-{entity_type}-{entity_id}",
        migration_version=PROGRAMMING_TRACK_MIGRATION_VERSION,
        entity_type=entity_type,
        entity_id=entity_id,
        status=status,
        message=message,
        previous_language=previous_language,
        previous_track_id=previous_track_id,
        previous_track_version_id=previous_track_version_id,
        assigned_track_id=assigned_track_id,
        assigned_track_version_id=assigned_version_id,
        migrated_at=timestamp
    );
    ledger.updated_at = timestamp;
}

def _preview_context(track_id: str | None, track_version_id: str | None, language: str | None) -> TrackContext | None {
    if track_id is not None and track_id.strip() != "" {
        track = find_track_readonly(track_id.strip());
        if track is None { return None; }
        version_id = track_version_id.strip() if track_version_id is not None else "";
        if version_id == "" and track.active_version_id is not None { version_id = track.active_version_id; }
        if version_id == "" { return None; }
        for version in track_versions(track) {
            if version.track_version_id == version_id and version.track_id == track.track_id {
                definition = builtin_track_by_language(language);
                if definition is not None and definition.track_id != track.track_id { return None; }
                return TrackContext(track.track_id, version.track_version_id, track.title, definition.canonical_language if definition is not None else None, "TRACK_ID");
            }
        }
        return None;
    }
    definition = builtin_track_by_language(language);
    if definition is None { return None; }
    return TrackContext(definition.track_id, definition.track_version_id, definition.title, definition.canonical_language, "LEGACY_PREVIEW");
}

def _context(track_id: str | None, track_version_id: str | None, language: str | None, dry_run: bool) -> TrackContext | None {
    return _preview_context(track_id, track_version_id, language) if dry_run else resolve_track_context(track_id, track_version_id, language);
}

def _count_unresolved(report_value: ProgrammingTrackMigrationReport, value: str | None, entity_id: str) {
    report_value.records_unresolved += 1;
    if value is not None and value.strip() != "" and value not in report_value.unresolved_values { report_value.unresolved_values.append(value); }
    _event("programming_track_migration.record_unresolved", "warning", {"entity_id": entity_id});
}

def _count_conflict(report_value: ProgrammingTrackMigrationReport, entity_id: str) {
    report_value.records_conflicts += 1;
    report_value.conflict_ids.append(entity_id);
    _event("programming_track_migration.conflict_detected", "warning", {"entity_id": entity_id});
}

def _apply_roadmap(roadmap: Roadmap, context: TrackContext, dry_run: bool, report_value: ProgrammingTrackMigrationReport) {
    report_value.records_migratable += 1;
    if roadmap.track_id == context.track_id and roadmap.track_version_id == context.track_version_id {
        report_value.records_unchanged += 1;
        return;
    }
    if not dry_run {
        old_track_id = roadmap.track_id;
        old_version_id = roadmap.track_version_id;
        roadmap.track_id = context.track_id;
        roadmap.track_version_id = context.track_version_id;
        _write_record("Roadmap", roadmap.id, "MIGRATED", roadmap.language, old_track_id, old_version_id, context, "Resolved from the roadmap's historical language.");
        for week in roadmap.weeks {
            old_week_track_id = week.track_id; old_week_version_id = week.track_version_id;
            week.track_id = context.track_id; week.track_version_id = context.track_version_id;
            _write_record("RoadmapWeek", week.id, "MIGRATED", None, old_week_track_id, old_week_version_id, context, "Inherited from roadmap.");
            for lesson in week.lessons {
                old_lesson_track_id = lesson.track_id; old_lesson_version_id = lesson.track_version_id;
                lesson.track_id = context.track_id; lesson.track_version_id = context.track_version_id;
                _write_record("RoadmapLesson", lesson.id, "MIGRATED", None, old_lesson_track_id, old_lesson_version_id, context, "Inherited from roadmap week.");
            }
            for milestone in week.milestones {
                old_milestone_track_id = milestone.track_id; old_milestone_version_id = milestone.track_version_id;
                milestone.track_id = context.track_id; milestone.track_version_id = context.track_version_id;
                _write_record("RoadmapMilestone", milestone.id, "MIGRATED", None, old_milestone_track_id, old_milestone_version_id, context, "Inherited from roadmap week.");
            }
        }
        _event("programming_track_migration.record_migrated", "success", {"entity_type": "Roadmap", "entity_id": roadmap.id});
    }
    report_value.records_migrated += 1;
}

def _inherit_assessment(assessment: Assessment, context: TrackContext, dry_run: bool, report_value: ProgrammingTrackMigrationReport) {
    report_value.records_scanned += 1;
    if assessment.track_id is not None and assessment.track_id != context.track_id { _count_conflict(report_value, assessment.id); return; }
    if assessment.track_id == context.track_id and assessment.track_version_id == context.track_version_id { report_value.records_unchanged += 1; return; }
    report_value.records_migratable += 1;
    if not dry_run {
        old_track_id = assessment.track_id; old_version_id = assessment.track_version_id;
        assessment.track_id = context.track_id; assessment.track_version_id = context.track_version_id;
        _write_record("Assessment", assessment.id, "MIGRATED", None, old_track_id, old_version_id, context, "Inherited from the unambiguous historical roadmap.");
    }
    report_value.records_migrated += 1;
}

def _apply_related(roadmap: Roadmap, context: TrackContext, dry_run: bool, report_value: ProgrammingTrackMigrationReport) {
    for assessment in [root -->][?:Assessment] {
        if assessment.id == roadmap.assessment_id { _inherit_assessment(assessment, context, dry_run, report_value); }
    }
    for attempt in [root -->][?:AssessmentAttempt] {
        if attempt.assessment_id == roadmap.assessment_id {
            report_value.records_scanned += 1;
            if attempt.track_id is not None and attempt.track_id != context.track_id { _count_conflict(report_value, attempt.id); }
            elif attempt.track_id == context.track_id and attempt.track_version_id == context.track_version_id { report_value.records_unchanged += 1; }
            else {
                report_value.records_migratable += 1; report_value.records_migrated += 1;
                if not dry_run { old_t = attempt.track_id; old_v = attempt.track_version_id; attempt.track_id = context.track_id; attempt.track_version_id = context.track_version_id; _write_record("AssessmentAttempt", attempt.id, "MIGRATED", None, old_t, old_v, context, "Inherited from assessment journey."); }
            }
        }
    }
    for evaluation in [root -->][?:AssessmentEvaluation] {
        if evaluation.assessment_id == roadmap.assessment_id {
            report_value.records_scanned += 1;
            if evaluation.track_id is not None and evaluation.track_id != context.track_id { _count_conflict(report_value, evaluation.id); }
            elif evaluation.track_id == context.track_id and evaluation.track_version_id == context.track_version_id { report_value.records_unchanged += 1; }
            else {
                report_value.records_migratable += 1; report_value.records_migrated += 1;
                if not dry_run { old_t = evaluation.track_id; old_v = evaluation.track_version_id; evaluation.track_id = context.track_id; evaluation.track_version_id = context.track_version_id; _write_record("AssessmentEvaluation", evaluation.id, "MIGRATED", None, old_t, old_v, context, "Inherited from assessment journey."); }
            }
        }
    }
    for lesson in [root -->][?:GeneratedLesson] {
        if lesson.roadmap_id == roadmap.id { _assign_generated_lesson(lesson, context, dry_run, report_value); }
    }
    for challenge in [root -->][?:GeneratedChallenge] {
        if challenge.roadmap_id == roadmap.id { _assign_generated_challenge(challenge, context, dry_run, report_value); }
    }
    for progress in [root -->][?:LessonProgress] {
        if progress.roadmap_id == roadmap.id { _assign_lesson_progress(progress, context, dry_run, report_value); }
    }
    for progress in [root -->][?:RoadmapProgress] {
        if progress.roadmap_id == roadmap.id { _assign_roadmap_progress(progress, context, dry_run, report_value); }
    }
    for event in [root -->][?:ProgressionEvent] {
        if event.roadmap_id == roadmap.id { _assign_progression_event(event, context, dry_run, report_value); }
    }
}

def _assign_generated_lesson(entity: GeneratedLesson, context: TrackContext, dry_run: bool, report_value: ProgrammingTrackMigrationReport) {
    report_value.records_scanned += 1;
    if entity.track_id is not None and entity.track_id != context.track_id { _count_conflict(report_value, entity.id); return; }
    if entity.track_id == context.track_id and entity.track_version_id == context.track_version_id { report_value.records_unchanged += 1; return; }
    report_value.records_migratable += 1; report_value.records_migrated += 1;
    if not dry_run { old_t = entity.track_id; old_v = entity.track_version_id; entity.track_id = context.track_id; entity.track_version_id = context.track_version_id; _write_record("GeneratedLesson", entity.id, "MIGRATED", entity.language, old_t, old_v, context, "Inherited from roadmap."); }
}

def _assign_generated_challenge(entity: GeneratedChallenge, context: TrackContext, dry_run: bool, report_value: ProgrammingTrackMigrationReport) {
    report_value.records_scanned += 1;
    if entity.track_id is not None and entity.track_id != context.track_id { _count_conflict(report_value, entity.id); return; }
    if entity.track_id == context.track_id and entity.track_version_id == context.track_version_id { report_value.records_unchanged += 1; return; }
    report_value.records_migratable += 1; report_value.records_migrated += 1;
    if not dry_run { old_t = entity.track_id; old_v = entity.track_version_id; entity.track_id = context.track_id; entity.track_version_id = context.track_version_id; _write_record("GeneratedChallenge", entity.id, "MIGRATED", entity.language, old_t, old_v, context, "Inherited from roadmap."); }
    for submission in [root -->][?:ChallengeSubmission] { if submission.challenge_id == entity.id { _assign_submission(submission, context, dry_run, report_value); } }
    for evaluation in [root -->][?:SubmissionEvaluation] { if evaluation.challenge_id == entity.id { _assign_submission_evaluation(evaluation, context, dry_run, report_value); } }
}

def _assign_submission(entity: ChallengeSubmission, context: TrackContext, dry_run: bool, report_value: ProgrammingTrackMigrationReport) {
    report_value.records_scanned += 1;
    if entity.track_id is not None and entity.track_id != context.track_id { _count_conflict(report_value, entity.id); return; }
    if entity.track_id == context.track_id and entity.track_version_id == context.track_version_id { report_value.records_unchanged += 1; return; }
    report_value.records_migratable += 1; report_value.records_migrated += 1;
    if not dry_run { old_t = entity.track_id; old_v = entity.track_version_id; entity.track_id = context.track_id; entity.track_version_id = context.track_version_id; _write_record("ChallengeSubmission", entity.id, "MIGRATED", entity.language, old_t, old_v, context, "Inherited from challenge."); }
}

def _assign_submission_evaluation(entity: SubmissionEvaluation, context: TrackContext, dry_run: bool, report_value: ProgrammingTrackMigrationReport) {
    report_value.records_scanned += 1;
    if entity.track_id is not None and entity.track_id != context.track_id { _count_conflict(report_value, entity.id); return; }
    if entity.track_id == context.track_id and entity.track_version_id == context.track_version_id { report_value.records_unchanged += 1; return; }
    report_value.records_migratable += 1; report_value.records_migrated += 1;
    if not dry_run { old_t = entity.track_id; old_v = entity.track_version_id; entity.track_id = context.track_id; entity.track_version_id = context.track_version_id; _write_record("SubmissionEvaluation", entity.id, "MIGRATED", entity.language, old_t, old_v, context, "Inherited from challenge."); }
}

def _assign_lesson_progress(entity: LessonProgress, context: TrackContext, dry_run: bool, report_value: ProgrammingTrackMigrationReport) {
    report_value.records_scanned += 1; report_value.records_migratable += 1;
    if entity.track_id == context.track_id and entity.track_version_id == context.track_version_id { report_value.records_migratable -= 1; report_value.records_unchanged += 1; return; }
    if entity.track_id is not None and entity.track_id != context.track_id { report_value.records_migratable -= 1; _count_conflict(report_value, entity.id); return; }
    report_value.records_migrated += 1;
    if not dry_run { old_t = entity.track_id; old_v = entity.track_version_id; entity.track_id = context.track_id; entity.track_version_id = context.track_version_id; _write_record("LessonProgress", entity.id, "MIGRATED", None, old_t, old_v, context, "Inherited from roadmap."); }
}

def _assign_roadmap_progress(entity: RoadmapProgress, context: TrackContext, dry_run: bool, report_value: ProgrammingTrackMigrationReport) {
    report_value.records_scanned += 1;
    if entity.track_id == context.track_id and entity.track_version_id == context.track_version_id { report_value.records_unchanged += 1; return; }
    if entity.track_id is not None and entity.track_id != context.track_id { _count_conflict(report_value, entity.id); return; }
    report_value.records_migratable += 1; report_value.records_migrated += 1;
    if not dry_run { old_t = entity.track_id; old_v = entity.track_version_id; entity.track_id = context.track_id; entity.track_version_id = context.track_version_id; _write_record("RoadmapProgress", entity.id, "MIGRATED", None, old_t, old_v, context, "Inherited from roadmap."); }
}

def _assign_progression_event(entity: ProgressionEvent, context: TrackContext, dry_run: bool, report_value: ProgrammingTrackMigrationReport) {
    report_value.records_scanned += 1;
    if entity.track_id == context.track_id and entity.track_version_id == context.track_version_id { report_value.records_unchanged += 1; return; }
    if entity.track_id is not None and entity.track_id != context.track_id { _count_conflict(report_value, entity.id); return; }
    report_value.records_migratable += 1; report_value.records_migrated += 1;
    if not dry_run { old_t = entity.track_id; old_v = entity.track_version_id; entity.track_id = context.track_id; entity.track_version_id = context.track_version_id; _write_record("ProgressionEvent", entity.id, "MIGRATED", None, old_t, old_v, context, "Inherited from roadmap."); }
}

def run_programming_track_migration(mode: str = "dry_run", batch_size: int = 100, scope_learner_id: str = "") -> ProgrammingTrackMigrationReport {
    normalized_mode = mode.strip().lower();
    report_value = _empty_report(normalized_mode);
    if normalized_mode not in ["dry_run", "apply"] or batch_size <= 0 {
        report_value.status = "failed"; report_value.records_failed = 1; report_value.completed_at = _now(); return report_value;
    }
    dry_run = normalized_mode == "dry_run";
    _event("programming_track_migration.started", "started", {"mode": normalized_mode, "batch_size": batch_size});
    if not dry_run {
        seeded = seed_builtin_programming_tracks();
        report_value.tracks_created = seeded.created;
        report_value.tracks_reused = seeded.unchanged;
        report_value.tracks_repaired = seeded.repaired;
        report_value.tracks_failed = seeded.failed;
        if seeded.failed > 0 { report_value.status = "failed"; report_value.completed_at = _now(); _event("programming_track_migration.failed", "failure"); return report_value; }
    }

    processed = 0;
    for roadmap in [root -->][?:Roadmap] {
        if scope_learner_id != "" and roadmap.learner_id != scope_learner_id { continue; }
        report_value.records_scanned += 1;
        if processed >= batch_size { break; }
        context = _context(roadmap.track_id, roadmap.track_version_id, roadmap.language, dry_run);
        if context is None {
            normalized = normalize_legacy_language(roadmap.language);
            definition = builtin_track_by_language(normalized);
            if roadmap.track_id is not None and definition is not None and roadmap.track_id != definition.track_id { _count_conflict(report_value, roadmap.id); }
            else { _count_unresolved(report_value, roadmap.language, roadmap.id); }
            continue;
        }
        _apply_roadmap(roadmap, context, dry_run, report_value);
        _apply_related(roadmap, context, dry_run, report_value);
        processed += 1;
    }

    # Learners inherit only when their historical roadmaps resolve to one track.
    for learner in [root -->][?:Learner] {
        if scope_learner_id != "" and learner.id != scope_learner_id { continue; }
        report_value.records_scanned += 1;
        contexts: list[TrackContext] = [];
        for roadmap in [root -->][?:Roadmap] {
            if roadmap.learner_id == learner.id {
                candidate = _context(roadmap.track_id, roadmap.track_version_id, roadmap.language, dry_run);
                if candidate is not None and not any(item.track_id != candidate.track_id for item in contexts) { contexts.append(candidate); }
            }
        }
        if len(contexts) > 0 and not any(item.track_id != contexts[0].track_id for item in contexts) {
            context = contexts[0];
            if learner.track_id == context.track_id and learner.track_version_id == context.track_version_id { report_value.records_unchanged += 1; }
            elif learner.track_id is not None and learner.track_id != context.track_id { _count_conflict(report_value, learner.id); }
            else {
                report_value.records_migratable += 1; report_value.records_migrated += 1;
                if not dry_run { old_t = learner.track_id; old_v = learner.track_version_id; learner.track_id = context.track_id; learner.track_version_id = context.track_version_id; _write_record("Learner", learner.id, "MIGRATED", None, old_t, old_v, context, "Inherited from one unambiguous learner journey track."); }
            }
        }
    }
    report_value.status = "completed_with_warnings" if report_value.records_unresolved + report_value.records_conflicts > 0 else "completed";
    report_value.completed_at = _now();
    event_name = "programming_track_migration.dry_run_completed" if dry_run else "programming_track_migration.completed";
    _event(event_name, "success", {"scanned": report_value.records_scanned, "migrated": report_value.records_migrated, "unresolved": report_value.records_unresolved, "conflicts": report_value.records_conflicts});
    return report_value;
}

def rollback_programming_track_migration -> ProgrammingTrackMigrationReport {
    report_value = _empty_report("rollback");
    ledger = _ledger(False);
    if ledger is None { report_value.status = "completed"; report_value.completed_at = _now(); return report_value; }
    for record in [ledger ->:HAS_MIGRATION_RECORD:->][?:ProgrammingTrackMigrationRecord] {
        report_value.records_scanned += 1;
        if record.status == "ROLLED_BACK" { report_value.records_unchanged += 1; continue; }
        restored = _restore_record(record);
        if restored { record.status = "ROLLED_BACK"; report_value.records_migrated += 1; }
        else { record.status = "FAILED"; report_value.records_failed += 1; }
    }
    report_value.status = "completed" if report_value.records_failed == 0 else "completed_with_warnings";
    report_value.completed_at = _now();
    _event("programming_track_migration.rolled_back", "success", {"restored": report_value.records_migrated, "failed": report_value.records_failed});
    return report_value;
}

def _restore_record(record: ProgrammingTrackMigrationRecord) -> bool {
    if record.entity_type == "Roadmap" { for entity in [root -->][?:Roadmap] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "RoadmapWeek" { for entity in [root -->][?:RoadmapWeek] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "RoadmapLesson" { for entity in [root -->][?:RoadmapLesson] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "RoadmapMilestone" { for entity in [root -->][?:RoadmapMilestone] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "Assessment" { for entity in [root -->][?:Assessment] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "AssessmentAttempt" { for entity in [root -->][?:AssessmentAttempt] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "AssessmentEvaluation" { for entity in [root -->][?:AssessmentEvaluation] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "GeneratedLesson" { for entity in [root -->][?:GeneratedLesson] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "GeneratedChallenge" { for entity in [root -->][?:GeneratedChallenge] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "ChallengeSubmission" { for entity in [root -->][?:ChallengeSubmission] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "SubmissionEvaluation" { for entity in [root -->][?:SubmissionEvaluation] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "LessonProgress" { for entity in [root -->][?:LessonProgress] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "RoadmapProgress" { for entity in [root -->][?:RoadmapProgress] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "ProgressionEvent" { for entity in [root -->][?:ProgressionEvent] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    elif record.entity_type == "Learner" { for entity in [root -->][?:Learner] { if entity.id == record.entity_id { entity.track_id = record.previous_track_id; entity.track_version_id = record.previous_track_version_id; return True; } } }
    return False;
}
