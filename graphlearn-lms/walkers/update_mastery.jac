"""Update learner skill mastery from persisted evaluation evidence."""

import from datetime { datetime }
import from edges.domain_edges { evidenced_by, mastered, signals, targets }
import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentEvaluation,
    AssessmentEvaluationLink,
    SkillSignal
}
import from nodes.challenge { SubmissionEvaluation, SubmissionSkillSignal }
import from nodes.learner { Learner }
import from nodes.mastery {
    MasteryEvidence,
    MasteryLevel,
    MasterySourceType,
    MasteryUpdateResult,
    SkillMastery,
    UpdatedSkillMasteryRecord
}
import from nodes.skill { Skill }

glob ASSESSMENT_EVIDENCE_WEIGHT = 0.35;
glob SUBMISSION_EVIDENCE_WEIGHT = 0.65;
glob DEFAULT_EVIDENCE_CONFIDENCE = 0.75;

obj MasteryUpdateError {
    has code: str;
    has message: str;
}

obj SkillMasteryView {
    has id: str;
    has learner_id: str;
    has skill_id: str;
    has score: int;
    has level: str;
    has evidence_count: int;
    has last_source_type: str;
    has last_source_id: str;
    has updated_at: str;
    has created_at: str;
}

obj MasteryEvidenceView {
    has id: str;
    has learner_id: str;
    has skill_id: str;
    has source_type: str;
    has source_id: str;
    has signal_score: float;
    has confidence: float;
    has weighted_score: float;
    has evidence_summary: str;
    has created_at: str;
}

obj UpdatedSkillMastery {
    has skill_id: str;
    has previous_score: int;
    has new_score: int;
    has delta: int;
    has mastery_level: str;
    has evidence_count: int;
}

obj MasteryUpdateSummary {
    has learner_id: str;
    has source_type: str;
    has source_id: str;
    has updated_at: str;
    has updated_skills: list[UpdatedSkillMastery] = [];
}

