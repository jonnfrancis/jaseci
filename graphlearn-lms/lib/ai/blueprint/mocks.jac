"""Deterministic offline implementations of the Feature 45 AI contracts."""
import from lib.ai.blueprint.contracts { BlueprintConfidence, BlueprintCritique, BlueprintCritiqueInput, BlueprintPrerequisiteCandidate, BlueprintSynthesisInput, ConceptMergeInput, CourseBlueprintDraft, CourseChunkAnalysis, CourseChunkAnalysisInput, MergedCourseConcept, PrerequisiteInferenceInput }

obj MockChunkAnalyzer { has outputs: list[CourseChunkAnalysis]; has index: int = 0; def analyze(input: CourseChunkAnalysisInput) -> CourseChunkAnalysis { _ = input; result = self.outputs[self.index]; self.index += 1; return result; } }
obj MockConceptMerger { has outputs: list[list[MergedCourseConcept]]; has index: int = 0; def merge(input: ConceptMergeInput) -> list[MergedCourseConcept] { _ = input; result = self.outputs[self.index]; self.index += 1; return result; } }
obj MockBlueprintSynthesizer { has outputs: list[CourseBlueprintDraft]; has index: int = 0; def synthesize(input: BlueprintSynthesisInput) -> CourseBlueprintDraft { _ = input; result = self.outputs[self.index]; self.index += 1; return result; } }
obj MockPrerequisiteInferencer { has outputs: list[list[BlueprintPrerequisiteCandidate]]; has index: int = 0; def infer(input: PrerequisiteInferenceInput) -> list[BlueprintPrerequisiteCandidate] { _ = input; result = self.outputs[self.index]; self.index += 1; return result; } }
obj MockBlueprintCritic { has outputs: list[BlueprintCritique]; has index: int = 0; def critique(input: BlueprintCritiqueInput) -> BlueprintCritique { _ = input; result = self.outputs[self.index]; self.index += 1; return result; } }

def insufficient_evidence_critique -> BlueprintCritique { return BlueprintCritique(grounded=False, missing_topic_hints=["Source material is too weak for reliable interpretation."], confidence=BlueprintConfidence.LOW); }
