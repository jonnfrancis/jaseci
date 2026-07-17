"""Learning-track validation, persistence, lifecycle, seeding, and compatibility."""

import re;
import from datetime { datetime, timezone }
import from uuid { uuid4 }
import from edges.domain_edges { HAS_LEARNING_TRACK, HAS_TRACK_CONFIGURATION, HAS_TRACK_VERSION }
import from lib.observability.events { ObservabilityEvent }
import from lib.observability.logger { emit_event }
import from lib.learning_track.registry {
    BUILTIN_PROGRAMMING_TRACKS,
    BuiltinProgrammingTrackDefinition,
    builtin_track_by_id,
    builtin_track_by_language,
    builtin_track_by_version_id,
    normalize_legacy_language,
    registry_is_valid
}
import from nodes.learning_track {
    CreateLearningTrackInput,
    LearningCatalogue,
    LearningTrack,
    LearningTrackDetail,
    LearningTrackError,
    LearningTrackMigrationReport,
    LearningTrackResult,
    LearningTrackStatus,
    LearningTrackSummary,
    LearningTrackType,
    LearningTrackVisibility,
    TrackConfiguration,
    TrackDifficultyLevel,
    TrackOwnershipType,
    TrackSourceKind,
    TrackVersion,
    TrackVersionStatus
}
import from nodes.programming_track_migration {
    BuiltinTrackSeedOutcome,
    BuiltinTrackSeedReport,
    LegacyTrackResolution,
    TrackContext
}

glob MAX_TRACK_TITLE_LENGTH: int = 160;
glob MAX_COURSE_CODE_LENGTH: int = 40;
glob MAX_TRACK_DURATION_WEEKS: int = 520;

def _now -> str {
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z");
}

def _error(code: str, message: str, details: dict[str, str] | None = None) -> LearningTrackResult {
    safe_details: dict[str, str] = {} if details is None else details;
    return LearningTrackResult(
        ok=False,
        error=LearningTrackError(code=code, message=message, details=safe_details)
    );
}

def _emit(event_name: str, track: LearningTrack, version: TrackVersion | None = None, actor_id: str = "") {
    version_id = version.track_version_id if version is not None else "";
    version_number = version.version_number if version is not None else 0;
    emit_event(ObservabilityEvent(
        timestamp=_now(),
        level="info",
        event=event_name,
        status="completed",
        message=event_name,
        request_id="",
        correlation_id="",
        entity_ids={"track_id": track.track_id, "track_version_id": version_id},
        attributes={
            "version_number": version_number,
            "track_type": str(track.track_type),
            "actor_id": actor_id
        }
    ));
}

def _clean_optional(value: str | None) -> str | None {
    if value is None { return None; }
    cleaned = value.strip();
    return cleaned if cleaned != "" else None;
}

def _valid_title(value: str) -> bool {
    cleaned = value.strip();
    if cleaned == "" or len(cleaned) > MAX_TRACK_TITLE_LENGTH { return False; }
    for char in cleaned {
        if ord(char) < 32 or ord(char) == 127 { return False; }
    }
    return True;
}

def _slug_base(title: str) -> str {
    slug = re.sub(r"[^a-z0-9]+", "-", title.strip().lower()).strip("-");
    return slug;
}

def _valid_course_code(value: str | None) -> bool {
    if value is None { return True; }
    cleaned = value.strip();
    if len(cleaned) > MAX_COURSE_CODE_LENGTH { return False; }
    return re.fullmatch(r"[A-Za-z0-9 /-]*", cleaned) is not None;
}

def _valid_ownership(input: CreateLearningTrackInput, actor_id: str, trusted_system: bool) -> bool {
    if input.track_type == LearningTrackType.PROGRAMMING_LANGUAGE {
        return trusted_system and input.ownership_type == TrackOwnershipType.SYSTEM and input.owner_id is None;
    }
    if input.track_type == LearningTrackType.LECTURER_COURSE {
        return input.ownership_type == TrackOwnershipType.LECTURER and actor_id.strip() != "";
    }
    return False;
}

