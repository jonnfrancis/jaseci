"""Reusable walker, AI, and graph-operation observability helpers."""

import os;
import from lib.observability.events { ObservabilityEvent, TraceSpan }
import from lib.observability.logger { emit_event, utc_timestamp }
import from lib.observability.metrics { record_byllm_call, record_walker_completed, record_walker_started }
import from lib.observability.tracing { finish_span, monotonic_ms, new_identifier, start_span }

glob AI_WALKERS: list[str] = [
    "initialize_assessment", "generate_roadmap", "generate_lesson",
    "generate_challenge", "evaluate_submission", "recommend_next_action"
];

def walker_slow_threshold_ms(walker_name: str) -> int {
    if walker_name in AI_WALKERS {
        return int(os.getenv("OBSERVABILITY_AI_SLOW_MS", "10000"));
    }
    if walker_name == "get_dashboard" {
        return int(os.getenv("OBSERVABILITY_DASHBOARD_SLOW_MS", "2000"));
    }
    return int(os.getenv("OBSERVABILITY_WALKER_SLOW_MS", "1000"));
}

def lifecycle_event(
    event_name: str,
    level: str,
    status: str,
    walker_name: str,
    request_id: str,
    correlation_id: str,
    learner_id: str = "",
    duration_ms: int = 0,
    error_code: str = "",
    message: str = "",
    entity_ids: dict[str, object] = {},
    attributes: dict[str, object] = {}
) {
    emit_event(ObservabilityEvent(
        timestamp=utc_timestamp(), level=level, event=event_name, status=status,
        message=message, request_id=request_id, correlation_id=correlation_id,
        walker_name=walker_name, learner_id=learner_id, duration_ms=duration_ms,
        error_code=error_code, entity_ids=entity_ids, attributes=attributes
    ));
}

def walker_entity_ids(walker_value: object) -> dict[str, object] {
    ids: dict[str, object] = {};
    for field_name in [
        "assessment_id", "assessment_attempt_id", "assessment_evaluation_id",
        "roadmap_id", "roadmap_lesson_id", "generated_lesson_id",
        "challenge_id", "submission_id", "evaluation_id", "skill_id", "source_id"
    ] {
        value = str(getattr(walker_value, field_name, ""));
        if value != "" {
            ids[field_name] = value;
        }
    }
    return ids;
}

obj WalkerExecutionContext {
    has request_id: str;
    has correlation_id: str;
    has walker_name: str;
    has learner_id: str;
    has started_ms: int;
    has trace: TraceSpan;
    has entity_ids: dict[str, object] = {};
}

glob ACTIVE_WALKERS: dict[int, WalkerExecutionContext] = {};

def observe_walker_start(walker_value: object) {
    global ACTIVE_WALKERS;
    request_id = str(getattr(walker_value, "request_id", ""));
    correlation_id = str(getattr(walker_value, "correlation_id", ""));
    request_id = request_id if request_id != "" else new_identifier("req");
    correlation_id = correlation_id if correlation_id != "" else new_identifier("corr");
    setattr(walker_value, "request_id", request_id);
    setattr(walker_value, "correlation_id", correlation_id);
    walker_name = walker_value.__class__.__name__;
    learner_id = str(getattr(walker_value, "learner_id", ""));
    started_ms = monotonic_ms();
    entity_ids = walker_entity_ids(walker_value);
    trace = start_span(f"walker.{walker_name}", correlation_id);
    ACTIVE_WALKERS[id(walker_value)] = WalkerExecutionContext(request_id=request_id, correlation_id=correlation_id, walker_name=walker_name, learner_id=learner_id, started_ms=started_ms, trace=trace, entity_ids=entity_ids);
    record_walker_started(walker_name);
    lifecycle_event("walker.started", "info", "started", walker_name, request_id, correlation_id, learner_id, entity_ids=entity_ids, attributes={"environment": os.getenv("JAC_PROFILE", "development")});
}

def observe_walker_finish(walker_value: object) {
    global ACTIVE_WALKERS;
    context = ACTIVE_WALKERS.get(id(walker_value));
    if context is None { return; }
    current = context as WalkerExecutionContext;
    duration = max(0, monotonic_ms() - current.started_ms);
    raw_errors = getattr(walker_value, "errors", []) as list[object];
    raw_reports = getattr(walker_value, "reports", []) as list[object];
    if len(raw_reports) > 0 {
        output_id = str(getattr(raw_reports[0], "id", ""));
        if output_id != "" { current.entity_ids["output_id"] = output_id; }
    }
    success = len(raw_errors) == 0;
    error_code = "" if success else str(getattr(raw_errors[0], "code", "unknown_error"));
    slow = duration > walker_slow_threshold_ms(current.walker_name);
    record_walker_completed(current.walker_name, success, duration, slow);
    finish_span(current.trace, duration, success, error_code);
    lifecycle_event("walker.completed" if success else "walker.failed", "info" if success else "error", "success" if success else "failure", current.walker_name, current.request_id, current.correlation_id, current.learner_id, duration, error_code, "Walker completed." if success else "Walker failed with a safe application error.", current.entity_ids);
    if slow {
        lifecycle_event("walker.slow", "warn", "slow", current.walker_name, current.request_id, current.correlation_id, current.learner_id, duration, attributes={"threshold_ms": walker_slow_threshold_ms(current.walker_name)});
    }
    ACTIVE_WALKERS.pop(id(walker_value), None);
}

