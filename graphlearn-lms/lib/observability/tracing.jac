"""Lightweight internal trace spans."""

import time;
import uuid;
import os;
import from lib.observability.events { TraceSpan }
import from lib.observability.logger { utc_timestamp }

glob TRACE_SPANS: list[TraceSpan] = [];

def trace_enabled -> bool {
    return os.getenv("TRACE_ENABLED", "true").strip().lower() not in ["0", "false", "no", "off"];
}

def new_identifier(prefix: str) -> str {
    return f"{prefix}_{str(uuid.uuid4())}";
}

def start_span(operation_name: str, trace_id: str = "", parent_span_id: str = "") -> TraceSpan {
    global TRACE_SPANS;
    span = TraceSpan(
        trace_id=trace_id if trace_id != "" else new_identifier("trace"),
        span_id=new_identifier("span"),
        parent_span_id=parent_span_id,
        operation_name=operation_name,
        start_time=utc_timestamp()
    );
    if trace_enabled() { TRACE_SPANS.append(span); }
    return span;
}

def finish_span(span: TraceSpan, duration_ms: int, success: bool, error_code: str = "") {
    span.end_time = utc_timestamp();
    span.duration_ms = duration_ms;
    span.status = "success" if success else "failure";
    span.error_code = error_code;
}

def captured_spans -> list[TraceSpan] {
    return TRACE_SPANS.copy();
}

def reset_spans {
    global TRACE_SPANS;
    TRACE_SPANS = [];
}

def monotonic_ms -> int {
    return int(time.perf_counter() * 1000);
}