def default_catalogue -> LearningCatalogue {
    catalogues: list[LearningCatalogue] = [root.shared -->][?:LearningCatalogue];
    for catalogue in catalogues {
        if catalogue.catalogue_id == "global" { return catalogue; }
    }
    timestamp = _now();
    catalogue = (root.shared ++> LearningCatalogue(created_at=timestamp, updated_at=timestamp))[0];
    grant(catalogue, level=ConnectPerm);
    return catalogue;
}

def existing_catalogue -> LearningCatalogue | None {
    catalogues: list[LearningCatalogue] = [root.shared -->][?:LearningCatalogue];
    for catalogue in catalogues {
        if catalogue.catalogue_id == "global" { return catalogue; }
    }
    return None;
}

def find_track_readonly(track_id: str) -> LearningTrack | None {
    catalogue = existing_catalogue();
    if catalogue is None { return None; }
    for track in [catalogue ->:HAS_LEARNING_TRACK:->][?:LearningTrack] {
        if track.track_id == track_id { return track; }
    }
    return None;
}

def catalogue_tracks -> list[LearningTrack] {
    catalogue = default_catalogue();
    return [catalogue ->:HAS_LEARNING_TRACK:->][?:LearningTrack];
}

def find_track(track_id: str) -> LearningTrack | None {
    for track in catalogue_tracks() {
        if track.track_id == track_id { return track; }
    }
    return None;
}

def _find_version(track: LearningTrack, track_version_id: str) -> TrackVersion | None {
    for version in [track ->:HAS_TRACK_VERSION:->][?:TrackVersion] {
        if version.track_version_id == track_version_id { return version; }
    }
    return None;
}

def track_versions(track: LearningTrack) -> list[TrackVersion] {
    return [track ->:HAS_TRACK_VERSION:->][?:TrackVersion];
}

def track_configuration(track: LearningTrack) -> TrackConfiguration | None {
    for configuration in [track ->:HAS_TRACK_CONFIGURATION:->][?:TrackConfiguration] {
        return configuration;
    }
    return None;
}

def _unique_slug(title: str) -> str {
    base = _slug_base(title);
    if base == "" { return ""; }
    candidate = base;
    suffix = 2;
    while True {
        collision = False;
        for track in catalogue_tracks() {
            if track.slug == candidate { collision = True; break; }
        }
        if not collision { return candidate; }
        candidate = f"{base}-{suffix}";
        suffix += 1;
    }
    return candidate;
}

def _summary(track: LearningTrack) -> LearningTrackSummary {
    return LearningTrackSummary(
        track_id=track.track_id,
        slug=track.slug,
        title=track.title,
        short_description=track.short_description,
        track_type=track.track_type,
        status=track.status,
        visibility=track.visibility,
        course_code=track.course_code,
        subject_area=track.subject_area,
        active_version_id=track.active_version_id,
        is_enrollment_open=track.is_enrollment_open
    );
}

def track_detail(track: LearningTrack) -> LearningTrackDetail {
    return LearningTrackDetail(
        track=_summary(track),
        ownership_type=track.ownership_type,
        owner_id=track.owner_id,
        institution_id=track.institution_id,
        academic_level=track.academic_level,
        default_difficulty=track.default_difficulty,
        estimated_duration_weeks=track.estimated_duration_weeks,
        current_version_number=track.current_version_number,
        created_at=track.created_at,
        updated_at=track.updated_at,
        published_at=track.published_at
    );
}

