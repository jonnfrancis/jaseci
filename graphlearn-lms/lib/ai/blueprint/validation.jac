"""Deterministic authority for blueprint fields, keys, evidence, coverage, and cycles."""
import from lib.ai.blueprint.contracts { BlueprintEvidenceRef, BlueprintPrerequisiteCandidate, CourseBlueprintDraft, CourseChunkAnalysis, CourseChunkEvidence, MergedCourseConcept }
import from lib.ai.blueprint.errors { BlueprintAIErrorCode, BlueprintValidationIssue, BlueprintValidationResult }
import from lib.ai.blueprint.prompts { COURSE_BLUEPRINT_SCHEMA_VERSION }

glob MAX_CONCEPTS_PER_CHUNK: int = 30;
glob MAX_ALIASES_PER_CONCEPT: int = 10;
glob MAX_OBJECTIVES_PER_CONCEPT: int = 10;
glob MAX_EVIDENCE_PER_CONCEPT: int = 10;
glob MAX_COURSE_CONCEPTS: int = 500;
glob MAX_COURSE_MODULES: int = 100;
glob MAX_COURSE_OUTCOMES: int = 100;
glob MAX_PREREQUISITES: int = 2000;
glob MAX_CONCEPT_NAME: int = 200;
glob MAX_CONCEPT_DESCRIPTION: int = 2000;
glob MAX_MODULE_TITLE: int = 250;
glob MAX_MODULE_DESCRIPTION: int = 3000;
glob MAX_OUTCOME_STATEMENT: int = 1000;
glob MAX_PREREQUISITE_RATIONALE: int = 2000;

def _issue(code: BlueprintAIErrorCode, message: str, reference: str = "") -> BlueprintValidationIssue { return BlueprintValidationIssue(code=code, message=message, reference=reference); }
def _duplicate(values: list[str]) -> bool { seen: set[str] = set(); for value in values { if value == "" or value in seen { return True; } seen.add(value); } return False; }
def _evidence_errors(refs: list[BlueprintEvidenceRef], allowed: set[str], index: dict[str, CourseChunkEvidence] | None = None) -> tuple[list[BlueprintValidationIssue], list[BlueprintValidationIssue]] {
    errors: list[BlueprintValidationIssue] = []; warnings: list[BlueprintValidationIssue] = []; evidence_index: dict[str, CourseChunkEvidence] = index if index is not None else {};
    if len(refs) == 0 { errors.append(_issue(BlueprintAIErrorCode.INSUFFICIENT_EVIDENCE, "Grounded output requires at least one evidence reference.")); }
    for ref in refs {
        if ref.chunk_id not in allowed { errors.append(_issue(BlueprintAIErrorCode.EVIDENCE_REFERENCE_INVALID, "Evidence references an unknown or out-of-scope chunk.", ref.chunk_id)); continue; }
        if ref.page_start is not None and ref.page_end is not None and ref.page_start > ref.page_end { errors.append(_issue(BlueprintAIErrorCode.DOMAIN_INVALID, "Evidence page range is invalid.", ref.chunk_id)); }
        if ref.chunk_id in evidence_index { chunk = evidence_index[ref.chunk_id]; if ref.page_start is not None and chunk.page_start is not None and ref.page_start != chunk.page_start { warnings.append(_issue(BlueprintAIErrorCode.DOMAIN_INVALID, "Evidence page hint differs from canonical chunk provenance.", ref.chunk_id)); } if ref.quote_hint is not None and (ref.quote_hint as str).lower() not in chunk.content.lower() { warnings.append(_issue(BlueprintAIErrorCode.DOMAIN_INVALID, "Quote hint was not found in canonical chunk content.", ref.chunk_id)); } }
    }
    return (errors, warnings);
}

