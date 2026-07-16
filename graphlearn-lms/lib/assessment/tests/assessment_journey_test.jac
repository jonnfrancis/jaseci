"""Assessment journey integration tests."""

import from services.assessment_journey {
    load_assessment_journey,
    retry_assessment_evaluation,
    start_assessment_journey,
    submit_and_evaluate_assessment,
    supported_language_tracks
}

def _response(question_id: str, question_type: str, selected_option_id: str = "", short_answer: str = "") -> dict[str, str] {
    return {
        "question_id": question_id,
        "question_type": question_type,
        "selected_option_id": selected_option_id,
        "short_answer": short_answer
    };
}

test "python assessment journey completes end to end" {
    learner_id = "journey-python-learner";
    started = start_assessment_journey("Python", learner_id, "Python Learner");
    assessment_id = started.assessment_id;

    result = submit_and_evaluate_assessment(
        learner_id,
        assessment_id,
        [
            _response(f"{assessment_id}-q1", "multiple_choice", f"{assessment_id}-q1-o1"),
            _response(f"{assessment_id}-q2", "multiple_choice", f"{assessment_id}-q2-o2"),
            _response(f"{assessment_id}-q3", "short_answer", "", " bool ")
        ],
        "python-flow-submitted"
    );

    assert result.status == "results";
    assert result.selected_language == "Python";
    assert result.evaluation is not None;
    assert result.evaluation.score.percentage == 100;
    assert result.evaluation.score.earned_points == 3;
    assert len(result.evaluation.skill_signals) == 3;
}

test "jac assessment journey completes end to end" {
    learner_id = "journey-jac-learner";
    started = start_assessment_journey("Jac", learner_id, "Jac Learner");
    assessment_id = started.assessment_id;

    result = submit_and_evaluate_assessment(
        learner_id,
        assessment_id,
        [
            _response(f"{assessment_id}-q1", "multiple_choice", f"{assessment_id}-q1-o1"),
            _response(f"{assessment_id}-q2", "multiple_choice", f"{assessment_id}-q2-o2"),
            _response(f"{assessment_id}-q3", "short_answer", "", "edge")
        ],
        "jac-flow-submitted"
    );

    assert result.status == "results";
    assert result.selected_language == "Jac";
    assert result.evaluation is not None;
    assert result.evaluation.score.percentage == 100;
    assert result.evaluation.score.possible_points == 3;
    assert len(result.evaluation.skill_signals) == 3;
}

test "assessment journey derives response types from persisted questions" {
    learner_id = "journey-server-type-learner";
    started = start_assessment_journey("Python", learner_id, "Server Type Learner");
    assessment_id = started.assessment_id;

    result = submit_and_evaluate_assessment(
        learner_id,
        assessment_id,
        [
            _response(f"{assessment_id}-q1", "stale_client_type", f"{assessment_id}-q1-o1"),
            _response(f"{assessment_id}-q2", "stale_client_type", f"{assessment_id}-q2-o2"),
            _response(f"{assessment_id}-q3", "stale_client_type", "", "bool")
        ],
        "server-derived-types"
    );

    assert result.status == "results";
    assert result.evaluation is not None;
    assert result.evaluation.score.possible_points == 3;
}

test "assessment journey recovers persisted state after start" {
    learner_id = "journey-recovery-learner";
    started = start_assessment_journey("Python", learner_id, "Recovery Learner");
    recovered = load_assessment_journey(learner_id);

    assert recovered.status == "assessment";
    assert recovered.assessment_id == started.assessment_id;
    assert recovered.selected_language == "Python";
    assert recovered.assessment is not None;
}

test "assessment journey rejects invalid submission" {
    learner_id = "journey-invalid-learner";
    started = start_assessment_journey("Jac", learner_id, "Invalid Learner");
    failed = False;

    try {
        submit_and_evaluate_assessment(
            learner_id,
            started.assessment_id,
            [
                _response("not-on-assessment", "multiple_choice", "missing-option")
            ],
            "invalid-submission"
        );
    } except Exception {
        failed = True;
    }

    assert failed;
}

test "assessment journey handles evaluation retry failure state" {
    learner_id = "journey-retry-learner";
    started = start_assessment_journey("Python", learner_id, "Retry Learner");

    result = retry_assessment_evaluation(
        learner_id,
        started.assessment_id,
        "missing-attempt",
        "retry-with-missing-attempt"
    );

    assert result.status == "evaluation_pending";
    assert result.error_message == "Assessment submitted successfully. Evaluation pending.";
}

test "assessment journey exposes only python and jac tracks" {
    tracks = supported_language_tracks();

    assert len(tracks) == 2;
    assert tracks[0].name == "Python";
    assert tracks[1].name == "Jac";
}

test "new account starts assessment with track first context" {
    tracks = supported_language_tracks();
    python = tracks[0];
    started = start_assessment_journey(
        python.id,
        "journey-track-first-learner",
        "Track First Learner",
        python.track_id,
        python.track_version_id
    );

    assert started.status == "assessment";
    assert started.selected_language == "Python";
    assert started.track_id == "trk_builtin_python";
    assert started.track_version_id == "trv_builtin_python_v1";
}
