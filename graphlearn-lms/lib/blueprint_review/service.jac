"""Feature 49 lecturer blueprint review domain services."""
import datetime;
import json;
import uuid;
import from lib.blueprint_review.repositories { BlueprintReviewRepository }
import from lib.blueprint_validation.repositories { BlueprintValidationRepository }
import from lib.blueprint_validation.service { BlueprintValidationService }
import from lib.course_blueprint.repositories { CourseBlueprintRepository }
import from lib.curriculum_graph.repositories { CurriculumGraphRepository }
import from lib.curriculum_graph.service { TopicSkillGraphGenerationService }
import from lib.learning_track.repositories { repository_find_track, repository_find_version }
import from nodes.curriculum { BlueprintApproval, BlueprintApprovalRequest, BlueprintApprovalStatus, BlueprintConcept, BlueprintEntityPatchRequest, BlueprintEvidenceRef, BlueprintGraphIdMap, BlueprintLearningOutcomeNode, BlueprintModule, BlueprintPrerequisite, BlueprintReviewChange, BlueprintReviewChangeType, BlueprintReviewSession, BlueprintReviewStatus, BlueprintValidationContext, BlueprintValidationIssue, BlueprintValidationReport, BlueprintValidationSeverity, BlueprintValidationStatus, CourseBlueprint, GraphGenerationContext, LecturerBlueprintReviewView, ReviewConceptView, ReviewModuleView, ReviewOutcomeView, ReviewPrerequisiteView, ReviewValidationSummary }
import from nodes.learning_track { LearningTrack, TrackVersion, TrackVersionStatus }

def _now -> str { return datetime.datetime.now(datetime.timezone.utc).isoformat(); }
def _fail(code: str) { raise ValueError(code); }
def _string_list(raw: str) -> list[str] { try { return json.loads(raw) as list[str]; } except Exception { return []; } }

