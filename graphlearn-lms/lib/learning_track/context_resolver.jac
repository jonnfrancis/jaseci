"""Authoritative track-context resolution shared by curriculum walkers."""

import from edges.domain_edges { HAS_ENROLLMENT }
import from lib.learning_track.application_services { resolve_track_context_service }
import from lib.learning_track.repositories {
    repository_active_version, repository_find_enrollment, repository_find_track,
    repository_find_version, repository_version_belongs_to
}
import from lib.learning_track.repository_types { ResolvedTrackContext, ServiceError, ServiceResult }
import from nodes.assessment { Assessment, AssessmentAttempt, AssessmentEvaluation }
import from nodes.challenge { ChallengeSubmission, GeneratedChallenge, SubmissionEvaluation }
import from nodes.enrollment { Enrollment, Submission }
import from nodes.learner { Learner }
import from nodes.learning_track { LearningTrack, LearningTrackType, TrackVersion, TrackVersionStatus }
import from nodes.lesson { GeneratedLesson }
import from nodes.roadmap { Roadmap, RoadmapLesson }

obj ResolveTrackContextInput {
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has language: str | None = None;
    has learner_id: str | None = None;
    has enrollment_id: str | None = None;
    has assessment_id: str | None = None;
    has roadmap_id: str | None = None;
    has roadmap_item_id: str | None = None;
    has lesson_id: str | None = None;
    has activity_id: str | None = None;
    has submission_id: str | None = None;
}

obj TrackContext {
    has track_id: str;
    has track_version_id: str;
    has track_type: LearningTrackType;
    has track_title: str;
    has version_number: int;
    has resolution_source: str;
    has is_published: bool;
    has is_enrollment_open: bool;
    has legacy_language: str | None = None;
    has enrollment_id: str | None = None;
}

obj TrackResponseMeta {
    has track_id: str;
    has track_version_id: str;
    has track_title: str;
    has track_type: LearningTrackType;
    has version_number: int;
    has legacy_language: str | None = None;
}

def _error(code: str, message: str) -> ServiceResult {
    return ServiceResult(ok=False, error=ServiceError(code=code, message=message));
}

def _clean(value: str | None) -> str | None {
    if value is None { return None; }
    cleaned = value.strip();
    return cleaned if cleaned != "" else None;
}

def _learner(learner_id: str | None) -> Learner | None {
    if learner_id is None { return None; }
    for learner in [root -->][?:Learner] {
        if learner.id == learner_id { return learner; }
    }
    return None;
}

def _entity_context(input: ResolveTrackContextInput) -> tuple[str | None, str | None, str | None, str | None] {
    for assessment in [root -->][?:Assessment] {
        if input.assessment_id is not None and assessment.id == input.assessment_id {
            return (assessment.track_id, assessment.track_version_id, assessment.learner_id, None);
        }
    }
    for attempt in [root -->][?:AssessmentAttempt] {
        if input.assessment_id is not None and attempt.id == input.assessment_id {
            return (attempt.track_id, attempt.track_version_id, attempt.learner_id, attempt.enrollment_id);
        }
    }
    for evaluation in [root -->][?:AssessmentEvaluation] {
        if input.assessment_id is not None and evaluation.id == input.assessment_id {
            return (evaluation.track_id, evaluation.track_version_id, evaluation.learner_id, None);
        }
    }
    for roadmap in [root -->][?:Roadmap] {
        if input.roadmap_id is not None and roadmap.id == input.roadmap_id {
            return (roadmap.track_id, roadmap.track_version_id, roadmap.learner_id, roadmap.enrollment_id);
        }
    }
    for lesson in [root -->][?:GeneratedLesson] {
        if input.lesson_id is not None and lesson.id == input.lesson_id {
            return (lesson.track_id, lesson.track_version_id, lesson.learner_id, None);
        }
    }
    for challenge in [root -->][?:GeneratedChallenge] {
        if input.activity_id is not None and challenge.id == input.activity_id {
            return (challenge.track_id, challenge.track_version_id, challenge.learner_id, None);
        }
    }
    for submission in [root -->][?:ChallengeSubmission] {
        if input.submission_id is not None and submission.id == input.submission_id {
            return (submission.track_id, submission.track_version_id, submission.learner_id, None);
        }
    }
    for evaluation in [root -->][?:SubmissionEvaluation] {
        if input.submission_id is not None and evaluation.id == input.submission_id {
            return (evaluation.track_id, evaluation.track_version_id, evaluation.learner_id, None);
        }
    }
    return (None, None, None, None);
}

