"""Frontend recovery state for the assessment-to-roadmap journey."""

glob JOURNEY_LANGUAGE_KEY: str = "graphlearn.journey.language";
glob JOURNEY_ASSESSMENT_KEY: str = "graphlearn.journey.assessment_id";
glob JOURNEY_ATTEMPT_KEY: str = "graphlearn.journey.attempt_id";
glob JOURNEY_EVALUATION_KEY: str = "graphlearn.journey.evaluation_id";
glob JOURNEY_ROADMAP_KEY: str = "graphlearn.journey.roadmap_id";
glob JOURNEY_TRACK_KEY: str = "selectedTrackId";
glob JOURNEY_TRACK_VERSION_KEY: str = "selectedTrackVersionId";

obj JourneyRecoveryState {
    has selected_language: str = "";
    has assessment_id: str = "";
    has attempt_id: str = "";
    has evaluation_id: str = "";
    has roadmap_id: str = "";
    has track_id: str = "";
    has track_version_id: str = "";
}

def _read(key: str) -> str {
    value = localStorage.getItem(key); # jac:ignore[W2001,E1030,W6002]
    return str(value) if value else "";
}

def _write(key: str, value: str) {
    if value != "" {
        localStorage.setItem(key, value); # jac:ignore[W2001,E1030,W6002]
    }
}

def:pub read_journey_state() -> JourneyRecoveryState {
    track_id = _read(JOURNEY_TRACK_KEY);
    track_version_id = _read(JOURNEY_TRACK_VERSION_KEY);
    language = _read(JOURNEY_LANGUAGE_KEY);
    if track_id == "" {
        normalized = language.strip().lower();
        if normalized == "python" {
            track_id = "trk_builtin_python";
            track_version_id = "trv_builtin_python_v1";
        } elif normalized == "jac" or normalized == "jaseci" {
            track_id = "trk_builtin_jaseci";
            track_version_id = "trv_builtin_jaseci_v1";
        }
        _write(JOURNEY_TRACK_KEY, track_id);
        _write(JOURNEY_TRACK_VERSION_KEY, track_version_id);
    }
    return JourneyRecoveryState(
        selected_language=language,
        assessment_id=_read(JOURNEY_ASSESSMENT_KEY),
        attempt_id=_read(JOURNEY_ATTEMPT_KEY),
        evaluation_id=_read(JOURNEY_EVALUATION_KEY),
        roadmap_id=_read(JOURNEY_ROADMAP_KEY),
        track_id=track_id,
        track_version_id=track_version_id
    );
}

def:pub read_journey_language() -> str {
    return _read(JOURNEY_LANGUAGE_KEY);
}

def:pub save_journey_state(
    selected_language: str,
    assessment_id: str,
    attempt_id: str,
    evaluation_id: str,
    roadmap_id: str,
    track_id: str = "",
    track_version_id: str = ""
) {
    _write(JOURNEY_LANGUAGE_KEY, selected_language);
    _write(JOURNEY_ASSESSMENT_KEY, assessment_id);
    _write(JOURNEY_ATTEMPT_KEY, attempt_id);
    _write(JOURNEY_EVALUATION_KEY, evaluation_id);
    _write(JOURNEY_ROADMAP_KEY, roadmap_id);
    _write(JOURNEY_TRACK_KEY, track_id);
    _write(JOURNEY_TRACK_VERSION_KEY, track_version_id);
}

def:pub clear_journey_state() {
    localStorage.removeItem(JOURNEY_LANGUAGE_KEY); # jac:ignore[W2001,E1030,W6002]
    localStorage.removeItem(JOURNEY_ASSESSMENT_KEY); # jac:ignore[W2001,E1030,W6002]
    localStorage.removeItem(JOURNEY_ATTEMPT_KEY); # jac:ignore[W2001,E1030,W6002]
    localStorage.removeItem(JOURNEY_EVALUATION_KEY); # jac:ignore[W2001,E1030,W6002]
    localStorage.removeItem(JOURNEY_ROADMAP_KEY); # jac:ignore[W2001,E1030,W6002]
    localStorage.removeItem(JOURNEY_TRACK_KEY); # jac:ignore[W2001,E1030,W6002]
    localStorage.removeItem(JOURNEY_TRACK_VERSION_KEY); # jac:ignore[W2001,E1030,W6002]
}
