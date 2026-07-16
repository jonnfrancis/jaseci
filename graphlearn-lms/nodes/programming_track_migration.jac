"""Programming-track compatibility and migration records."""

obj LegacyTrackResolution {
    has resolved: bool;
    has canonical_language: str | None;
    has track_id: str | None;
    has track_version_id: str | None;
    has source_value: str | None;
    has resolution_type: str;
    has error_code: str | None;
    has message: str = "";
}

obj TrackContext {
    has track_id: str;
    has track_version_id: str;
    has title: str;
    has legacy_language: str | None;
    has resolution_source: str;
}

obj BuiltinTrackSeedOutcome {
    has canonical_language: str;
    has track_id: str;
    has status: str;
    has message: str = "";
}

obj BuiltinTrackSeedReport {
    has status: str;
    has created: int = 0;
    has unchanged: int = 0;
    has repaired: int = 0;
    has skipped: int = 0;
    has failed: int = 0;
    has outcomes: list[BuiltinTrackSeedOutcome] = [];
}

node ProgrammingTrackMigrationLedger {
    has migration_name: str = "programming-track-migration";
    has migration_version: int = 1;
    has created_at: str = "";
    has updated_at: str = "";
}

node ProgrammingTrackMigrationRecord {
    has migration_id: str;
    has migration_version: int;
    has entity_type: str;
    has entity_id: str;
    has status: str;
    has message: str;
    has previous_language: str | None = None;
    has previous_track_id: str | None = None;
    has previous_track_version_id: str | None = None;
    has assigned_track_id: str | None = None;
    has assigned_track_version_id: str | None = None;
    has migrated_at: str | None = None;
}

obj ProgrammingTrackMigrationReport {
    has migration: str;
    has version: int;
    has mode: str;
    has status: str;
    has started_at: str;
    has completed_at: str;
    has tracks_created: int = 0;
    has tracks_reused: int = 0;
    has tracks_repaired: int = 0;
    has tracks_failed: int = 0;
    has records_scanned: int = 0;
    has records_migratable: int = 0;
    has records_migrated: int = 0;
    has records_unchanged: int = 0;
    has records_unresolved: int = 0;
    has records_conflicts: int = 0;
    has records_failed: int = 0;
    has unresolved_values: list[str] = [];
    has conflict_ids: list[str] = [];
}

edge HAS_MIGRATION_RECORD {}
