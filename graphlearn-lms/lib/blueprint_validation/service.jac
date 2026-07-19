"""Deterministic blueprint grounding and review-readiness quality gate."""
import datetime;
import hashlib;
import json;
import re;
import unicodedata;
import uuid;
import from edges.domain_edges {
    HAS_CHUNK_SET,
    HAS_CONTENT_CHUNK,
    HAS_EXTRACTION,
    HAS_SOURCE_DOCUMENT
}
import from lib.blueprint_validation.observability {
    blueprint_validation_event,
    record_blueprint_validation
}
import from lib.blueprint_validation.repositories { BlueprintValidationRepository }
import from lib.course_blueprint.repositories { CourseBlueprintRepository }
import from lib.curriculum_graph.repositories { CurriculumGraphRepository }
import from lib.curriculum_graph.service { TopicSkillGraphGenerationService }
import from lib.learning_track.repositories {
    repository_find_track,
    repository_find_version
}
import from nodes.curriculum {
    BlueprintConcept,
    BlueprintGenerationStatus,
    BlueprintLearningOutcomeNode,
    BlueprintModule,
    BlueprintPrerequisite,
    BlueprintRepairAction,
    BlueprintValidationCategory,
    BlueprintValidationContext,
    BlueprintValidationIssue,
    BlueprintValidationReport,
    BlueprintValidationResult,
    BlueprintValidationSeverity,
    BlueprintValidationStatus,
    CourseBlueprint,
    CourseContentChunk,
    CourseDocument,
    CurriculumGraphGenerationRun,
    CurriculumGraphGenerationStatus,
    DocumentChunkSet,
    DocumentExtraction,
    PrerequisiteCycleResult
}
import from nodes.learning_track {
    LearningTrack,
    LearningTrackStatus,
    TrackVersion,
    TrackVersionStatus
}

glob BLUEPRINT_VALIDATION_SCHEMA_VERSION: int = 1;
glob BLUEPRINT_VALIDATOR_VERSION: str = "deterministic-v1";
glob ACTION_VERBS: list[str] = [
         "apply",
         "analyze",
         "compare",
         "create",
         "define",
         "demonstrate",
         "design",
         "evaluate",
         "explain",
         "identify",
         "implement",
         "solve",
         "use"
     ];

def _now -> str {
    return datetime.datetime.now(datetime.timezone.utc).isoformat();
}
def _hash(value: str) -> str {
    return hashlib.sha256(value.encode("utf-8")).hexdigest();
}
def _normalize(value: str) -> str {
    return " ".join(unicodedata.normalize("NFKC", value).casefold().strip().split());
}
def _tokens(value: str) -> set[str] {
    values = re.findall("[a-z0-9]+", _normalize(value)) as list[str];
    result: set[str] = set();
    for token in values {
        if len(token) > 2 {
            result.add(token);
        }
    }
    return result;
}
def _issue(
    category: BlueprintValidationCategory,
    severity: BlueprintValidationSeverity,
    code: str,
    message: str,
    action: BlueprintRepairAction,
    entity_type: str | None = None,
    entity_key: str | None = None,
    chunks: list[str] | None = None,
    review: bool = False
) -> BlueprintValidationIssue {
    chunk_values: list[str] = chunks if chunks is not None else [];
    return BlueprintValidationIssue(
        issue_id="bvi_" + uuid.uuid4().hex,
        category=category,
        severity=severity,
        code=code,
        message=message,
        repair_action=action,
        blueprint_entity_type=entity_type,
        blueprint_entity_key=entity_key,
        evidence_chunk_ids_json=json.dumps(chunk_values),
        repairable=action in [
            BlueprintRepairAction.AUTO_RETRY_STAGE,
            BlueprintRepairAction.REGENERATE_BLUEPRINT,
            BlueprintRepairAction.REGENERATE_GRAPH
        ],
        requires_lecturer_review=review
    );
}
def _evidence_ids(value: str) -> list[str] {
    try {
        raw = json.loads(value) as list[dict[str, object]];
        return [
            str(item.get("chunk_id", ""))
            for item in raw
            if str(item.get("chunk_id", "")) != ""
        ];
    } except Exception {
        return [];
    }
}
def _evidence_items(value: str) -> list[dict[str, object]] {
    try {
        return json.loads(value) as list[dict[str, object]];
    } except Exception {
        return [];
    }
}
def _result(
    item: BlueprintValidationReport, issue_count: int, reused: bool = False
) -> BlueprintValidationResult {
    return BlueprintValidationResult(
        validation_report_id=item.validation_report_id,
        status=item.status,
        source_coverage_ratio=item.source_coverage_ratio,
        concept_coverage_ratio=item.concept_coverage_ratio,
        module_coverage_ratio=item.module_coverage_ratio,
        grounding_ratio=item.grounding_ratio,
        issue_count=issue_count,
        warning_count=item.warning_count,
        error_count=item.error_count,
        critical_count=item.critical_count,
        eligible_for_review=item.eligible_for_review,
        requires_regeneration=item.requires_regeneration,
        requires_source_replacement=item.requires_source_replacement,
        reused=reused
    );
}

