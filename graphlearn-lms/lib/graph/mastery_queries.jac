"""Canonical root-scoped learner mastery lookup."""

import from nodes.mastery { SkillMastery }

def skill_mastery_for(learner_id: str, skill_id: str) -> SkillMastery | None {
    for mastery in [root -->][?:SkillMastery] {
        if mastery.learner_id == learner_id and mastery.skill_id == skill_id {
            return mastery;
        }
    }
    return None;
}
