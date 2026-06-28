"""Client auth DTOs and normalized session shape."""

obj:pub AuthSession {
    has authenticated: bool = False;
    has token: str = "";
    has learner_id: str = "";
    has username: str = "";
    has email: str = "";
}