def validate_chunk_analysis(input_chunk: CourseChunkEvidence, analysis: CourseChunkAnalysis) -> BlueprintValidationResult {
    errors: list[BlueprintValidationIssue] = []; warnings: list[BlueprintValidationIssue] = []; allowed: set[str] = {input_chunk.chunk_id}; index: dict[str, CourseChunkEvidence] = {input_chunk.chunk_id: input_chunk};
    if analysis.chunk_id != input_chunk.chunk_id { errors.append(_issue(BlueprintAIErrorCode.EVIDENCE_REFERENCE_INVALID, "Analysis chunk id must match its supplied chunk.", analysis.chunk_id)); }
    if len(analysis.concepts) > MAX_CONCEPTS_PER_CHUNK { errors.append(_issue(BlueprintAIErrorCode.OUTPUT_LIMIT_EXCEEDED, "Chunk concept limit exceeded.")); }
    if _duplicate([item.candidate_id for item in analysis.concepts]) { errors.append(_issue(BlueprintAIErrorCode.DUPLICATE_KEY, "Candidate ids must be non-empty and unique.")); }
    for item in analysis.concepts {
        if item.canonical_name.strip() == "" or len(item.canonical_name) > MAX_CONCEPT_NAME or item.description.strip() == "" or len(item.description) > MAX_CONCEPT_DESCRIPTION { errors.append(_issue(BlueprintAIErrorCode.DOMAIN_INVALID, "Concept name or description is invalid.", item.candidate_id)); }
        if len(item.aliases) > MAX_ALIASES_PER_CONCEPT or len(item.suggested_learning_objectives) > MAX_OBJECTIVES_PER_CONCEPT or len(item.evidence) > MAX_EVIDENCE_PER_CONCEPT { errors.append(_issue(BlueprintAIErrorCode.OUTPUT_LIMIT_EXCEEDED, "Concept nested output limit exceeded.", item.candidate_id)); }
        (e, w) = _evidence_errors(item.evidence, allowed, index); errors += e; warnings += w;
    }
    return BlueprintValidationResult(valid=len(errors) == 0, errors=errors, warnings=warnings, source_coverage=1.0 if len(analysis.concepts) > 0 else 0.0);
}

def validate_merged_concepts(candidates: list[str], allowed_chunk_ids: list[str], concepts: list[MergedCourseConcept]) -> BlueprintValidationResult {
    errors: list[BlueprintValidationIssue] = []; allowed = set(allowed_chunk_ids); keys = [item.local_concept_key for item in concepts]; accounted: set[str] = set();
    if _duplicate(keys) { errors.append(_issue(BlueprintAIErrorCode.DUPLICATE_KEY, "Merged concept keys must be non-empty and unique.")); }
    for item in concepts { for source_id in item.source_candidate_ids { if source_id not in candidates { errors.append(_issue(BlueprintAIErrorCode.DANGLING_REFERENCE, "Merged concept references an unknown candidate.", source_id)); } accounted.add(source_id); } (e, _) = _evidence_errors(item.evidence, allowed); errors += e; }
    missing = [item for item in candidates if item not in accounted];
    for item in missing { errors.append(_issue(BlueprintAIErrorCode.COVERAGE_LOW, "Input candidate was not accounted for by concept merge.", item)); }
    coverage = float(len(accounted.intersection(set(candidates)))) / float(len(candidates)) if len(candidates) > 0 else 1.0;
    return BlueprintValidationResult(valid=len(errors) == 0, errors=errors, source_coverage=coverage);
}

