"""Skill domain node."""

node Skill {
    has id: str;
    has name: str;
    has description: str;
    has category: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has skill_id: str | None = None;
    has title: str | None = None;
    has skill_type: str = "CONCEPT";
    has difficulty: str = "MIXED";
    has mastery_threshold: float = 0.80;
    has order_hint: int | None = None;
    has created_at: str = "";
    has updated_at: str = "";
}
