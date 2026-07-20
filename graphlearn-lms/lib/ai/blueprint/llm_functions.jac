"""Provider-independent typed byLLM blueprint declarations with no tool access."""
import json;
import from byllm.plugin { JacRuntime }
import from byllm.schema { json_to_instance, type_to_schema }
import from lib.ai.blueprint.contracts { BlueprintCritique, BlueprintCritiqueInput, BlueprintPrerequisiteCandidate, BlueprintSynthesisInput, ConceptMergeInput, CourseBlueprintDraft, CourseChunkAnalysis, CourseChunkAnalysisInput, MergedCourseConcept, PrerequisiteInferenceInput }
import from lib.ai.blueprint.prompts { GROUNDING_POLICY, MODULE_POLICY, PREREQUISITE_POLICY, UNTRUSTED_SOURCE_POLICY }

glob llm = JacRuntime.default_llm();

def _json_value(raw: str) -> object { text = raw.strip(); if text.startswith("```") { lines = text.split(chr(10)); if len(lines) >= 3 { text = chr(10).join(lines[1:len(lines) - 1]); } } return json.loads(text); }
def _schema(ty: type) -> str { return json.dumps(type_to_schema(ty, None), separators=(",", ":")); } # jac:ignore[E1053]

def _analyze_course_chunk_json(input: CourseChunkAnalysisInput, output_schema: str) -> str by llm(temperature=0.1, max_tokens=5000, system_prompt=UNTRUSTED_SOURCE_POLICY + " " + GROUNDING_POLICY);
sem _analyze_course_chunk_json = "Return only a valid JSON object, with no Markdown, matching CourseChunkAnalysis: chunk_id, summary, concepts, confidence, explicit_learning_outcomes, assessment_signals, prerequisite_signals, and warnings. Extract only supported educational concepts from the bounded evidence. Never build a roadmap, lesson, quiz, persisted ID, or external curriculum.";
sem _analyze_course_chunk_json.input = "Trusted course metadata plus one bounded untrusted source chunk and prompt version.";
sem _analyze_course_chunk_json.output_schema = "Exact JSON schema that the returned JSON must satisfy, including nested objects and enum names.";
def analyze_course_chunk(input: CourseChunkAnalysisInput) -> CourseChunkAnalysis { schema = _schema(CourseChunkAnalysis); for _attempt in range(3) { raw = _analyze_course_chunk_json(input, schema); try { return json_to_instance(_json_value(raw) as dict, CourseChunkAnalysis) as CourseChunkAnalysis; } except Exception { if _attempt == 2 { raise ValueError("BYLLM_BLUEPRINT_OUTPUT_INVALID"); } } } raise ValueError("BYLLM_BLUEPRINT_OUTPUT_INVALID"); }

def _merge_course_concepts_json(input: ConceptMergeInput, output_schema: str) -> str by llm(temperature=0.1, max_tokens=6000, system_prompt=UNTRUSTED_SOURCE_POLICY + " " + GROUNDING_POLICY);
sem _merge_course_concepts_json = "Return only a valid JSON array, with no Markdown, whose objects match MergedCourseConcept. Merge obvious duplicate course concepts, normalize synonyms, preserve supplied evidence, and keep related but distinct concepts separate.";
sem _merge_course_concepts_json.input = "Candidate concepts, allowed evidence IDs, trusted course metadata, and merge version.";
sem _merge_course_concepts_json.output_schema = "Exact JSON schema that the returned JSON array must satisfy.";
def merge_course_concepts(input: ConceptMergeInput) -> list[MergedCourseConcept] { schema = _schema(list[MergedCourseConcept]); for _attempt in range(3) { raw = _merge_course_concepts_json(input, schema); try { items = _json_value(raw) as list; return [json_to_instance(item as dict, MergedCourseConcept) as MergedCourseConcept for item in items]; } except Exception { if _attempt == 2 { raise ValueError("BYLLM_BLUEPRINT_OUTPUT_INVALID"); } } } raise ValueError("BYLLM_BLUEPRINT_OUTPUT_INVALID"); }

