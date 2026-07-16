"""Skill domain node."""

node Skill {
    has id: str;
    has name: str;
    has description: str;
    has category: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}