def create_track(
    input: CreateLearningTrackInput,
    actor_id: str,
    trusted_system: bool = False,
    track_id_override: str | None = None
) -> LearningTrackResult {
    if not _valid_title(input.title) {
        return _error("TRACK_VALIDATION_FAILED", "A non-empty valid title is required.");
    }
    if not _valid_ownership(input, actor_id, trusted_system) {
        return _error("INVALID_TRACK_OWNER", "The track type and ownership are not valid.");
    }
    if input.estimated_duration_weeks is not None and (
        input.estimated_duration_weeks <= 0 or input.estimated_duration_weeks > MAX_TRACK_DURATION_WEEKS
    ) {
        return _error("TRACK_VALIDATION_FAILED", "Estimated duration is outside the supported range.");
    }
    if not _valid_course_code(input.course_code) {
        return _error("TRACK_VALIDATION_FAILED", "Course code contains unsupported characters or is too long.");
    }

    if track_id_override is not None and track_id_override.startswith("trk_builtin_") and not trusted_system {
        return _error("LEARNING_TRACK_ID_CONFLICT", "The built-in identifier namespace is reserved.");
    }
    track_id = track_id_override if track_id_override is not None else f"trk_{uuid4().hex}";
    if find_track(track_id) is not None {
        return _error("LEARNING_TRACK_ID_CONFLICT", "The learning-track identifier already exists.", {"track_id": track_id});
    }
    slug = _unique_slug(input.title);
    if slug == "" { return _error("TRACK_VALIDATION_FAILED", "The title cannot produce a valid slug."); }
    timestamp = _now();
    owner_id: str | None = None;
    if input.track_type == LearningTrackType.LECTURER_COURSE { owner_id = actor_id.strip(); }
    status = LearningTrackStatus.DRAFT;
    visibility = input.visibility if trusted_system else LearningTrackVisibility.PRIVATE;
    track = LearningTrack(
        track_id=track_id,
        slug=slug,
        title=input.title.strip(),
        short_description=input.short_description.strip(),
        track_type=input.track_type,
        status=status,
        visibility=visibility,
        ownership_type=input.ownership_type,
        owner_id=owner_id,
        institution_id=_clean_optional(input.institution_id),
        course_code=_clean_optional(input.course_code),
        subject_area=_clean_optional(input.subject_area),
        academic_level=_clean_optional(input.academic_level),
        default_difficulty=input.default_difficulty,
        estimated_duration_weeks=input.estimated_duration_weeks,
        created_at=timestamp,
        updated_at=timestamp
    );
    catalogue = default_catalogue();
    track = (catalogue +>:HAS_LEARNING_TRACK(created_at=timestamp):+> track)[0];
    configuration_id = f"cfg_{track_id[4:]}" if trusted_system and track_id.startswith("trk_builtin_") else f"cfg_{track_id}";
    configuration = (track +>:HAS_TRACK_CONFIGURATION:+> TrackConfiguration(
        configuration_id=configuration_id,
        track_id=track_id,
        supports_code_challenge=input.track_type == LearningTrackType.PROGRAMMING_LANGUAGE,
        created_at=timestamp,
        updated_at=timestamp
    ))[0];
    grant(track, level=ReadPerm);
    grant(configuration, level=ReadPerm);
    _emit("learning_track.created", track, actor_id=actor_id);
    return LearningTrackResult(ok=True, track=track);
}

def create_initial_version_for_track(track: LearningTrack, actor_id: str, source_kind: TrackSourceKind = TrackSourceKind.MANUAL) -> LearningTrackResult {
    if track.ownership_type == TrackOwnershipType.LECTURER and track.owner_id != actor_id {
        return _error("INVALID_TRACK_OWNER", "Only the track owner may create a version.");
    }
    if track.current_version_number != 0 or len(track_versions(track)) > 0 {
        return _error("TRACK_VERSION_MISMATCH", "Version 1 already exists for this track.");
    }
    timestamp = _now();
    version = (track +>:HAS_TRACK_VERSION(version_number=1, created_at=timestamp):+> TrackVersion(
        track_version_id=f"trv_{track.track_id}_v1",
        track_id=track.track_id,
        version_number=1,
        title_snapshot=track.title,
        description_snapshot=track.short_description,
        source_kind=source_kind,
        created_by=actor_id,
        created_at=timestamp,
        updated_at=timestamp
    ))[0];
    track.current_version_number = 1;
    track.updated_at = timestamp;
    grant(version, level=ReadPerm);
    _emit("track_version.created", track, version, actor_id);
    return LearningTrackResult(ok=True, track=track, version=version);
}