walker ObservableWalker {
    can observability_start with Root entry {
        global ACTIVE_WALKERS;
        request_id = str(getattr(self, "request_id", ""));
        correlation_id = str(getattr(self, "correlation_id", ""));
        request_id = request_id if request_id != "" else new_identifier("req");
        correlation_id = correlation_id if correlation_id != "" else new_identifier("corr");
        setattr(self, "request_id", request_id);
        setattr(self, "correlation_id", correlation_id);
        walker_name = self.__class__.__name__;
        learner_id = str(getattr(self, "learner_id", ""));
        started_ms = monotonic_ms();
        entity_ids = walker_entity_ids(self);
        trace = start_span(f"walker.{walker_name}", correlation_id);
        ACTIVE_WALKERS[id(self)] = WalkerExecutionContext(
            request_id=request_id, correlation_id=correlation_id, walker_name=walker_name,
            learner_id=learner_id, started_ms=started_ms, trace=trace, entity_ids=entity_ids
        );
        record_walker_started(walker_name);
        lifecycle_event(
            "walker.started", "info", "started", walker_name,
            request_id, correlation_id, learner_id,
            entity_ids=entity_ids,
            attributes={"environment": os.getenv("JAC_PROFILE", "development")}
        );
    }

    can observability_finish with Root exit {
        global ACTIVE_WALKERS;
        context = ACTIVE_WALKERS.get(id(self));
        if context is None {
            return;
        }
        current = context as WalkerExecutionContext;
        duration = max(0, monotonic_ms() - current.started_ms);
        raw_errors = getattr(self, "errors", []) as list[object];
        raw_reports = getattr(self, "reports", []) as list[object];
        if len(raw_reports) > 0 {
            output_id = str(getattr(raw_reports[0], "id", ""));
            if output_id != "" {
                current.entity_ids["output_id"] = output_id;
            }
        }
        success = len(raw_errors) == 0;
        error_code = "";
        if not success {
            first_error = raw_errors[0];
            error_code = str(getattr(first_error, "code", "unknown_error"));
        }
        slow = duration > walker_slow_threshold_ms(current.walker_name);
        record_walker_completed(current.walker_name, success, duration, slow);
        finish_span(current.trace, duration, success, error_code);
        lifecycle_event(
            "walker.completed" if success else "walker.failed",
            "info" if success else "error", "success" if success else "failure",
            current.walker_name, current.request_id, current.correlation_id,
            current.learner_id, duration, error_code,
            "Walker completed." if success else "Walker failed with a safe application error.",
            current.entity_ids
        );
        if slow {
            lifecycle_event(
                "walker.slow", "warn", "slow", current.walker_name,
                current.request_id, current.correlation_id, current.learner_id,
                duration, attributes={"threshold_ms": walker_slow_threshold_ms(current.walker_name)}
            );
        }
        ACTIVE_WALKERS.pop(id(self), None);
    }
}

def ai_call_started(walker_name: str, function_name: str, request_id: str, correlation_id: str, safe_context: dict[str, object] = {}) -> int {
    record_byllm_call(walker_name);
    lifecycle_event("ai.call.started", "info", "started", walker_name, request_id, correlation_id, attributes={"function": function_name, **safe_context});
    return monotonic_ms();
}

def ai_call_completed(walker_name: str, function_name: str, request_id: str, correlation_id: str, started_ms: int, validation_ok: bool = True) {
    lifecycle_event("ai.call.completed", "info", "success", walker_name, request_id, correlation_id, duration_ms=max(0, monotonic_ms() - started_ms), attributes={"function": function_name, "validation_ok": validation_ok});
}

def ai_call_failed(walker_name: str, function_name: str, request_id: str, correlation_id: str, started_ms: int, error_type: str) {
    lifecycle_event("ai.call.failed", "error", "failure", walker_name, request_id, correlation_id, duration_ms=max(0, monotonic_ms() - started_ms), error_code="ai_error", message="AI call failed.", attributes={"function": function_name, "error_type": error_type});
}

def graph_operation_event(operation_name: str, access_kind: str, success: bool, duration_ms: int, affected_count: int = 0) {
    lifecycle_event(
        "repository.query.completed" if access_kind == "read" else "repository.write.completed",
        "info" if success else "error", "success" if success else "failure",
        "", new_identifier("req"), new_identifier("corr"), duration_ms=duration_ms,
        error_code="" if success else "persistence_error",
        attributes={"operation": operation_name, "access": access_kind, "affected_count": affected_count}
    );
}

def transaction_event(operation_name: str, committed: bool, duration_ms: int) {
    lifecycle_event(
        "repository.transaction.committed" if committed else "repository.transaction.rolled_back",
        "info" if committed else "error", "success" if committed else "failure",
        "", new_identifier("req"), new_identifier("corr"), duration_ms=duration_ms,
        error_code="" if committed else "persistence_error",
        attributes={"operation": operation_name}
    );
}
