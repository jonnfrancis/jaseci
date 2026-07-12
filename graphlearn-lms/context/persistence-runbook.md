# Persistence Operations Runbook

GraphLearn stores LMS domain state in Jac's graph database. SQLite is the local single-process backend; scaled deployments use the Jac-supported MongoDB backend configured with `MONGODB_URI`.

## Required production environment

* `MONGODB_URI`: durable MongoDB connection string
* `JWT_SECRET`: long random signing secret, stored in the deployment secret manager
* `REDIS_URL`: required when the deployment uses multiple replicas/cache coordination

Never commit real values. Use `.env.example` as the key list only.

## Local development

Run Jac commands from the project root so the runtime-managed `.jac` database location remains stable. Ordinary restarts must preserve `.jac/`. `jac clean --data` and deleting database files are destructive resets, not restart steps.

## Startup checks

Before accepting traffic, verify that the configured database is reachable and record only:

* backend type
* non-secret logical database/data location
* schema repair mode
* connection success/failure

Never log connection strings, credentials, tokens, learner content, or raw AI payloads.

## Schema recovery

For persisted archetype load failures, inspect quarantine before changing data:

```text
jac db quarantine list --app main.jac
jac db recover-all --app main.jac
```

Confirm the exact command syntax against the installed Jac version. Use `schema_alias`, `schema_drop`, `schema_upgrade`, and `@archetype_alias` for compatible migrations. Never delete production data to resolve a schema mismatch.

## Backup and restore

Production MongoDB backups must be automated, encrypted, retention-scoped, and restored periodically in a non-production environment. A restore is accepted only after the authenticated restart flow can rebuild dashboard, roadmap, lesson, skill-map, and tutor read models.

## Failure semantics

A database outage is an availability error. It must not be converted into an empty assessment, missing roadmap, or new-learner state. Client surfaces should retain the current journey hint and offer retry/login recovery without writing replacement records.
