"""Small localStorage-backed auth persistence helpers."""


glob AUTH_TOKEN_KEY: str = "graphlearn.auth.token";
glob AUTH_LEARNER_KEY: str = "graphlearn.auth.learner_id";
glob AUTH_EMAIL_KEY: str = "graphlearn.auth.email";
glob AUTH_USERNAME_KEY: str = "graphlearn.auth.username";

def _read_storage(key: str) -> str {
    value = localStorage.getItem(key); # jac:ignore[W2001,E1030,W6002]
    return str(value) if value else "";
}

def _write_storage(key: str, value: str) {
    localStorage.setItem(key, value); # jac:ignore[W2001,E1030,W6002]
}

def _remove_storage(key: str) {
    localStorage.removeItem(key); # jac:ignore[W2001,E1030,W6002]
}

def:pub read_auth_session() -> dict {
    learner_id: str = "";
    email: str = "";
    token: str = "";
    username: str = "";

    learner_id = _read_storage(AUTH_LEARNER_KEY);
    email = _read_storage(AUTH_EMAIL_KEY);
    token = _read_storage(AUTH_TOKEN_KEY);
    username = _read_storage(AUTH_USERNAME_KEY);

    return {
        "authenticated": learner_id != "",
        "token": token,
        "learner_id": learner_id,
        "username": username,
        "email": email
    };
}

def:pub save_auth_session(session: dict) {
    _write_storage(AUTH_LEARNER_KEY, session.learner_id);
    _write_storage(AUTH_EMAIL_KEY, session.email);
    _write_storage(AUTH_USERNAME_KEY, session.username);
    if session.token != "" {
        _write_storage(AUTH_TOKEN_KEY, session.token);
        _write_storage("jac_token", session.token);
    }
}

def:pub clear_auth_session() {
    _remove_storage(AUTH_TOKEN_KEY);
    _remove_storage("jac_token");
    _remove_storage(AUTH_LEARNER_KEY);
    _remove_storage(AUTH_EMAIL_KEY);
    _remove_storage(AUTH_USERNAME_KEY);
}
