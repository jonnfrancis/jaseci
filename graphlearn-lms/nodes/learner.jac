"""Learner domain node."""

node Learner {
    has id: str;
    has name: str;
    has createdAt: str;
    has updatedAt: str;
    has auth_user_id: str = "";
    has auth_root_id: str = "";
    has email: str = "";
}
