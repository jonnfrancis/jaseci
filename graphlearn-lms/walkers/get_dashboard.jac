"""Read-only learner dashboard aggregation."""

import from edges.domain_edges { contains }
import from lib.observability.instrumentation { observe_walker_finish, observe_walker_start }
import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentEvaluation,
    AssessmentEvaluationLink
}
import from nodes.challenge {
    ChallengeSubmission,
    ChallengeSubmissionStatus,
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

obj DashboardError {
    has code: str;
    has message: str;
}

obj DashboardLearnerSummary {
    has learner_id: str;
    has name: str;
}

obj DashboardRoadmapSummary {
    has roadmap_id: str;
    has language: str;
    has title: str;
    has status: str;
}

obj DashboardRoadmapProgress {
    has total_lessons: int;
    has completed_lessons: int;
    has available_lessons: int;
    has locked_lessons: int;
    has percent_complete: int;
    has current_roadmap_lesson_id: str;
}

obj DashboardSkillSummary {
    has skill_id: str;
    has name: str;
    has score: int;
    has level: str;
}

obj DashboardMasterySummary {
    has average_mastery: int;
    has mastered_count: int;
    has proficient_count: int;
    has developing_count: int;
    has beginner_count: int;
    has strongest_skills: list[DashboardSkillSummary] = [];
    has weakest_skills: list[DashboardSkillSummary] = [];
}

obj DashboardLessonSummary {
    has total_lessons: int;
    has generated_lessons: int;
    has pending_lessons: int;
    has completed_lessons: int;
    has available_lessons: int;
    has locked_lessons: int;
    has in_progress_lessons: int;
}

obj DashboardChallengeSummary {
    has generated_challenges: int;
    has draft_submissions: int;
    has submitted_challenges: int;
    has evaluated_submissions: int;
    has passed_challenges: int;
    has failed_challenges: int;
}

obj DashboardCurrentLesson {
    has roadmap_lesson_id: str;
    has title: str;
    has summary: str;
    has week_number: int;
    has order_index: int;
    has status: str;
    has generation_status: str;
    has generated_lesson_id: str = "";
    has challenge_id: str = "";
}

obj DashboardRecentActivity {
    has type: str;
    has title: str;
    has timestamp: str;
    has description: str = "";
    has related_entity_id: str = "";
}

obj DashboardView {
    has learner: DashboardLearnerSummary;
    has roadmap_progress: DashboardRoadmapProgress;
    has mastery_summary: DashboardMasterySummary;
    has lesson_summary: DashboardLessonSummary;
    has challenge_summary: DashboardChallengeSummary;
    has dashboard_state: str;
    has active_roadmap: DashboardRoadmapSummary | None = None;
    has current_lesson: DashboardCurrentLesson | None = None;
    has recent_activity: list[DashboardRecentActivity] = [];
}

def _empty_roadmap_progress -> DashboardRoadmapProgress {
    return DashboardRoadmapProgress(
        total_lessons=0,
        completed_lessons=0,
        available_lessons=0,
        locked_lessons=0,
        percent_complete=0,
        current_roadmap_lesson_id=""
    );
}

def _empty_mastery_summary -> DashboardMasterySummary {
    return DashboardMasterySummary(
        average_mastery=0,
        mastered_count=0,
        proficient_count=0,
        developing_count=0,
        beginner_count=0
    );
}

def _empty_lesson_summary -> DashboardLessonSummary {
    return DashboardLessonSummary(
        total_lessons=0,
        generated_lessons=0,
        pending_lessons=0,
        completed_lessons=0,
        available_lessons=0,
        locked_lessons=0,
        in_progress_lessons=0
    );
}

def _empty_challenge_summary -> DashboardChallengeSummary {
    return DashboardChallengeSummary(
        generated_challenges=0,
        draft_submissions=0,
        submitted_challenges=0,
        evaluated_submissions=0,
        passed_challenges=0,
        failed_challenges=0
    );
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
    challenge_ids = [challenge.id for challenge in challenges];
    submissions: list[ChallengeSubmission] = [];
    for submission in [root -->][?:ChallengeSubmission] {
        if submission.learner_id == learner_id and submission.challenge_id in challenge_ids {
            submissions = submissions + [submission];
        }
    }
    return submissions;
}

def _evaluations_for(learner_id: str, challenges: list[GeneratedChallenge]) -> list[SubmissionEvaluation] {
    challenge_ids = [challenge.id for challenge in challenges];
    evaluations: list[SubmissionEvaluation] = [];
    for evaluation in [root -->][?:SubmissionEvaluation] {
        if evaluation.learner_id == learner_id and evaluation.challenge_id in challenge_ids {
            evaluations = evaluations + [evaluation];
        }
    }
    return evaluations;
}

def _skill_ids_for_roadmap(roadmap: Roadmap) -> list[str] {
    ids: list[str] = [];
    for lesson in _roadmap_lessons(roadmap) {
        for skill_id in lesson.target_skill_ids {
            if skill_id.strip() != "" and skill_id not in ids {
                ids = ids + [skill_id];
            }
        }
    }
    return ids;
}

def _skill_name(skill_id: str) -> str {
    for skill in [root -->][?:Skill, id == skill_id] {
        return skill.name;
    }
    return skill_id;
}

def _mastery_records(learner_id: str, roadmap: Roadmap | None) -> list[SkillMastery] {
    relevant_ids: list[str] = [];
    if roadmap is not None {
        relevant_ids = _skill_ids_for_roadmap(roadmap as Roadmap);
    }
    records: list[SkillMastery] = [];
    for mastery in [root -->][?:SkillMastery] {
        if mastery.learner_id == learner_id {
            if len(relevant_ids) == 0 or mastery.skill_id in relevant_ids {
                records = records + [mastery];
            }
        }
    }
    return records;
}

def _score_key(skill: DashboardSkillSummary) -> str {
    return f"{skill.score:03d}-{skill.skill_id}";
}

def _top_skills(skills: list[DashboardSkillSummary]) -> list[DashboardSkillSummary] {
    ordered = sorted(skills, key=_score_key);
    top: list[DashboardSkillSummary] = [];
    for index in range(len(ordered) - 1, -1, -1) {
        if len(top) < 3 {
            top = top + [ordered[index]];
        }
    }
    return top;
}

def _bottom_skills(skills: list[DashboardSkillSummary]) -> list[DashboardSkillSummary] {
    ordered = sorted(skills, key=_score_key);
    bottom: list[DashboardSkillSummary] = [];
    for skill in ordered {
        if len(bottom) < 3 {
            bottom = bottom + [skill];
        }
    }
    return bottom;
}

def _mastery_summary(records: list[SkillMastery]) -> DashboardMasterySummary {
    if len(records) == 0 {
        return _empty_mastery_summary();
    }
    total_score = 0;
    mastered_count = 0;
    proficient_count = 0;
    developing_count = 0;
    beginner_count = 0;
    skills: list[DashboardSkillSummary] = [];
    for record in records {
        total_score += record.score;
        if str(record.level) == "mastered" {
            mastered_count += 1;
        } elif str(record.level) == "proficient" {
            proficient_count += 1;
        } elif str(record.level) == "developing" {
            developing_count += 1;
        } else {
            beginner_count += 1;
        }
        skills = skills + [
            DashboardSkillSummary(
                skill_id=record.skill_id,
                name=_skill_name(record.skill_id),
                score=record.score,
                level=str(record.level)
            )
        ];
    }
    return DashboardMasterySummary(
        average_mastery=int(total_score / len(records)),
        mastered_count=mastered_count,
        proficient_count=proficient_count,
        developing_count=developing_count,
        beginner_count=beginner_count,
        strongest_skills=_top_skills(skills),
        weakest_skills=_bottom_skills(skills)
    );
}

def _roadmap_progress_view(progress: RoadmapProgress | None, lessons: list[RoadmapLesson]) -> DashboardRoadmapProgress {
    if progress is None {
        total = len(lessons);
        return DashboardRoadmapProgress(
            total_lessons=total,
            completed_lessons=0,
            available_lessons=0,
            locked_lessons=total,
            percent_complete=0,
            current_roadmap_lesson_id=""
        );
    }
    loaded = progress as RoadmapProgress;
    return DashboardRoadmapProgress(
        total_lessons=loaded.total_lessons,
        completed_lessons=loaded.completed_lessons,
        available_lessons=loaded.available_lessons,
        locked_lessons=loaded.locked_lessons,
        percent_complete=loaded.percent_complete,
        current_roadmap_lesson_id=loaded.current_roadmap_lesson_id
    );
}

def _lesson_summary(
    lessons: list[RoadmapLesson],
    generated: list[GeneratedLesson],
    progress_records: list[LessonProgress]
) -> DashboardLessonSummary {
    generated_count = 0;
    for lesson in generated {
        if lesson.generation_status == LessonGenerationStatus.generated {
            generated_count += 1;
        }
    }
    completed_count = 0;
    available_count = 0;
    locked_count = 0;
    in_progress_count = 0;
    for lesson in lessons {
        progress = _find_lesson_progress(progress_records, lesson.id);
        if progress is None {
            locked_count += 1;
        } elif (progress as LessonProgress).status == LessonUnlockState.completed {
            completed_count += 1;
        } elif (progress as LessonProgress).status == LessonUnlockState.available {
            available_count += 1;
        } elif (progress as LessonProgress).status == LessonUnlockState.in_progress {
            in_progress_count += 1;
        } else {
            locked_count += 1;
        }
    }
    return DashboardLessonSummary(
        total_lessons=len(lessons),
        generated_lessons=generated_count,
        pending_lessons=len(lessons) - generated_count,
        completed_lessons=completed_count,
        available_lessons=available_count,
        locked_lessons=locked_count,
        in_progress_lessons=in_progress_count
    );
}

def _challenge_summary(
    challenges: list[GeneratedChallenge],
    submissions: list[ChallengeSubmission],
    evaluations: list[SubmissionEvaluation]
) -> DashboardChallengeSummary {
    draft_count = 0;
    submitted_count = 0;
    for submission in submissions {
        if submission.status == ChallengeSubmissionStatus.draft {
            draft_count += 1;
        } elif submission.status == ChallengeSubmissionStatus.submitted {
            submitted_count += 1;
        }
    }
    passed_count = 0;
    failed_count = 0;
    for evaluation in evaluations {
        if evaluation.passed {
            passed_count += 1;
        } else {
            failed_count += 1;
        }
    }
    return DashboardChallengeSummary(
        generated_challenges=len(challenges),
        draft_submissions=draft_count,
        submitted_challenges=submitted_count,
        evaluated_submissions=len(evaluations),
        passed_challenges=passed_count,
        failed_challenges=failed_count
    );
}

def _lesson_status(lesson_id: str, progress_records: list[LessonProgress]) -> str {
    progress = _find_lesson_progress(progress_records, lesson_id);
    if progress is None {
        return "locked";
    }
    return str((progress as LessonProgress).status);
}

def _find_lesson_by_id(lessons: list[RoadmapLesson], lesson_id: str) -> RoadmapLesson | None {
    for lesson in lessons {
        if lesson.id == lesson_id {
            return lesson;
        }
    }
    return None;
}

def _current_lesson(
    roadmap: Roadmap,
    lessons: list[RoadmapLesson],
    progress: RoadmapProgress | None,
    progress_records: list[LessonProgress],
    generated: list[GeneratedLesson],
    challenges: list[GeneratedChallenge]
) -> DashboardCurrentLesson | None {
    selected: RoadmapLesson | None = None;
    if progress is not None and (progress as RoadmapProgress).current_roadmap_lesson_id != "" {
        selected = _find_lesson_by_id(lessons, (progress as RoadmapProgress).current_roadmap_lesson_id);
    }
    if selected is None {
        for record in progress_records {
            if record.status == LessonUnlockState.available or record.status == LessonUnlockState.in_progress {
                selected = _find_lesson_by_id(lessons, record.roadmap_lesson_id);
                if selected is not None {
                    break;
                }
            }
        }
    }
    if selected is None and len(lessons) > 0 {
        selected = lessons[0];
    }
    if selected is None {
        return None;
    }
    lesson = selected as RoadmapLesson;
    generated_lesson = _find_generated_lesson(generated, lesson.id);
    challenge = _find_challenge(challenges, lesson.id);
    return DashboardCurrentLesson(
        roadmap_lesson_id=lesson.id,
        title=lesson.title,
        summary=lesson.summary,
        week_number=_week_number_for(roadmap, lesson),
        order_index=lesson.order_index,
        status=_lesson_status(lesson.id, progress_records),
        generation_status=str(lesson.generation_status),
        generated_lesson_id=(generated_lesson as GeneratedLesson).id if generated_lesson is not None else "",
        challenge_id=(challenge as GeneratedChallenge).id if challenge is not None else ""
    );
}

def _activity_key(activity: DashboardRecentActivity) -> str {
    return activity.timestamp + "|" + activity.type + "|" + activity.related_entity_id;
}

def _add_activity(
    activities: list[DashboardRecentActivity],
    activity_type: str,
    title: str,
    timestamp: str,
    related_entity_id: str = "",
    description: str = ""
) -> list[DashboardRecentActivity] {
    if timestamp.strip() == "" {
        return activities;
    }
    return activities + [
        DashboardRecentActivity(
            type=activity_type,
            title=title,
            description=description,
            timestamp=timestamp,
            related_entity_id=related_entity_id
        )
    ];
}

def _recent_activity(
    learner_id: str,
    roadmap: Roadmap | None,
    generated: list[GeneratedLesson],
    challenges: list[GeneratedChallenge],
    submissions: list[ChallengeSubmission],
    evaluations: list[SubmissionEvaluation]
) -> list[DashboardRecentActivity] {
    activities: list[DashboardRecentActivity] = [];
    for attempt in [root -->][?:AssessmentAttempt] {
        if attempt.learner_id == learner_id {
            activities = _add_activity(activities, "assessment_submitted", "Assessment submitted", attempt.submitted_at, attempt.id);
        }
    }
    for evaluation in [root -->][?:AssessmentEvaluation] {
        if evaluation.learner_id == learner_id {
            activities = _add_activity(activities, "assessment_evaluated", "Assessment evaluated", evaluation.created_at, evaluation.id);
        }
    }
    for assessment in [root -->][?:Assessment] {
        if assessment.learner_id == learner_id {
            for attempt in [assessment ->:AssessmentAttemptLink:->][?:AssessmentAttempt] {
                for evaluation in [attempt ->:AssessmentEvaluationLink:->][?:AssessmentEvaluation] {
                    activities = _add_activity(activities, "assessment_evaluated", "Assessment evaluated", evaluation.created_at, evaluation.id);
                }
            }
        }
    }
    if roadmap is not None {
        activities = _add_activity(activities, "roadmap_generated", "Roadmap generated", (roadmap as Roadmap).created_at, (roadmap as Roadmap).id);
        for event in [root -->][?:ProgressionEvent] {
            if event.learner_id == learner_id and event.roadmap_id == (roadmap as Roadmap).id {
                activities = _add_activity(activities, str(event.event_type), event.message, event.created_at, event.id);
            }
        }
    }
    for lesson in generated {
        activities = _add_activity(activities, "lesson_generated", f"{lesson.title} generated", lesson.created_at, lesson.id);
    }
    for challenge in challenges {
        activities = _add_activity(activities, "challenge_generated", f"{challenge.title} generated", challenge.created_at, challenge.id);
    }
    for submission in submissions {
        activities = _add_activity(activities, "challenge_submitted", "Challenge submitted", submission.submitted_at, submission.id);
    }
    for evaluation in evaluations {
        activities = _add_activity(activities, "submission_evaluated", "Challenge submission evaluated", evaluation.evaluated_at, evaluation.id);
    }
    for evidence in [root -->][?:MasteryEvidence] {
        if evidence.learner_id == learner_id {
            activities = _add_activity(activities, "mastery_updated", "Mastery updated", evidence.created_at, evidence.id);
        }
    }
    ordered = sorted(activities, key=_activity_key);
    recent: list[DashboardRecentActivity] = [];
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

def _dashboard_state(
    learner_id: str,
    roadmap: Roadmap | None,
    progress: RoadmapProgress | None
) -> str {
    assessment_exists = _has_assessment(learner_id);
    evaluation_exists = _has_assessment_evaluation(learner_id);
    if not assessment_exists {
        return "no_assessment";
    }
    if not evaluation_exists {
        return "assessment_started";
    }
    if roadmap is None {
        return "roadmap_missing";
    }
    if progress is None {
        return "roadmap_ready";
    }
    if (progress as RoadmapProgress).status == RoadmapProgressStatus.completed {
        return "completed";
    }
    return "in_progress";
}

def _base_view(learner: Learner, state: str) -> DashboardView {
    return DashboardView(
        learner=DashboardLearnerSummary(learner_id=learner.id, name=learner.name),
        roadmap_progress=_empty_roadmap_progress(),
        mastery_summary=_empty_mastery_summary(),
        lesson_summary=_empty_lesson_summary(),
        challenge_summary=_empty_challenge_summary(),
        dashboard_state=state
    );
}

walker get_dashboard {
    has learner_id: str;
    has language: str = "";
    has roadmap_id: str = "";
    has errors: list[DashboardError] = [];
    has reports: list[DashboardView] = [];
    has request_id: str = "";
    has correlation_id: str = "";

    can observability_start with Root entry { observe_walker_start(self); }
    can observability_finish with Root exit { observe_walker_finish(self); }

    can load with Root entry {
        if self.learner_id.strip() == "" {
            self.errors = self.errors + [DashboardError(code="missing_learner", message="Log in again to load the dashboard.")];
            return;
        }
        language_normalized = self.language.strip().lower();
        if language_normalized != "" and language_normalized not in ["python", "jac"] {
            self.errors = self.errors + [DashboardError(code="unsupported_language", message="Dashboard currently supports python and jac only.")];
            return;
        }
        learner = _find_learner(self.learner_id);
        if learner is None {
            self.errors = self.errors + [DashboardError(code="missing_learner", message="Learner does not exist.")];
            return;
        }

        roadmap: Roadmap | None = None;
        if self.roadmap_id.strip() != "" {
            found = _find_roadmap(self.roadmap_id);
            if found is None {
                self.errors = self.errors + [DashboardError(code="missing_roadmap", message="Roadmap does not exist.")];
                return;
            }
            if found.learner_id != self.learner_id {
                self.errors = self.errors + [DashboardError(code="roadmap_learner_mismatch", message="Roadmap does not belong to this learner.")];
                return;
            }
            if language_normalized != "" and found.language != language_normalized {
                self.errors = self.errors + [DashboardError(code="language_mismatch", message="Roadmap language does not match the requested dashboard language.")];
                return;
            }
            roadmap = found;
        } else {
            roadmap = _latest_active_roadmap(self.learner_id, language_normalized);
        }

        if roadmap is None {
            report _base_view(learner as Learner, _dashboard_state(self.learner_id, None, None));
            return;
        }

        active = roadmap as Roadmap;
        lessons = _ordered_lessons(active);
        progress = _find_roadmap_progress(self.learner_id, active.id);
        if progress is not None and (progress as RoadmapProgress).total_lessons < (progress as RoadmapProgress).completed_lessons {
            self.errors = self.errors + [DashboardError(code="malformed_progress", message="Roadmap progress totals are inconsistent.")];
            return;
        }
        lesson_progress = _lesson_progress_records(self.learner_id, active.id);
        generated = _generated_lessons(self.learner_id, active.id);
        challenges = _generated_challenges(self.learner_id, active.id);
        submissions = _submissions_for(self.learner_id, challenges);
        evaluations = _evaluations_for(self.learner_id, challenges);

        report DashboardView(
            learner=DashboardLearnerSummary(learner_id=(learner as Learner).id, name=(learner as Learner).name),
            active_roadmap=DashboardRoadmapSummary(
                roadmap_id=active.id,
                language=active.language,
                title=active.title,
                status=str(active.status)
            ),
            roadmap_progress=_roadmap_progress_view(progress, lessons),
            mastery_summary=_mastery_summary(_mastery_records(self.learner_id, active)),
            lesson_summary=_lesson_summary(lessons, generated, lesson_progress),
            challenge_summary=_challenge_summary(challenges, submissions, evaluations),
            current_lesson=_current_lesson(active, lessons, progress, lesson_progress, generated, challenges),
            recent_activity=_recent_activity(self.learner_id, active, generated, challenges, submissions, evaluations),
            dashboard_state=_dashboard_state(self.learner_id, active, progress)
        );
    }
}
