"""Challenge workspace service for generated challenges, evaluation, and progression."""

import from edges.domain_edges { contains, evaluated, submitted_for }
import from nodes.challenge {
    ChallengeSubmission,
    ChallengeSubmissionStatus,
    GeneratedChallenge,
    SubmissionEvaluation
}
import from nodes.lesson { GeneratedLesson }
import from nodes.roadmap { Roadmap, RoadmapLesson, RoadmapWeek }
import from walkers.evaluate_submission {
    SubmissionEvaluationError,
    SubmissionEvaluationView,
    evaluate_submission,
    submission_evaluation_to_view
}
import from walkers.generate_challenge {
    ChallengeGenerationError,
    GeneratedChallengeView,
    generate_challenge,
    generated_challenge_to_view,
    get_generated_challenge
}
import from walkers.unlock_next_lesson {
    ProgressionError,
    ProgressionResult,
    unlock_next_lesson
}
import from walkers.update_mastery {
    MasteryUpdateError,
    MasteryUpdateSummary,
    update_mastery
}
import from walkers.submit_challenge {
    ChallengeSubmissionError,
    ChallengeSubmissionView,
    challenge_submission_to_view,
    submit_challenge
}

obj ChallengeSubmissionDraft {
    has challenge_id: str;
    has learner_id: str;
    has code: str;
    has language: str;
    has status: str;
    has updated_at: str = "";
}

obj ChallengeWorkspaceState {
    has status: str;
    has challenge: GeneratedChallengeView | None = None;
    has draft: ChallengeSubmissionDraft | None = None;
    has latest_submission: ChallengeSubmissionView | None = None;
    has latest_evaluation: SubmissionEvaluationView | None = None;
    has lesson_title: str = "";
    has message: str = "";
}

obj ChallengeStartState {
    has status: str;
    has challenge: GeneratedChallengeView | None = None;
    has message: str = "";
    has generated_now: bool = False;
}

obj ChallengeSubmitState {
    has status: str;
    has submission: ChallengeSubmissionView | None = None;
    has evaluation: SubmissionEvaluationView | None = None;
    has mastery_update: MasteryUpdateSummary | None = None;
    has progression: ProgressionResult | None = None;
    has message: str = "";
}

def _find_roadmap(roadmap_id: str) -> Roadmap | None {
    for roadmap in [root -->][?:Roadmap, id == roadmap_id] {
        return roadmap;
    }
    return None;
}

def _find_roadmap_lesson(roadmap: Roadmap, roadmap_lesson_id: str) -> RoadmapLesson | None {
    for lesson in roadmap.lessons {
        if lesson.id == roadmap_lesson_id {
            return lesson;
        }
    }
    for week in [roadmap ->:contains:->][?:RoadmapWeek] {
        for lesson in [week ->:contains:->][?:RoadmapLesson] {
            if lesson.id == roadmap_lesson_id {
                return lesson;
            }
        }
    }
    return None;
}

def _find_generated_lesson(generated_lesson_id: str) -> GeneratedLesson | None {
    for lesson in [root -->][?:GeneratedLesson, id == generated_lesson_id] {
        return lesson;
    }
    return None;
}

def _find_challenge(challenge_id: str) -> GeneratedChallenge | None {
    for challenge in [root -->][?:GeneratedChallenge, id == challenge_id] {
        return challenge;
    }
    return None;
}

def _latest_draft(challenge: GeneratedChallenge, learner_id: str) -> ChallengeSubmissionDraft | None {
    latest: ChallengeSubmission | None = None;
    for submission in [challenge ->:submitted_for:->][?:ChallengeSubmission] {
        if submission.learner_id == learner_id and submission.status == ChallengeSubmissionStatus.draft {
            latest = submission;
        }
    }
    if latest is None {
        return None;
    }
    draft = latest as ChallengeSubmission;
    return ChallengeSubmissionDraft(
        challenge_id=draft.challenge_id,
        learner_id=draft.learner_id,
        code=draft.code,
        language=draft.language,
        status=draft.status.value,
        updated_at=draft.updated_at
    );
}