def create_initial_version(track_id: str, actor_id: str, source_kind: TrackSourceKind = TrackSourceKind.MANUAL) -> LearningTrackResult {
    track = find_track(track_id);
    if track is None { return _error("LEARNING_TRACK_NOT_FOUND", "Learning track was not found.", {"track_id": track_id}); }
    return create_initial_version_for_track(track, actor_id, source_kind);
}

def create_next_draft_version(track_id: str, actor_id: str, change_summary: str = "") -> LearningTrackResult {
    track = find_track(track_id);
    if track is None { return _error("LEARNING_TRACK_NOT_FOUND", "Learning track was not found."); }
    if track.ownership_type == TrackOwnershipType.SYSTEM or track.owner_id != actor_id {
        return _error("INVALID_TRACK_OWNER", "This actor cannot create a draft for the track.");
    }
    for version in track_versions(track) {
        if version.status == TrackVersionStatus.DRAFT or version.status == TrackVersionStatus.REVIEW_REQUIRED {
            return _error("TRACK_ALREADY_HAS_DRAFT", "The track already has an active draft version.");
        }
    }
    number = track.current_version_number + 1;
    timestamp = _now();
    version = (track +>:HAS_TRACK_VERSION(version_number=number, created_at=timestamp):+> TrackVersion(
        track_version_id=f"trv_{track.track_id}_v{number}",
        track_id=track.track_id,
        version_number=number,
        title_snapshot=track.title,
        description_snapshot=track.short_description,
        change_summary=change_summary.strip(),
        source_kind=TrackSourceKind.MANUAL,
        created_by=actor_id,
        created_at=timestamp,
        updated_at=timestamp
    ))[0];
    track.current_version_number = number;
    track.updated_at = timestamp;
    grant(version, level=ReadPerm);
    _emit("track_version.created", track, version, actor_id);
    return LearningTrackResult(ok=True, track=track, version=version);
}

def _track_transition_allowed(old: LearningTrackStatus, new: LearningTrackStatus) -> bool {
    if old == LearningTrackStatus.DRAFT { return new in [LearningTrackStatus.PROCESSING, LearningTrackStatus.REVIEW_REQUIRED, LearningTrackStatus.FAILED, LearningTrackStatus.ARCHIVED]; }
    if old == LearningTrackStatus.PROCESSING { return new in [LearningTrackStatus.REVIEW_REQUIRED, LearningTrackStatus.FAILED, LearningTrackStatus.DRAFT]; }
    if old == LearningTrackStatus.REVIEW_REQUIRED { return new in [LearningTrackStatus.DRAFT, LearningTrackStatus.PUBLISHED, LearningTrackStatus.FAILED, LearningTrackStatus.ARCHIVED]; }
    if old == LearningTrackStatus.PUBLISHED { return new == LearningTrackStatus.ARCHIVED; }
    if old == LearningTrackStatus.FAILED { return new in [LearningTrackStatus.DRAFT, LearningTrackStatus.PROCESSING, LearningTrackStatus.ARCHIVED]; }
    return False;
}

def transition_track_status(track_id: str, new_status: LearningTrackStatus, actor_id: str) -> LearningTrackResult {
    track = find_track(track_id);
    if track is None { return _error("LEARNING_TRACK_NOT_FOUND", "Learning track was not found."); }
    if track.ownership_type == TrackOwnershipType.SYSTEM or track.owner_id != actor_id {
        return _error("INVALID_TRACK_OWNER", "This actor cannot change the track lifecycle.");
    }
    if not _track_transition_allowed(track.status, new_status) {
        return _error("INVALID_TRACK_STATUS_TRANSITION", "The requested track transition is not allowed.");
    }
    if new_status == LearningTrackStatus.PUBLISHED and not validate_active_version(track) {
        return _error("TRACK_ACTIVE_VERSION_INVALID", "A published active version is required before publication.");
    }
    old_status = track.status;
    track.status = new_status;
    track.updated_at = _now();
    if new_status == LearningTrackStatus.ARCHIVED {
        track.archived_at = track.updated_at;
        track.is_enrollment_open = False;
        _emit("learning_track.archived", track, actor_id=actor_id);
    } else { _emit("learning_track.status_changed", track, actor_id=actor_id); }
    _ = old_status;
    return LearningTrackResult(ok=True, track=track);
}

