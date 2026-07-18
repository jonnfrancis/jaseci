"""Low-cardinality document-security counters and duration samples."""

glob DOCUMENT_VALIDATION_METRICS: dict[str, int] = {};

def record_document_validation(result: str, error_code: str, duration_ms: int) {
    keys = ["document_validation_total", "document_validation_" + result.lower() + "_total"];
    if error_code == "DOCUMENT_MALWARE_DETECTED" { keys.append("document_validation_malware_detected_total"); }
    if error_code == "DOCUMENT_MACRO_CONTENT_DETECTED" { keys.append("document_validation_macro_detected_total"); }
    if error_code == "DOCUMENT_ENCRYPTED_UNSUPPORTED" { keys.append("document_validation_encrypted_total"); }
    if error_code in ["DOCUMENT_ARCHIVE_BOMB_RISK", "DOCUMENT_ARCHIVE_LIMIT_EXCEEDED", "DOCUMENT_ARCHIVE_PATH_TRAVERSAL"] { keys.append("document_validation_archive_risk_total"); }
    if error_code == "DOCUMENT_SIGNATURE_MISMATCH" { keys.append("document_validation_signature_mismatch_total"); }
    if error_code == "MALWARE_SCAN_UNAVAILABLE" { keys.append("document_validation_scanner_unavailable_total"); }
    for key in keys { DOCUMENT_VALIDATION_METRICS[key] = DOCUMENT_VALIDATION_METRICS.get(key, 0) + 1; }
    DOCUMENT_VALIDATION_METRICS["document_validation_duration_ms_total"] = DOCUMENT_VALIDATION_METRICS.get("document_validation_duration_ms_total", 0) + duration_ms;
}

def document_validation_metric(name: str) -> int { return DOCUMENT_VALIDATION_METRICS.get(name, 0); }

def reset_document_validation_metrics { global DOCUMENT_VALIDATION_METRICS; DOCUMENT_VALIDATION_METRICS = {}; }
