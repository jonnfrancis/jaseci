"""Coverage for read-only learner skill map retrieval."""

import from edges.domain_edges { Prerequisite, assigned, contains, mastered, targets }
import from nodes.learner { Learner }
import from nodes.mastery { MasteryLevel, SkillMastery }
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapMilestone,
    RoadmapStatus,
    RoadmapWeek
}
import from nodes.skill { Skill }
import from walkers.get_skill_map { SkillMapEdge, get_skill_map }

def _unique_id(prefix: str) -> str {
    return f"{prefix}-{len([root -->][?:Learner]) + 1}";
}

def _seed_learner(learner_id: str) -> Learner {
    return (root ++> Learner(
        id=learner_id,
        name="Skill Map Learner",
        createdAt="2026-06-30",
        updatedAt="2026-06-30"
    ))[0];
}

def _seed_skill(skill_id: str, name: str, category: str = "python") -> Skill {
    return (root ++> Skill(
        id=skill_id,
        name=name,
        description=f"{name} description.",
        category=category
    ))[0];
}

def _seed_roadmap(
    learner: Learner,
    prefix: str,
    language: str,
    skill_ids: list[str],
    status: RoadmapStatus = RoadmapStatus.active
) -> Roadmap {
    roadmap = (root ++> Roadmap(
        id=f"{prefix}-roadmap",
        learner_id=learner.id,
        language=language,
        title="Skill Map Roadmap",
        description="Seeded roadmap.",
        estimated_weeks=1,
        status=status,
        created_at="2026-06-30T00:00:00Z",
        assessment_id=f"{prefix}-assessment",
        assessment_attempt_id=f"{prefix}-attempt",
        assessment_evaluation_id=f"{prefix}-evaluation"
    ))[0];
    learner +>:assigned:+> roadmap;
    week = (roadmap +>:contains:+> RoadmapWeek(
        id=f"{prefix}-week-1",
        roadmap_id=roadmap.id,
        week_number=1,
        title="Week One",
        summary="Seeded week."
    ))[0];
    roadmap.weeks.append(week);
    lesson = (week +>:contains:+> RoadmapLesson(
        id=f"{prefix}-lesson-1",
        roadmap_id=roadmap.id,
        week_id=week.id,
        title="Seeded Lesson",
        summary="Targets seeded skills.",
        target_skill_ids=skill_ids,
        difficulty="beginner",
        estimated_minutes=10,
        order_index=1,
        generation_status=RoadmapLessonGenerationStatus.pending
    ))[0];
    week.lessons.append(lesson);
    roadmap.lessons.append(lesson);
    for skill_id in skill_ids {
        skill = _find_skill(skill_id);
        if skill is not None {
            lesson +>:targets:+> (skill as Skill);
        }
    }
    return roadmap;
}

def _find_skill(skill_id: str) -> Skill | None {
    for skill in [root -->][?:Skill, id == skill_id] {
        return skill;
    }
    return None;
}

def _seed_mastery(
    learner: Learner,
    skill: Skill,
    score: int,
    level: MasteryLevel,
    evidence_count: int
) -> SkillMastery {
    mastery = (root ++> SkillMastery(
        id=f"skill-mastery-{learner.id}-{skill.id}",
        learner_id=learner.id,
        skill_id=skill.id,
        score=score,
        level=level,
        evidence_count=evidence_count,
        last_source_type="submission_evaluation",
        last_source_id=f"{skill.id}-source",
        updated_at="2026-06-30T01:00:00Z",
        created_at="2026-06-30T01:00:00Z"
    ))[0];
    learner +>:mastered:+> mastery;
    mastery +>:targets:+> skill;
    return mastery;
}

