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
    started = start_assessment_journey("Python");
    assessment_id = started.assessment_id;

    result = submit_and_evaluate_assessment(
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
    started = start_assessment_journey("Jac");
    assessment_id = started.assessment_id;

    result = submit_and_evaluate_assessment(
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

test "assessment journey recovers persisted state after start" {
    started = start_assessment_journey("Python");
    recovered = load_assessment_journey();

    assert recovered.status == "assessment";
    assert recovered.assessment_id == started.assessment_id;
    assert recovered.selected_language == "Python";
    assert recovered.assessment is not None;
}

test "assessment journey rejects invalid submission" {
    started = start_assessment_journey("Jac");
    failed = False;

    try {
        submit_and_evaluate_assessment(
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
    started = start_assessment_journey("Python");

    result = retry_assessment_evaluation(
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