def validate_blueprint(draft: CourseBlueprintDraft, allowed_chunk_ids: list[str], evidence_index: list[CourseChunkEvidence] | None = None, coverage_chunk_ids: list[str] | None = None) -> BlueprintValidationResult {
    errors: list[BlueprintValidationIssue] = []; warnings: list[BlueprintValidationIssue] = []; allowed = set(allowed_chunk_ids); coverage_required = set(coverage_chunk_ids) if coverage_chunk_ids is not None else allowed; evidence_items: list[CourseChunkEvidence] = evidence_index if evidence_index is not None else []; index = {item.chunk_id: item for item in evidence_items};
    if draft.schema_version != COURSE_BLUEPRINT_SCHEMA_VERSION { errors.append(_issue(BlueprintAIErrorCode.SCHEMA_VERSION_UNSUPPORTED, "Unsupported course blueprint schema version.")); }
    if len(draft.concepts) > MAX_COURSE_CONCEPTS or len(draft.modules) > MAX_COURSE_MODULES or len(draft.learning_outcomes) > MAX_COURSE_OUTCOMES or len(draft.prerequisites) > MAX_PREREQUISITES { errors.append(_issue(BlueprintAIErrorCode.OUTPUT_LIMIT_EXCEEDED, "Course blueprint output limit exceeded.")); }
    concept_keys = [item.local_concept_key for item in draft.concepts]; outcome_keys = [item.outcome_key for item in draft.learning_outcomes]; module_keys = [item.module_key for item in draft.modules];
    if _duplicate(concept_keys) or _duplicate(outcome_keys) or _duplicate(module_keys) { errors.append(_issue(BlueprintAIErrorCode.DUPLICATE_KEY, "Blueprint local keys must be non-empty and unique within their type.")); }
    concept_set = set(concept_keys); outcome_set = set(outcome_keys); used_chunks: set[str] = set();
    for concept in draft.concepts { if len(concept.canonical_name) > MAX_CONCEPT_NAME or len(concept.description) > MAX_CONCEPT_DESCRIPTION { errors.append(_issue(BlueprintAIErrorCode.DOMAIN_INVALID, "Concept text limit exceeded.", concept.local_concept_key)); } (e, w) = _evidence_errors(concept.evidence, allowed, index); errors += e; warnings += w; for ref in concept.evidence { if ref.chunk_id in allowed { used_chunks.add(ref.chunk_id); } } }
    for outcome in draft.learning_outcomes { if len(outcome.statement) > MAX_OUTCOME_STATEMENT { errors.append(_issue(BlueprintAIErrorCode.DOMAIN_INVALID, "Outcome text limit exceeded.", outcome.outcome_key)); } (e, w) = _evidence_errors(outcome.evidence, allowed, index); errors += e; warnings += w; }
    for module in draft.modules { if len(module.title) > MAX_MODULE_TITLE or len(module.description) > MAX_MODULE_DESCRIPTION or module.order_index < 0 or (module.estimated_learning_hours is not None and module.estimated_learning_hours <= 0.0) { errors.append(_issue(BlueprintAIErrorCode.DOMAIN_INVALID, "Module fields are invalid.", module.module_key)); } for key in module.concept_keys { if key not in concept_set { errors.append(_issue(BlueprintAIErrorCode.DANGLING_REFERENCE, "Module references an unknown concept.", key)); } } for key in module.learning_outcome_keys { if key not in outcome_set { errors.append(_issue(BlueprintAIErrorCode.DANGLING_REFERENCE, "Module references an unknown outcome.", key)); } } (e, w) = _evidence_errors(module.evidence, allowed, index); errors += e; warnings += w; }
    for edge in draft.prerequisites { if edge.prerequisite_concept_key not in concept_set or edge.dependent_concept_key not in concept_set { errors.append(_issue(BlueprintAIErrorCode.DANGLING_REFERENCE, "Prerequisite references an unknown concept.")); } if edge.prerequisite_concept_key == edge.dependent_concept_key or len(edge.rationale) > MAX_PREREQUISITE_RATIONALE { errors.append(_issue(BlueprintAIErrorCode.DOMAIN_INVALID, "Prerequisite relationship is invalid.")); } (e, w) = _evidence_errors(edge.evidence, allowed, index); errors += e; warnings += w; }
    if prerequisite_cycle(draft.prerequisites) { errors.append(_issue(BlueprintAIErrorCode.DOMAIN_INVALID, "Prerequisite cycle detected.")); }
    coverage = float(len(used_chunks.intersection(coverage_required))) / float(len(coverage_required)) if len(coverage_required) > 0 else 1.0;
    if coverage < 0.99 { warnings.append(_issue(BlueprintAIErrorCode.COVERAGE_LOW, "Blueprint concept coverage is below the required source threshold.")); }
    return BlueprintValidationResult(valid=len(errors) == 0, errors=errors, warnings=warnings, source_coverage=coverage);
}

def prerequisite_cycle(edges: list[BlueprintPrerequisiteCandidate]) -> bool {
    graph: dict[str, list[str]] = {}; for edge in edges { graph.setdefault(edge.prerequisite_concept_key, []).append(edge.dependent_concept_key); }
    visiting: set[str] = set(); visited: set[str] = set();
    def visit_key(key: str) -> bool { if key in visiting { return True; } if key in visited { return False; } visiting.add(key); for next_key in graph.get(key, []) { if visit_key(next_key) { return True; } } visiting.remove(key); visited.add(key); return False; }
    for key in graph { if visit_key(key) { return True; } }
    return False;
}
