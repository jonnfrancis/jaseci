"""Trusted graph-to-policy resource context builders and ownership migration."""

import from edges.domain_edges {
    FOR_TRACK, FOR_TRACK_VERSION, HAS_BLUEPRINT, HAS_LEARNING_TRACK,
    HAS_SOURCE_DOCUMENT, HAS_SUBMISSION, HAS_TRACK_ACCESS, OWNS_TRACK
}
import from lib.identity.repositories { LecturerRepository }
import from lib.identity.services { identity_now }
import from lib.learning_track.repositories { repository_catalogue, repository_find_track, repository_find_version, repository_version_belongs_to }
import from nodes.authorization { AuthorizationResourceContext, OwnershipMigrationReport, TrackAccessRole }
import from nodes.curriculum { CourseBlueprint, CourseDocument }
import from nodes.enrollment { Enrollment, Submission }
import from nodes.identity { LecturerProfile }
import from nodes.learning_track { LearningTrack, TrackOwnershipType, TrackVersion }

def _access_role(profile: LecturerProfile, track: LearningTrack) -> TrackAccessRole | None {
    for access in [edge profile ->:HAS_TRACK_ACCESS:-> track] {
        if access.revoked_at is None and (access.expires_at is None or access.expires_at > identity_now()) { return access.access_role; }
    }
    return None;
}

def ownership_context(profile: LecturerProfile | None, track: LearningTrack) -> AuthorizationResourceContext {
    owner_edges = [track <-:OWNS_TRACK:<-[?:LecturerProfile]];
    ownership_edge_exists = profile is not None and track in [(profile as LecturerProfile) ->:OWNS_TRACK:->[?:LearningTrack]];
    conflict = len(owner_edges) > 1;
    if len(owner_edges) == 1 and owner_edges[0].lecturer_id != track.owner_id { conflict = True; }
    if profile is not None and ownership_edge_exists and track.owner_id != (profile as LecturerProfile).lecturer_id { conflict = True; }
    return AuthorizationResourceContext(
        resource_type="LearningTrack", resource_id=track.track_id,
        track_id=track.track_id, owner_lecturer_id=track.owner_id,
        track_status=track.status, track_ownership_type=track.ownership_type,
        institution_id=track.institution_id,
        access_role=_access_role(profile as LecturerProfile, track) if profile is not None else None,
        ownership_edge_exists=ownership_edge_exists, ownership_conflict=conflict
    );
}

def track_resource_context(track_id: str, lecturer_id: str | None = None) -> AuthorizationResourceContext | None {
    track = repository_find_track(track_id);
    if track is None { return None; }
    profile: LecturerProfile | None = None;
    if lecturer_id is not None { profile = LecturerRepository().find_by_lecturer_id(lecturer_id); }
    return ownership_context(profile, track);
}

def version_resource_context(track_id: str, track_version_id: str, lecturer_id: str | None = None) -> AuthorizationResourceContext | None {
    track = repository_find_track(track_id);
    if track is None { return None; }
    version = repository_find_version(track, track_version_id);
    if version is None { return None; }
    context = track_resource_context(track_id, lecturer_id);
    if context is None { return None; }
    context.resource_type = "TrackVersion"; context.resource_id = version.track_version_id;
    context.track_version_id = version.track_version_id; context.version_status = version.status;
    context.version_belongs_to_track = repository_version_belongs_to(track, version);
    return context;
}

def document_resource_context(track: LearningTrack, version: TrackVersion, document: CourseDocument, profile: LecturerProfile | None) -> AuthorizationResourceContext {
    context = ownership_context(profile, track);
    context.resource_type = "CourseDocument"; context.resource_id = document.document_id;
    context.track_version_id = version.track_version_id; context.version_status = version.status;
    context.version_belongs_to_track = repository_version_belongs_to(track, version) and document in [version ->:HAS_SOURCE_DOCUMENT:->[?:CourseDocument]] and document.track_id == track.track_id and document.track_version_id == version.track_version_id;
    return context;
}

def blueprint_resource_context(track: LearningTrack, version: TrackVersion, blueprint: CourseBlueprint, profile: LecturerProfile | None) -> AuthorizationResourceContext {
    context = ownership_context(profile, track);
    context.resource_type = "CourseBlueprint"; context.resource_id = blueprint.blueprint_id;
    context.track_version_id = version.track_version_id; context.version_status = version.status;
    context.version_belongs_to_track = repository_version_belongs_to(track, version) and blueprint in [version ->:HAS_BLUEPRINT:->[?:CourseBlueprint]] and blueprint.track_id == track.track_id and blueprint.track_version_id == version.track_version_id;
    return context;
}

def enrollment_resource_context(track: LearningTrack, enrollment: Enrollment, profile: LecturerProfile | None) -> AuthorizationResourceContext {
    context = ownership_context(profile, track);
    context.resource_type = "Enrollment"; context.resource_id = enrollment.enrollment_id;
    context.track_version_id = enrollment.track_version_id; context.learner_id = enrollment.learner_id;
    context.enrollment_id = enrollment.enrollment_id;
    context.enrollment_belongs_to_track = enrollment.track_id == track.track_id and track in [enrollment ->:FOR_TRACK:->[?:LearningTrack]] and len([enrollment ->:FOR_TRACK_VERSION:->[?:TrackVersion]]) == 1;
    return context;
}

def submission_resource_context(track: LearningTrack, enrollment: Enrollment, submission: Submission, profile: LecturerProfile | None) -> AuthorizationResourceContext {
    context = enrollment_resource_context(track, enrollment, profile);
    context.resource_type = "Submission"; context.resource_id = submission.submission_id;
    context.submission_id = submission.submission_id;
    context.submission_belongs_to_track = submission in [enrollment ->:HAS_SUBMISSION:->[?:Submission]] and submission.enrollment_id == enrollment.enrollment_id and submission.learner_id == enrollment.learner_id and submission.track_id == track.track_id and submission.track_version_id == enrollment.track_version_id;
    context.flagged_for_review = submission.status == "REVIEW_REQUIRED" or '"needs_review": true' in submission.grading_metadata_json.lower();
    return context;
}

def migrate_current_lecturer_ownership -> OwnershipMigrationReport {
    migration_result = OwnershipMigrationReport(); profile = LecturerRepository().find_by_user_id(jid(root));
    if profile is None { migration_result.skipped = 1; return migration_result; }
    current_profile = profile as LecturerProfile;
    catalogue = repository_catalogue();
    if catalogue is None { return migration_result; }
    for track in [catalogue ->:HAS_LEARNING_TRACK:->[?:LearningTrack]] {
        if track.ownership_type != TrackOwnershipType.LECTURER or track.owner_id != current_profile.lecturer_id { continue; }
        migration_result.scanned += 1; owners = [track <-:OWNS_TRACK:<-[?:LecturerProfile]];
        if len(owners) > 1 or (len(owners) == 1 and owners[0].lecturer_id != current_profile.lecturer_id) { migration_result.conflicts += 1; continue; }
        if track in [current_profile ->:OWNS_TRACK:->[?:LearningTrack]] { migration_result.unchanged += 1; continue; }
        current_profile +>:OWNS_TRACK(granted_at=identity_now()):+> track; migration_result.backfilled += 1;
    }
    return migration_result;
}
