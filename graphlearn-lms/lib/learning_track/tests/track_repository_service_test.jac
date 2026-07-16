"""Feature 33 repository, service, idempotency, and isolation tests."""

import from uuid { uuid4 }
import from edges.domain_edges { CONTAINS_SKILL, HAS_TRACK_VERSION, PREREQUISITE }
import from lib.learning_track.application_services {
    create_track_service, resolve_track_context_service, validate_version_mutable
}
import from lib.learning_track.repositories {
    repository_find_version, repository_prerequisite_cycle, repository_skills,
    repository_version_belongs_to
}
import from lib.learning_track.repository_types { ActorContext, IdempotencyContext, ResolvedTrackContext }
import from lib.learning_track.service { create_track, seed_builtin_tracks }
import from nodes.learning_track {
    CreateLearningTrackInput, LearningTrack, LearningTrackType, TrackOwnershipType, TrackSourceKind,
    TrackVersion, TrackVersionStatus
}
import from nodes.skill { Skill }

def unique_value(prefix: str) -> str {
    return f"{prefix}-{str(uuid4())}";
}

def lecturer_input(title: str) -> CreateLearningTrackInput {
    return CreateLearningTrackInput(
        title=title,
        track_type=LearningTrackType.LECTURER_COURSE,
        ownership_type=TrackOwnershipType.LECTURER
    );
}

test "repository proves version ownership through edge" {
    first = create_track(lecturer_input(unique_value("Repository Track A")), "repo-owner-a");
    second = create_track(lecturer_input(unique_value("Repository Track B")), "repo-owner-b");
    assert first.ok and first.track is not None and second.ok and second.track is not None;
    detached = TrackVersion(
        track_version_id=unique_value("detached-version"),
        track_id=first.track.track_id,
        version_number=1,
        title_snapshot="Detached",
        source_kind=TrackSourceKind.MANUAL,
        created_by="repo-owner-a",
        created_at="now",
        updated_at="now"
    );
    second.track +>:HAS_TRACK_VERSION(version_number=1, created_at="now"):+> detached;
    assert repository_find_version(first.track, detached.track_version_id) is None;
    assert not repository_version_belongs_to(first.track, detached);
    assert not repository_version_belongs_to(second.track, detached);
}

test "curriculum repository isolates track versions and detects cycles" {
    created = create_track(lecturer_input(unique_value("Curriculum Isolation")), "curriculum-owner");
    assert created.ok and created.track is not None;
    track = created.track;
    v1 = (track +>:HAS_TRACK_VERSION(version_number=1, created_at="now"):+> TrackVersion(
        track_version_id=unique_value("v1"), track_id=track.track_id, version_number=1,
        title_snapshot=track.title, source_kind=TrackSourceKind.MANUAL,
        created_by="curriculum-owner", created_at="now", updated_at="now"
    ))[0];
    v2 = (track +>:HAS_TRACK_VERSION(version_number=2, created_at="now"):+> TrackVersion(
        track_version_id=unique_value("v2"), track_id=track.track_id, version_number=2,
        title_snapshot=track.title, source_kind=TrackSourceKind.MANUAL,
        created_by="curriculum-owner", created_at="now", updated_at="now"
    ))[0];
    a = Skill(unique_value("legacy-a"), "A", "", "core", track.track_id, v1.track_version_id, "a", "A", order_hint=1);
    b = Skill(unique_value("legacy-b"), "B", "", "core", track.track_id, v1.track_version_id, "b", "B", order_hint=2);
    foreign = Skill(unique_value("legacy-c"), "C", "", "core", track.track_id, v2.track_version_id, "c", "C", order_hint=1);
    v1 +>:CONTAINS_SKILL(order_index=1):+> a;
    v1 +>:CONTAINS_SKILL(order_index=2):+> b;
    v2 +>:CONTAINS_SKILL(order_index=1):+> foreign;
    a +>:PREREQUISITE:+> b;
    b +>:PREREQUISITE:+> a;
    assert len(repository_skills(track, v1.track_version_id)) == 2;
    assert foreign not in repository_skills(track, v1.track_version_id);
    assert repository_prerequisite_cycle(track, v1.track_version_id) == ["a", "b"];
}

test "track context service owns legacy language compatibility" {
    _ = seed_builtin_tracks();
    result = resolve_track_context_service(None, None, " Python ");
    assert result.ok and result.value is not None;
    context = result.value as ResolvedTrackContext;
    assert context.track_id == "trk_builtin_python";
    assert context.track_version_id == "trv_builtin_python_v1";
    mismatch = resolve_track_context_service("trk_builtin_python", "trv_builtin_jaseci_v1", None);
    assert not mismatch.ok and mismatch.error is not None and mismatch.error.code == "TRACK_VERSION_MISMATCH";
}

test "track creation service is idempotent and ignores claimed owner" {
    actor_id = unique_value("lecturer");
    request_id = unique_value("request");
    actor = ActorContext(user_id=actor_id, request_id=request_id, lecturer_id=actor_id, roles=["lecturer"]);
    key = f"create-track:{actor_id}:{request_id}";
    idem = IdempotencyContext(key=key, operation="create-track", actor_id=actor_id, request_id=request_id);
    input = lecturer_input(unique_value("Idempotent Course"));
    input.owner_id = "attacker-claimed-owner";
    first = create_track_service(actor, input, idem);
    second = create_track_service(actor, input, idem);
    assert first.ok and first.value is not None and second.ok and second.value is not None;
    assert second.replayed;
    first_track = first.value as LearningTrack;
    second_track = second.value as LearningTrack;
    assert first_track.track_id == second_track.track_id;
    assert first_track.owner_id == actor_id;
    assert repository_find_version(first_track, f"trv_{first_track.track_id}_v1") is not None;
}

test "published versions are immutable through domain service" {
    version = TrackVersion(
        track_version_id=unique_value("published"), track_id=unique_value("track"), version_number=1,
        title_snapshot="Published", source_kind=TrackSourceKind.MANUAL,
        created_by="owner", created_at="now", updated_at="now", status=TrackVersionStatus.PUBLISHED
    );
    result = validate_version_mutable(version);
    assert not result.ok and result.error is not None and result.error.code == "TRACK_VERSION_IMMUTABLE";
}
