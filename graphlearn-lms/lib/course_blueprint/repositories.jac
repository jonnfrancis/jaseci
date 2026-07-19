"""Graph repositories for durable blueprint drafts and restart artifacts."""
import from edges.domain_edges { HAS_BLUEPRINT, HAS_BLUEPRINT_CONCEPT, HAS_BLUEPRINT_GENERATION_RUN, HAS_BLUEPRINT_MODULE, HAS_BLUEPRINT_OUTCOME, HAS_BLUEPRINT_PREREQUISITE, HAS_BLUEPRINT_WARNING, HAS_CHUNK_ANALYSIS_ARTIFACT, HAS_MERGED_CONCEPT_ARTIFACT }
import from nodes.curriculum { BlueprintConcept, BlueprintGenerationRun, BlueprintLearningOutcomeNode, BlueprintModule, BlueprintPrerequisite, BlueprintWarningNode, ChunkAnalysisArtifact, CourseBlueprint, MergedConceptArtifact }
import from nodes.learning_track { TrackVersion }

obj CourseBlueprintRepository {
    def list_generations(version: TrackVersion) -> list[CourseBlueprint] { return [version ->:HAS_BLUEPRINT:->[?:CourseBlueprint]]; }
    def find_by_id(version: TrackVersion, blueprint_id: str) -> CourseBlueprint | None { for item in self.list_generations(version) { if item.blueprint_id == blueprint_id { return item; } } return None; }
    def find_active_for_version(version: TrackVersion) -> CourseBlueprint | None { for item in self.list_generations(version) { if item.is_active { return item; } } return None; }
    def find_matching_generation(version: TrackVersion, identity: str) -> CourseBlueprint | None { for item in self.list_generations(version) { if item.generation_identity == identity and str(item.generation_status) in ["GENERATED", "REVIEW_REQUIRED"] { return item; } } return None; }
    def save_blueprint_shell(version: TrackVersion, blueprint: CourseBlueprint) -> bool { if blueprint.track_version_id != version.track_version_id or blueprint.track_id != version.track_id { return False; } version +>:HAS_BLUEPRINT:+> blueprint; return True; }
    def save_concepts(blueprint: CourseBlueprint, items: list[BlueprintConcept]) { for item in items { blueprint +>:HAS_BLUEPRINT_CONCEPT:+> item; } }
    def save_outcomes(blueprint: CourseBlueprint, items: list[BlueprintLearningOutcomeNode]) { for item in items { blueprint +>:HAS_BLUEPRINT_OUTCOME:+> item; } }
    def save_modules(blueprint: CourseBlueprint, items: list[BlueprintModule]) { for item in items { blueprint +>:HAS_BLUEPRINT_MODULE(order_index=item.order_index):+> item; } }
    def save_prerequisites(blueprint: CourseBlueprint, items: list[BlueprintPrerequisite]) { for item in items { blueprint +>:HAS_BLUEPRINT_PREREQUISITE:+> item; } }
    def save_warnings(blueprint: CourseBlueprint, items: list[BlueprintWarningNode]) { for item in items { blueprint +>:HAS_BLUEPRINT_WARNING:+> item; } }
    def activate(version: TrackVersion, blueprint: CourseBlueprint) { for old in self.list_generations(version) { old.is_active = False; } blueprint.is_active = True; }
    def list_concepts(blueprint: CourseBlueprint) -> list[BlueprintConcept] { return [blueprint ->:HAS_BLUEPRINT_CONCEPT:->[?:BlueprintConcept]]; }
    def list_outcomes(blueprint: CourseBlueprint) -> list[BlueprintLearningOutcomeNode] { return [blueprint ->:HAS_BLUEPRINT_OUTCOME:->[?:BlueprintLearningOutcomeNode]]; }
    def list_modules(blueprint: CourseBlueprint) -> list[BlueprintModule] { items: list[BlueprintModule] = [blueprint ->:HAS_BLUEPRINT_MODULE:->[?:BlueprintModule]]; items.sort(key=lambda m: BlueprintModule : m.order_index); return items; }
    def list_prerequisites(blueprint: CourseBlueprint) -> list[BlueprintPrerequisite] { return [blueprint ->:HAS_BLUEPRINT_PREREQUISITE:->[?:BlueprintPrerequisite]]; }
    def list_warnings(blueprint: CourseBlueprint) -> list[BlueprintWarningNode] { return [blueprint ->:HAS_BLUEPRINT_WARNING:->[?:BlueprintWarningNode]]; }
}

obj BlueprintGenerationArtifactRepository {
    def list_runs(version: TrackVersion) -> list[BlueprintGenerationRun] { return [version ->:HAS_BLUEPRINT_GENERATION_RUN:->[?:BlueprintGenerationRun]]; }
    def find_generation_run(version: TrackVersion, config_hash: str, chunk_set_id: str) -> BlueprintGenerationRun | None { for item in self.list_runs(version) { if item.generation_config_hash == config_hash and item.chunk_set_id == chunk_set_id and item.status not in ["FAILED", "CANCELLED"] { return item; } } return None; }
    def save_run(version: TrackVersion, run: BlueprintGenerationRun) { version +>:HAS_BLUEPRINT_GENERATION_RUN:+> run; }
    def save_checkpoint(run: BlueprintGenerationRun, step: str, status: str, updated_at: str) { run.current_step = step; run.status = status; run.updated_at = updated_at; }
    def list_chunk_analyses(run: BlueprintGenerationRun) -> list[ChunkAnalysisArtifact] { return [run ->:HAS_CHUNK_ANALYSIS_ARTIFACT:->[?:ChunkAnalysisArtifact]]; }
    def find_chunk_analysis_by_hash(run: BlueprintGenerationRun, input_hash: str) -> ChunkAnalysisArtifact | None { for item in self.list_chunk_analyses(run) { if item.input_hash == input_hash { return item; } } return None; }
    def save_chunk_analysis(run: BlueprintGenerationRun, item: ChunkAnalysisArtifact) { run +>:HAS_CHUNK_ANALYSIS_ARTIFACT:+> item; }
    def find_merged_concept_artifact(run: BlueprintGenerationRun, input_hash: str) -> MergedConceptArtifact | None { for item in [run ->:HAS_MERGED_CONCEPT_ARTIFACT:->[?:MergedConceptArtifact]] { if item.input_hash == input_hash { return item; } } return None; }
    def save_merged_concepts(run: BlueprintGenerationRun, item: MergedConceptArtifact) { run +>:HAS_MERGED_CONCEPT_ARTIFACT:+> item; }
}
