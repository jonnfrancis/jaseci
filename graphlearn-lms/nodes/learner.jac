"""Learner domain node."""

node Learner {
    has id: str;
    has name: str;
    has createdAt: str;
    has updatedAt: str;
    has auth_user_id: str = "";
    has auth_root_id: str = "";
    has email: str = "";
    # Authoritative current selection; never use it to rewrite historical records.
    has active_track_id: str | None = None;
    has active_track_version_id: str | None = None;
    # Deprecated compatibility aliases retained through the migration window.
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}
