"""Challenge domain node."""

import from nodes.lesson { Difficulty }

enum ChallengeSubmissionStatus: str {
    draft = "draft",
    submitted = "submitted"
}

node Challenge {
    has id: str;
    has title: str;
    has description: str;
    has skillId: str;
    has difficulty: Difficulty;
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
}
