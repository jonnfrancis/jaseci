Read `AGENTS.md`, `context/architecture-context.md`, `context/domain-context.md`, `context/persistence-context.md`, and `context/production-context.md` before starting.

# 27-observability.md

We're implementing the observability subsystem.

This feature adds structured logging, tracing, and walker execution metrics across the LMS.

The goal is to make backend behavior visible during development, testing, demos, and production debugging.

Do not change learner-facing behavior.

Do not modify learning logic.

Do not change AI prompts.

Do not change mastery formulas.

Do not change progression rules.

Do not create new UI features unless a minimal developer-only debug output already exists.

---

## Goal

Make LMS executions observable.

The system should answer:

* Which walker ran?
* Who triggered it?
* What input context was used?
* Did it succeed or fail?
* How long did it take?
* Did it call byLLM?
* Did it write to persistence?
* Which entity ids were created or updated?
* Where did an error happen?
* Are certain walkers slow or failing often?

Observability should help debug issues without exposing sensitive learner data.

---

## Observability Scope

Add observability to:

* authentication-aware walker calls
* assessment generation
* assessment submission
* assessment evaluation
* roadmap generation
* lesson generation
* challenge generation
* challenge submission
* submission evaluation
* mastery update
* skill map retrieval
* progression update
* dashboard aggregation
* AI tutor recommendation
* repository operations where useful
* byLLM calls where useful

---

## Core Requirements

Implement:

* structured logging
* request/correlation ids
* walker execution metrics
* error logging
* latency tracking
* AI call tracking
* repository operation tracking
* safe redaction rules

Do not log secrets.

Do not log passwords.

Do not log auth tokens.

Do not log full learner submitted code by default.

Do not log raw LLM responses by default.

Do not log personally sensitive data unnecessarily.

---

## Suggested Backend Structure

Create observability modules.

Suggested structure:

```text id="k4bebm"
jac/observability/
├── logger.jac
├── tracing.jac
├── metrics.jac
├── redaction.jac
├── events.jac
└── index.jac
```

Adapt paths to the existing project convention if needed.

---

## Structured Logging

Create a reusable logger.

Logs should be structured, not random print statements.

Each log entry should include:

* timestamp
* level
* event name
* walker name optional
* learner id optional
* request id
* correlation id
* entity ids optional
* duration ms optional
* status
* error code optional
* message

Example log shape:

```json id="h3hdu4"
{
  "timestamp": "2026-07-12T19:00:00Z",
  "level": "info",
  "event": "walker.completed",
  "walker": "generate_lesson",
  "learner_id": "learner_001",
  "request_id": "req_123",
  "correlation_id": "corr_456",
  "duration_ms": 1842,
  "status": "success",
  "entity_ids": {
    "roadmap_id": "roadmap_001",
    "roadmap_lesson_id": "roadmap_lesson_003",
    "generated_lesson_id": "lesson_001"
  }
}
```

Use consistent event names.

Avoid ad-hoc log messages.

---

## Log Levels

Support at least:

```text id="o06m86"
debug
info
warn
error
```

Recommended usage:

* `debug`: detailed development-only context
* `info`: successful important lifecycle events
* `warn`: recoverable issues, fallback behavior, missing optional data
* `error`: failed walker execution, failed persistence, failed AI call

Do not use `error` for normal incomplete learner states.

Example:

```text id="mzb5af"
dashboard_state = no_assessment
```

This is not an error.

---

## Request And Correlation IDs

Every walker execution should have a request id.

If a request id already exists in the inbound request context, reuse it.

If not, generate one.

Use correlation id to connect multi-step workflows.

Example flow:

```text id="h6j69g"
assessment → roadmap → lesson → challenge → submission → evaluation → mastery → progression
```

All related events may share a correlation id where possible.

This makes debugging full learner journeys easier.

---

## Walker Execution Instrumentation

Create a reusable wrapper/helper for walker execution.

Each walker should log:

* start event
* success event
* failure event
* duration
* key input ids
* key output ids

Example events:

