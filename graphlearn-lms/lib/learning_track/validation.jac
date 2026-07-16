"""Central validation and authoritative-parent copying for track context."""

import from lib.learning_track.service { catalogue_tracks, find_track_readonly, track_versions }
import from nodes.learning_track { LearningTrack }
import from nodes.track_context { TrackValidationResult }

def _valid(track_id: str, track_version_id: str, message: str = "Track context is valid.") -> TrackValidationResult {
    return TrackValidationResult(True, track_id, track_version_id, None, message);
}

def _invalid(code: str, message: str, track_id: str | None = None, track_version_id: str | None = None) -> TrackValidationResult {
    return TrackValidationResult(False, track_id, track_version_id, code, message);
}

def validate_track_exists(track_id: str | None) -> TrackValidationResult {
    if track_id is None or track_id.strip() == "" {
        return _invalid("TRACK_CONTEXT_MISSING", "A learning-track identifier is required.");
    }
    track = find_track_readonly(track_id.strip());
    if track is None {
        return _invalid("TRACK_NOT_FOUND", "The learning track does not exist.", track_id.strip());
    }
    return TrackValidationResult(True, (track as LearningTrack).track_id, None, None, "Learning track exists.");
}

def validate_track_version_exists(track_version_id: str | None) -> TrackValidationResult {
    if track_version_id is None or track_version_id.strip() == "" {
        return _invalid("TRACK_CONTEXT_MISSING", "A learning-track version identifier is required.");
    }
    for track in catalogue_tracks() {
        for version in track_versions(track) {
            if version.track_version_id == track_version_id.strip() {
                return TrackValidationResult(True, version.track_id, version.track_version_id, None, "Learning-track version exists.");
            }
        }
    }
    return _invalid("TRACK_VERSION_NOT_FOUND", "The learning-track version does not exist.", None, track_version_id.strip());
}

def validate_version_belongs_to_track(track_id: str | None, track_version_id: str | None) -> TrackValidationResult {
    track_result = validate_track_exists(track_id);
    if not track_result.valid { return track_result; }
    version_result = validate_track_version_exists(track_version_id);
    if not version_result.valid { return version_result; }
    if version_result.track_id != track_result.track_id {
        return _invalid("TRACK_VERSION_MISMATCH", "The learning-track version belongs to another track.", track_result.track_id, version_result.track_version_id);
    }
    return _valid(track_result.track_id as str, version_result.track_version_id as str);
}

def validate_parent_child_track_match(
    parent_track_id: str | None,
    parent_track_version_id: str | None,
    child_track_id: str | None,
    child_track_version_id: str | None
) -> TrackValidationResult {
    parent = validate_version_belongs_to_track(parent_track_id, parent_track_version_id);
    if not parent.valid { return parent; }
    child = validate_version_belongs_to_track(child_track_id, child_track_version_id);
    if not child.valid { return child; }
    if parent.track_id != child.track_id or parent.track_version_id != child.track_version_id {
        return _invalid("PARENT_TRACK_MISMATCH", "The child record does not belong to its parent's learning track and version.", child.track_id, child.track_version_id);
    }
    return _valid(child.track_id as str, child.track_version_id as str, "Parent and child track contexts match.");
}

def validate_curriculum_entity_track(track_id: str | None, track_version_id: str | None) -> TrackValidationResult {
    result = validate_version_belongs_to_track(track_id, track_version_id);
    if not result.valid and result.error_code == "TRACK_CONTEXT_MISSING" {
        result.error_code = "CURRICULUM_ENTITY_TRACK_MISMATCH";
    }
    return result;
}

def validate_learner_record_track(track_id: str | None, track_version_id: str | None) -> TrackValidationResult {
    result = validate_version_belongs_to_track(track_id, track_version_id);
    if not result.valid and result.error_code == "TRACK_CONTEXT_MISSING" {
        result.error_code = "LEARNER_RECORD_TRACK_MISMATCH";
    }
    return result;
}

def resolve_record_track_context(track_id: str | None, track_version_id: str | None) -> TrackValidationResult {
    return validate_version_belongs_to_track(track_id, track_version_id);
}

def copy_track_context_from_parent(parent_track_id: str | None, parent_track_version_id: str | None) -> TrackValidationResult {
    result = validate_version_belongs_to_track(parent_track_id, parent_track_version_id);
    if not result.valid { return result; }
    return _valid(result.track_id as str, result.track_version_id as str, "Track context copied from the authoritative parent.");
}