def _version_transition_allowed(old: TrackVersionStatus, new: TrackVersionStatus) -> bool {
    if old == TrackVersionStatus.DRAFT { return new in [TrackVersionStatus.REVIEW_REQUIRED, TrackVersionStatus.FAILED, TrackVersionStatus.ARCHIVED]; }
    if old == TrackVersionStatus.REVIEW_REQUIRED { return new in [TrackVersionStatus.DRAFT, TrackVersionStatus.APPROVED, TrackVersionStatus.FAILED, TrackVersionStatus.ARCHIVED]; }
    if old == TrackVersionStatus.APPROVED { return new in [TrackVersionStatus.PUBLISHED, TrackVersionStatus.ARCHIVED]; }
    if old == TrackVersionStatus.PUBLISHED { return new in [TrackVersionStatus.SUPERSEDED, TrackVersionStatus.ARCHIVED]; }
    if old == TrackVersionStatus.FAILED { return new in [TrackVersionStatus.DRAFT, TrackVersionStatus.ARCHIVED]; }
    return False;
}

def transition_version_status(track_id: str, track_version_id: str, new_status: TrackVersionStatus, actor_id: str) -> LearningTrackResult {
    track = find_track(track_id);
    if track is None { return _error("LEARNING_TRACK_NOT_FOUND", "Learning track was not found."); }
    if track.ownership_type == TrackOwnershipType.SYSTEM or track.owner_id != actor_id {
        return _error("INVALID_TRACK_OWNER", "This actor cannot change the version lifecycle.");
    }
    version = _find_version(track, track_version_id);
    if version is None { return _error("TRACK_VERSION_NOT_FOUND", "Track version was not found."); }
    if not _version_transition_allowed(version.status, new_status) {
        code = "TRACK_VERSION_IMMUTABLE" if version.status == TrackVersionStatus.PUBLISHED else "TRACK_VERSION_MISMATCH";
        return _error(code, "The requested version transition is not allowed.");
    }
    timestamp = _now();
    version.status = new_status;
    version.updated_at = timestamp;
    if new_status == TrackVersionStatus.APPROVED { version.approved_by = actor_id; version.approved_at = timestamp; }
    _emit("track_version.status_changed", track, version, actor_id);
    return LearningTrackResult(ok=True, track=track, version=version);
}

def activate_published_version(track_id: str, track_version_id: str, actor_id: str) -> LearningTrackResult {
    track = find_track(track_id);
    if track is None { return _error("LEARNING_TRACK_NOT_FOUND", "Learning track was not found."); }
    if track.ownership_type == TrackOwnershipType.SYSTEM or track.owner_id != actor_id {
        return _error("INVALID_TRACK_OWNER", "This actor cannot publish this track.");
    }
    version = _find_version(track, track_version_id);
    if version is None { return _error("TRACK_VERSION_NOT_FOUND", "Track version was not found."); }
    if version.track_id != track.track_id { return _error("TRACK_VERSION_MISMATCH", "Version belongs to another track."); }
    if version.status != TrackVersionStatus.APPROVED { return _error("TRACK_VERSION_MISMATCH", "Only an approved version can be activated."); }
    timestamp = _now();
    if track.active_version_id is not None {
        previous = _find_version(track, track.active_version_id);
        if previous is not None and previous.status == TrackVersionStatus.PUBLISHED {
            previous.status = TrackVersionStatus.SUPERSEDED;
            previous.superseded_at = timestamp;
            previous.updated_at = timestamp;
        }
    }
    version.status = TrackVersionStatus.PUBLISHED;
    version.published_at = timestamp;
    version.updated_at = timestamp;
    track.active_version_id = version.track_version_id;
    track.updated_at = timestamp;
    _emit("track_version.activated", track, version, actor_id);
    return LearningTrackResult(ok=True, track=track, version=version);
}

def validate_active_version(track: LearningTrack) -> bool {
    if track.active_version_id is None { return False; }
    version = _find_version(track, track.active_version_id);
    return version is not None and version.track_id == track.track_id and version.status == TrackVersionStatus.PUBLISHED;
}

