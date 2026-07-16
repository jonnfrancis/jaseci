"""Small localStorage-backed auth persistence helpers."""


glob AUTH_TOKEN_KEY: str = "graphlearn.auth.token";
glob AUTH_LEARNER_KEY: str = "graphlearn.auth.learner_id";
glob AUTH_EMAIL_KEY: str = "graphlearn.auth.email";
glob AUTH_USERNAME_KEY: str = "graphlearn.auth.username";
glob AUTH_LECTURER_KEY: str = "graphlearn.auth.lecturer_id";
glob AUTH_ROLES_KEY: str = "graphlearn.auth.active_roles";

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
    lecturer_id: str = "";
    active_roles: list[str] = [];

    learner_id = _read_storage(AUTH_LEARNER_KEY);
    email = _read_storage(AUTH_EMAIL_KEY);
    token = _read_storage(AUTH_TOKEN_KEY);
    username = _read_storage(AUTH_USERNAME_KEY);
    lecturer_id = _read_storage(AUTH_LECTURER_KEY);
    roles_raw = _read_storage(AUTH_ROLES_KEY);
    if roles_raw != "" { active_roles = JSON.parse(roles_raw) as list[str]; } # jac:ignore[W2001,W6002]

    return {
        "authenticated": learner_id != "",
        "token": token,
        "learner_id": learner_id,
        "lecturer_id": lecturer_id,
        "active_roles": active_roles,
        "username": username,
        "email": email
    };
}

def:pub save_auth_session(session: dict) {
    learner_id = str(session["learner_id"] or "");
    email = str(session["email"] or "");
    username = str(session["username"] or "");
    token = str(session["token"] or "");
    _write_storage(AUTH_LEARNER_KEY, learner_id);
    _write_storage(AUTH_EMAIL_KEY, email);
    _write_storage(AUTH_USERNAME_KEY, username);
    _write_storage(AUTH_LECTURER_KEY, str(session["lecturer_id"] or ""));
    roles_json = JSON.stringify(session["active_roles"] or []) as str; # jac:ignore[W2001,W6002]
    _write_storage(AUTH_ROLES_KEY, roles_json);
    if token != "" {
        _write_storage(AUTH_TOKEN_KEY, token);
        _write_storage("jac_token", token);
    }
}

def:pub clear_auth_session() {
    _remove_storage(AUTH_TOKEN_KEY);
    _remove_storage("jac_token");
    _remove_storage(AUTH_LEARNER_KEY);
    _remove_storage(AUTH_EMAIL_KEY);
    _remove_storage(AUTH_USERNAME_KEY);
    _remove_storage(AUTH_LECTURER_KEY);
    _remove_storage(AUTH_ROLES_KEY);
}