def _synthesize_course_blueprint_json(input: BlueprintSynthesisInput, output_schema: str) -> str by llm(temperature=0.1, max_tokens=8000, system_prompt=UNTRUSTED_SOURCE_POLICY + " " + GROUNDING_POLICY + " " + MODULE_POLICY);
sem _synthesize_course_blueprint_json = "Return only a valid JSON object, with no Markdown, matching CourseBlueprintDraft. Create a grounded course blueprint from merged concepts; do not publish, personalize, generate lessons or quizzes, or invent unsupported syllabus content.";
sem _synthesize_course_blueprint_json.input = "Merged concepts, source outcomes and summaries, allowed evidence IDs, and contract versions.";
sem _synthesize_course_blueprint_json.output_schema = "Exact JSON schema that the returned JSON must satisfy, including local-reference and evidence shapes.";
def synthesize_course_blueprint(input: BlueprintSynthesisInput) -> CourseBlueprintDraft { schema = _schema(CourseBlueprintDraft); for _attempt in range(3) { raw = _synthesize_course_blueprint_json(input, schema); try { return json_to_instance(_json_value(raw) as dict, CourseBlueprintDraft) as CourseBlueprintDraft; } except Exception { if _attempt == 2 { raise ValueError("BYLLM_BLUEPRINT_OUTPUT_INVALID"); } } } raise ValueError("BYLLM_BLUEPRINT_OUTPUT_INVALID"); }

def _infer_course_prerequisites_json(input: PrerequisiteInferenceInput, output_schema: str) -> str by llm(temperature=0.1, max_tokens=3000, system_prompt=UNTRUSTED_SOURCE_POLICY + " " + GROUNDING_POLICY + " " + PREREQUISITE_POLICY);
sem _infer_course_prerequisites_json = "Return only a valid JSON array, with no Markdown, whose objects match BlueprintPrerequisiteCandidate. Propose only evidence-grounded, high-value prerequisite relationships between supplied concept keys.";
sem _infer_course_prerequisites_json.input = "Supported concepts and modules with allowed evidence IDs.";
sem _infer_course_prerequisites_json.output_schema = "Exact JSON schema that the returned JSON array must satisfy.";
def infer_course_prerequisites(input: PrerequisiteInferenceInput) -> list[BlueprintPrerequisiteCandidate] { schema = _schema(list[BlueprintPrerequisiteCandidate]); for _attempt in range(3) { raw = _infer_course_prerequisites_json(input, schema); try { items = _json_value(raw) as list; return [json_to_instance(item as dict, BlueprintPrerequisiteCandidate) as BlueprintPrerequisiteCandidate for item in items]; } except Exception { if _attempt == 2 { raise ValueError("BYLLM_BLUEPRINT_OUTPUT_INVALID"); } } } raise ValueError("BYLLM_BLUEPRINT_OUTPUT_INVALID"); }

def _critique_course_blueprint_json(input: BlueprintCritiqueInput, output_schema: str) -> str by llm(temperature=0.1, max_tokens=2600, system_prompt=UNTRUSTED_SOURCE_POLICY + " " + GROUNDING_POLICY);
sem _critique_course_blueprint_json = "Return only a valid JSON object, with no Markdown, matching BlueprintCritique. Provide an advisory grounding critique; deterministic validators remain authoritative.";
sem _critique_course_blueprint_json.input = "A typed draft and bounded source evidence index.";
sem _critique_course_blueprint_json.output_schema = "Exact JSON schema that the returned JSON must satisfy.";
def critique_course_blueprint(input: BlueprintCritiqueInput) -> BlueprintCritique { schema = _schema(BlueprintCritique); for _attempt in range(3) { raw = _critique_course_blueprint_json(input, schema); try { return json_to_instance(_json_value(raw) as dict, BlueprintCritique) as BlueprintCritique; } except Exception { if _attempt == 2 { raise ValueError("BYLLM_BLUEPRINT_OUTPUT_INVALID"); } } } raise ValueError("BYLLM_BLUEPRINT_OUTPUT_INVALID"); }
