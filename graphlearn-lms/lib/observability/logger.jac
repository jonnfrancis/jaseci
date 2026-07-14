"""Structured JSON event logger with safe defaults."""

import json;
import os;
import from datetime { datetime, timezone }
import from lib.observability.events { ObservabilityEvent }
import from lib.observability.redaction { redact_fields }

glob LOG_LEVELS: dict[str, int] = {"debug": 10, "info": 20, "warn": 30, "error": 40};
glob CAPTURED_EVENTS: list[ObservabilityEvent] = [];

def utc_timestamp -> str {
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z");
}

def observability_enabled -> bool {
    return os.getenv("OBSERVABILITY_ENABLED", "true").strip().lower() not in ["0", "false", "no", "off"];
}

def _should_emit(level: str) -> bool {
    configured = os.getenv("LOG_LEVEL", "info").strip().lower();
    return LOG_LEVELS.get(level, 20) >= LOG_LEVELS.get(configured, 20);
}

def event_to_dict(item: ObservabilityEvent) -> dict[str, object] {
    return {
        "timestamp": item.timestamp,
        "level": item.level,
        "event": item.event,
        "walker": item.walker_name,
        "learner_id": item.learner_id,
        "request_id": item.request_id,
        "correlation_id": item.correlation_id,
        "duration_ms": item.duration_ms,
        "status": item.status,
        "error_code": item.error_code,
        "message": item.message,
        "entity_ids": redact_fields(item.entity_ids),
        "attributes": redact_fields(item.attributes)
    };
}

def emit_event(item: ObservabilityEvent) {
    global CAPTURED_EVENTS;
    if not observability_enabled() {
        return;
    }
    CAPTURED_EVENTS.append(item);
    if _should_emit(item.level) {
        print(json.dumps(event_to_dict(item), separators=(",", ":"), default=str));
    }
}

def captured_events -> list[ObservabilityEvent] {
    return CAPTURED_EVENTS.copy();
}

def reset_captured_events {
    global CAPTURED_EVENTS;
    CAPTURED_EVENTS = [];
}
