"""Thin wrapper around Jac runtime auth helpers."""

import from "@jac/runtime" { __getApiBaseUrl, jacIsLoggedIn, jacLogin,  jacLogout, jacSignup, jacSetToken }
import from .auth_storage { clear_auth_session, read_auth_session, save_auth_session }

def _auth_token_from_storage() -> str {
    token = localStorage.getItem("graphlearn.auth.token"); # jac:ignore[W2001,E1030,W6002]
    if token {
        return str(token);
    }
    for key in ["jac_token", "jac_access_token", "access_token", "token", "JAC_AUTH_TOKEN"] {
        candidate = localStorage.getItem(key); # jac:ignore[W2001,E1030,W6002]
        if candidate {
            return str(candidate);
        }
    }
    return "";
}

def _normalize_learner_id(raw_id: str, email: str) -> str {
    if raw_id.strip() != "" {
        return raw_id.strip();
    }
    return email.strip().lower();
}

def _first_auth_envelope(raw: any) -> dict {
    if isinstance(raw, list) and len(raw) > 0 {
        return raw[0] as dict;
    }
    return raw as dict;
}

def _auth_data(envelope: dict) -> dict {
    data = envelope["data"];
    if data {
        return data as dict;
    }
    return {};
}

async def _post_auth(path: str, body: dict) -> dict {
    response: any = None;
    raw: any = None;
    body_text: str = "";
    response = await fetch(__getApiBaseUrl() + path, { # jac:ignore[W2001,W6002]
        "method": "POST",
        "headers": {"Content-Type": "application/json"},
        "body": JSON.stringify(body) # jac:ignore[W2001,W6002]
    });
    body_text = await response.text();
    raw = JSON.parse(body_text); # jac:ignore[W2001,W6002]
    envelope = _first_auth_envelope(raw);
    if not response.ok or not envelope["ok"] {
        raise Exception("Authentication request failed.");
    }
    return envelope;
}

def:pub current_auth_session() -> dict {
    stored: dict = {};
    authenticated_value: bool = False;
    token_value: str = "";
    learner_id_value: str = "";
    username_value: str = "";
    email_value: str = "";

    stored = read_auth_session();

    authenticated_value = jacIsLoggedIn();

    if stored["authenticated"] {
        authenticated_value = True;
    }

    token_value = _auth_token_from_storage();
    learner_id_value = str(stored["learner_id"] or "");
    username_value = str(stored["username"] or "");
    email_value = str(stored["email"] or "");

    return {
        "authenticated": authenticated_value,
        "token": token_value,
        "learner_id": learner_id_value,
        "username": username_value,
        "email": email_value
    };
}

def:pub is_authenticated() -> bool {
    return jacIsLoggedIn() or read_auth_session().authenticated;
}

def:pub get_current_token() -> str {
    return _auth_token_from_storage();
}

def:pub get_current_learner_id() -> str {
    return read_auth_session().learner_id;
}

async def:pub register_user(username: str, email: str, password: str) -> dict {
    signup_result: dict | None = None;
    login_session: dict = {};

    signup_result = await jacSignup(email, password);

    if not signup_result["success"] {
        return {
            "authenticated": False,
            "token": "",
            "learner_id": "",
            "username": username,
            "email": email
        };
    }

    login_session = await login_user(email, password);

    if login_session["authenticated"] as bool {
        success_session = {
            "authenticated": True,
            "token": login_session["token"],
            "learner_id": login_session["learner_id"],
            "username": username,
            "email": email
        };

        save_auth_session(success_session);

        return success_session;
    }

    session = {
        "authenticated": False,
        "token": "",
        "learner_id": "",
        "username": username,
        "email": email
    };

    return session;
}

async def:pub login_user(email: str, password: str) -> dict {
    ok: bool = False;

    ok = await jacLogin(email, password);

    if not ok {
        return {
            "authenticated": False,
            "token": "",
            "learner_id": "",
            "username": "",
            "email": email
        };
    }

    session = {
        "authenticated": True,
        "token": "",
        "learner_id": email.strip().lower(),
        "username": email,
        "email": email
    };

    save_auth_session(session);

    return session;
}

def:pub logout_user() {
    jacLogout();
    clear_auth_session();
}
