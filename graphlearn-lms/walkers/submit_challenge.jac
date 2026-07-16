"""Persist learner coding challenge submissions without grading."""

import from datetime { datetime }
import from edges.domain_edges { attempted, submitted_for }
import from lib.observability.instrumentation { observe_walker_finish, observe_walker_start }
import from nodes.challenge {
    ChallengeSubmission,
    ChallengeSubmissionStatus,
    GeneratedChallenge
}
import from nodes.learner { Learner }

obj ChallengeSubmissionError {
    has code: str;
    has message: str;
}

obj ChallengeSubmissionView {
    has id: str;
    has challenge_id: str;
    has learner_id: str;
    has code: str;
    has language: str;
    has status: str;
    has submitted_at: str;
}

def _current_timestamp -> str {
    return datetime.utcnow().isoformat() + "Z";
}

def _find_learner(learner_id: str) -> Learner | None {
    for learner in [root -->][?:Learner, id == learner_id] {
        return learner;
    }
    return None;
}

def _find_challenge(challenge_id: str) -> GeneratedChallenge | None {
    for challenge in [root -->][?:GeneratedChallenge, id == challenge_id] {
        return challenge;
    }
    return None;
}

def challenge_submission_to_view(submission: ChallengeSubmission) -> ChallengeSubmissionView {
    return ChallengeSubmissionView(
        id=submission.id,
        challenge_id=submission.challenge_id,
        learner_id=submission.learner_id,
        code=submission.code,
        language=submission.language,
        status=submission.status.value,
        submitted_at=submission.submitted_at
    );
}

walker submit_challenge {
    has learner_id: str;
    has roadmap_id: str;
    has roadmap_lesson_id: str;
    has challenge_id: str;
    has code: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has enrollment_id: str | None = None;
    has language: str | None = None;
    has idempotency_key: str | None = None;
    has errors: list[ChallengeSubmissionError] = [];
    has reports: list[ChallengeSubmissionView] = [];
    has request_id: str = "";
    has correlation_id: str = "";

    can observability_start with Root entry { observe_walker_start(self); }
    can observability_finish with Root exit { observe_walker_finish(self); }

    can submit with Root entry {
        if self.learner_id.strip() == "" {
            self.errors = self.errors + [ChallengeSubmissionError(code="missing_learner", message="Log in again to submit this challenge.")];
            return;
        }
        if self.challenge_id.strip() == "" {
            self.errors = self.errors + [ChallengeSubmissionError(code="missing_challenge", message="No challenge id was provided.")];
            return;
        }
        if self.code.strip() == "" {
            self.errors = self.errors + [ChallengeSubmissionError(code="empty_code", message="Add code before submitting your solution.")];
            return;
        }

        learner = _find_learner(self.learner_id);
        if learner is None {
            self.errors = self.errors + [ChallengeSubmissionError(code="missing_learner", message="Learner does not exist.")];
            return;
        }

        challenge = _find_challenge(self.challenge_id);
        if challenge is None {
            self.errors = self.errors + [ChallengeSubmissionError(code="missing_challenge", message="Challenge does not exist.")];
            return;
        }
        if challenge.learner_id != self.learner_id {
            self.errors = self.errors + [ChallengeSubmissionError(code="learner_mismatch", message="Challenge does not belong to this learner.")];
            return;
        }
        if challenge.roadmap_id != self.roadmap_id or challenge.roadmap_lesson_id != self.roadmap_lesson_id {
            self.errors = self.errors + [ChallengeSubmissionError(code="challenge_context_mismatch", message="Challenge does not belong to this roadmap lesson.")];
            return;
        }
        if challenge.language not in ["python", "jac"] {
            self.errors = self.errors + [ChallengeSubmissionError(code="unsupported_language", message="Challenge language is not supported.")];
            return;
        }

        timestamp = _current_timestamp();
        submission_count = len([challenge ->:submitted_for:->][?:ChallengeSubmission]);
        submission_id = f"submission-{self.learner_id}-{challenge.id}-{submission_count + 1}";
        submission = (root ++> ChallengeSubmission(
            id=submission_id,
            learner_id=self.learner_id,
            challenge_id=challenge.id,
            language=challenge.language,
            code=self.code,
            status=ChallengeSubmissionStatus.submitted,
            submitted_at=timestamp,
            created_at=timestamp,
            updated_at=timestamp
            , track_id=challenge.track_id
            , track_version_id=challenge.track_version_id
        ))[0];
        learner +>:attempted:+> submission;
        challenge +>:submitted_for:+> submission;
        submission +>:submitted_for:+> challenge;
        report challenge_submission_to_view(submission);
    }
}
