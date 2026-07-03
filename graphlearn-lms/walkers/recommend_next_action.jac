"""Read-only AI tutor next-action recommendation."""

import from datetime { datetime }
import from lib.ai.utilities {
    TutorRecommendationContext,
    TutorRecommendationPriority,
    TutorRecommendationResult,
    TutorRecommendationType,
    generate_next_action_recommendation
}
import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentEvaluation,
    AssessmentEvaluationLink
}
import from nodes.challenge {
    ChallengeSubmission,
    GeneratedChallenge,
    SubmissionEvaluation
}
import from nodes.learner { Learner }
import from nodes.lesson { GeneratedLesson, LessonGenerationStatus }
import from nodes.mastery { MasteryEvidence, SkillMastery }
import from nodes.progression {
    LessonProgress,
    LessonUnlockState,
    ProgressionEvent,
    RoadmapProgress,
    RoadmapProgressStatus
}
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapStatus,
    RoadmapWeek
}
import from nodes.skill { Skill }
import from edges.domain_edges { contains }

obj TutorRecommendationError {
    has code: str;
    has message: str;
}

obj TutorRecommendationView {
    has learner_id: str;
    has roadmap_id: str;
    has language: str;
    has recommendation_type: str;
    has title: str;
    has recommended_action: str;
    has explanation: str;
    has confidence: float;
    has priority: str;
    has suggested_cta_label: str;
    has created_at: str;
    has related_roadmap_lesson_id: str = "";
    has related_challenge_id: str = "";
    has related_skill_ids: list[str] = [];
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

def _find_roadmap(roadmap_id: str) -> Roadmap | None {
    for roadmap in [root -->][?:Roadmap, id == roadmap_id] {
        return roadmap;
    }
    return None;
}

def _latest_active_roadmap(learner_id: str, language: str = "") -> Roadmap | None {
    latest: Roadmap | None = None;
    for roadmap in [root -->][?:Roadmap] {
        if roadmap.learner_id == learner_id and roadmap.status == RoadmapStatus.active {
            if language == "" or roadmap.language == language {
                if latest is None or roadmap.created_at > (latest as Roadmap).created_at {
                    latest = roadmap;
                }
            }
        }
    }
    return latest;
}

def _roadmap_weeks(roadmap: Roadmap) -> list[RoadmapWeek] {
    if len(roadmap.weeks) > 0 {
        return roadmap.weeks;
    }
    return [roadmap ->:contains:->][?:RoadmapWeek];
}

def _roadmap_lessons(roadmap: Roadmap) -> list[RoadmapLesson] {
    if len(roadmap.lessons) > 0 {
        return roadmap.lessons;
    }
    loaded: list[RoadmapLesson] = [];
    for week in _roadmap_weeks(roadmap) {
        for lesson in [week ->:contains:->][?:RoadmapLesson] {
            loaded = loaded + [lesson];
        }
    }
    return loaded;
}

def _week_number_for(roadmap: Roadmap, lesson: RoadmapLesson) -> int {
    for week in _roadmap_weeks(roadmap) {
        if week.id == lesson.week_id {
            return week.week_number;
        }
    }
    return 0;
}

def _lesson_order_key(roadmap: Roadmap, lesson: RoadmapLesson) -> str {
    return f"{_week_number_for(roadmap, lesson):06d}-{lesson.order_index:06d}-{lesson.id}";
}

def _ordered_lessons(roadmap: Roadmap) -> list[RoadmapLesson] {
    return sorted(_roadmap_lessons(roadmap), key=lambda lesson: RoadmapLesson : _lesson_order_key(roadmap, lesson));
}

def _find_roadmap_progress(learner_id: str, roadmap_id: str) -> RoadmapProgress | None {
    for progress in [root -->][?:RoadmapProgress] {
        if progress.learner_id == learner_id and progress.roadmap_id == roadmap_id {
            return progress;
        }
    }
    return None;
}

def _lesson_progress_records(learner_id: str, roadmap_id: str) -> list[LessonProgress] {
    records: list[LessonProgress] = [];
    for progress in [root -->][?:LessonProgress] {
        if progress.learner_id == learner_id and progress.roadmap_id == roadmap_id {
            records = records + [progress];
        }
    }
    return records;
}

def _find_lesson_progress(records: list[LessonProgress], lesson_id: str) -> LessonProgress | None {
    for progress in records {
        if progress.roadmap_lesson_id == lesson_id {
            return progress;
        }
    }
    return None;
}

def _find_lesson_by_id(lessons: list[RoadmapLesson], lesson_id: str) -> RoadmapLesson | None {
    for lesson in lessons {
        if lesson.id == lesson_id {
            return lesson;
        }
    }
    return None;
}

def _generated_lessons(learner_id: str, roadmap_id: str) -> list[GeneratedLesson] {
    lessons: list[GeneratedLesson] = [];
    for lesson in [root -->][?:GeneratedLesson] {
        if lesson.learner_id == learner_id and lesson.roadmap_id == roadmap_id {
            lessons = lessons + [lesson];
        }
    }
    return lessons;
}

def _find_generated_lesson(generated: list[GeneratedLesson], roadmap_lesson_id: str) -> GeneratedLesson | None {
    for lesson in generated {
        if lesson.roadmap_lesson_id == roadmap_lesson_id and lesson.generation_status == LessonGenerationStatus.generated {
            return lesson;
        }
    }
    return None;
}

def _generated_challenges(learner_id: str, roadmap_id: str) -> list[GeneratedChallenge] {
    challenges: list[GeneratedChallenge] = [];
    for challenge in [root -->][?:GeneratedChallenge] {
        if challenge.learner_id == learner_id and challenge.roadmap_id == roadmap_id {
            challenges = challenges + [challenge];
        }
    }
    return challenges;
}

def _find_challenge(challenges: list[GeneratedChallenge], roadmap_lesson_id: str) -> GeneratedChallenge | None {
    for challenge in challenges {
        if challenge.roadmap_lesson_id == roadmap_lesson_id {
            return challenge;
        }
    }
    return None;
}

def _submissions_for(learner_id: str, challenges: list[GeneratedChallenge]) -> list[ChallengeSubmission] {
    ids = [challenge.id for challenge in challenges];
    submissions: list[ChallengeSubmission] = [];
    for submission in [root -->][?:ChallengeSubmission] {
        if submission.learner_id == learner_id and submission.challenge_id in ids {
            submissions = submissions + [submission];
        }
    }
    return submissions;
}

def _evaluations_for(learner_id: str, challenges: list[GeneratedChallenge]) -> list[SubmissionEvaluation] {
    ids = [challenge.id for challenge in challenges];
    evaluations: list[SubmissionEvaluation] = [];
    for evaluation in [root -->][?:SubmissionEvaluation] {
        if evaluation.learner_id == learner_id and evaluation.challenge_id in ids {
            evaluations = evaluations + [evaluation];
        }
    }
    return evaluations;
}

def _latest_evaluation_for_challenge(evaluations: list[SubmissionEvaluation], challenge_id: str) -> SubmissionEvaluation | None {
    latest: SubmissionEvaluation | None = None;
    for evaluation in evaluations {
        if evaluation.challenge_id == challenge_id {
            if latest is None or evaluation.evaluated_at > (latest as SubmissionEvaluation).evaluated_at {
                latest = evaluation;
            }
        }
    }
    return latest;
}

def _mastery_records(learner_id: str, roadmap: Roadmap | None) -> list[SkillMastery] {
    ids: list[str] = [];
    if roadmap is not None {
        for lesson in _roadmap_lessons(roadmap as Roadmap) {
            for skill_id in lesson.target_skill_ids {
                if skill_id not in ids {
                    ids = ids + [skill_id];
                }
            }
        }
    }
    records: list[SkillMastery] = [];
    for mastery in [root -->][?:SkillMastery] {
        if mastery.learner_id == learner_id and (len(ids) == 0 or mastery.skill_id in ids) {
            records = records + [mastery];
        }
    }
    return records;
}

def _score_key(mastery: SkillMastery) -> str {
    return f"{mastery.score:03d}-{mastery.skill_id}";
}

def _weak_skills(records: list[SkillMastery]) -> list[str] {
    ordered = sorted(records, key=_score_key);
    skills: list[str] = [];
    for mastery in ordered {
        if len(skills) < 3 and mastery.score < 40 {
            skills = skills + [mastery.skill_id];
        }
    }
    return skills;
}

def _strong_skills(records: list[SkillMastery]) -> list[str] {
    ordered = sorted(records, key=_score_key);
    skills: list[str] = [];
    for index in range(len(ordered) - 1, -1, -1) {
        if len(skills) < 3 {
            skills = skills + [ordered[index].skill_id];
        }
    }
    return skills;
}

def _average_mastery(records: list[SkillMastery]) -> int {
    if len(records) == 0 {
        return 0;
    }
    total = 0;
    for mastery in records {
        if mastery.score < 0 or mastery.score > 100 {
            return -1;
        }
        total += mastery.score;
    }
    return int(total / len(records));
}

def _recent_activity(learner_id: str, roadmap_id: str) -> list[str] {
    items: list[str] = [];
    for event in [root -->][?:ProgressionEvent] {
        if event.learner_id == learner_id and event.roadmap_id == roadmap_id {
            items = items + [event.created_at + " " + event.message];
        }
    }
    for evidence in [root -->][?:MasteryEvidence] {
        if evidence.learner_id == learner_id {
            items = items + [evidence.created_at + " Mastery evidence for " + evidence.skill_id];
        }
    }
    ordered = sorted(items);
    recent: list[str] = [];
    for index in range(len(ordered) - 1, -1, -1) {
        if len(recent) < 5 {
            recent = recent + [ordered[index]];
        }
    }
    return recent;
}

def _has_assessment(learner_id: str) -> bool {
    for assessment in [root -->][?:Assessment] {
        if assessment.learner_id == learner_id {
            return True;
        }
    }
    return False;
}

def _has_assessment_evaluation(learner_id: str) -> bool {
    for evaluation in [root -->][?:AssessmentEvaluation] {
        if evaluation.learner_id == learner_id {
            return True;
        }
    }
    for assessment in [root -->][?:Assessment] {
        if assessment.learner_id == learner_id {
            for attempt in [assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt] {
                for evaluation in [attempt ->:AssessmentEvaluationLink:->][?:AssessmentEvaluation] {
                    if evaluation.learner_id == learner_id {
                        return True;
                    }
                }
            }
        }
    }
    return False;
}

def _current_lesson(
    lessons: list[RoadmapLesson],
    progress: RoadmapProgress | None,
    progress_records: list[LessonProgress]
) -> RoadmapLesson | None {
    if progress is not None and (progress as RoadmapProgress).current_roadmap_lesson_id != "" {
        selected = _find_lesson_by_id(lessons, (progress as RoadmapProgress).current_roadmap_lesson_id);
        if selected is not None {
            return selected;
        }
    }
    for record in progress_records {
        if record.status == LessonUnlockState.available or record.status == LessonUnlockState.in_progress {
            selected = _find_lesson_by_id(lessons, record.roadmap_lesson_id);
            if selected is not None {
                return selected;
            }
        }
    }
    if len(lessons) > 0 {
        return lessons[0];
    }
    return None;
}

def _clamp_confidence(value: float) -> float {
    if value < 0.0 {
        return 0.0;
    }
    if value > 1.0 {
        return 1.0;
    }
    return value;
}

def _view(
    learner_id: str,
    roadmap_id: str,
    language: str,
    recommendation_type: str,
    title: str,
    action: str,
    explanation: str,
    priority: str,
    confidence: float,
    lesson_id: str = "",
    challenge_id: str = "",
    skill_ids: list[str] | None = None,
    cta: str = "Continue"
) -> TutorRecommendationView {
    normalized_skill_ids = skill_ids if skill_ids is not None else [];
    return TutorRecommendationView(
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        language=language,
        recommendation_type=recommendation_type,
        title=title,
        recommended_action=action,
        explanation=explanation,
        confidence=_clamp_confidence(confidence),
        priority=priority,
        related_roadmap_lesson_id=lesson_id,
        related_challenge_id=challenge_id,
        related_skill_ids=normalized_skill_ids,
        suggested_cta_label=cta,
        created_at=_current_timestamp()
    );
}

def _from_ai(learner_id: str, roadmap_id: str, language: str, result: TutorRecommendationResult) -> TutorRecommendationView {
    return _view(
        learner_id,
        roadmap_id,
        language,
        result.recommendation_type.value,
        result.title,
        result.recommended_action,
        result.explanation,
        result.priority.value,
        result.confidence,
        result.related_roadmap_lesson_id,
        result.related_challenge_id,
        result.related_skill_ids,
        result.suggested_cta_label
    );
}

def _build_context(
    roadmap: Roadmap,
    lessons: list[RoadmapLesson],
    progress: RoadmapProgress | None,
    progress_records: list[LessonProgress],
    current: RoadmapLesson | None,
    generated: list[GeneratedLesson],
    challenges: list[GeneratedChallenge],
    evaluations: list[SubmissionEvaluation],
    mastery: list[SkillMastery]
) -> TutorRecommendationContext {
    available: list[str] = [];
    locked: list[str] = [];
    completed: list[str] = [];
    for lesson in lessons {
        record = _find_lesson_progress(progress_records, lesson.id);
        if record is None or (record as LessonProgress).status == LessonUnlockState.locked {
            locked = locked + [lesson.title];
        } elif (record as LessonProgress).status == LessonUnlockState.completed {
            completed = completed + [lesson.title];
        } else {
            available = available + [lesson.title];
        }
    }
    average = _average_mastery(mastery);
    current_summary = "No current lesson.";
    if current is not None {
        cur = current as RoadmapLesson;
        cur_progress = _find_lesson_progress(progress_records, cur.id);
        status = (cur_progress as LessonProgress).status.value if cur_progress is not None else "locked";
        generated_lesson = _find_generated_lesson(generated, cur.id);
        challenge = _find_challenge(challenges, cur.id);
        current_summary = f"{cur.title}; status={status}; generation={cur.generation_status.value}; generated_lesson_id={(generated_lesson as GeneratedLesson).id if generated_lesson is not None else ''}; challenge_id={(challenge as GeneratedChallenge).id if challenge is not None else ''}; target_skills={','.join(cur.target_skill_ids)}";
    }
    failed = 0;
    passed = 0;
    for evaluation in evaluations {
        if evaluation.passed {
            passed += 1;
        } else {
            failed += 1;
        }
    }
    total = len(lessons);
    completed_count = (progress as RoadmapProgress).completed_lessons if progress is not None else 0;
    available_count = (progress as RoadmapProgress).available_lessons if progress is not None else 0;
    locked_count = (progress as RoadmapProgress).locked_lessons if progress is not None else total;
    current_id = (progress as RoadmapProgress).current_roadmap_lesson_id if progress is not None else "";
    return TutorRecommendationContext(
        language=roadmap.language,
        roadmap_title=roadmap.title,
        roadmap_status=roadmap.status.value,
        roadmap_progress_summary=f"total={total}; completed={completed_count}; available={available_count}; locked={locked_count}; current={current_id}",
        current_lesson_summary=current_summary,
        lesson_status_summary=f"generated={len(generated)}; available={len(available)}; locked={len(locked)}; completed={len(completed)}",
        challenge_status_summary=f"generated={len(challenges)}; evaluated={len(evaluations)}; passed={passed}; failed={failed}",
        mastery_summary=f"average={average}; records={len(mastery)}",
        weakest_skills=_weak_skills(mastery),
        strongest_skills=_strong_skills(mastery),
        recent_activity=_recent_activity(roadmap.learner_id, roadmap.id),
        available_lessons=available,
        locked_lessons=locked,
        completed_lessons=completed
    );
}

walker recommend_next_action {
    has learner_id: str;
    has roadmap_id: str = "";
    has language: str = "";
    has errors: list[TutorRecommendationError] = [];
    has reports: list[TutorRecommendationView] = [];

    can recommend with Root entry {
        language_normalized = self.language.strip().lower();
        if self.learner_id.strip() == "" {
            self.errors = self.errors + [TutorRecommendationError(code="missing_learner", message="Log in again to get a recommendation.")];
            return;
        }
        if language_normalized != "" and language_normalized not in ["python", "jac"] {
            self.errors = self.errors + [TutorRecommendationError(code="unsupported_language", message="Recommendations currently support python and jac only.")];
            return;
        }
        learner = _find_learner(self.learner_id);
        if learner is None {
            self.errors = self.errors + [TutorRecommendationError(code="missing_learner", message="Learner does not exist.")];
            return;
        }

        if not _has_assessment(self.learner_id) {
            report _view(self.learner_id, "", language_normalized, "start_assessment", "Start your assessment", "Start the initial assessment so GraphLearn can understand your current level.", "A roadmap recommendation needs assessment evidence first.", "high", 0.9, "", "", [], "Start assessment");
            return;
        }
        if not _has_assessment_evaluation(self.learner_id) {
            report _view(self.learner_id, "", language_normalized, "start_assessment", "Finish your assessment", "Complete and submit your assessment before starting a roadmap.", "Your assessment exists but has not been evaluated yet.", "high", 0.9, "", "", [], "Continue assessment");
            return;
        }

        roadmap: Roadmap | None = None;
        if self.roadmap_id.strip() != "" {
            found = _find_roadmap(self.roadmap_id);
            if found is None {
                self.errors = self.errors + [TutorRecommendationError(code="missing_roadmap", message="Roadmap does not exist.")];
                return;
            }
            if found.learner_id != self.learner_id {
                self.errors = self.errors + [TutorRecommendationError(code="roadmap_learner_mismatch", message="Roadmap does not belong to this learner.")];
                return;
            }
            if language_normalized != "" and found.language != language_normalized {
                self.errors = self.errors + [TutorRecommendationError(code="language_mismatch", message="Roadmap language does not match the requested recommendation language.")];
                return;
            }
            roadmap = found;
        } else {
            roadmap = _latest_active_roadmap(self.learner_id, language_normalized);
        }
        if roadmap is None {
            report _view(self.learner_id, "", language_normalized, "generate_roadmap", "Generate your roadmap", "Generate a personalized roadmap from your assessment results.", "Your assessment is evaluated, but no active roadmap is available yet.", "high", 0.9, "", "", [], "Generate roadmap");
            return;
        }

        active = roadmap as Roadmap;
        lessons = _ordered_lessons(active);
        progress = _find_roadmap_progress(self.learner_id, active.id);
        if progress is not None and (progress as RoadmapProgress).total_lessons < (progress as RoadmapProgress).completed_lessons {
            self.errors = self.errors + [TutorRecommendationError(code="malformed_progress", message="Roadmap progress totals are inconsistent.")];
            return;
        }
        progress_records = _lesson_progress_records(self.learner_id, active.id);
        generated = _generated_lessons(self.learner_id, active.id);
        challenges = _generated_challenges(self.learner_id, active.id);
        submissions = _submissions_for(self.learner_id, challenges);
        _ = submissions;
        evaluations = _evaluations_for(self.learner_id, challenges);
        mastery = _mastery_records(self.learner_id, active);
        average = _average_mastery(mastery);
        if average < 0 {
            self.errors = self.errors + [TutorRecommendationError(code="malformed_mastery", message="Mastery score must be between 0 and 100.")];
            return;
        }

        if progress is not None and (progress as RoadmapProgress).status == RoadmapProgressStatus.completed {
            report _view(self.learner_id, active.id, active.language, "completed", "Roadmap complete", "Review your skill map or start a new roadmap when ready.", "You have completed every lesson in this roadmap.", "low", 0.9, "", "", [], "View skill map");
            return;
        }
        if progress is None or (progress as RoadmapProgress).status == RoadmapProgressStatus.not_started {
            first_lesson_id = lessons[0].id if len(lessons) > 0 else "";
            report _view(self.learner_id, active.id, active.language, "start_roadmap", "Start your roadmap", "Open the roadmap and begin the first available lesson.", "Your roadmap exists, but progression has not started yet.", "high", 0.9, first_lesson_id, "", [], "Start roadmap");
            return;
        }

        current = _current_lesson(lessons, progress, progress_records);
        if current is not None {
            lesson = current as RoadmapLesson;
            lesson_progress = _find_lesson_progress(progress_records, lesson.id);
            generated_lesson = _find_generated_lesson(generated, lesson.id);
            challenge = _find_challenge(challenges, lesson.id);
            if challenge is not None {
                latest_eval = _latest_evaluation_for_challenge(evaluations, (challenge as GeneratedChallenge).id);
                if latest_eval is not None and not (latest_eval as SubmissionEvaluation).passed {
                    report _view(self.learner_id, active.id, active.language, "retry_challenge", "Retry the challenge", "Review the feedback, adjust your solution, and resubmit the current challenge.", (latest_eval as SubmissionEvaluation).feedback_summary, "high", 0.9, lesson.id, (challenge as GeneratedChallenge).id, lesson.target_skill_ids, "Retry challenge");
                    return;
                }
            }
            if generated_lesson is None {
                report _view(self.learner_id, active.id, active.language, "generate_lesson", f"Open {lesson.title}", "Open this lesson so GraphLearn can prepare the learning content.", "This is the current unlocked lesson and its generated content is not ready yet.", "high", 0.9, lesson.id, "", lesson.target_skill_ids, "Open lesson");
                return;
            }
            if challenge is None and lesson_progress is not None {
                report _view(self.learner_id, active.id, active.language, "start_challenge", "Start the coding challenge", "Start the challenge for this lesson to practice the skill hands-on.", "The lesson content is ready and no challenge has been attempted for it yet.", "high", 0.9, lesson.id, "", lesson.target_skill_ids, "Start challenge");
                return;
            }
            if lesson_progress is not None and (lesson_progress as LessonProgress).status != LessonUnlockState.completed {
                if len(_weak_skills(mastery)) > 0 {
                    weak = _weak_skills(mastery);
                    report _view(self.learner_id, active.id, active.language, "practice_weak_skill", "Practice a weak skill", "Review the current lesson and focus on the weakest related skill before moving forward.", "Your mastery evidence shows a low-confidence skill that may block future progress.", "medium", 0.9, lesson.id, (challenge as GeneratedChallenge).id if challenge is not None else "", weak, "Practice skill");
                    return;
                }
                report _view(self.learner_id, active.id, active.language, "continue_lesson", f"Continue {lesson.title}", "Open the current lesson and complete its challenge when ready.", "This lesson is available and is the next safe step in your roadmap.", "high", 0.9, lesson.id, (challenge as GeneratedChallenge).id if challenge is not None else "", lesson.target_skill_ids, "Continue lesson");
                return;
            }
        }

        context = _build_context(active, lessons, progress, progress_records, current, generated, challenges, evaluations, mastery);
        try {
            ai_result = generate_next_action_recommendation(context);
            if ai_result.title.strip() == "" or ai_result.recommended_action.strip() == "" or ai_result.explanation.strip() == "" or ai_result.suggested_cta_label.strip() == "" {
                self.errors = self.errors + [TutorRecommendationError(code="invalid_ai_output", message="AI recommendation was missing required display fields.")];
                return;
            }
            report _from_ai(self.learner_id, active.id, active.language, ai_result);
        } except Exception {
            fallback_lesson_id = (current as RoadmapLesson).id if current is not None else "";
            report _view(self.learner_id, active.id, active.language, "continue_lesson", "Continue learning", "Continue with your current available lesson.", "AI recommendations are temporarily unavailable, so GraphLearn is using the safest roadmap-based next step.", "high", 0.75, fallback_lesson_id, "", [], "Continue lesson");
        }
    }
}
