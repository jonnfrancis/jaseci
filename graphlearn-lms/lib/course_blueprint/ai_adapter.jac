"""Injectable typed AI boundary for production byLLM and deterministic tests."""
import from lib.ai.blueprint.contracts { BlueprintCritique, BlueprintCritiqueInput, BlueprintPrerequisiteCandidate, BlueprintSynthesisInput, ConceptMergeInput, CourseBlueprintDraft, CourseChunkAnalysis, CourseChunkAnalysisInput, MergedCourseConcept, PrerequisiteInferenceInput }
import from lib.ai.blueprint.llm_functions { analyze_course_chunk, critique_course_blueprint, infer_course_prerequisites, merge_course_concepts, synthesize_course_blueprint }

obj BlueprintGenerationAI {
    def analyze(input: CourseChunkAnalysisInput) -> CourseChunkAnalysis { return analyze_course_chunk(input); }
    def merge(input: ConceptMergeInput) -> list[MergedCourseConcept] { return merge_course_concepts(input); }
    def synthesize(input: BlueprintSynthesisInput) -> CourseBlueprintDraft { return synthesize_course_blueprint(input); }
    def infer(input: PrerequisiteInferenceInput) -> list[BlueprintPrerequisiteCandidate] { return infer_course_prerequisites(input); }
    def critique(input: BlueprintCritiqueInput) -> BlueprintCritique { return critique_course_blueprint(input); }
}