def _latest_submission(challenge: GeneratedChallenge, learner_id: str) -> ChallengeSubmissionView | None {
    latest: ChallengeSubmission | None = None;
    for submission in [challenge ->:submitted_for:->][?:ChallengeSubmission] {
        if submission.learner_id == learner_id and submission.status == ChallengeSubmissionStatus.submitted {
            latest = submission;
        }
    }
    if latest is None {
        return None;
    }
    return challenge_submission_to_view(latest as ChallengeSubmission);
}

def _latest_submission_node(challenge: GeneratedChallenge, learner_id: str) -> ChallengeSubmission | None {
    latest: ChallengeSubmission | None = None;
    for submission in [challenge ->:submitted_for:->][?:ChallengeSubmission] {
        if submission.learner_id == learner_id and submission.status == ChallengeSubmissionStatus.submitted {
            latest = submission;
        }
    }
    return latest;
}

def _latest_evaluation(challenge: GeneratedChallenge, learner_id: str) -> SubmissionEvaluationView | None {
    latest_submission = _latest_submission_node(challenge, learner_id);
    if latest_submission is not None {
        for evaluation in [(latest_submission as ChallengeSubmission) ->:evaluated:->][?:SubmissionEvaluation] {
            if evaluation.learner_id == learner_id and evaluation.challenge_id == challenge.id {
                return submission_evaluation_to_view(evaluation);
            }
        }
    }
    for evaluation in [challenge ->:evaluated:->][?:SubmissionEvaluation] {
        if evaluation.learner_id == learner_id and evaluation.challenge_id == challenge.id {
            return submission_evaluation_to_view(evaluation);
        }
    }
    return None;
}

def _challenge_error_message(errors: list[ChallengeGenerationError]) -> str {
    if len(errors) == 0 {
        return "Challenge generation failed.";
    }
    return errors[0].message;
}

def _submission_error_message(errors: list[ChallengeSubmissionError]) -> str {
    if len(errors) == 0 {
        return "Challenge submission failed.";
    }
    return errors[0].message;
}

def _evaluation_error_message(errors: list[SubmissionEvaluationError]) -> str {
    if len(errors) == 0 {
        return "Submission evaluation failed.";
    }
    return errors[0].message;
}

def _mastery_error_message(errors: list[MasteryUpdateError]) -> str {
    if len(errors) == 0 {
        return "Mastery update failed.";
    }
    return errors[0].message;
}

def _progression_error_message(errors: list[ProgressionError]) -> str {
    if len(errors) == 0 {
        return "Lesson progression could not be updated.";
    }
    return errors[0].message;
}

def:priv open_challenge(
    learner_id: str,
    roadmap_id: str,
    roadmap_lesson_id: str,
    challenge_id: str
) -> ChallengeWorkspaceState {
    if learner_id.strip() == "" {
        return ChallengeWorkspaceState(status="missing_learner", message="Log in again to open this challenge.");
    }
    if roadmap_id.strip() == "" or roadmap_lesson_id.strip() == "" or challenge_id.strip() == "" {
        return ChallengeWorkspaceState(status="missing_route_param", message="Challenge route is incomplete.");
    }
    roadmap = _find_roadmap(roadmap_id);
    if roadmap is None {
        return ChallengeWorkspaceState(status="missing_roadmap", message="Roadmap could not be found.");
    }
    if roadmap.learner_id != learner_id {
        return ChallengeWorkspaceState(status="learner_mismatch", message="This roadmap does not belong to the current learner.");
    }
    roadmap_lesson = _find_roadmap_lesson(roadmap, roadmap_lesson_id);
    if roadmap_lesson is None {
        return ChallengeWorkspaceState(status="missing_roadmap_lesson", message="Roadmap lesson could not be found.");
    }
    challenge = _find_challenge(challenge_id);
    if challenge is None {
        return ChallengeWorkspaceState(status="missing_challenge", message="Challenge could not be found.");
    }
    if challenge.learner_id != learner_id or challenge.roadmap_id != roadmap_id or challenge.roadmap_lesson_id != roadmap_lesson_id {
        return ChallengeWorkspaceState(status="challenge_mismatch", message="Challenge does not belong to this roadmap lesson.");
    }
    if challenge.language not in ["python", "jac"] {
        return ChallengeWorkspaceState(status="unsupported_language", message="Challenge language is not supported.");
    }

    return ChallengeWorkspaceState(
        status="ready",
        challenge=generated_challenge_to_view(challenge),
        draft=_latest_draft(challenge, learner_id),
        latest_submission=_latest_submission(challenge, learner_id),
        latest_evaluation=_latest_evaluation(challenge, learner_id),
        lesson_title=roadmap_lesson.title
    );
}

