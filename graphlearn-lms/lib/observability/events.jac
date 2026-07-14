"""Typed observability event records."""

obj ObservabilityEvent {
    has timestamp: str;
    has level: str;
    has event: str;
    has status: str;
    has message: str;
    has request_id: str;
    has correlation_id: str;
    has walker_name: str = "";
    has learner_id: str = "";
    has duration_ms: int = 0;
    has error_code: str = "";
    has entity_ids: dict[str, object] = {};
    has attributes: dict[str, object] = {};
}

obj TraceSpan {
    has trace_id: str;
    has span_id: str;
    has parent_span_id: str;
    has operation_name: str;
    has start_time: str;
    has end_time: str = "";
    has duration_ms: int = 0;
    has status: str = "started";
    has error_code: str = "";
}