obj BlueprintValidationService {
    has blueprint_repository: CourseBlueprintRepository = CourseBlueprintRepository();
    has validation_repository: BlueprintValidationRepository = BlueprintValidationRepository();
    has graph_repository: CurriculumGraphRepository = CurriculumGraphRepository();

    def _cycle(
        prerequisites: list[BlueprintPrerequisite], required_only: bool = True
    ) -> PrerequisiteCycleResult {
        graph: dict[str, list[str]] = {};
        for item in prerequisites {
            if required_only and item.strength != "REQUIRED" {
                continue;
            }
            graph.setdefault(item.prerequisite_concept_key, []).append(
                item.dependent_concept_key
            );
        }
        visiting: list[str] = [];
        visited: set[str] = set();
        paths: list[list[str]] = [];
        def walk(key: str) -> bool {
            if key in visiting {
                start = visiting.index(key);
                paths.append(visiting[start:] + [key]);
                return True;
            }
            if key in visited {
                return False;
            }
            visiting.append(key);
            found = False;
            for target in graph.get(key, []) {
                if walk(target) {
                    found = True;
                }
            }
            visiting.pop();
            visited.add(key);
            return found;
        }
        for key in graph {
            _ = walk(key);
        }
        return PrerequisiteCycleResult(has_cycle=len(paths) > 0, cycle_paths=paths);
    }
    def _grounded(
        concept: BlueprintConcept, chunks: dict[str, CourseContentChunk]
    ) -> bool {
        claims = _tokens(concept.canonical_name + " " + concept.description);
        try {
            claims.update(
                _tokens(" ".join(json.loads(concept.aliases_json) as list[str]))
            );
        } except Exception { }
        evidence_text = " ";
        for chunk_id in _evidence_ids(concept.evidence_json) {
            if chunk_id in chunks {
                evidence_text += " " + chunks[chunk_id].content;
            }
        }
        evidence_tokens = _tokens(evidence_text);
        return len(claims.intersection(evidence_tokens)) > 0;
    }
    def _identity(
        blueprint: CourseBlueprint, graph_id: str, context: BlueprintValidationContext
    ) -> str {
        content = blueprint.generation_identity + "|" + blueprint.updated_at + "|" + blueprint.source_checksum_sha256;
        return _hash(
            blueprint.blueprint_id + "|" + _hash(content) + "|" + str(
                context.validation_schema_version
            ) + "|" + BLUEPRINT_VALIDATOR_VERSION + "|" + graph_id
        );
    }
    def validate_blueprint(
        blueprint_id: str, context: BlueprintValidationContext
    ) -> BlueprintValidationResult {
        started = datetime.datetime.now(datetime.timezone.utc);
        track = repository_find_track(context.track_id);
        if track is None {
            return BlueprintValidationResult(
                validation_report_id="",
                status=BlueprintValidationStatus.INVALID,
                error_code="BLUEPRINT_NOT_READY_FOR_VALIDATION"
            );
        }
        version = repository_find_version(
            track as LearningTrack, context.track_version_id
        );
        if version is None
        or version.status not in [
            TrackVersionStatus.DRAFT,
            TrackVersionStatus.REVIEW_REQUIRED
        ] {
            return BlueprintValidationResult(
                validation_report_id="",
                status=BlueprintValidationStatus.INVALID,
                error_code="BLUEPRINT_NOT_READY_FOR_VALIDATION"
            );
        }
        blueprint = self.blueprint_repository.find_by_id(
            version as TrackVersion, blueprint_id
        );
        if blueprint is None
        or blueprint.blueprint_id != context.blueprint_id
        or blueprint.track_id != context.track_id
        or blueprint.track_version_id != context.track_version_id
        or blueprint.generation_status not in [
            BlueprintGenerationStatus.GENERATED,
            BlueprintGenerationStatus.REVIEW_REQUIRED
        ] {
            return BlueprintValidationResult(
                validation_report_id="",
                status=BlueprintValidationStatus.INVALID,
                error_code="BLUEPRINT_NOT_READY_FOR_VALIDATION"
            );
        }
        graph_id = context.graph_generation_id or "";
        graph_run = self.graph_repository.find_run(version as TrackVersion, graph_id)
            if graph_id != ""
            else None;
        if graph_run is None
        or not graph_run.is_active
        or graph_run.blueprint_id != blueprint_id
        or graph_run.status not in [
            CurriculumGraphGenerationStatus.GENERATED,
            CurriculumGraphGenerationStatus.GENERATED_WITH_WARNINGS
        ] {
            return BlueprintValidationResult(
                validation_report_id="",
                status=BlueprintValidationStatus.INVALID,
                error_code="BLUEPRINT_NOT_READY_FOR_VALIDATION"
            );
        }
        identity = self._identity(blueprint as CourseBlueprint, graph_id, context);
        existing = self.validation_repository.find_matching_report(
            blueprint as CourseBlueprint, identity
        );
        if existing is not None and not context.force_revalidate {
            issues = self.validation_repository.list_issues(existing);
            blueprint_validation_event(
                "reused",
                {
                    "blueprint_id": blueprint_id,
                    "validation_report_id": existing.validation_report_id,
                    "track_id": context.track_id,
                    "track_version_id": context.track_version_id
                },
                {"status": str(existing.status)},
                context.request_id
            );
            return _result(existing, len(issues), True);
        }
        report_id = "bvr_" + uuid.uuid4().hex;
        entities: dict[str, object] = {
            "blueprint_id": blueprint_id,
            "validation_report_id": report_id,
            "track_id": context.track_id,
            "track_version_id": context.track_version_id
        };
        blueprint_validation_event(
            "started",
            entities,
            {"schema_version": context.validation_schema_version},
            context.request_id,
            "started"
        );
        issues: list[BlueprintValidationIssue] = [];
        concepts = self.blueprint_repository.list_concepts(
            blueprint as CourseBlueprint
        );
        modules = self.blueprint_repository.list_modules(blueprint as CourseBlueprint);
        outcomes = self.blueprint_repository.list_outcomes(
            blueprint as CourseBlueprint
        );
        prerequisites = self.blueprint_repository.list_prerequisites(
            blueprint as CourseBlueprint
        );
        if context.config.enable_critic_pass {
            for warning in self.blueprint_repository.list_warnings(blueprint as CourseBlueprint) {
                if warning.warning_type in ["POSSIBLE_HALLUCINATION", "UNSUPPORTED_EXTERNAL_KNOWLEDGE"] {
                    issues.append(_issue(BlueprintValidationCategory.AI_CRITIQUE, BlueprintValidationSeverity.WARNING, "BLUEPRINT_UNSUPPORTED_CONCEPT", "The bounded critic flagged potentially unsupported curriculum for lecturer review.", BlueprintRepairAction.LECTURER_REVIEW, chunks=_evidence_ids(warning.evidence_json), review=True));
                } elif warning.warning_type == "CONFLICTING_SOURCE" {
                    issues.append(_issue(BlueprintValidationCategory.SOURCE_CONFLICT, BlueprintValidationSeverity.WARNING, "BLUEPRINT_SOURCE_CONFLICT", "Source material may contain conflicting statements.", BlueprintRepairAction.LECTURER_REVIEW, chunks=_evidence_ids(warning.evidence_json), review=True));
                }
            }
        }
        document: CourseDocument | None = None;
        for item in [version->:HAS_SOURCE_DOCUMENT:->[?:CourseDocument]] {
            if item.document_id == blueprint.document_id and item.is_active {
                document = item;
            }
        }
        extraction: DocumentExtraction | None = None;
        chunk_set: DocumentChunkSet | None = None;
        chunks: dict[str, CourseContentChunk] = {};
        if document is not None {
            current_document = document as CourseDocument;
            if current_document.checksum == blueprint.source_checksum_sha256 {
                for item in [current_document->:HAS_EXTRACTION:->[?:DocumentExtraction]] {
                    if item.extraction_id == blueprint.extraction_id
                    and item.is_active {
                        extraction = item;
                    }
                }
            }
        }
        if extraction is not None {
            current_extraction = extraction as DocumentExtraction;
            for item in [current_extraction->:HAS_CHUNK_SET:->[?:DocumentChunkSet]] {
                if item.chunk_set_id == blueprint.chunk_set_id and item.is_active {
                    chunk_set = item;
                }
            }
        }
        if chunk_set is not None {
            current_chunk_set = chunk_set as DocumentChunkSet;
            for item in [current_chunk_set->:HAS_CONTENT_CHUNK:->[?:CourseContentChunk]] {
                chunks[item.chunk_id] = item;
            }
        }
        if document is None
        or extraction is None
        or chunk_set is None
        or len(chunks) == 0 {
            issues.append(
                _issue(
                    BlueprintValidationCategory.SCHEMA,
                    BlueprintValidationSeverity.CRITICAL,
                    "BLUEPRINT_NOT_READY_FOR_VALIDATION",
                    "The active source identity no longer matches this blueprint.",
                    BlueprintRepairAction.REPLACE_SOURCE_DOCUMENT
                )
            );
        }
        concept_keys: set[str] = set();
        normalized_concepts: set[str] = set();
        grounded_count = 0;
        used_chunks: set[str] = set();
        for concept in concepts {
            if concept.local_concept_key.strip() == ""
            or concept.local_concept_key in concept_keys {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.SCHEMA,
                        BlueprintValidationSeverity.ERROR,
                        "BLUEPRINT_DUPLICATE_LOCAL_KEY",
                        "Concept local keys must be non-empty and unique.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "CONCEPT",
                        concept.local_concept_key
                    )
                );
            }
            concept_keys.add(concept.local_concept_key);
            normalized = _normalize(concept.canonical_name);
            if normalized == "" or concept.description.strip() == "" {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.SCHEMA,
                        BlueprintValidationSeverity.ERROR,
                        "BLUEPRINT_SCHEMA_INVALID",
                        "Concept name and description are required.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "CONCEPT",
                        concept.local_concept_key
                    )
                );
            }
            if normalized in normalized_concepts {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.DUPLICATE,
                        BlueprintValidationSeverity.ERROR,
                        "BLUEPRINT_DUPLICATE_CONCEPT",
                        "Exact normalized concept duplicate remains after merge.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "CONCEPT",
                        concept.local_concept_key
                    )
                );
            }
            normalized_concepts.add(normalized);
            evidence_refs = _evidence_items(concept.evidence_json);
            valid_refs = 0;
            weak_only = len(evidence_refs) > 0;
            for ref in evidence_refs {
                chunk_id = str(ref.get("chunk_id", ""));
                if chunk_id not in chunks {
                    issues.append(
                        _issue(
                            BlueprintValidationCategory.EVIDENCE,
                            BlueprintValidationSeverity.ERROR,
                            "BLUEPRINT_INVALID_EVIDENCE_REFERENCE",
                            "Evidence references an unknown or inactive source chunk.",
                            BlueprintRepairAction.REGENERATE_BLUEPRINT,
                            "CONCEPT",
                            concept.local_concept_key,
                            [chunk_id]
                        )
                    );
                    continue;
                }
                chunk = chunks[chunk_id];
                if chunk.track_id != context.track_id
                or chunk.track_version_id != context.track_version_id
                or chunk.document_id != blueprint.document_id {
                    issues.append(
                        _issue(
                            BlueprintValidationCategory.EVIDENCE,
                            BlueprintValidationSeverity.CRITICAL,
                            "BLUEPRINT_EVIDENCE_TRACK_VERSION_MISMATCH",
                            "Evidence belongs to another course version.",
                            BlueprintRepairAction.REGENERATE_BLUEPRINT,
                            "CONCEPT",
                            concept.local_concept_key,
                            [chunk_id]
                        )
                    );
                    continue;
                }
                valid_refs += 1;
                used_chunks.add(chunk_id);
                strength = str(ref.get("strength", "DIRECT"));
                if "WEAK" not in strength {
                    weak_only = False;
                }
                page_start = ref.get("page_start");
                page_end = ref.get("page_end");
                if page_start is not None
                and page_end is not None
                and (
                    int(page_start) > int(page_end)
                    or (
                        chunk.page_start is not None
                        and int(page_start) < (chunk.page_start as int)
                    )
                    or (
                        chunk.page_end is not None
                        and int(page_end) > (chunk.page_end as int)
                    )
                ) {
                    issues.append(
                        _issue(
                            BlueprintValidationCategory.EVIDENCE,
                            BlueprintValidationSeverity.ERROR,
                            "BLUEPRINT_INVALID_EVIDENCE_REFERENCE",
                            "Evidence page range falls outside canonical chunk provenance.",
                            BlueprintRepairAction.REGENERATE_BLUEPRINT,
                            "CONCEPT",
                            concept.local_concept_key,
                            [chunk_id]
                        )
                    );
                }
                quote = str(ref.get("quote_hint", ""));
                if quote != "" and _normalize(quote) not in _normalize(chunk.content) {
                    issues.append(
                        _issue(
                            BlueprintValidationCategory.EVIDENCE,
                            BlueprintValidationSeverity.WARNING,
                            "BLUEPRINT_EVIDENCE_QUOTE_MISMATCH",
                            "Evidence quote hint was not found verbatim; the chunk reference remains authoritative.",
                            BlueprintRepairAction.LECTURER_REVIEW,
                            "CONCEPT",
                            concept.local_concept_key,
                            [chunk_id],
                            True
                        )
                    );
                }
            }
            if weak_only {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.EVIDENCE,
                        BlueprintValidationSeverity.WARNING,
                        "BLUEPRINT_EVIDENCE_TOO_WEAK",
                        "Concept is supported only by weak inference.",
                        BlueprintRepairAction.LECTURER_REVIEW,
                        "CONCEPT",
                        concept.local_concept_key,
                        _evidence_ids(concept.evidence_json),
                        True
                    )
                );
            }
            if valid_refs == 0 or not self._grounded(concept, chunks) {
                severity = BlueprintValidationSeverity.ERROR
                    if concept.should_be_taught_explicitly
                    else BlueprintValidationSeverity.WARNING;
                issues.append(
                    _issue(
                        BlueprintValidationCategory.GROUNDING,
                        severity,
                        "BLUEPRINT_UNSUPPORTED_CONCEPT",
                        "Concept is not plausibly supported by its source evidence.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "CONCEPT",
                        concept.local_concept_key,
                        _evidence_ids(concept.evidence_json)
                    )
                );
            } else {
                grounded_count += 1;
            }
        }
        module_keys: set[str] = set();
        module_orders: set[int] = set();
        module_names: set[str] = set();
        assigned: set[str] = set();
        module_for_concept: dict[str, int] = {};
        for module in modules {
            if module.local_module_key.strip() == ""
            or module.local_module_key in module_keys {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.SCHEMA,
                        BlueprintValidationSeverity.ERROR,
                        "BLUEPRINT_DUPLICATE_LOCAL_KEY",
                        "Module keys must be unique.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "MODULE",
                        module.local_module_key
                    )
                );
            }
            module_keys.add(module.local_module_key);
            if module.title.strip() == ""
            or module.order_index < 0
            or module.order_index in module_orders
            or (
                module.estimated_learning_hours is not None
                and module.estimated_learning_hours <= 0.0
            ) {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.MODULE_STRUCTURE,
                        BlueprintValidationSeverity.ERROR,
                        "BLUEPRINT_SCHEMA_INVALID",
                        "Module title, order, or estimated hours are invalid.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "MODULE",
                        module.local_module_key
                    )
                );
            }
            module_orders.add(module.order_index);
            normalized = _normalize(module.title);
            if normalized in module_names {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.DUPLICATE,
                        BlueprintValidationSeverity.WARNING,
                        "BLUEPRINT_DUPLICATE_MODULE",
                        "Modules have duplicate normalized titles.",
                        BlueprintRepairAction.LECTURER_REVIEW,
                        "MODULE",
                        module.local_module_key,
                        review=True
                    )
                );
            }
            module_names.add(normalized);
            keys = json.loads(module.concept_keys_json) as list[str];
            outcome_keys = json.loads(module.learning_outcome_keys_json) as list[str];
            if len(keys) == 0 {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.MODULE_STRUCTURE,
                        BlueprintValidationSeverity.ERROR,
                        "BLUEPRINT_MODULE_EMPTY",
                        "Module contains no concepts.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "MODULE",
                        module.local_module_key
                    )
                );
            }
            if len(keys) > context.config.max_concepts_per_module {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.MODULE_STRUCTURE,
                        BlueprintValidationSeverity.WARNING,
                        "BLUEPRINT_MODULE_TOO_BROAD",
                        "Module contains an unusually high concept count.",
                        BlueprintRepairAction.LECTURER_REVIEW,
                        "MODULE",
                        module.local_module_key,
                        review=True
                    )
                );
            }
            if len(keys) == 1
            and module.estimated_learning_hours is not None
            and module.estimated_learning_hours < 0.5 {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.MODULE_STRUCTURE,
                        BlueprintValidationSeverity.WARNING,
                        "BLUEPRINT_MODULE_TOO_NARROW",
                        "Module may be too narrow for a standalone learning unit.",
                        BlueprintRepairAction.LECTURER_REVIEW,
                        "MODULE",
                        module.local_module_key,
                        review=True
                    )
                );
            }
            for chunk_id in _evidence_ids(module.evidence_json) {
                if chunk_id not in chunks {
                    issues.append(_issue(BlueprintValidationCategory.EVIDENCE, BlueprintValidationSeverity.ERROR, "BLUEPRINT_INVALID_EVIDENCE_REFERENCE", "Module evidence is invalid.", BlueprintRepairAction.REGENERATE_BLUEPRINT, "MODULE", module.local_module_key, [chunk_id]));
                } else { used_chunks.add(chunk_id); }
            }
            for key in keys {
                if key not in concept_keys {
                    issues.append(
                        _issue(
                            BlueprintValidationCategory.REFERENCE,
                            BlueprintValidationSeverity.ERROR,
                            "BLUEPRINT_DANGLING_REFERENCE",
                            "Module references an unknown concept.",
                            BlueprintRepairAction.REGENERATE_BLUEPRINT,
                            "MODULE",
                            module.local_module_key
                        )
                    );
                } else {
                    assigned.add(key);
                    module_for_concept[key] = module.order_index;
                }
            }
            if module.importance == "REQUIRED" and len(outcome_keys) == 0 {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.LEARNING_OUTCOME,
                        BlueprintValidationSeverity.WARNING,
                        "BLUEPRINT_OUTCOME_NOT_GROUNDED",
                        "Required module has no mapped learning outcome.",
                        BlueprintRepairAction.LECTURER_REVIEW,
                        "MODULE",
                        module.local_module_key,
                        review=True
                    )
                );
            }
        }
        outcome_keys_set: set[str] = set();
        outcome_names: set[str] = set();
        for outcome in outcomes {
            normalized = _normalize(outcome.statement);
            if outcome.local_outcome_key.strip() == ""
            or outcome.local_outcome_key in outcome_keys_set {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.SCHEMA,
                        BlueprintValidationSeverity.ERROR,
                        "BLUEPRINT_DUPLICATE_LOCAL_KEY",
                        "Outcome keys must be unique.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "OUTCOME",
                        outcome.local_outcome_key
                    )
                );
            }
            outcome_keys_set.add(outcome.local_outcome_key);
            if normalized in outcome_names {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.DUPLICATE,
                        BlueprintValidationSeverity.ERROR,
                        "BLUEPRINT_DUPLICATE_OUTCOME",
                        "Duplicate learning outcome remains.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "OUTCOME",
                        outcome.local_outcome_key
                    )
                );
            }
            outcome_names.add(normalized);
            first = normalized.split()[0] if len(normalized.split()) > 0 else "";
            if first not in ACTION_VERBS {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.LEARNING_OUTCOME,
                        BlueprintValidationSeverity.WARNING,
                        "BLUEPRINT_OUTCOME_TOO_VAGUE",
                        "Learning outcome should begin with a measurable action verb.",
                        BlueprintRepairAction.LECTURER_REVIEW,
                        "OUTCOME",
                        outcome.local_outcome_key,
                        review=True
                    )
                );
            }
            for chunk_id in _evidence_ids(outcome.evidence_json) {
                if chunk_id not in chunks {
                    issues.append(
                        _issue(
                            BlueprintValidationCategory.EVIDENCE,
                            BlueprintValidationSeverity.ERROR,
                            "BLUEPRINT_INVALID_EVIDENCE_REFERENCE",
                            "Outcome evidence is invalid.",
                            BlueprintRepairAction.REGENERATE_BLUEPRINT,
                            "OUTCOME",
                            outcome.local_outcome_key,
                            [chunk_id]
                        )
                    );
                } else {
                    used_chunks.add(chunk_id);
                }
            }
        }
        pairs: set[str] = set();
        for item in prerequisites {
            pair = item.prerequisite_concept_key + "->" + item.dependent_concept_key;
            if item.prerequisite_concept_key not in concept_keys
            or item.dependent_concept_key not in concept_keys {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.REFERENCE,
                        BlueprintValidationSeverity.ERROR,
                        "BLUEPRINT_DANGLING_REFERENCE",
                        "Prerequisite endpoint does not resolve.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "PREREQUISITE",
                        item.blueprint_prerequisite_id
                    )
                );
            }
            if item.prerequisite_concept_key == item.dependent_concept_key {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.PREREQUISITE,
                        BlueprintValidationSeverity.CRITICAL,
                        "BLUEPRINT_PREREQUISITE_SELF_EDGE",
                        "Self prerequisites are invalid.",
                        BlueprintRepairAction.REGENERATE_BLUEPRINT,
                        "PREREQUISITE",
                        item.blueprint_prerequisite_id
                    )
                );
            }
            if pair in pairs {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.PREREQUISITE,
                        BlueprintValidationSeverity.ERROR,
                        "BLUEPRINT_PREREQUISITE_DUPLICATE",
                        "Duplicate prerequisite relationship remains.",
                        BlueprintRepairAction.AUTO_RETRY_STAGE,
                        "PREREQUISITE",
                        item.blueprint_prerequisite_id
                    )
                );
            }
            pairs.add(pair);
            if item.confidence == "LOW" {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.PREREQUISITE,
                        BlueprintValidationSeverity.WARNING,
                        "BLUEPRINT_PREREQUISITE_LOW_CONFIDENCE",
                        "Low-confidence prerequisite requires review and is not enforced.",
                        BlueprintRepairAction.LECTURER_REVIEW,
                        "PREREQUISITE",
                        item.blueprint_prerequisite_id,
                        review=True
                    )
                );
            }
            for chunk_id in _evidence_ids(item.evidence_json) {
                if chunk_id not in chunks {
                    issues.append(_issue(BlueprintValidationCategory.EVIDENCE, BlueprintValidationSeverity.ERROR, "BLUEPRINT_INVALID_EVIDENCE_REFERENCE", "Prerequisite evidence is invalid.", BlueprintRepairAction.REGENERATE_BLUEPRINT, "PREREQUISITE", item.blueprint_prerequisite_id, [chunk_id]));
                } else { used_chunks.add(chunk_id); }
            }
            if item.prerequisite_concept_key in module_for_concept
            and item.dependent_concept_key in module_for_concept
            and module_for_concept[item.prerequisite_concept_key] > module_for_concept[
                item.dependent_concept_key
            ] {
                issues.append(
                    _issue(
                        BlueprintValidationCategory.MODULE_STRUCTURE,
                        BlueprintValidationSeverity.WARNING,
                        "BLUEPRINT_MODULE_ORDER_CONFLICT",
                        "A later module contains a prerequisite for an earlier module.",
                        BlueprintRepairAction.LECTURER_REVIEW,
                        "PREREQUISITE",
                        item.blueprint_prerequisite_id,
                        review=True
                    )
                );
            }
        }
        cycle = self._cycle(prerequisites);
        if cycle.has_cycle {
            issues.append(
                _issue(
                    BlueprintValidationCategory.PREREQUISITE,
                    BlueprintValidationSeverity.CRITICAL,
                    "BLUEPRINT_PREREQUISITE_CYCLE",
                    "Required prerequisite graph contains a cycle.",
                    BlueprintRepairAction.REGENERATE_BLUEPRINT
                )
            );
            blueprint_validation_event(
                "prerequisite_failed",
                entities,
                {"cycle_count": len(cycle.cycle_paths)},
                context.request_id,
                "failed",
                error_code="BLUEPRINT_PREREQUISITE_CYCLE"
            );
        }
        explicit = {
            c.local_concept_key
            for c in concepts
            if c.should_be_taught_explicitly
        };
        module_ratio = float(len(explicit.intersection(assigned))) / float(
            len(explicit)
        )
            if len(explicit) > 0
            else 0.0;
        source_ratio = min(
            blueprint.source_coverage_ratio,
            float(len(used_chunks)) / float(len(chunks))
        )
            if len(chunks) > 0
            else 0.0;
        concept_ratio = blueprint.concept_coverage_ratio;
        grounding_ratio = float(grounded_count) / float(len(concepts))
            if len(concepts) > 0
            else 0.0;
        if source_ratio < context.config.min_source_chunk_coverage {
            issues.append(
                _issue(
                    BlueprintValidationCategory.COVERAGE,
                    BlueprintValidationSeverity.ERROR,
                    "BLUEPRINT_SOURCE_COVERAGE_LOW",
                    "Not all eligible source chunks are represented by grounded concepts.",
                    BlueprintRepairAction.REGENERATE_BLUEPRINT
                )
            );
        }
        if concept_ratio < context.config.min_concept_coverage {
            issues.append(
                _issue(
                    BlueprintValidationCategory.COVERAGE,
                    BlueprintValidationSeverity.ERROR,
                    "BLUEPRINT_CONCEPT_COVERAGE_LOW",
                    "Source candidate coverage is below policy.",
                    BlueprintRepairAction.REGENERATE_BLUEPRINT
                )
            );
        }
        if module_ratio < context.config.min_module_coverage {
            issues.append(
                _issue(
                    BlueprintValidationCategory.COVERAGE,
                    BlueprintValidationSeverity.ERROR,
                    "BLUEPRINT_MODULE_COVERAGE_LOW",
                    "Explicit concepts are missing primary module placement.",
                    BlueprintRepairAction.REGENERATE_BLUEPRINT
                )
            );
        }
        if grounding_ratio < context.config.min_grounding_ratio {
            issues.append(
                _issue(
                    BlueprintValidationCategory.GROUNDING,
                    BlueprintValidationSeverity.ERROR,
                    "BLUEPRINT_GROUNDING_RATIO_LOW",
                    "Grounding ratio is below policy.",
                    BlueprintRepairAction.REGENERATE_BLUEPRINT
                )
            );
        }
        integrity = TopicSkillGraphGenerationService().validate_graph(
            version as TrackVersion, graph_run as CurriculumGraphGenerationRun
        );
        if not integrity.valid
        or graph_run.module_count != len(modules)
        or graph_run.skill_count != len(explicit)
        or graph_run.learning_outcome_count != len(outcomes) {
            issues.append(
                _issue(
                    BlueprintValidationCategory.GRAPH_INTEGRITY,
                    BlueprintValidationSeverity.ERROR,
                    "BLUEPRINT_GRAPH_INCONSISTENT",
                    "Draft curriculum graph does not match the validated blueprint.",
                    BlueprintRepairAction.REGENERATE_GRAPH
                )
            );
            blueprint_validation_event(
                "graph_failed",
                entities,
                {"orphan_count": len(integrity.orphan_skills)},
                context.request_id,
                "failed",
                error_code="BLUEPRINT_GRAPH_INCONSISTENT"
            );
        }
        warning_count = len(
            [
                item
                for item in issues
                if item.severity == BlueprintValidationSeverity.WARNING
            ]
        );
        error_count = len(
            [
                item
                for item in issues
                if item.severity == BlueprintValidationSeverity.ERROR
            ]
        );
        critical_count = len(
            [
                item
                for item in issues
                if item.severity == BlueprintValidationSeverity.CRITICAL
            ]
        );
        status = BlueprintValidationStatus.INVALID
            if error_count + critical_count > 0
            else (
                BlueprintValidationStatus.VALID_WITH_WARNINGS
                    if warning_count > 0
                    else BlueprintValidationStatus.VALID
            );
        eligible = status in [
            BlueprintValidationStatus.VALID,
            BlueprintValidationStatus.VALID_WITH_WARNINGS
        ];
        requires_source = False;
        requires_regeneration = False;
        for issue in issues {
            if issue.repair_action == BlueprintRepairAction.REPLACE_SOURCE_DOCUMENT {
                requires_source = True;
            }
            if issue.repair_action in [
                BlueprintRepairAction.REGENERATE_BLUEPRINT,
                BlueprintRepairAction.REGENERATE_GRAPH,
                BlueprintRepairAction.AUTO_RETRY_STAGE
            ] {
                requires_regeneration = True;
            }
        }
        now = _now();
        validation_report = BlueprintValidationReport(
            validation_report_id=report_id,
            blueprint_id=blueprint_id,
            track_id=context.track_id,
            track_version_id=context.track_version_id,
            status=status,
            validation_schema_version=context.validation_schema_version,
            validator_version=BLUEPRINT_VALIDATOR_VERSION,
            validation_identity=identity,
            blueprint_content_hash=_hash(
                blueprint.generation_identity + "|" + blueprint.updated_at
            ),
            graph_generation_id=graph_id,
            created_at=now,
            validated_at=now,
            source_coverage_ratio=source_ratio,
            concept_coverage_ratio=concept_ratio,
            module_coverage_ratio=module_ratio,
            grounding_ratio=grounding_ratio,
            warning_count=warning_count,
            error_count=error_count,
            critical_count=critical_count,
            grounded_concept_count=grounded_count,
            unsupported_concept_count=len(concepts) - grounded_count,
            eligible_for_review=eligible,
            requires_regeneration=requires_regeneration,
            requires_source_replacement=requires_source
        );
        if not self.validation_repository.save_report(
            blueprint as CourseBlueprint, validation_report
        ) {
            return BlueprintValidationResult(
                validation_report_id="",
                status=BlueprintValidationStatus.INVALID,
                error_code="BLUEPRINT_VALIDATION_INTERNAL_ERROR"
            );
        }
        self.validation_repository.save_issues(validation_report, issues);
        blueprint.validation_status = str(status);
        if eligible {
            blueprint.generation_status = BlueprintGenerationStatus.REVIEW_REQUIRED;
            version.status = TrackVersionStatus.REVIEW_REQUIRED;
            (track as LearningTrack).status = LearningTrackStatus.REVIEW_REQUIRED;
        } else {
            version.status = TrackVersionStatus.FAILED;
            (track as LearningTrack).status = LearningTrackStatus.FAILED;
        }
        duration = int(
            (
                datetime.datetime.now(datetime.timezone.utc) - started
            ).total_seconds() * 1000.0
        );
        record_blueprint_validation(
            str(status),
            duration,
            source_ratio,
            concept_ratio,
            module_ratio,
            grounding_ratio,
            len(concepts) - grounded_count,
            len(cycle.cycle_paths),
            len(
                [
                    i
                    for i in issues
                    if i.code == "BLUEPRINT_DANGLING_REFERENCE"
                ]
            )
        );
        blueprint_validation_event(
            "completed" if eligible else "invalid",
            entities,
            {
                "status": str(status),
                "source_coverage_ratio": source_ratio,
                "concept_coverage_ratio": concept_ratio,
                "module_coverage_ratio": module_ratio,
                "grounding_ratio": grounding_ratio,
                "issue_count": len(issues)
            },
            context.request_id,
            "completed" if eligible else "invalid",
            duration
        );
        return _result(validation_report, len(issues));
    }

    def revalidate_blueprint(
        blueprint_id: str, context: BlueprintValidationContext
    ) -> BlueprintValidationResult {
        context.force_revalidate = True;
        return self.validate_blueprint(blueprint_id, context);
    }
    def get_validation_report(
        track_id: str, track_version_id: str, blueprint_id: str
    ) -> BlueprintValidationResult | None {
        track = repository_find_track(track_id);
        if track is None {
            return None;
        }
        version = repository_find_version(track as LearningTrack, track_version_id);
        if version is None {
            return None;
        }
        blueprint = self.blueprint_repository.find_by_id(
            version as TrackVersion, blueprint_id
        );
        if blueprint is None {
            return None;
        }
        item = self.validation_repository.find_latest_report(
            blueprint as CourseBlueprint
        );
        return _result(item, len(self.validation_repository.list_issues(item)))
            if item is not None
            else None;
    }
}