obj MasterySignalInput {
    has skill_id: str;
    has signal_score: float;
    has confidence: float;
    has evidence_summary: str;
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

def _find_skill(skill_id: str) -> Skill | None {
    for skill in [root -->][?:Skill, id == skill_id] {
        return skill;
    }
    return None;
}

def _find_assessment_evaluation(evaluation_id: str) -> AssessmentEvaluation | None {
    for evaluation in [root -->][?:AssessmentEvaluation, id == evaluation_id] {
        return evaluation;
    }
    for assessment in [root -->][?:Assessment] {
        for attempt in [assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt] {
            for evaluation in [attempt ->:AssessmentEvaluationLink:->][?:AssessmentEvaluation] {
                if evaluation.id == evaluation_id {
                    return evaluation;
                }
            }
        }
    }
    return None;
}

def _find_submission_evaluation(evaluation_id: str) -> SubmissionEvaluation | None {
    for evaluation in [root -->][?:SubmissionEvaluation, id == evaluation_id] {
        return evaluation;
    }
    return None;
}

def _source_type_from_str(source_type: str) -> MasterySourceType | None {
    if source_type == "assessment_evaluation" {
        return MasterySourceType.assessment_evaluation;
    }
    if source_type == "submission_evaluation" {
        return MasterySourceType.submission_evaluation;
    }
    return None;
}

def _source_weight(source_type: MasterySourceType) -> float {
    if source_type == MasterySourceType.assessment_evaluation {
        return ASSESSMENT_EVIDENCE_WEIGHT;
    }
    return SUBMISSION_EVIDENCE_WEIGHT;
}

def _mastery_level(score: int) -> MasteryLevel {
    if score >= 90 {
        return MasteryLevel.mastered;
    }
    if score >= 70 {
        return MasteryLevel.proficient;
    }
    if score >= 40 {
        return MasteryLevel.developing;
    }
    return MasteryLevel.beginner;
}

def _clamp_int(value: int, low: int, high: int) -> int {
    if value < low {
        return low;
    }
    if value > high {
        return high;
    }
    return value;
}

def _clamp_float(value: float, low: float, high: float) -> float {
    if value < low {
        return low;
    }
    if value > high {
        return high;
    }
    return value;
}

def _round_score(value: float) -> int {
    return _clamp_int(int(value + 0.5), 0, 100);
}

def calculate_mastery_score(
    previous_score: int,
    signal_score: float,
    source_weight: float,
    confidence: float
) -> int {
    signal_score_100 = _clamp_float(signal_score, 0.0, 1.0) * 100.0;
    effective_weight = source_weight * _clamp_float(confidence, 0.0, 1.0);
    # Incremental deterministic blend: move the existing score toward the new signal
    # by source-weight times confidence. This avoids old evidence being erased by one update.
    blended = float(_clamp_int(previous_score, 0, 100)) + ((signal_score_100 - float(_clamp_int(previous_score, 0, 100))) * effective_weight);
    return _round_score(blended);
}

def _find_skill_mastery(learner_id: str, skill_id: str) -> SkillMastery | None {
    for mastery in [root -->][?:SkillMastery] {
        if mastery.learner_id == learner_id and mastery.skill_id == skill_id {
            return mastery;
        }
    }
    return None;
}

def _find_update_result(
    learner_id: str,
    source_type: MasterySourceType,
    source_id: str
) -> MasteryUpdateResult | None {
    for result in [root -->][?:MasteryUpdateResult] {
        if result.learner_id == learner_id and result.source_type == source_type and result.source_id == source_id {
            return result;
        }
    }
    return None;
}

def _assessment_signals(evaluation: AssessmentEvaluation) -> list[MasterySignalInput] {
    signals_out: list[MasterySignalInput] = [];
    for signal in evaluation.skill_signals {
        signals_out = signals_out + [
            MasterySignalInput(
                skill_id=signal.skill_id,
                signal_score=signal.accuracy,
                confidence=DEFAULT_EVIDENCE_CONFIDENCE,
                evidence_summary=f"Assessment signal from {evaluation.id}: {signal.correct_count} correct and {signal.incorrect_count} incorrect responses."
            )
        ];
    }
    return signals_out;
}

def _submission_signals(evaluation: SubmissionEvaluation) -> list[MasterySignalInput] {
    signal_nodes = evaluation.skill_signals;
    if len(signal_nodes) == 0 {
        signal_nodes = [evaluation ->:signals:->][?:SubmissionSkillSignal];
    }
    signals_out: list[MasterySignalInput] = [];
    for signal in signal_nodes {
        signals_out = signals_out + [
            MasterySignalInput(
                skill_id=signal.skill_id,
                signal_score=signal.score,
                confidence=signal.confidence,
                evidence_summary=signal.evidence
            )
        ];
    }
    return signals_out;
}

def _result_to_summary(result: MasteryUpdateResult) -> MasteryUpdateSummary {
    updated: list[UpdatedSkillMastery] = [];
    for item in result.updated_skills {
        updated = updated + [
            UpdatedSkillMastery(
                skill_id=item.skill_id,
                previous_score=item.previous_score,
                new_score=item.new_score,
                delta=item.delta,
                mastery_level=item.mastery_level,
                evidence_count=item.evidence_count
            )
        ];
    }
    return MasteryUpdateSummary(
        learner_id=result.learner_id,
        source_type=result.source_type.value,
        source_id=result.source_id,
        updated_at=result.updated_at,
        updated_skills=updated
    );
}

walker update_mastery {
    has learner_id: str;
    has source_type: str;
    has source_id: str;
    has errors: list[MasteryUpdateError] = [];
    has reports: list[MasteryUpdateSummary] = [];

    can update with Root entry {
        if self.learner_id.strip() == "" {
            self.errors = self.errors + [MasteryUpdateError(code="missing_learner", message="Log in again to update mastery.")];
            return;
        }
        if self.source_id.strip() == "" {
            self.errors = self.errors + [MasteryUpdateError(code="missing_source", message="No evaluation source id was provided.")];
            return;
        }
        source_type_value = _source_type_from_str(self.source_type);
        if source_type_value is None {
            self.errors = self.errors + [MasteryUpdateError(code="unsupported_source_type", message="Mastery updates support assessment_evaluation and submission_evaluation only.")];
            return;
        }
        source = source_type_value as MasterySourceType;

        learner = _find_learner(self.learner_id);
        if learner is None {
            self.errors = self.errors + [MasteryUpdateError(code="missing_learner", message="Learner does not exist.")];
            return;
        }

        existing_result = _find_update_result(self.learner_id, source, self.source_id);
        if existing_result is not None {
            report _result_to_summary(existing_result);
            return;
        }

        signal_inputs: list[MasterySignalInput] = [];
        source_evaluation: AssessmentEvaluation | SubmissionEvaluation | None = None;
        if source == MasterySourceType.assessment_evaluation {
            assessment_evaluation = _find_assessment_evaluation(self.source_id);
            if assessment_evaluation is None {
                self.errors = self.errors + [MasteryUpdateError(code="missing_assessment_evaluation", message="Assessment evaluation does not exist.")];
                return;
            }
            if assessment_evaluation.learner_id != self.learner_id {
                self.errors = self.errors + [MasteryUpdateError(code="learner_mismatch", message="Assessment evaluation does not belong to this learner.")];
                return;
            }
            source_evaluation = assessment_evaluation;
            signal_inputs = _assessment_signals(assessment_evaluation);
        } else {
            submission_evaluation = _find_submission_evaluation(self.source_id);
            if submission_evaluation is None {
                self.errors = self.errors + [MasteryUpdateError(code="missing_submission_evaluation", message="Submission evaluation does not exist.")];
                return;
            }
            if submission_evaluation.learner_id != self.learner_id {
                self.errors = self.errors + [MasteryUpdateError(code="learner_mismatch", message="Submission evaluation does not belong to this learner.")];
                return;
            }
            source_evaluation = submission_evaluation;
            signal_inputs = _submission_signals(submission_evaluation);
        }

        if len(signal_inputs) == 0 {
            self.errors = self.errors + [MasteryUpdateError(code="missing_skill_signals", message="Evaluation has no skill signals to apply to mastery.")];
            return;
        }

        for signal in signal_inputs {
            if signal.signal_score < 0.0 or signal.signal_score > 1.0 {
                self.errors = self.errors + [MasteryUpdateError(code="invalid_signal_score", message="Skill signal scores must be between 0.0 and 1.0.")];
            }
            if signal.confidence < 0.0 or signal.confidence > 1.0 {
                self.errors = self.errors + [MasteryUpdateError(code="invalid_confidence", message="Skill signal confidence must be between 0.0 and 1.0.")];
            }
            if _find_skill(signal.skill_id) is None {
                self.errors = self.errors + [MasteryUpdateError(code="missing_skill", message=f"Skill {signal.skill_id} does not exist.")];
            }
        }
        if len(self.errors) > 0 {
            return;
        }

        timestamp = _current_timestamp();
        source_weight = _source_weight(source);
        result = (root ++> MasteryUpdateResult(
            id=f"mastery-update-{self.learner_id}-{source.value}-{self.source_id}",
            learner_id=self.learner_id,
            source_type=source,
            source_id=self.source_id,
            updated_at=timestamp
        ))[0];
        updated_records: list[UpdatedSkillMasteryRecord] = [];

        signal_index = 1;
        for signal in signal_inputs {
            skill = _find_skill(signal.skill_id) as Skill;
            mastery = _find_skill_mastery(self.learner_id, signal.skill_id);
            if mastery is None {
                mastery = (root ++> SkillMastery(
                    id=f"skill-mastery-{self.learner_id}-{signal.skill_id}",
                    learner_id=self.learner_id,
                    skill_id=signal.skill_id,
                    score=0,
                    level=MasteryLevel.beginner,
                    evidence_count=0,
                    last_source_type="",
                    last_source_id="",
                    updated_at=timestamp,
                    created_at=timestamp
                ))[0];
                learner +>:mastered:+> mastery;
                mastery +>:targets:+> skill;
            }

            previous_score = _clamp_int(mastery.score, 0, 100);
            new_score = calculate_mastery_score(
                previous_score,
                signal.signal_score,
                source_weight,
                signal.confidence
            );
            new_level = _mastery_level(new_score);
            effective_weight = source_weight * signal.confidence;

            evidence = (root ++> MasteryEvidence(
                id=f"mastery-evidence-{self.learner_id}-{source.value}-{self.source_id}-{signal.skill_id}-{signal_index}",
                learner_id=self.learner_id,
                skill_id=signal.skill_id,
                source_type=source,
                source_id=self.source_id,
                signal_score=signal.signal_score,
                confidence=signal.confidence,
                weighted_score=(signal.signal_score * 100.0) * effective_weight,
                evidence_summary=signal.evidence_summary,
                created_at=timestamp
            ))[0];
            learner +>:evidenced_by:+> evidence;
            evidence +>:targets:+> skill;
            if source_evaluation is not None {
                evidence +>:evidenced_by:+> source_evaluation;
            }

            mastery.score = new_score;
            mastery.level = new_level;
            mastery.evidence_count = mastery.evidence_count + 1;
            mastery.last_source_type = source.value;
            mastery.last_source_id = self.source_id;
            mastery.updated_at = timestamp;

            record = UpdatedSkillMasteryRecord(
                skill_id=signal.skill_id,
                previous_score=previous_score,
                new_score=new_score,
                delta=new_score - previous_score,
                mastery_level=new_level.value,
                evidence_count=mastery.evidence_count
            );
            updated_records = updated_records + [record];
            result.updated_skills.append(record);
            signal_index += 1;
        }

        report _result_to_summary(result);
    }
}
