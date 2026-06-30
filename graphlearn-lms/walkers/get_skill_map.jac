"""Read-only learner skill map with mastery overlays."""

import from datetime { datetime }
import from edges.domain_edges { Prerequisite, contains, requires, targets, teaches }
import from nodes.learner { Learner }
import from nodes.mastery { MasteryLevel, SkillMastery }
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapMilestone,
    RoadmapStatus,
    RoadmapWeek
}
import from nodes.skill { Skill }

obj SkillMapError {
    has code: str;
    has message: str;
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

def _current_timestamp -> str {
    return datetime.utcnow().isoformat() + "Z";
}

def _empty_summary -> SkillMapSummary {
    return SkillMapSummary(
        total_skills=0,
        mastered_count=0,
        proficient_count=0,
        developing_count=0,
        beginner_count=0,
        average_mastery=0
    );
}

def _empty_view(learner_id: str, language: str, roadmap_id: str) -> SkillMapView {
    return SkillMapView(
        learner_id=learner_id,
        language=language,
        roadmap_id=roadmap_id,
        summary=_empty_summary(),
        generated_at=_current_timestamp()
    );
}

def _find_learner(learner_id: str) -> Learner | None {
    for learner in [root -->][?:Learner, id == learner_id] {
        return learner;
    }
    return None;
}

def _find_roadmap(roadmap_id: str) -> Roadmap | None {
    for roadmap in [root -->][?:Roadmap, id == roadmap_id] {
        return roadmap;
    }
    return None;
}

def _find_active_roadmap(learner_id: str, language: str) -> Roadmap | None {
    for roadmap in [root -->][?:Roadmap] {
        if roadmap.learner_id == learner_id and roadmap.language == language and roadmap.status == RoadmapStatus.active {
            return roadmap;
        }
    }
    return None;
}

def _find_skill(skill_id: str) -> Skill | None {
    for skill in [root -->][?:Skill, id == skill_id] {
        return skill;
    }
    return None;
}

def _find_mastery(learner_id: str, skill_id: str) -> SkillMastery | None {
    for mastery in [root -->][?:SkillMastery] {
        if mastery.learner_id == learner_id and mastery.skill_id == skill_id {
            return mastery;
        }
    }
    return None;
}

def _roadmap_lessons(roadmap: Roadmap) -> list[RoadmapLesson] {
    lessons = roadmap.lessons;
    if len(lessons) > 0 {
        return lessons;
    }
    loaded: list[RoadmapLesson] = [];
    for week in [roadmap ->:contains:->][?:RoadmapWeek] {
        for lesson in [week ->:contains:->][?:RoadmapLesson] {
            loaded = loaded + [lesson];
        }
    }
    return loaded;
}

def _roadmap_milestones(roadmap: Roadmap) -> list[RoadmapMilestone] {
    milestones = roadmap.milestones;
    if len(milestones) > 0 {
        return milestones;
    }
    loaded: list[RoadmapMilestone] = [];
    for week in [roadmap ->:contains:->][?:RoadmapWeek] {
        for milestone in [week ->:contains:->][?:RoadmapMilestone] {
            loaded = loaded + [milestone];
        }
    }
    return loaded;
}

def _add_unique_str(values: list[str], value: str) -> list[str] {
    if value.strip() == "" or value in values {
        return values;
    }
    return values + [value];
}

def _skill_ids_for_roadmap(roadmap: Roadmap) -> list[str] {
    ids: list[str] = [];
    for lesson in _roadmap_lessons(roadmap) {
        for skill_id in lesson.target_skill_ids {
            ids = _add_unique_str(ids, skill_id);
        }
        for skill in [lesson ->:targets:->][?:Skill] {
            ids = _add_unique_str(ids, skill.id);
        }
    }
    for milestone in _roadmap_milestones(roadmap) {
        for skill_id in milestone.required_skill_ids {
            ids = _add_unique_str(ids, skill_id);
        }
        for skill in [milestone ->:requires:->][?:Skill] {
            ids = _add_unique_str(ids, skill.id);
        }
    }
    return ids;
}

def _target_lesson_ids(roadmap: Roadmap, skill_id: str) -> list[str] {
    ids: list[str] = [];
    for lesson in _roadmap_lessons(roadmap) {
        if skill_id in lesson.target_skill_ids {
            ids = _add_unique_str(ids, lesson.id);
        }
        for skill in [lesson ->:targets:->][?:Skill] {
            if skill.id == skill_id {
                ids = _add_unique_str(ids, lesson.id);
            }
        }
    }
    return ids;
}

def _clamp_int(value: int, low: int, high: int) -> int {
    if value < low {
        return low;
    }
    if value > high {
        return high;
    }
    return value;
}

def _status_for_score(score: int) -> str {
    if score >= 90 {
        return "mastered";
    }
    if score >= 40 {
        return "in_progress";
    }
    return "available";
}

def _level_for_score(score: int) -> str {
    if score >= 90 {
        return "mastered";
    }
    if score >= 70 {
        return "proficient";
    }
    if score >= 40 {
        return "developing";
    }
    return "beginner";
}

def _skill_view(learner_id: str, roadmap: Roadmap, skill: Skill) -> SkillMapSkill {
    mastery = _find_mastery(learner_id, skill.id);
    score = 0;
    level = "beginner";
    evidence_count = 0;
    if mastery is not None {
        score = _clamp_int((mastery as SkillMastery).score, 0, 100);
        level = (mastery as SkillMastery).level.value;
        evidence_count = (mastery as SkillMastery).evidence_count;
    }
    return SkillMapSkill(
        skill_id=skill.id,
        name=skill.name,
        description=skill.description,
        category=skill.category,
        mastery_score=score,
        mastery_level=level,
        status=_status_for_score(score),
        evidence_count=evidence_count,
        target_lesson_ids=_target_lesson_ids(roadmap, skill.id)
    );
}

def _skill_order(skill: SkillMapSkill) -> str {
    return skill.skill_id;
}

def _edge_key(map_edge: SkillMapEdge) -> str {
    return map_edge.from_skill_id + "|" + map_edge.to_skill_id + "|" + map_edge.type;
}

def _add_edge(edges: list[SkillMapEdge], from_id: str, to_id: str, edge_type: str) -> list[SkillMapEdge] {
    if from_id.strip() == "" or to_id.strip() == "" or from_id == to_id {
        return edges;
    }
    new_edge = SkillMapEdge(from_skill_id=from_id, to_skill_id=to_id, type=edge_type);
    new_key = _edge_key(new_edge);
    for existing_edge in edges {
        if _edge_key(existing_edge) == new_key {
            return edges;
        }
    }
    return edges + [new_edge];
}

def _edges_for_skills(skill_ids: list[str]) -> list[SkillMapEdge] {
    edges: list[SkillMapEdge] = [];
    for skill_id in skill_ids {
        skill = _find_skill(skill_id);
        if skill is not None {
            source = skill as Skill;
            for target in [source ->:Prerequisite:->][?:Skill] {
                if target.id in skill_ids {
                    edges = _add_edge(edges, source.id, target.id, "prerequisite");
                }
            }
            for target in [source ->:teaches:->][?:Skill] {
                if target.id in skill_ids {
                    edges = _add_edge(edges, source.id, target.id, "teaches");
                }
            }
        }
    }
    return edges;
}

def _summary(skills: list[SkillMapSkill]) -> SkillMapSummary {
    total = len(skills);
    mastered_count = 0;
    proficient_count = 0;
    developing_count = 0;
    beginner_count = 0;
    total_score = 0;
    for skill in skills {
        total_score += skill.mastery_score;
        if skill.mastery_level == "mastered" {
            mastered_count += 1;
        } elif skill.mastery_level == "proficient" {
            proficient_count += 1;
        } elif skill.mastery_level == "developing" {
            developing_count += 1;
        } else {
            beginner_count += 1;
        }
    }
    average = 0 if total == 0 else int(total_score / total);
    return SkillMapSummary(
        total_skills=total,
        mastered_count=mastered_count,
        proficient_count=proficient_count,
        developing_count=developing_count,
        beginner_count=beginner_count,
        average_mastery=average
    );
}

def _skill_map_view(learner_id: str, language: str, roadmap: Roadmap) -> SkillMapView {
    skill_ids = _skill_ids_for_roadmap(roadmap);
    skill_views: list[SkillMapSkill] = [];
    for skill_id in skill_ids {
        skill = _find_skill(skill_id);
        if skill is not None {
            skill_views = skill_views + [_skill_view(learner_id, roadmap, skill as Skill)];
        }
    }
    sorted_skills = sorted(skill_views, key=_skill_order);
    return SkillMapView(
        learner_id=learner_id,
        language=language,
        roadmap_id=roadmap.id,
        summary=_summary(sorted_skills),
        skills=sorted_skills,
        edges=_edges_for_skills(skill_ids),
        generated_at=_current_timestamp()
    );
}

walker get_skill_map {
    has learner_id: str;
    has language: str;
    has roadmap_id: str = "";
    has errors: list[SkillMapError] = [];
    has reports: list[SkillMapView] = [];

    can load with Root entry {
        language_normalized = self.language.strip().lower();
        if self.learner_id.strip() == "" {
            self.errors = self.errors + [SkillMapError(code="missing_learner", message="Log in again to load the skill map.")];
            return;
        }
        if language_normalized not in ["python", "jac"] {
            self.errors = self.errors + [SkillMapError(code="unsupported_language", message="Skill maps currently support python and jac only.")];
            return;
        }

        learner = _find_learner(self.learner_id);
        if learner is None {
            self.errors = self.errors + [SkillMapError(code="missing_learner", message="Learner does not exist.")];
            return;
        }

        roadmap: Roadmap | None = None;
        if self.roadmap_id.strip() != "" {
            found = _find_roadmap(self.roadmap_id);
            if found is None {
                self.errors = self.errors + [SkillMapError(code="missing_roadmap", message="Roadmap does not exist.")];
                return;
            }
            if found.learner_id != self.learner_id {
                self.errors = self.errors + [SkillMapError(code="roadmap_learner_mismatch", message="Roadmap does not belong to this learner.")];
                return;
            }
            if found.language != language_normalized {
                self.errors = self.errors + [SkillMapError(code="language_mismatch", message="Roadmap language does not match the requested skill map language.")];
                return;
            }
            roadmap = found;
        } else {
            roadmap = _find_active_roadmap(self.learner_id, language_normalized);
        }

        if roadmap is None {
            report _empty_view(self.learner_id, language_normalized, "");
            return;
        }

        report _skill_map_view(self.learner_id, language_normalized, roadmap as Roadmap);
    }
}
