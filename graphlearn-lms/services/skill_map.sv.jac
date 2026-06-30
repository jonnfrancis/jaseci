"""Skill map read service for the client UI."""

import from nodes.roadmap { Roadmap }
import from walkers.get_skill_map {
    SkillMapEdge as WalkerSkillMapEdge,
    SkillMapError,
    SkillMapSkill as WalkerSkillMapSkill,
    SkillMapSummary as WalkerSkillMapSummary,
    SkillMapView as WalkerSkillMapView,
    get_skill_map
}

obj SkillMapSummary {
    has total_skills: int;
    has mastered_count: int;
    has proficient_count: int;
    has developing_count: int;
    has beginner_count: int;
    has average_mastery: int;
}

obj SkillMapSkill {
    has skill_id: str;
    has name: str;
    has description: str;
    has category: str;
    has mastery_score: int;
    has mastery_level: str;
    has status: str;
    has evidence_count: int;
    has target_lesson_ids: list[str] = [];
}

obj SkillMapEdge {
    has from_skill_id: str;
    has to_skill_id: str;
    has type: str;
}

obj SkillMapView {
    has learner_id: str;
    has language: str;
    has roadmap_id: str;
    has summary: SkillMapSummary;
    has generated_at: str;
    has skills: list[SkillMapSkill] = [];
    has edges: list[SkillMapEdge] = [];
}

obj SkillMapLoadState {
    has status: str;
    has skill_map: SkillMapView | None = None;
    has message: str = "";
}

def _find_roadmap(roadmap_id: str) -> Roadmap | None {
    for roadmap in [root -->][?:Roadmap, id == roadmap_id] {
        return roadmap;
    }
    return None;
}

def _normalize_language(language: str) -> str {
    lowered = language.strip().lower();
    if lowered == "python" {
        return "python";
    }
    if lowered == "jac" {
        return "jac";
    }
    return "";
}

def _first_error_message(errors: list[SkillMapError]) -> str {
    if len(errors) == 0 {
        return "Skill map could not be loaded.";
    }
    return str(errors[0].message);
}

def _first_error_code(errors: list[SkillMapError]) -> str {
    if len(errors) == 0 {
        return "failed";
    }
    return str(errors[0].code);
}

def _summary_to_view(summary: WalkerSkillMapSummary) -> SkillMapSummary {
    return SkillMapSummary(
        total_skills=summary.total_skills,
        mastered_count=summary.mastered_count,
        proficient_count=summary.proficient_count,
        developing_count=summary.developing_count,
        beginner_count=summary.beginner_count,
        average_mastery=summary.average_mastery
    );
}

def _skill_to_view(skill: WalkerSkillMapSkill) -> SkillMapSkill {
    return SkillMapSkill(
        skill_id=skill.skill_id,
        name=skill.name,
        description=skill.description,
        category=skill.category,
        mastery_score=skill.mastery_score,
        mastery_level=skill.mastery_level,
        status=skill.status,
        evidence_count=skill.evidence_count,
        target_lesson_ids=skill.target_lesson_ids
    );
}

def _edge_to_view(map_edge: WalkerSkillMapEdge) -> SkillMapEdge {
    return SkillMapEdge(
        from_skill_id=map_edge.from_skill_id,
        to_skill_id=map_edge.to_skill_id,
        type=map_edge.type
    );
}

def _map_to_view(raw: WalkerSkillMapView) -> SkillMapView {
    skills: list[SkillMapSkill] = [];
    for skill in raw.skills {
        skills = skills + [_skill_to_view(skill)];
    }
    edges: list[SkillMapEdge] = [];
    for edge in raw.edges {
        edges = edges + [_edge_to_view(edge)];
    }
    return SkillMapView(
        learner_id=raw.learner_id,
        language=raw.language,
        roadmap_id=raw.roadmap_id,
        summary=_summary_to_view(raw.summary),
        generated_at=raw.generated_at,
        skills=skills,
        edges=edges
    );
}

def:pub load_skill_map(
    learner_id: str,
    language: str = "",
    roadmap_id: str = ""
) -> SkillMapLoadState {
    if learner_id.strip() == "" {
        return SkillMapLoadState(
            status="missing_learner",
            message="Log in again to load your skill map."
        );
    }

    requested_language = _normalize_language(language);
    if requested_language == "" and roadmap_id.strip() != "" {
        roadmap = _find_roadmap(roadmap_id);
        if roadmap is None {
            return SkillMapLoadState(
                status="missing_roadmap",
                message="Roadmap could not be found."
            );
        }
        if roadmap.learner_id != learner_id {
            return SkillMapLoadState(
                status="roadmap_learner_mismatch",
                message="This roadmap does not belong to the current learner."
            );
        }
        requested_language = _normalize_language(roadmap.language);
    }

    if requested_language == "" {
        return SkillMapLoadState(
            status="missing_language",
            message="Choose Python or Jac before loading a skill map."
        );
    }

    result = root spawn get_skill_map(
        learner_id=learner_id,
        language=requested_language,
        roadmap_id=roadmap_id
    );
    if len(result.errors) > 0 {
        return SkillMapLoadState(
            status=_first_error_code(result.errors),
            message=_first_error_message(result.errors)
        );
    }
    if len(result.reports) == 0 {
        return SkillMapLoadState(
            status="malformed",
            message="The skill map response was empty."
        );
    }

    return SkillMapLoadState(status="ready", skill_map=_map_to_view(result.reports[0]));
}