```text id="qiyq9h"
walker.started
walker.completed
walker.failed
```

Instrument these walkers:

* initialize_assessment
* submit_assessment
* evaluate_assessment
* generate_roadmap
* generate_lesson
* generate_challenge
* submit_challenge
* evaluate_submission
* update_mastery
* get_skill_map
* unlock_next_lesson
* get_dashboard
* recommend_next_action

Do not change walker return shapes unless necessary.

---

## Walker Metrics

Track execution metrics per walker.

Minimum metrics:

* execution count
* success count
* failure count
* average duration
* latest duration
* slow execution count
* byLLM call count if applicable

Suggested metric names:

```text id="l2n4aq"
walker.execution.count
walker.execution.success
walker.execution.failure
walker.execution.duration_ms
walker.execution.slow
```

Metric labels:

* walker
* status
* language optional
* source_type optional
* environment optional

Do not use high-cardinality labels such as full prompt text, full user names, full code, or raw ids unless the observability stack is designed for it.

---

## Slow Execution Thresholds

Define default slow execution thresholds.

Suggested values:

```text id="tdfrns"
normal walker: 1000 ms
AI generation walker: 10000 ms
dashboard aggregation: 2000 ms
database write transaction: 2000 ms
```

Slow AI walkers include:

* initialize_assessment
* generate_roadmap
* generate_lesson
* generate_challenge
* evaluate_submission
* recommend_next_action

If a walker exceeds threshold, log:

```text id="ldejzb"
walker.slow
```

Do not fail the walker only because it is slow.

---

## Tracing

Add lightweight tracing.

Trace important spans:

* walker execution
* repository call
* database transaction
* byLLM call
* graph traversal
* DTO assembly

Suggested span fields:

* trace id
* span id
* parent span id
* operation name
* start time
* end time
* duration ms
* status
* error optional

Example span names:

```text id="fy5pd4"
walker.generate_lesson
repository.lesson.get_generated_lesson
ai.generate_lesson_content
repository.lesson.create_generated_lesson
```

Use simple internal tracing first if a full tracing backend is not configured yet.

Do not introduce a heavy observability platform unless the project already uses one.

---

## byLLM Observability

Instrument byLLM-powered functions.

Track:

* function name
* model/provider if safely available
* start time
* duration
* success/failure
* structured output validation result
* retry count if available
* error type if failure

Do not log:

* full prompts by default
* raw LLM responses by default
* provider API keys
* secrets
* full learner submission code

Allowed safe context:

* language
* lesson title
* challenge id
* output type
* token counts if available
* duration
* error category

Example events:

```text id="elrojf"
ai.call.started
ai.call.completed
ai.call.failed
ai.output.validation_failed
```

---

## Repository Observability

Instrument repository operations where useful.

Track:

* operation name
* entity type
* read/write
* duration
* success/failure
* transaction id if available
* affected count if useful

Example events:

```text id="ynhuta"
repository.query.completed
repository.write.completed
repository.transaction.started
repository.transaction.committed
repository.transaction.rolled_back
```

Do not log full database rows by default.

Do not log raw SQL unless explicitly enabled for local development.

---

## Error Logging

Create consistent error logging.

Each error log should include:

* error code
* error type
* safe message
* walker name
* request id
* correlation id
* relevant entity ids
* stack trace only in development if safe

Common error categories:

```text id="fykkc9"
validation_error
auth_error
not_found
persistence_error
ai_error
configuration_error
unknown_error
```

Do not expose raw stack traces to the frontend.

Frontend responses should receive safe structured errors.

---

## Redaction Rules

Create a redaction helper.

Sensitive values to redact:

* password
* auth token
* access token
* refresh token
* API key
* secret
* database URL
* email if not needed
* full submitted code by default
* raw AI prompt by default
* raw AI response by default

Redacted value format:

```text id="6ygxm5"
[REDACTED]
```

For submitted code, log only safe metadata:

* character count
* line count
* language
* challenge id

Do not log the full code unless a local debug flag explicitly allows it.

---

