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
    has canonical_name: str | None = None;
    has concept_type: str = "CORE";
    has aliases_json: str = "[]";
    has key_terms_json: str = "[]";
    has status: str = "ACTIVE";
    has blueprint_id: str | None = None;
    has blueprint_concept_key: str | None = None;
    has graph_generation_id: str | None = None;
    has evidence_json: str = "[]";
    has topological_rank: int | None = None;
}
