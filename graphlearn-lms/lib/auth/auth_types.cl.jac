"""Client auth DTOs and normalized session shape."""

obj:pub AuthSession {
    has authenticated: bool = False;
    has token: str = "";
    has learner_id: str = "";
    has lecturer_id: str = "";
    has active_roles: list[str] = [];
    has username: str = "";
    has email: str = "";
}