def _materialize(track_id: str, version_id: str, source: str, enrollment_id: str | None = None) -> ServiceResult {
    track = repository_find_track(track_id);
    if track is None { return _error("TRACK_NOT_FOUND", "Learning track was not found."); }
    version = repository_find_version(track, version_id);
    if version is None { return _error("TRACK_VERSION_NOT_FOUND", "Track version was not found."); }
    if not repository_version_belongs_to(track, version) {
        return _error("TRACK_VERSION_MISMATCH", "Track version does not belong to the track.");
    }
    legacy: str | None = None;
    if track.track_id == "trk_builtin_python" { legacy = "python"; }
    elif track.track_id == "trk_builtin_jaseci" { legacy = "jaseci"; }
    return ServiceResult(ok=True, value=TrackContext(
        track_id=track.track_id,
        track_version_id=version.track_version_id,
        track_type=track.track_type,
        track_title=track.title,
        version_number=version.version_number,
        legacy_language=legacy,
        resolution_source=source,
        is_published=version.status == TrackVersionStatus.PUBLISHED,
        is_enrollment_open=track.is_enrollment_open,
        enrollment_id=enrollment_id
    ));
}

def _conflicts(input: ResolveTrackContextInput, track_id: str, version_id: str) -> bool {
    requested_track = _clean(input.track_id);
    requested_version = _clean(input.track_version_id);
    if requested_track is not None and requested_track != track_id { return True; }
    if requested_version is not None and requested_version != version_id { return True; }
    if _clean(input.language) is not None {
        legacy = resolve_track_context_service(track_id, version_id, input.language);
        if not legacy.ok { return True; }
    }
    return False;
}

def resolve_track_context(input: ResolveTrackContextInput, _operation: str = "") -> ServiceResult {
    entity = _entity_context(input);
    if entity[0] is not None and entity[1] is not None {
        if input.learner_id is not None and entity[2] is not None and input.learner_id != entity[2] {
            return _error("LEARNER_CONTEXT_MISMATCH", "Referenced entity does not belong to the learner.");
        }
        if _conflicts(input, entity[0] as str, entity[1] as str) {
            return _error("TRACK_CONTEXT_CONFLICT", "Supplied context conflicts with the referenced entity.");
        }
        return _materialize(entity[0] as str, entity[1] as str, "PARENT_ENTITY", entity[3]);
    }

    learner = _learner(input.learner_id);
    if input.enrollment_id is not None {
        if learner is None { return _error("LEARNER_NOT_FOUND", "Learner was not found."); }
        enrollment = repository_find_enrollment(learner, input.enrollment_id);
        if enrollment is None { return _error("ENROLLMENT_NOT_FOUND", "Enrollment was not found for the learner."); }
        if _conflicts(input, enrollment.track_id, enrollment.track_version_id) {
            return _error("TRACK_CONTEXT_CONFLICT", "Supplied context conflicts with the enrollment.");
        }
        return _materialize(enrollment.track_id, enrollment.track_version_id, "ENROLLMENT", enrollment.enrollment_id);
    }

    explicit = resolve_track_context_service(input.track_id, input.track_version_id, input.language);
    if not explicit.ok or explicit.value is None { return explicit; }
    resolved = explicit.value as ResolvedTrackContext;
    track_id = resolved.track_id;
    version_id = resolved.track_version_id;
    source = "LEGACY_LANGUAGE" if _clean(input.track_id) is None else ("EXPLICIT_TRACK_AND_VERSION" if _clean(input.track_version_id) is not None else "EXPLICIT_TRACK_ACTIVE_VERSION");
    return _materialize(track_id, version_id, source);
}

def track_response_meta(context: TrackContext) -> TrackResponseMeta {
    return TrackResponseMeta(
        track_id=context.track_id,
        track_version_id=context.track_version_id,
        track_title=context.track_title,
        track_type=context.track_type,
        version_number=context.version_number,
        legacy_language=context.legacy_language
    );
}
