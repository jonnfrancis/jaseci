"""Safe redaction and metadata helpers for observability payloads."""

glob REDACTED: str = "[REDACTED]";
glob SENSITIVE_KEYS: list[str] = [
    "password", "token", "auth_token", "access_token", "refresh_token",
    "api_key", "secret", "database_url", "email", "code", "prompt",
    "response", "raw_response"
];

def is_sensitive_key(key: str) -> bool {
    normalized = key.strip().lower();
    for sensitive in SENSITIVE_KEYS {
        if sensitive in normalized {
            return True;
        }
    }
    return False;
}

def redact_fields(values: dict[str, object]) -> dict[str, object] {
    safe: dict[str, object] = {};
    for pair in values.items() {
        key = pair[0];
        value = pair[1];
        safe[key] = REDACTED if is_sensitive_key(key) else value;
    }
    return safe;
}

def submission_code_metadata(code: str, language: str, challenge_id: str) -> dict[str, object] {
    return {
        "character_count": len(code),
        "line_count": 0 if code == "" else len(code.splitlines()),
        "language": language,
        "challenge_id": challenge_id
    };
}