obj LecturerBlueprintReviewService {
    has blueprint_repository: CourseBlueprintRepository = CourseBlueprintRepository();
    has review_repository: BlueprintReviewRepository = BlueprintReviewRepository();
    has validation_repository: BlueprintValidationRepository = BlueprintValidationRepository();
    has graph_repository: CurriculumGraphRepository = CurriculumGraphRepository();

    def _load(track_id: str, track_version_id: str, blueprint_id: str | None = None) -> tuple[LearningTrack, TrackVersion, CourseBlueprint] {
        track = repository_find_track(track_id); if track is None { _fail("BLUEPRINT_REVIEW_NOT_READY"); }
        version = repository_find_version(track as LearningTrack, track_version_id); if version is None or version.status in [TrackVersionStatus.PUBLISHED, TrackVersionStatus.SUPERSEDED, TrackVersionStatus.ARCHIVED] { _fail("BLUEPRINT_REVIEW_NOT_READY"); }
        blueprint = self.blueprint_repository.find_active_for_version(version as TrackVersion) if blueprint_id is None else self.blueprint_repository.find_by_id(version as TrackVersion, blueprint_id as str);
        if blueprint is None or not blueprint.is_active { _fail("BLUEPRINT_REVIEW_SUPERSEDED"); }
        return (track as LearningTrack, version as TrackVersion, blueprint as CourseBlueprint);
    }

    def _session(blueprint: CourseBlueprint, lecturer_id: str) -> BlueprintReviewSession {
        current = self.review_repository.current(blueprint);
        if current is not None { return current as BlueprintReviewSession; }
        report = self.validation_repository.find_latest_report(blueprint);
        if report is None or not report.eligible_for_review or report.status not in [BlueprintValidationStatus.VALID, BlueprintValidationStatus.VALID_WITH_WARNINGS] { _fail("BLUEPRINT_REVIEW_NOT_READY"); }
        now = _now(); item = BlueprintReviewSession(review_session_id="brs_" + uuid.uuid4().hex, blueprint_id=blueprint.blueprint_id, track_id=blueprint.track_id, track_version_id=blueprint.track_version_id, lecturer_id=lecturer_id, status=BlueprintReviewStatus.READY_FOR_REVIEW, blueprint_revision=1, started_at=now, updated_at=now, last_validation_report_id=report.validation_report_id);
        if not self.review_repository.save_session(blueprint, item) { _fail("BLUEPRINT_REVIEW_INTERNAL_ERROR"); }
        return item;
    }

    def _issues(report: BlueprintValidationReport | None, entity_type: str, entity_key: str) -> list[str] { if report is None { return []; } return [i.message for i in self.validation_repository.list_issues(report as BlueprintValidationReport) if (i.blueprint_entity_type or "").upper() == entity_type and i.blueprint_entity_key == entity_key]; }
    def _view(blueprint: CourseBlueprint, session: BlueprintReviewSession) -> LecturerBlueprintReviewView {
        report = self.validation_repository.find_latest_report(blueprint); issues = self.validation_repository.list_issues(report as BlueprintValidationReport) if report is not None else [];
        blocking = [i.code for i in issues if i.severity in [BlueprintValidationSeverity.ERROR, BlueprintValidationSeverity.CRITICAL]];
        summary = ReviewValidationSummary(status=str(report.status) if report is not None else "NOT_VALIDATED", source_coverage_ratio=report.source_coverage_ratio if report is not None else 0.0, concept_coverage_ratio=report.concept_coverage_ratio if report is not None else 0.0, module_coverage_ratio=report.module_coverage_ratio if report is not None else 0.0, grounding_ratio=report.grounding_ratio if report is not None else 0.0, warning_count=report.warning_count if report is not None else 0, blocking_issue_count=len(blocking), blocking_issue_codes=blocking);
        modules: list[ReviewModuleView] = []; for item in self.blueprint_repository.list_modules(blueprint) { modules.append(ReviewModuleView(module_id=item.blueprint_module_id, local_module_key=item.local_module_key, title=item.title, description=item.description, order_index=item.order_index, concept_keys=_string_list(item.concept_keys_json), outcome_keys=_string_list(item.learning_outcome_keys_json), evidence=[], confidence=item.confidence, validation_issues=self._issues(report, "MODULE", item.local_module_key), edited_by_lecturer=item.edited_by_lecturer)); }
        concepts: list[ReviewConceptView] = []; for item in self.blueprint_repository.list_concepts(blueprint) { concepts.append(ReviewConceptView(concept_id=item.blueprint_concept_id, local_concept_key=item.local_concept_key, canonical_name=item.canonical_name, description=item.description, aliases=_string_list(item.aliases_json), key_terms=_string_list(item.key_terms_json), learning_objectives=_string_list(item.learning_objectives_json), evidence=[], confidence=item.confidence, validation_issues=self._issues(report, "CONCEPT", item.local_concept_key), edited_by_lecturer=item.edited_by_lecturer)); }
        outcomes: list[ReviewOutcomeView] = []; for item in self.blueprint_repository.list_outcomes(blueprint) { outcomes.append(ReviewOutcomeView(outcome_id=item.blueprint_outcome_id, local_outcome_key=item.local_outcome_key, statement=item.statement, level=item.level, evidence=[], validation_issues=self._issues(report, "OUTCOME", item.local_outcome_key), edited_by_lecturer=item.edited_by_lecturer)); }
        prerequisites: list[ReviewPrerequisiteView] = []; for item in self.blueprint_repository.list_prerequisites(blueprint) { prerequisites.append(ReviewPrerequisiteView(prerequisite_id=item.blueprint_prerequisite_id, prerequisite_concept_key=item.prerequisite_concept_key, dependent_concept_key=item.dependent_concept_key, strength=item.strength, rationale=item.rationale, confidence=item.confidence, evidence=[], validation_issues=self._issues(report, "PREREQUISITE", item.blueprint_prerequisite_id), edited_by_lecturer=item.edited_by_lecturer)); }
        eligible = report is not None and report.validation_report_id == session.last_validation_report_id and report.status in [BlueprintValidationStatus.VALID, BlueprintValidationStatus.VALID_WITH_WARNINGS] and len(blocking) == 0 and session.status != BlueprintReviewStatus.SUPERSEDED;
        return LecturerBlueprintReviewView(blueprint_id=blueprint.blueprint_id, review_status=session.status, blueprint_revision=session.blueprint_revision, course_title=blueprint.course_title, course_summary=blueprint.course_summary, modules=modules, concepts=concepts, outcomes=outcomes, prerequisites=prerequisites, validation_summary=summary, approval_available=eligible, warnings=_string_list(blueprint.warnings_json), review_session_id=session.review_session_id);
    }

    def get_review(track_id: str, track_version_id: str, lecturer_id: str) -> LecturerBlueprintReviewView { (_, _, blueprint) = self._load(track_id, track_version_id); return self._view(blueprint, self._session(blueprint, lecturer_id)); }

    def update_entity(track_id: str, track_version_id: str, actor_id: str, request: BlueprintEntityPatchRequest) -> LecturerBlueprintReviewView {
        (_, version, blueprint) = self._load(track_id, track_version_id, request.blueprint_id); session = self._session(blueprint, actor_id);
        if request.expected_revision != session.blueprint_revision { _fail("BLUEPRINT_REVIEW_REVISION_CONFLICT"); }
        if request.idempotency_key is not None and self.review_repository.find_idempotent_change(session, request.idempotency_key as str) is not None { return self._view(blueprint, session); }
        patch = json.loads(request.patch_json) as dict[str, any]; allowed: list[str] = []; entity: any = None;
        kind = request.entity_type.upper();
        if kind == "COURSE" { entity = blueprint; allowed = ["course_summary", "estimated_duration_weeks"]; }
        elif kind == "MODULE" { for item in self.blueprint_repository.list_modules(blueprint) { if item.local_module_key == request.entity_key { entity = item; } } allowed = ["title", "description", "order_index", "importance", "estimated_learning_hours"]; }
        elif kind == "CONCEPT" { for item in self.blueprint_repository.list_concepts(blueprint) { if item.local_concept_key == request.entity_key { entity = item; } } allowed = ["canonical_name", "description", "aliases_json", "learning_objectives_json", "key_terms_json", "should_be_taught_explicitly"]; }
        elif kind == "OUTCOME" { for item in self.blueprint_repository.list_outcomes(blueprint) { if item.local_outcome_key == request.entity_key { entity = item; } } allowed = ["statement", "level"]; }
        elif kind == "PREREQUISITE" { for item in self.blueprint_repository.list_prerequisites(blueprint) { if item.blueprint_prerequisite_id == request.entity_key { entity = item; } } allowed = ["strength", "rationale"]; }
        else { _fail("BLUEPRINT_REVIEW_ENTITY_NOT_FOUND"); }
        if entity is None { _fail("BLUEPRINT_REVIEW_ENTITY_NOT_FOUND"); }
        if len(patch) == 0 { _fail("BLUEPRINT_REVIEW_INVALID_PATCH"); }
        now = _now(); next_revision = session.blueprint_revision + 1;
        for field in patch { if field not in allowed { _fail("BLUEPRINT_REVIEW_FIELD_NOT_EDITABLE"); } old = getattr(entity, field); value = patch[field]; setattr(entity, field, value); self.review_repository.save_change(session, BlueprintReviewChange(change_id="brc_" + uuid.uuid4().hex, review_session_id=session.review_session_id, blueprint_id=blueprint.blueprint_id, actor_id=actor_id, entity_type=kind, entity_key=request.entity_key, field_name=field, old_value_json=json.dumps(old), new_value_json=json.dumps(value), change_type=str(BlueprintReviewChangeType.UPDATE_FIELD), created_at=now, revision=next_revision, idempotency_key=request.idempotency_key)); }
        if kind != "COURSE" { entity.edited_by_lecturer = True; entity.last_edited_at = now; entity.last_edited_by = actor_id; }
        blueprint.updated_at = now; blueprint.validation_status = str(BlueprintValidationStatus.NOT_VALIDATED); blueprint.approved_at = None; blueprint.approved_by = None; session.blueprint_revision = next_revision; session.status = BlueprintReviewStatus.IN_REVIEW; session.updated_at = now; session.approved_at = None; session.approved_by = None; session.last_validation_report_id = None;
        version.status = TrackVersionStatus.DRAFT;
        graph = TopicSkillGraphGenerationService().generate_graph(blueprint.blueprint_id, GraphGenerationContext(track_id=track_id, track_version_id=track_version_id, blueprint_id=blueprint.blueprint_id, request_id="review-revision-" + str(next_revision), actor_id=actor_id, force_regenerate=True));
        if graph.graph_generation_id is None { session.status = BlueprintReviewStatus.CHANGES_REQUIRED; _fail(graph.error_code or "BLUEPRINT_REVIEW_VALIDATION_FAILED"); }
        validation = BlueprintValidationService().validate_blueprint(blueprint.blueprint_id, BlueprintValidationContext(track_id=track_id, track_version_id=track_version_id, blueprint_id=blueprint.blueprint_id, graph_generation_id=graph.graph_generation_id, request_id="review-revision-" + str(next_revision), actor_id=actor_id, force_revalidate=True));
        session.last_validation_report_id = validation.validation_report_id; session.status = BlueprintReviewStatus.IN_REVIEW if validation.eligible_for_review else BlueprintReviewStatus.CHANGES_REQUIRED; session.updated_at = _now(); return self._view(blueprint, session);
    }

    def approve(track_id: str, track_version_id: str, actor_id: str, request: BlueprintApprovalRequest) -> BlueprintApproval {
        (_, version, blueprint) = self._load(track_id, track_version_id, request.blueprint_id); session = self._session(blueprint, actor_id); if request.expected_revision != session.blueprint_revision { _fail("BLUEPRINT_REVIEW_REVISION_CONFLICT"); }
        report = self.validation_repository.find_latest_report(blueprint); if report is None or report.validation_report_id != session.last_validation_report_id or report.status not in [BlueprintValidationStatus.VALID, BlueprintValidationStatus.VALID_WITH_WARNINGS] or not report.eligible_for_review or report.graph_generation_id is None { _fail("BLUEPRINT_REVIEW_APPROVAL_STALE"); }
        for issue in self.validation_repository.list_issues(report as BlueprintValidationReport) { if issue.severity in [BlueprintValidationSeverity.ERROR, BlueprintValidationSeverity.CRITICAL] { _fail("BLUEPRINT_REVIEW_APPROVAL_BLOCKED"); } }
        for existing in self.review_repository.approvals(session) { if existing.approved_revision == session.blueprint_revision and existing.validation_report_id == report.validation_report_id and existing.graph_generation_id == report.graph_generation_id and existing.status == BlueprintApprovalStatus.APPROVED { return existing; } }
        now = _now(); approval = BlueprintApproval(approval_id="bap_" + uuid.uuid4().hex, blueprint_id=blueprint.blueprint_id, track_version_id=track_version_id, approved_revision=session.blueprint_revision, approved_by=actor_id, approved_at=now, validation_report_id=report.validation_report_id, graph_generation_id=report.graph_generation_id as str, approval_note=request.approval_note); self.review_repository.save_approval(session, approval); session.status = BlueprintReviewStatus.APPROVED; session.approved_at = now; session.approved_by = actor_id; session.updated_at = now; blueprint.approved_at = now; blueprint.approved_by = actor_id; version.status = TrackVersionStatus.APPROVED; return approval;
    }
}
