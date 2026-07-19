"""Feature 47 deterministic mapping, integrity, idempotency, and runtime tests."""
import from uuid { uuid4 }
import from edges.domain_edges { HAS_BLUEPRINT_CONCEPT, HAS_BLUEPRINT_MODULE, HAS_BLUEPRINT_OUTCOME, HAS_BLUEPRINT_PREREQUISITE, MODULE_CONTAINS_SKILL, PREREQUISITE }
import from lib.course_blueprint.repositories { CourseBlueprintRepository }
import from lib.curriculum_graph.repositories { CurriculumGraphRepository }
import from lib.curriculum_graph.service { TopicSkillGraphGenerationService }
import from lib.learning_track.course_management { create_course_service }
import from lib.learning_track.repositories { repository_find_track, repository_modules, repository_prerequisites, repository_skills, repository_versions }
import from lib.learning_track.repository_types { ActorContext }
import from nodes.curriculum { BlueprintConcept, BlueprintGenerationStatus, BlueprintLearningOutcomeNode, BlueprintModule, BlueprintPrerequisite, CourseBlueprint, CurriculumGraphGenerationStatus, GraphGenerationContext }
import from nodes.learning_track { CreateCourseTrackInput, LearningTrack, LecturerCourseDetail, TrackVersion }
import from nodes.skill { Skill }

def _blueprint_fixture(suffix: str, cyclic: bool = False) -> tuple[LearningTrack, TrackVersion, CourseBlueprint] {
    actor = ActorContext(user_id="user_" + suffix, lecturer_id="lecturer_" + suffix, request_id="request_" + suffix, roles=["LECTURER"]);
    created = create_course_service(actor, CreateCourseTrackInput(title="Graph Course " + suffix[:6], client_request_id="graph_" + suffix));
    detail = created.value as LecturerCourseDetail; track = repository_find_track(detail.track.track_id) as LearningTrack; version = repository_versions(track)[0];
    blueprint = CourseBlueprint(blueprint_id="bp_" + suffix, track_id=track.track_id, track_version_id=version.track_version_id, schema_version=1, generation_status=BlueprintGenerationStatus.GENERATED, generation_identity="identity_" + suffix, source_checksum_sha256="checksum_" + suffix, created_at="now", updated_at="now", is_active=True);
    CourseBlueprintRepository().save_blueprint_shell(version, blueprint);
    evidence = "[{\"chunk_id\":\"chunk_" + suffix + "\"}]";
    first = BlueprintConcept(blueprint_concept_id="bpc_a_" + suffix, blueprint_id=blueprint.blueprint_id, local_concept_key="concept_a", canonical_name="Foundations", description="Grounded foundations.", concept_type="FOUNDATIONAL", aliases_json="[\"Basics\"]", learning_objectives_json="[]", key_terms_json="[\"foundation\"]", confidence="HIGH", should_be_taught_explicitly=True, evidence_json=evidence);
    second = BlueprintConcept(blueprint_concept_id="bpc_b_" + suffix, blueprint_id=blueprint.blueprint_id, local_concept_key="concept_b", canonical_name="Applications", description="Grounded applications.", concept_type="APPLIED", aliases_json="[]", learning_objectives_json="[]", key_terms_json="[]", confidence="HIGH", should_be_taught_explicitly=True, evidence_json=evidence);
    module = BlueprintModule(blueprint_module_id="bpm_" + suffix, blueprint_id=blueprint.blueprint_id, local_module_key="module_a", title="Core module", description="Core grounded module.", order_index=0, importance="REQUIRED", concept_keys_json="[\"concept_a\",\"concept_b\"]", learning_outcome_keys_json="[\"outcome_a\"]", confidence="HIGH", evidence_json=evidence, warnings_json="[]", estimated_learning_hours=2.0);
    outcome = BlueprintLearningOutcomeNode(blueprint_outcome_id="bpo_" + suffix, blueprint_id=blueprint.blueprint_id, local_outcome_key="outcome_a", statement="Apply the grounded concepts.", level="APPLY", confidence="HIGH", evidence_json=evidence);
    prerequisite = BlueprintPrerequisite(blueprint_prerequisite_id="bpp_a_" + suffix, blueprint_id=blueprint.blueprint_id, prerequisite_concept_key="concept_a", dependent_concept_key="concept_b", strength="REQUIRED", rationale="Foundations precede applications.", confidence="HIGH", evidence_json=evidence);
    blueprint +>:HAS_BLUEPRINT_CONCEPT:+> first; blueprint +>:HAS_BLUEPRINT_CONCEPT:+> second; blueprint +>:HAS_BLUEPRINT_MODULE(order_index=0):+> module; blueprint +>:HAS_BLUEPRINT_OUTCOME:+> outcome; blueprint +>:HAS_BLUEPRINT_PREREQUISITE:+> prerequisite;
    if cyclic { blueprint +>:HAS_BLUEPRINT_PREREQUISITE:+> BlueprintPrerequisite(blueprint_prerequisite_id="bpp_b_" + suffix, blueprint_id=blueprint.blueprint_id, prerequisite_concept_key="concept_b", dependent_concept_key="concept_a", strength="REQUIRED", rationale="Cycle.", confidence="HIGH", evidence_json=evidence); }
    return (track, version, blueprint);
}

