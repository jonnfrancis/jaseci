"""Canonical root-scoped learner mastery lookup."""

import from nodes.mastery { SkillMastery }
import from lib.observability.instrumentation { graph_operation_event }
import from lib.observability.tracing { monotonic_ms }

def skill_mastery_for(learner_id: str, skill_id: str) -> SkillMastery | None {
    started = monotonic_ms();
    for mastery in [root -->][?:SkillMastery] {
        if mastery.learner_id == learner_id and mastery.skill_id == skill_id {
            graph_operation_event("skill_mastery_for", "read", True, max(0, monotonic_ms() - started), 1);
            return mastery;
        }
    }
    graph_operation_event("skill_mastery_for", "read", True, max(0, monotonic_ms() - started), 0);
    return None;
}
