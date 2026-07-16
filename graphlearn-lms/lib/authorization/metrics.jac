"""Low-cardinality authorization and compatibility-fallback metrics."""

glob AUTHORIZATION_ALLOW_TOTAL: int = 0;
glob AUTHORIZATION_DENY_TOTAL: int = 0;
glob OWNERSHIP_SCALAR_FALLBACK_TOTAL: int = 0;

def record_authorization(allowed: bool) {
    global AUTHORIZATION_ALLOW_TOTAL, AUTHORIZATION_DENY_TOTAL;
    if allowed { AUTHORIZATION_ALLOW_TOTAL += 1; } else { AUTHORIZATION_DENY_TOTAL += 1; }
}

def record_owner_scalar_fallback {
    global OWNERSHIP_SCALAR_FALLBACK_TOTAL; OWNERSHIP_SCALAR_FALLBACK_TOTAL += 1;
}

def reset_authorization_metrics {
    global AUTHORIZATION_ALLOW_TOTAL, AUTHORIZATION_DENY_TOTAL, OWNERSHIP_SCALAR_FALLBACK_TOTAL;
    AUTHORIZATION_ALLOW_TOTAL = 0; AUTHORIZATION_DENY_TOTAL = 0; OWNERSHIP_SCALAR_FALLBACK_TOTAL = 0;
}

def ownership_scalar_fallback_total -> int { return OWNERSHIP_SCALAR_FALLBACK_TOTAL; }