def can_discover(track: LearningTrack, viewer_id: str = "") -> bool {
    if track.status != LearningTrackStatus.PUBLISHED or not validate_active_version(track) { return False; }
    if track.visibility == LearningTrackVisibility.PUBLIC { return True; }
    if track.visibility == LearningTrackVisibility.PRIVATE { return track.owner_id is not None and track.owner_id == viewer_id; }
    return False;
}

def can_enroll(track: LearningTrack, viewer_id: str = "") -> bool {
    return track.status != LearningTrackStatus.ARCHIVED and track.is_enrollment_open and can_discover(track, viewer_id);
}

def list_discoverable_tracks(viewer_id: str = "") -> list[LearningTrackSummary] {
    return [_summary(track) for track in catalogue_tracks() if can_discover(track, viewer_id)];
}

def resolve_legacy_programming_track(
    track_id: str | None,
    track_version_id: str | None,
    language: str | None
) -> LegacyTrackResolution {
    clean_track_id = track_id.strip() if track_id is not None else "";
    clean_version_id = track_version_id.strip() if track_version_id is not None else "";
    normalized = normalize_legacy_language(language);
    source = language;

    if clean_track_id != "" {
        track = find_track(clean_track_id);
        if track is None {
            return LegacyTrackResolution(False, None, None, None, source, "UNRESOLVED", "LEARNING_TRACK_NOT_FOUND", "The supplied track does not exist.");
        }
        version_id = clean_version_id;
        if version_id == "" {
            if track.active_version_id is None {
                return LegacyTrackResolution(False, None, track.track_id, None, source, "UNRESOLVED", "TRACK_ACTIVE_VERSION_INVALID", "The track has no active version.");
            }
            version_id = track.active_version_id;
        }
        version = _find_version(track, version_id);
        if version is None or version.track_id != track.track_id {
            return LegacyTrackResolution(False, None, track.track_id, version_id, source, "CONFLICT", "TRACK_VERSION_MISMATCH", "The supplied version does not belong to the track.");
        }
        definition = builtin_track_by_id(track.track_id);
        canonical = definition.canonical_language if definition is not None else None;
        if normalized is not None {
            language_definition = builtin_track_by_language(normalized);
            if language_definition is None or language_definition.track_id != track.track_id {
                return LegacyTrackResolution(False, canonical, track.track_id, version.track_version_id, source, "CONFLICT", "TRACK_LANGUAGE_CONFLICT", "The legacy language conflicts with the authoritative track.");
            }
        }
        return LegacyTrackResolution(True, canonical, track.track_id, version.track_version_id, source, "TRACK_ID", None, "Resolved from the authoritative track reference.");
    }

    if clean_version_id != "" {
        definition = builtin_track_by_version_id(clean_version_id);
        if definition is None {
            return LegacyTrackResolution(False, None, None, clean_version_id, source, "UNRESOLVED", "TRACK_VERSION_NOT_FOUND", "The supplied version is not registered.");
        }
        return LegacyTrackResolution(False, definition.canonical_language, None, clean_version_id, source, "CONFLICT", "TRACK_VERSION_MISMATCH", "A version cannot be resolved without its track.");
    }
    if normalized is None {
        return LegacyTrackResolution(False, None, None, None, source, "MISSING", "TRACK_CONTEXT_MISSING", "No curriculum identity was supplied.");
    }
    definition = builtin_track_by_language(normalized);
    if definition is None {
        return LegacyTrackResolution(False, None, None, None, source, "UNRESOLVED", "LEGACY_LANGUAGE_UNRESOLVED", "The legacy language is not a supported exact alias.");
    }
    track = find_track(definition.track_id);
    if track is None or _find_version(track, definition.track_version_id) is None {
        return LegacyTrackResolution(False, definition.canonical_language, definition.track_id, definition.track_version_id, source, "UNRESOLVED", "BUILTIN_TRACK_NOT_SEEDED", "The registered track graph is incomplete.");
    }
    resolution_type = "CANONICAL_LANGUAGE" if normalized == definition.canonical_language else "ALIAS";
    return LegacyTrackResolution(True, definition.canonical_language, definition.track_id, definition.track_version_id, source, resolution_type, None, "Resolved through the canonical built-in registry.");
}

