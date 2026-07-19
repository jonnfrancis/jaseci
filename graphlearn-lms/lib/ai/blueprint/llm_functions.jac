"""Provider-independent typed byLLM blueprint declarations with no tool access."""
import from byllm.plugin { JacRuntime }
import from lib.ai.blueprint.contracts { BlueprintCritique, BlueprintCritiqueInput, BlueprintPrerequisiteCandidate, BlueprintSynthesisInput, ConceptMergeInput, CourseBlueprintDraft, CourseChunkAnalysis, CourseChunkAnalysisInput, MergedCourseConcept, PrerequisiteInferenceInput }
import from lib.ai.blueprint.prompts { GROUNDING_POLICY, MODULE_POLICY, PREREQUISITE_POLICY, UNTRUSTED_SOURCE_POLICY }

glob llm = JacRuntime.default_llm();

def analyze_course_chunk(input: CourseChunkAnalysisInput) -> CourseChunkAnalysis by llm(temperature=0.1, max_tokens=2400, max_output_retries=2, system_prompt=UNTRUSTED_SOURCE_POLICY + " " + GROUNDING_POLICY);
sem analyze_course_chunk = "Extract supported educational concepts, explicit outcomes, terminology, assessment signals, and prerequisite signals from one bounded course evidence unit. Never build a roadmap, lesson, quiz, persisted ID, or external curriculum.";
sem analyze_course_chunk.input = "Trusted course metadata plus one bounded untrusted source chunk and prompt version.";

def merge_course_concepts(input: ConceptMergeInput) -> list[MergedCourseConcept] by llm(temperature=0.1, max_tokens=3000, max_output_retries=2, system_prompt=UNTRUSTED_SOURCE_POLICY + " " + GROUNDING_POLICY);
sem merge_course_concepts = "Merge obvious duplicate course concepts, normalize synonyms, preserve the union of supplied evidence, and keep related but distinct concepts separate.";
sem merge_course_concepts.input = "Candidate concepts, allowed evidence IDs, trusted course metadata, and merge version.";

def synthesize_course_blueprint(input: BlueprintSynthesisInput) -> CourseBlueprintDraft by llm(temperature=0.1, max_tokens=5000, max_output_retries=2, system_prompt=UNTRUSTED_SOURCE_POLICY + " " + GROUNDING_POLICY + " " + MODULE_POLICY);
sem synthesize_course_blueprint = "Create a grounded typed course blueprint draft from merged concepts; do not publish, personalize, generate full lessons or quizzes, or invent unsupported syllabus content.";
sem synthesize_course_blueprint.input = "Merged concepts, source outcomes and summaries, allowed evidence IDs, and contract versions.";

def infer_course_prerequisites(input: PrerequisiteInferenceInput) -> list[BlueprintPrerequisiteCandidate] by llm(temperature=0.1, max_tokens=3000, max_output_retries=2, system_prompt=UNTRUSTED_SOURCE_POLICY + " " + GROUNDING_POLICY + " " + PREREQUISITE_POLICY);
sem infer_course_prerequisites = "Propose only evidence-grounded, high-value prerequisite relationships between supplied concept keys.";
sem infer_course_prerequisites.input = "Supported concepts and modules with allowed evidence IDs.";

def critique_course_blueprint(input: BlueprintCritiqueInput) -> BlueprintCritique by llm(temperature=0.1, max_tokens=2600, max_output_retries=2, system_prompt=UNTRUSTED_SOURCE_POLICY + " " + GROUNDING_POLICY);
sem critique_course_blueprint = "Advisory grounding critique of a typed blueprint. Deterministic validators remain authoritative.";
sem critique_course_blueprint.input = "A typed draft and bounded source evidence index.";