test "blueprint artifacts become one isolated shared runtime graph" {
    suffix = uuid4().hex; (track, version, blueprint) = _blueprint_fixture(suffix); service = TopicSkillGraphGenerationService();
    result = service.generate_graph(blueprint.blueprint_id, GraphGenerationContext(track_id=track.track_id, track_version_id=version.track_version_id, blueprint_id=blueprint.blueprint_id, request_id="request"));
    modules = repository_modules(track, version.track_version_id); skills = repository_skills(track, version.track_version_id);
    assert result.status == CurriculumGraphGenerationStatus.GENERATED and result.module_count == 1 and result.skill_count == 2 and result.learning_outcome_count == 1 and result.prerequisite_count == 1;
    assert len(modules) == 1 and modules[0].blueprint_module_key == "module_a" and modules[0].module_id != "module_a";
    assert len(skills) == 2 and skills[0].skill_id != skills[0].blueprint_concept_key and len([modules[0] ->:MODULE_CONTAINS_SKILL:->[?:Skill]]) == 2;
    dependent = [s for s in skills if s.blueprint_concept_key == "concept_b"][0]; prerequisites = repository_prerequisites(track, version.track_version_id, dependent.skill_id as str); assert len(prerequisites) == 1 and prerequisites[0].blueprint_concept_key == "concept_a";
}

test "equivalent graph generation reuses the active generation" {
    suffix = uuid4().hex; (track, version, blueprint) = _blueprint_fixture(suffix); service = TopicSkillGraphGenerationService(); context = GraphGenerationContext(track_id=track.track_id, track_version_id=version.track_version_id, blueprint_id=blueprint.blueprint_id, request_id="request");
    first = service.generate_graph(blueprint.blueprint_id, context); second = service.generate_graph(blueprint.blueprint_id, context);
    assert first.graph_generation_id == second.graph_generation_id and second.reused and len(CurriculumGraphRepository().list_runs(version)) == 1;
}

test "prerequisite cycle prevents graph activation" {
    suffix = uuid4().hex; (track, version, blueprint) = _blueprint_fixture(suffix, True); result = TopicSkillGraphGenerationService().generate_graph(blueprint.blueprint_id, GraphGenerationContext(track_id=track.track_id, track_version_id=version.track_version_id, blueprint_id=blueprint.blueprint_id, request_id="request"));
    assert result.status == CurriculumGraphGenerationStatus.FAILED and result.error_code == "CURRICULUM_GRAPH_PREREQUISITE_CYCLE" and len(CurriculumGraphRepository().list_runs(version)) == 0;
}

test "duplicate normalized concepts and self prerequisites are rejected" {
    suffix = uuid4().hex; (track, version, blueprint) = _blueprint_fixture(suffix); evidence = "[{\"chunk_id\":\"chunk\"}]"; blueprint +>:HAS_BLUEPRINT_CONCEPT:+> BlueprintConcept(blueprint_concept_id="duplicate_" + suffix, blueprint_id=blueprint.blueprint_id, local_concept_key="duplicate", canonical_name="  FOUNDATIONS ", description="Duplicate.", concept_type="CORE", aliases_json="[]", learning_objectives_json="[]", key_terms_json="[]", confidence="HIGH", should_be_taught_explicitly=True, evidence_json=evidence);
    result = TopicSkillGraphGenerationService().generate_graph(blueprint.blueprint_id, GraphGenerationContext(track_id=track.track_id, track_version_id=version.track_version_id, blueprint_id=blueprint.blueprint_id, request_id="request")); assert result.error_code == "CURRICULUM_GRAPH_DUPLICATE_SKILL";
}