test "skill map defaults missing mastery records" {
    prefix = _unique_id("skill-map-defaults");
    learner = _seed_learner(f"{prefix}-learner");
    variables = _seed_skill(f"{prefix}-variables", "Variables");
    functions = _seed_skill(f"{prefix}-functions", "Functions");
    roadmap = _seed_roadmap(learner, prefix, "python", [variables.id, functions.id]);

    result = root spawn get_skill_map(
        learner_id=learner.id,
        language="python",
        roadmap_id=roadmap.id
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.roadmap_id == roadmap.id;
    assert view.summary.total_skills == 2;
    assert view.summary.beginner_count == 2;
    assert view.summary.average_mastery == 0;
    assert view.skills[0].mastery_score == 0;
    assert view.skills[0].mastery_level == "beginner";
    assert view.skills[0].status == "available";
    assert len(view.skills[0].target_lesson_ids) == 1;
}

test "skill map overlays assessment and challenge mastery counts" {
    prefix = _unique_id("skill-map-mastery");
    learner = _seed_learner(f"{prefix}-learner");
    beginner = _seed_skill("python_beginner_map", "Beginner");
    developing = _seed_skill("python_developing_map", "Developing");
    proficient = _seed_skill("python_proficient_map", "Proficient");
    mastered_skill = _seed_skill("python_mastered_map", "Mastered");
    _seed_roadmap(
        learner,
        prefix,
        "python",
        [beginner.id, developing.id, proficient.id, mastered_skill.id]
    );
    _seed_mastery(learner, developing, 55, MasteryLevel.developing, 2);
    _seed_mastery(learner, proficient, 82, MasteryLevel.proficient, 3);
    _seed_mastery(learner, mastered_skill, 94, MasteryLevel.mastered, 4);

    result = root spawn get_skill_map(learner_id=learner.id, language="python");

    assert len(result.errors) == 0;
    summary = result.reports[0].summary;
    assert summary.total_skills == 4;
    assert summary.beginner_count == 1;
    assert summary.developing_count == 1;
    assert summary.proficient_count == 1;
    assert summary.mastered_count == 1;
    assert summary.average_mastery == 57;
}

test "skill map includes prerequisite edges" {
    prefix = _unique_id("skill-map-prereq");
    learner = _seed_learner(f"{prefix}-learner");
    variables = _seed_skill("python_variables_prereq", "Variables");
    functions = _seed_skill("python_functions_prereq", "Functions");
    variables +>:Prerequisite:+> functions;
    _seed_roadmap(learner, prefix, "python", [variables.id, functions.id]);

    result = root spawn get_skill_map(learner_id=learner.id, language="python");

    assert len(result.errors) == 0;
    assert len(result.reports[0].edges) == 1;
    map_edge: SkillMapEdge = result.reports[0].edges[0];
    assert map_edge.from_skill_id == variables.id;
    assert map_edge.to_skill_id == functions.id;
    assert map_edge.type == "prerequisite";
}

test "skill map filters by requested roadmap" {
    prefix = _unique_id("skill-map-filter");
    learner = _seed_learner(f"{prefix}-learner");
    python_skill = _seed_skill("python_filter_skill", "Python Filter");
    jac_skill = _seed_skill("jac_filter_skill", "Jac Filter", "jac");
    python_roadmap = _seed_roadmap(learner, f"{prefix}-python", "python", [python_skill.id]);
    _seed_roadmap(learner, f"{prefix}-jac", "jac", [jac_skill.id]);

    result = root spawn get_skill_map(
        learner_id=learner.id,
        language="python",
        roadmap_id=python_roadmap.id
    );

    assert len(result.errors) == 0;
    assert result.reports[0].summary.total_skills == 1;
    assert result.reports[0].skills[0].skill_id == python_skill.id;
}

test "skill map rejects missing roadmap" {
    prefix = _unique_id("skill-map-missing-roadmap");
    learner = _seed_learner(f"{prefix}-learner");

    result = root spawn get_skill_map(
        learner_id=learner.id,
        language="python",
        roadmap_id="missing-roadmap"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "missing_roadmap";
}

test "skill map rejects unsupported language" {
    prefix = _unique_id("skill-map-unsupported");
    learner = _seed_learner(f"{prefix}-learner");

    result = root spawn get_skill_map(
        learner_id=learner.id,
        language="typescript"
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "unsupported_language";
}

test "skill map returns empty view when no active roadmap exists" {
    prefix = _unique_id("skill-map-empty");
    learner = _seed_learner(f"{prefix}-learner");

    result = root spawn get_skill_map(
        learner_id=learner.id,
        language="python"
    );

    assert len(result.errors) == 0;
    view = result.reports[0];
    assert view.learner_id == learner.id;
    assert view.language == "python";
    assert view.roadmap_id == "";
    assert view.summary.total_skills == 0;
    assert view.summary.average_mastery == 0;
    assert len(view.skills) == 0;
    assert len(view.edges) == 0;
}

test "skill map rejects roadmap owned by another learner" {
    prefix = _unique_id("skill-map-owner");
    learner = _seed_learner(f"{prefix}-learner");
    other = _seed_learner(f"{prefix}-other");
    skill = _seed_skill("python_owner_skill", "Owner Skill");
    roadmap = _seed_roadmap(other, prefix, "python", [skill.id]);

    result = root spawn get_skill_map(
        learner_id=learner.id,
        language="python",
        roadmap_id=roadmap.id
    );

    assert len(result.reports) == 0;
    assert result.errors[0].code == "roadmap_learner_mismatch";
}