## Environment Configuration

Add observability configuration.

Suggested environment variables:

```text id="g7m4xo"
LOG_LEVEL=info
OBSERVABILITY_ENABLED=true
TRACE_ENABLED=true
METRICS_ENABLED=true
LOG_AI_PAYLOADS=false
LOG_SUBMISSION_CODE=false
```

Defaults should be safe.

Production defaults:

```text id="5lcljy"
LOG_LEVEL=info
LOG_AI_PAYLOADS=false
LOG_SUBMISSION_CODE=false
```

Development may allow more debug logs, but secrets should still be redacted.

---

## Frontend Observability

Add minimal frontend logging only if already consistent with the project.

Frontend may track:

* page load failures
* walker call failures
* dashboard load failure
* tutor panel failure
* challenge submission failure

Do not add a heavy analytics system in this feature.

Do not track personal learner behavior beyond operational debugging.

Backend observability is the priority.

---

## Audit Events

Some LMS events are important enough to be auditable.

Suggested audit-style events:

* user registered
* user logged in
* assessment submitted
* roadmap generated
* challenge submitted
* submission evaluated
* mastery updated
* lesson unlocked
* roadmap completed

Audit events should be safe and structured.

Do not store raw submissions or AI outputs in audit events.

---

## Metrics Output

For MVP, metrics may be:

* logged as structured events
* exposed through an internal metrics helper
* stored in memory during development
* sent to the configured monitoring backend if one exists

Do not introduce unnecessary infrastructure if the project does not have it yet.

If a `/metrics` endpoint is added, ensure it does not expose sensitive information.

---

## Observability Dashboard Out Of Scope

Do not build a monitoring dashboard in this feature.

Do not build admin UI.

Do not build charts.

This feature only emits logs, traces, and metrics.

---

## Integration With Existing Walkers

Update the existing walkers carefully.

For each walker:

1. create request/correlation context
2. log start
3. execute current logic
4. log success with duration
5. log failure with safe error
6. emit metrics

Preserve the walker’s existing behavior and return value.

Do not rewrite the whole walker.

---

## Testing

Create tests for:

* logger formats structured output
* redaction removes sensitive fields
* walker start log emits
* walker success log emits
* walker failure log emits
* duration is captured
* slow walker emits slow event
* byLLM call success is logged safely
* byLLM call failure is logged safely
* repository transaction commit is logged
* repository transaction rollback is logged
* metrics increment on success
* metrics increment on failure
* correlation id propagates where supported

Tests should not require live AI providers.

Use mocked walkers/repositories/byLLM calls where needed.

---

## Manual Verification

Run the full LMS flow and verify logs/traces appear:

```text id="j7y4gw"
Register/Login
→ Start assessment
→ Submit assessment
→ Evaluate assessment
→ Generate roadmap
→ Generate lesson
→ Generate challenge
→ Submit challenge
→ Evaluate submission
→ Update mastery
→ Unlock next lesson
→ Load dashboard
→ Load AI tutor panel
```

Confirm each major step produces:

* start log
* completion log
* duration
* safe entity ids
* no secrets
* no raw tokens
* no raw code
* no raw AI payloads

---

## Explicitly Out of Scope

Do not implement:

* admin monitoring dashboard
* learner-facing observability UI
* analytics product tracking
* payment analytics
* recommendation changes
* mastery formula changes
* progression rule changes
* new database schema beyond optional observability config/events if needed
* external monitoring vendor integration unless already configured

This feature only adds observability instrumentation.

---

## Check When Done

* Structured logger exists
* Redaction helper exists
* Request id is added to walker executions
* Correlation id is supported
* Walker start events are logged
* Walker success events are logged
* Walker failure events are logged
* Walker durations are recorded
* Slow walker executions are flagged
* Walker execution metrics are captured
* byLLM calls are logged safely
* Repository operations are observable where useful
* Transaction commits and rollbacks are observable
* Sensitive fields are redacted
* Full LMS flow is observable
* Tests pass
* Existing learner behavior is unchanged
