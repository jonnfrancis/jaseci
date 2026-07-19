"""Stable blueprint AI error taxonomy."""

enum BlueprintAIErrorCode: str {
    PROVIDER_UNAVAILABLE = "BYLLM_BLUEPRINT_PROVIDER_UNAVAILABLE", TIMEOUT = "BYLLM_BLUEPRINT_TIMEOUT", RATE_LIMITED = "BYLLM_BLUEPRINT_RATE_LIMITED", EMPTY_RESPONSE = "BYLLM_BLUEPRINT_EMPTY_RESPONSE", STRUCTURED_OUTPUT_INVALID = "BYLLM_BLUEPRINT_STRUCTURED_OUTPUT_INVALID", DOMAIN_INVALID = "BYLLM_BLUEPRINT_DOMAIN_INVALID", EVIDENCE_REFERENCE_INVALID = "BYLLM_EVIDENCE_REFERENCE_INVALID", DANGLING_REFERENCE = "BYLLM_BLUEPRINT_DANGLING_REFERENCE", DUPLICATE_KEY = "BYLLM_BLUEPRINT_DUPLICATE_KEY", OUTPUT_LIMIT_EXCEEDED = "BYLLM_BLUEPRINT_OUTPUT_LIMIT_EXCEEDED", INSUFFICIENT_EVIDENCE = "BYLLM_BLUEPRINT_INSUFFICIENT_EVIDENCE", COVERAGE_LOW = "BYLLM_BLUEPRINT_COVERAGE_LOW", PROMPT_VERSION_UNSUPPORTED = "BYLLM_BLUEPRINT_PROMPT_VERSION_UNSUPPORTED", SCHEMA_VERSION_UNSUPPORTED = "BYLLM_BLUEPRINT_SCHEMA_VERSION_UNSUPPORTED", RETRY_EXHAUSTED = "BYLLM_BLUEPRINT_RETRY_EXHAUSTED"
}

obj BlueprintValidationIssue { has code: BlueprintAIErrorCode; has message: str; has reference: str = ""; }
obj BlueprintValidationResult { has valid: bool; has errors: list[BlueprintValidationIssue] = []; has warnings: list[BlueprintValidationIssue] = []; has source_coverage: float = 0.0; }

def transient_blueprint_error(code: BlueprintAIErrorCode) -> bool { return code in [BlueprintAIErrorCode.PROVIDER_UNAVAILABLE, BlueprintAIErrorCode.TIMEOUT, BlueprintAIErrorCode.RATE_LIMITED, BlueprintAIErrorCode.EMPTY_RESPONSE, BlueprintAIErrorCode.STRUCTURED_OUTPUT_INVALID]; }
def blueprint_user_message(code: BlueprintAIErrorCode) -> str { if code in [BlueprintAIErrorCode.INSUFFICIENT_EVIDENCE, BlueprintAIErrorCode.COVERAGE_LOW] { return "The uploaded notes do not contain enough structured course content to generate a reliable course outline. Please review or replace the document."; } return "We could not interpret the course notes right now. Please retry processing."; }
