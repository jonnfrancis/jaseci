"""Low-cardinality in-memory walker metrics for MVP observability."""

import os;

def metrics_enabled -> bool {
    return os.getenv("METRICS_ENABLED", "true").strip().lower() not in ["0", "false", "no", "off"];
}

obj WalkerMetric {
    has walker_name: str;
    has execution_count: int = 0;
    has success_count: int = 0;
    has failure_count: int = 0;
    has total_duration_ms: int = 0;
    has latest_duration_ms: int = 0;
    has slow_execution_count: int = 0;
    has byllm_call_count: int = 0;

    def average_duration_ms -> float {
        return 0.0 if self.execution_count == 0 else self.total_duration_ms / self.execution_count;
    }
}

glob WALKER_METRICS: dict[str, WalkerMetric] = {};

def record_walker_started(walker_name: str) {
    if not metrics_enabled() { return; }
    metric = WALKER_METRICS.get(walker_name);
    if metric is None {
        metric = WalkerMetric(walker_name=walker_name);
        WALKER_METRICS[walker_name] = metric;
    }
    (metric as WalkerMetric).execution_count += 1;
}

def record_walker_completed(walker_name: str, success: bool, duration_ms: int, slow: bool) {
    if not metrics_enabled() { return; }
    metric = WALKER_METRICS.get(walker_name);
    if metric is None {
        metric = WalkerMetric(walker_name=walker_name, execution_count=1);
        WALKER_METRICS[walker_name] = metric;
    }
    current = metric as WalkerMetric;
    current.success_count += 1 if success else 0;
    current.failure_count += 0 if success else 1;
    current.total_duration_ms += duration_ms;
    current.latest_duration_ms = duration_ms;
    current.slow_execution_count += 1 if slow else 0;
}

def record_byllm_call(walker_name: str) {
    if not metrics_enabled() { return; }
    metric = WALKER_METRICS.get(walker_name);
    if metric is None {
        metric = WalkerMetric(walker_name=walker_name);
        WALKER_METRICS[walker_name] = metric;
    }
    (metric as WalkerMetric).byllm_call_count += 1;
}

def walker_metric(walker_name: str) -> WalkerMetric | None {
    return WALKER_METRICS.get(walker_name);
}

def reset_metrics {
    global WALKER_METRICS;
    WALKER_METRICS = {};
}