def resolve_track_context(track_id: str | None, track_version_id: str | None, language: str | None) -> TrackContext | None {
    resolution = resolve_legacy_programming_track(track_id, track_version_id, language);
    if not resolution.resolved or resolution.track_id is None or resolution.track_version_id is None { return None; }
    track = find_track(resolution.track_id);
    if track is None { return None; }
    return TrackContext(
        track_id=resolution.track_id,
        track_version_id=resolution.track_version_id,
        title=track.title,
        legacy_language=resolution.canonical_language,
        resolution_source=resolution.resolution_type
    );
}

def resolve_learning_track(track_id: str | None, language: str | None) -> LearningTrackResult {
    resolution = resolve_legacy_programming_track(track_id, None, language);
    if not resolution.resolved or resolution.track_id is None {
        return _error(resolution.error_code or "TRACK_VALIDATION_FAILED", resolution.message);
    }
    track = find_track(resolution.track_id);
    if track is None { return _error("LEARNING_TRACK_NOT_FOUND", "Learning track was not found."); }
    return LearningTrackResult(ok=True, track=track);
}

def _seed_failure(definition: BuiltinProgrammingTrackDefinition, message: str) -> BuiltinTrackSeedOutcome {
    return BuiltinTrackSeedOutcome(definition.canonical_language, definition.track_id, "FAILED", message);
}

