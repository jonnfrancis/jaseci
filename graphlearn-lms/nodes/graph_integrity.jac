"""Typed graph-integrity and mastery-unlock result contracts."""

obj GraphIntegrityIssue {
    has code: str;
    has severity: str;
    has message: str;
    has node_id: str | None = None;
    has edge_type: str | None = None;
    has details_json: str = "{}";
}

obj GraphIntegrityReport {
    has valid: bool;
    has issues: list[GraphIntegrityIssue];
    has checked_nodes: int;
    has checked_edges: int;
}

obj SkillUnlockEvaluation {
    has skill_id: str;
    has unlockable: bool;
    has blocker_skill_ids: list[str];
    has satisfied_skill_ids: list[str];
}

obj SkillGraphItem {
    has skill_id: str;
    has title: str;
    has mastery_score: float;
    has status: str;
    has prerequisite_ids: list[str];
    has unlockable: bool;
}
