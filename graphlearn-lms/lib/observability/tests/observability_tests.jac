"""Deterministic observability subsystem tests."""

import os;
import from lib.observability.events { ObservabilityEvent }
import from lib.observability.instrumentation {
    ObservableWalker, ai_call_completed, ai_call_failed, ai_call_started,
    graph_operation_event, lifecycle_event, transaction_event
}
import from lib.observability.logger { captured_events, event_to_dict, reset_captured_events, utc_timestamp }
import from lib.observability.metrics { WalkerMetric, reset_metrics, walker_metric }
import from lib.observability.redaction { REDACTED, redact_fields, submission_code_metadata }
import from lib.observability.tracing { reset_spans }

obj TestObservationError {
    has code: str;
    has message: str;
}

walker observed_success(ObservableWalker) {
    has learner_id: str = "learner-observed";
    has errors: list[TestObservationError] = [];
    has reports: list[str] = [];
    has request_id: str = "";
    has correlation_id: str = "";

    can run with Root entry {
        report "ok";
    }
}

walker observed_failure(ObservableWalker) {
    has learner_id: str = "learner-observed";
    has errors: list[TestObservationError] = [];
    has request_id: str = "";
    has correlation_id: str = "";

    can run with Root entry {
        self.errors = [TestObservationError(code="validation_error", message="Safe failure")];
        return;
    }
}

def _events_named(name: str) -> list[ObservabilityEvent] {
    return [item for item in captured_events() if item.event == name];
}

test "structured logger formats and redacts sensitive fields" {
    item = ObservabilityEvent(
        timestamp=utc_timestamp(), level="info", event="walker.completed",
        status="success", message="done", request_id="req-test",
        correlation_id="corr-test", walker_name="test_walker",
        entity_ids={"roadmap_id": "roadmap-1"},
        attributes={"auth_token": "secret-token", "prompt": "raw prompt", "language": "jac"}
    );
    output = event_to_dict(item);
    attributes = output["attributes"] as dict[str, object];
    assert output["event"] == "walker.completed";
    assert attributes["auth_token"] == REDACTED;
    assert attributes["prompt"] == REDACTED;
    assert attributes["language"] == "jac";
}

test "submission code is represented only by safe metadata" {
    metadata = submission_code_metadata("print('safe')\n", "python", "challenge-1");
    assert metadata["character_count"] == 14;
    assert metadata["line_count"] == 1;
    assert "code" not in metadata;
}

test "walker lifecycle emits start success duration metrics and correlation" {
    reset_captured_events();
    reset_metrics();
    reset_spans();
    _ = root spawn observed_success(request_id="req-existing", correlation_id="corr-existing");
    starts = _events_named("walker.started");
    completed = _events_named("walker.completed");
    assert len(starts) == 1;
    assert len(completed) == 1;
    assert starts[0].request_id == "req-existing";
    assert completed[0].correlation_id == "corr-existing";
    assert completed[0].duration_ms >= 0;
    metric = walker_metric("observed_success");
    assert metric is not None;
    assert (metric as WalkerMetric).execution_count == 1;
    assert (metric as WalkerMetric).success_count == 1;
}

test "walker lifecycle emits failure and increments failure metric" {
    reset_captured_events();
    reset_metrics();
    _ = root spawn observed_failure();
    failed = _events_named("walker.failed");
    assert len(failed) == 1;
    assert failed[0].error_code == "validation_error";
    assert failed[0].message == "Walker failed with a safe application error.";
    metric = walker_metric("observed_failure");
    assert metric is not None;
    assert (metric as WalkerMetric).failure_count == 1;
}

test "slow walker threshold emits warning event" {
    reset_captured_events();
    prior = os.getenv("OBSERVABILITY_WALKER_SLOW_MS", "1000");
    os.environ["OBSERVABILITY_WALKER_SLOW_MS"] = "-1";
    _ = root spawn observed_success();
    os.environ["OBSERVABILITY_WALKER_SLOW_MS"] = prior;
    assert len(_events_named("walker.slow")) == 1;
}

test "AI success and failure events remain payload safe" {
    reset_captured_events();
    started = ai_call_started("observed_success", "mock_ai", "req-ai", "corr-ai", {"prompt": "never log me", "language": "jac"});
    ai_call_completed("observed_success", "mock_ai", "req-ai", "corr-ai", started);
    ai_call_failed("observed_success", "mock_ai", "req-ai", "corr-ai", started, "MockProviderError");
    starts = _events_named("ai.call.started");
    assert len(starts) == 1;
    safe = event_to_dict(starts[0])["attributes"] as dict[str, object];
    assert safe["prompt"] == REDACTED;
    assert len(_events_named("ai.call.completed")) == 1;
    assert len(_events_named("ai.call.failed")) == 1;
}

test "repository and transaction outcomes emit structured events" {
    reset_captured_events();
    graph_operation_event("roadmap_lessons", "read", True, 3, 2);
    transaction_event("test_commit", True, 4);
    transaction_event("test_rollback", False, 5);
    assert len(_events_named("repository.query.completed")) == 1;
    assert len(_events_named("repository.transaction.committed")) == 1;
    assert len(_events_named("repository.transaction.rolled_back")) == 1;
}
