"""Challenge domain node."""

import from nodes.lesson { Difficulty }

enum ChallengeSubmissionStatus: str {
    draft = "draft",
    submitted = "submitted"
}

enum FeedbackType: str {
    strength = "strength",
    improvement = "improvement",
    suggestion = "suggestion"
}

node Challenge {
    has id: str;
    has title: str;
    has description: str;
    has skillId: str;
    has difficulty: Difficulty;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}

node GeneratedChallenge {
    has id: str;
    has learner_id: str;
    has roadmap_id: str;
    has roadmap_lesson_id: str;
    has generated_lesson_id: str;
    has language: str;
    has title: str;
    has prompt: str;
    has difficulty: str;
    has starter_code: str;
    has created_at: str;
    has updated_at: str;
    has instructions: list[ChallengeInstruction] = [];
    has expected_outcomes: list[ChallengeExpectedOutcome] = [];
    has constraints: list[ChallengeConstraint] = [];
    has hints: list[ChallengeHint] = [];
    has evaluation_criteria: list[ChallengeEvaluationCriterion] = [];
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}

node ChallengeInstruction {
    has id: str;
    has challenge_id: str;
    has content: str;
    has order_index: int;
}

node ChallengeExpectedOutcome {
    has id: str;
    has challenge_id: str;
    has content: str;
    has order_index: int;
}

node ChallengeConstraint {
    has id: str;
    has challenge_id: str;
    has content: str;
    has order_index: int;
}

node ChallengeHint {
    has id: str;
    has challenge_id: str;
    has content: str;
    has order_index: int;
}

node ChallengeEvaluationCriterion {
    has id: str;
    has challenge_id: str;
    has skill_id: str;
    has description: str;
    has weight: float;
    has order_index: int;
}

node ChallengeSubmission {
    has id: str;
    has learner_id: str;
    has challenge_id: str;
    has language: str;
    has code: str;
    has status: ChallengeSubmissionStatus;
    has submitted_at: str;
    has created_at: str;
    has updated_at: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}

node SubmissionEvaluation {
    has id: str;
    has learner_id: str;
    has challenge_id: str;
    has submission_id: str;
    has language: str;
    has score: int;
    has passed: bool;
    has feedback_summary: str;
    has suggested_next_step: str;
    has evaluation_version: str;
    has evaluated_at: str;
    has created_at: str;
    has criterion_results: list[CriterionResult] = [];
    has skill_signals: list[SubmissionSkillSignal] = [];
    has feedback_items: list[FeedbackItem] = [];
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}

node CriterionResult {
    has id: str;
    has evaluation_id: str;
    has criterion_id: str;
    has skill_id: str;
    has score: float;
    has feedback: str;
    has met: bool;
    has order_index: int;
}

node SubmissionSkillSignal {
    has id: str;
    has evaluation_id: str;
    has skill_id: str;
    has score: float;
    has confidence: float;
    has evidence: str;
    has order_index: int;
}

node FeedbackItem {
    has id: str;
    has evaluation_id: str;
    has feedback_type: FeedbackType;
    has content: str;
    has order_index: int;
}