def:priv start_challenge(
    learner_id: str,
    roadmap_id: str,
    roadmap_lesson_id: str,
    generated_lesson_id: str
) -> ChallengeStartState {
    if learner_id.strip() == "" {
        return ChallengeStartState(status="missing_learner", message="Log in again to start this challenge.");
    }
    generated_lesson = _find_generated_lesson(generated_lesson_id);
    if generated_lesson is None {
        return ChallengeStartState(status="missing_generated_lesson", message="Generated lesson could not be found.");
    }
    if generated_lesson.learner_id != learner_id or generated_lesson.roadmap_id != roadmap_id or generated_lesson.roadmap_lesson_id != roadmap_lesson_id {
        return ChallengeStartState(status="generated_lesson_mismatch", message="Generated lesson does not belong to this roadmap lesson.");
    }

    existing = get_generated_challenge(learner_id, generated_lesson_id);
    if existing is not None {
        return ChallengeStartState(status="ready", challenge=generated_challenge_to_view(existing));
    }

    result = root spawn generate_challenge(
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        roadmap_lesson_id=roadmap_lesson_id,
        generated_lesson_id=generated_lesson_id,
        language=generated_lesson.language
    );
    if len(result.errors) > 0 or len(result.reports) == 0 {
        return ChallengeStartState(status="generation_failed", message=_challenge_error_message(result.errors));
    }
    return ChallengeStartState(status="ready", challenge=result.reports[0], generated_now=True);
}

def:priv submit_challenge_solution(
    learner_id: str,
    roadmap_id: str,
    roadmap_lesson_id: str,
    challenge_id: str,
    code: str
) -> ChallengeSubmitState {
    result = root spawn submit_challenge(
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        roadmap_lesson_id=roadmap_lesson_id,
        challenge_id=challenge_id,
        code=code
    );
    if len(result.errors) > 0 or len(result.reports) == 0 {
        return ChallengeSubmitState(status="failed", message=_submission_error_message(result.errors));
    }
    submission = result.reports[0];

    evaluation_result = root spawn evaluate_submission(
        learner_id=learner_id,
        challenge_id=challenge_id,
        submission_id=submission.id
    );
    if len(evaluation_result.errors) > 0 or len(evaluation_result.reports) == 0 {
        return ChallengeSubmitState(
            status="evaluation_failed",
            submission=submission,
            message="Submission saved, but evaluation could not finish: " + _evaluation_error_message(evaluation_result.errors)
        );
    }
    evaluation = evaluation_result.reports[0];

    mastery_result = root spawn update_mastery(
        learner_id=learner_id,
        source_type="submission_evaluation",
        source_id=evaluation.id
    );
    if len(mastery_result.errors) > 0 or len(mastery_result.reports) == 0 {
        return ChallengeSubmitState(
            status="mastery_failed",
            submission=submission,
            evaluation=evaluation,
            message="Evaluation complete, but mastery could not update: " + _mastery_error_message(mastery_result.errors)
        );
    }
    mastery_update = mastery_result.reports[0];

    if not evaluation.passed {
        return ChallengeSubmitState(
            status="evaluated",
            submission=submission,
            evaluation=evaluation,
            mastery_update=mastery_update,
            message="Evaluation complete. Review the feedback, revise your solution, and submit again."
        );
    }

    progression_result = root spawn unlock_next_lesson(
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        completed_roadmap_lesson_id=roadmap_lesson_id,
        source_type="submission_evaluation",
        source_id=evaluation.id
    );
    if len(progression_result.errors) > 0 or len(progression_result.reports) == 0 {
        return ChallengeSubmitState(
            status="progression_failed",
            submission=submission,
            evaluation=evaluation,
            mastery_update=mastery_update,
            message="Evaluation passed, but lesson progression could not update: " + _progression_error_message(progression_result.errors)
        );
    }
    progression = progression_result.reports[0];
    return ChallengeSubmitState(
        status="completed",
        submission=submission,
        evaluation=evaluation,
        mastery_update=mastery_update,
        progression=progression,
        message=progression.message
    );
}