def _ensure_builtin(definition: BuiltinProgrammingTrackDefinition) -> BuiltinTrackSeedOutcome {
    if not definition.enabled { return BuiltinTrackSeedOutcome(definition.canonical_language, definition.track_id, "SKIPPED", "Registry entry is disabled."); }
    track = find_track(definition.track_id);
    created = False;
    repaired = False;
    if track is None {
        for other in catalogue_tracks() {
            if other.slug == definition.slug { return _seed_failure(definition, "The deterministic slug belongs to another track."); }
        }
        result = create_track(
            CreateLearningTrackInput(
                title=definition.title,
                short_description=definition.description,
                track_type=LearningTrackType.PROGRAMMING_LANGUAGE,
                visibility=LearningTrackVisibility.PUBLIC,
                ownership_type=TrackOwnershipType.SYSTEM,
                subject_area=definition.subject_area,
                default_difficulty=TrackDifficultyLevel.MIXED,
                estimated_duration_weeks=12
            ),
            actor_id="system",
            trusted_system=True,
            track_id_override=definition.track_id
        );
        if not result.ok or result.track is None { return _seed_failure(definition, "The deterministic track could not be created."); }
        track = result.track;
        created = True;
    }
    if track.track_type != LearningTrackType.PROGRAMMING_LANGUAGE or track.ownership_type != TrackOwnershipType.SYSTEM or track.owner_id is not None or track.slug != definition.slug {
        return _seed_failure(definition, "An immutable track identity field conflicts with the registry.");
    }

    timestamp = _now();
    versions = track_versions(track);
    version: TrackVersion | None = None;
    for candidate in versions {
        if candidate.track_version_id == definition.track_version_id { version = candidate; }
        elif candidate.version_number == 1 { return _seed_failure(definition, "Version 1 uses a conflicting deterministic identity."); }
    }
    if version is None {
        version = (track +>:HAS_TRACK_VERSION(version_number=1, created_at=timestamp):+> TrackVersion(
            track_version_id=definition.track_version_id,
            track_id=definition.track_id,
            version_number=1,
            title_snapshot=definition.title,
            description_snapshot=definition.description,
            source_kind=TrackSourceKind.SEEDED,
            created_by="system",
            created_at=timestamp,
            updated_at=timestamp,
            status=TrackVersionStatus.PUBLISHED,
            approved_by="system",
            approved_at=timestamp,
            published_at=timestamp
        ))[0];
        grant(version, level=ReadPerm);
        repaired = not created;
    } elif version.track_id != definition.track_id or version.version_number != 1 or version.source_kind != TrackSourceKind.SEEDED {
        return _seed_failure(definition, "The deterministic version conflicts with the registry.");
    }

    configuration = track_configuration(track);
    if configuration is None {
        configuration = (track +>:HAS_TRACK_CONFIGURATION:+> TrackConfiguration(
            configuration_id=definition.configuration_id,
            track_id=definition.track_id,
            supports_code_challenge=definition.supports_code_challenge,
            created_at=timestamp,
            updated_at=timestamp
        ))[0];
        grant(configuration, level=ReadPerm);
        repaired = not created;
    } elif configuration.configuration_id == f"cfg_{definition.track_id}" {
        configuration.configuration_id = definition.configuration_id;
        configuration.updated_at = timestamp;
        repaired = True;
    } elif configuration.configuration_id != definition.configuration_id or configuration.track_id != definition.track_id {
        return _seed_failure(definition, "The deterministic configuration conflicts with the registry.");
    }
    configuration.supports_code_challenge = definition.supports_code_challenge;

    if version.status != TrackVersionStatus.PUBLISHED {
        if version.status in [TrackVersionStatus.DRAFT, TrackVersionStatus.REVIEW_REQUIRED, TrackVersionStatus.APPROVED] {
            version.status = TrackVersionStatus.PUBLISHED;
            version.published_at = timestamp;
            version.updated_at = timestamp;
            repaired = True;
        } else { return _seed_failure(definition, "Version 1 is in an unsafe lifecycle state."); }
    }
    if track.active_version_id is not None and track.active_version_id != definition.track_version_id {
        return _seed_failure(definition, "The active version conflicts with the deterministic version.");
    }
    if track.status not in [LearningTrackStatus.DRAFT, LearningTrackStatus.PUBLISHED] {
        return _seed_failure(definition, "The track is in an unsafe lifecycle state.");
    }
    if track.active_version_id != definition.track_version_id or track.status != LearningTrackStatus.PUBLISHED or not track.is_enrollment_open or track.current_version_number < 1 {
        repaired = repaired or not created;
        track.active_version_id = definition.track_version_id;
        track.status = LearningTrackStatus.PUBLISHED;
        track.visibility = LearningTrackVisibility.PUBLIC;
        track.current_version_number = 1;
        track.is_enrollment_open = True;
        track.published_at = version.published_at or timestamp;
        track.updated_at = timestamp;
    }
    status = "CREATED" if created else ("REPAIRED" if repaired else "UNCHANGED");
    event_name = "builtin_programming_track.created" if created else ("builtin_programming_track.repaired" if repaired else "builtin_programming_track.reused");
    _emit(event_name, track, version, "system");
    return BuiltinTrackSeedOutcome(definition.canonical_language, definition.track_id, status);
}

def seed_builtin_programming_tracks -> BuiltinTrackSeedReport {
    report_value = BuiltinTrackSeedReport(status="completed");
    if not registry_is_valid() {
        report_value.status = "failed";
        report_value.failed = len(BUILTIN_PROGRAMMING_TRACKS);
        return report_value;
    }
    for definition in BUILTIN_PROGRAMMING_TRACKS {
        outcome = _ensure_builtin(definition);
        report_value.outcomes.append(outcome);
        if outcome.status == "CREATED" { report_value.created += 1; }
        elif outcome.status == "UNCHANGED" { report_value.unchanged += 1; }
        elif outcome.status == "REPAIRED" { report_value.repaired += 1; }
        elif outcome.status == "SKIPPED" { report_value.skipped += 1; }
        else { report_value.failed += 1; }
    }
    if report_value.failed > 0 { report_value.status = "failed"; }
    return report_value;
}

def seed_builtin_tracks -> LearningTrackMigrationReport {
    seeded = seed_builtin_programming_tracks();
    return LearningTrackMigrationReport(
        tracks_created=seeded.created,
        tracks_existing=seeded.unchanged + seeded.repaired,
        versions_created=seeded.created,
        records_failed=seeded.failed
    );
}
