"""Low-cardinality processing-job metrics."""
glob DOCUMENT_PROCESSING_METRICS: dict[str, int] = {};
def record_processing_job(result: str, duration_ms: int = 0) { for key in ["document_processing_jobs_total", "document_processing_jobs_" + result.lower() + "_total"] { DOCUMENT_PROCESSING_METRICS[key] = DOCUMENT_PROCESSING_METRICS.get(key, 0) + 1; } DOCUMENT_PROCESSING_METRICS["document_processing_stage_duration_ms"] = DOCUMENT_PROCESSING_METRICS.get("document_processing_stage_duration_ms", 0) + duration_ms; }
def processing_metric(name: str) -> int { return DOCUMENT_PROCESSING_METRICS.get(name, 0); }
