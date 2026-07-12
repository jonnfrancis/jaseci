"""Deterministic roadmap progression and lesson unlocking."""

import from datetime { datetime }
import from edges.domain_edges {
    Prerequisite,
    assigned,
    belongs_to,
    completed,
    contains,
    evaluated,
    progresses,
    submitted_for,
    targets,
    tracks,
    unlocked
}
import from nodes.challenge {
    ChallengeSubmission,
    ChallengeSubmissionStatus,
    GeneratedChallenge,
    SubmissionEvaluation
}
import from nodes.learner { Learner }
import from nodes.lesson { GeneratedLesson, LessonGenerationStatus }
import from nodes.mastery { SkillMastery }
import from nodes.progression {
    LessonProgress,
    LessonUnlockState,
    ProgressionEvent,
    ProgressionEventType,
    RoadmapProgress,
    RoadmapProgressStatus
}
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapStatus,
    RoadmapWeek
}
import from lib.graph.learning_queries { generated_lesson_for }
import from lib.graph.mastery_queries { skill_mastery_for }
import from nodes.skill { Skill }

glob MINIMUM_PREREQUISITE_MASTERY = 40;

obj ProgressionError {
    has code: str;
    has message: str;
}

obj LessonProgressView {
    has roadmap_lesson_id: str;
    has title: str;
    has status: str;
    has unlock_reason: str = "";
    has locked_reason: str = "";
    has completed_at: str = "";
    has unlocked_at: str = "";
}

obj RoadmapProgressView {
    has id: str;
    has learner_id: str;
    has roadmap_id: str;
    has total_lessons: int;
    has completed_lessons: int;
    has available_lessons: int;
    has locked_lessons: int;
    has percent_complete: int;
    has current_roadmap_lesson_id: str;
    has status: str;
    has updated_at: str;
}

obj ProgressionEventView {
    has id: str;
    has learner_id: str;
    has roadmap_id: str;
    has roadmap_lesson_id: str;
    has event_type: str;
    has source_type: str;
    has source_id: str;
    has message: str;
    has created_at: str;
}

obj ProgressionResult {
    has learner_id: str;
    has roadmap_id: str;
    has roadmap_completed: bool;
    has message: str;
    has current_lesson: LessonProgressView | None = None;
    has roadmap_progress: RoadmapProgressView | None = None;
    has newly_unlocked_lessons: list[LessonProgressView] = [];
    has locked_lessons: list[LessonProgressView] = [];
    has completed_lessons: list[LessonProgressView] = [];
    has events: list[ProgressionEventView] = [];
}

obj ProgressionEventDraft {
    has event_type: ProgressionEventType;
    has message: str;
    has lesson: RoadmapLesson | None = None;
    has source_type: str = "";
    has source_id: str = "";
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

def _roadmap_weeks(roadmap: Roadmap) -> list[RoadmapWeek] {
    weeks = roadmap.weeks;
    if len(weeks) > 0 {
        return weeks;
    }
    return [roadmap ->:contains:->][?:RoadmapWeek];
}

def _roadmap_lessons(roadmap: Roadmap) -> list[RoadmapLesson] {
    lessons = roadmap.lessons;
    if len(lessons) > 0 {
        return lessons;
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

def _roadmap_order_errors(roadmap: Roadmap, lessons: list[RoadmapLesson]) -> list[ProgressionError] {
    errors: list[ProgressionError] = [];
    seen_keys: list[str] = [];
    for lesson in lessons {
        week_number = _week_number_for(roadmap, lesson);
        if week_number <= 0 or lesson.order_index <= 0 {
            errors = errors + [
                ProgressionError(
                    code="malformed_roadmap_order",
                    message=f"Lesson {lesson.id} has invalid roadmap ordering."
                )
            ];
        }
        order_key = f"{week_number}:{lesson.order_index}";
        if order_key in seen_keys {
            errors = errors + [
                ProgressionError(
                    code="malformed_roadmap_order",
                    message=f"Roadmap has duplicate lesson order {order_key}."
                )
            ];
        }
        seen_keys = seen_keys + [order_key];
    }
    return errors;
}

def _find_lesson(lessons: list[RoadmapLesson], lesson_id: str) -> RoadmapLesson | None {
    for lesson in lessons {
        if lesson.id == lesson_id {
            return lesson;
        }
    }
    return None;
}

def _find_lesson_progress(
    learner_id: str,
    roadmap_id: str,
    roadmap_lesson_id: str
) -> LessonProgress | None {
    for progress in [root -->][?:LessonProgress] {
        if progress.learner_id == learner_id and progress.roadmap_id == roadmap_id and progress.roadmap_lesson_id == roadmap_lesson_id {
            return progress;
        }
    }
    return None;
}

def _find_roadmap_progress(learner_id: str, roadmap_id: str) -> RoadmapProgress | None {
    for progress in [root -->][?:RoadmapProgress] {
        if progress.learner_id == learner_id and progress.roadmap_id == roadmap_id {
            return progress;
        }
    }
    return None;
}

def _progress_id(learner_id: str, roadmap_id: str, roadmap_lesson_id: str) -> str {
    return f"lesson-progress-{learner_id}-{roadmap_id}-{roadmap_lesson_id}";
}

def _roadmap_progress_id(learner_id: str, roadmap_id: str) -> str {
    return f"roadmap-progress-{learner_id}-{roadmap_id}";
}

def _get_or_create_lesson_progress(
    learner: Learner,
    roadmap: Roadmap,
    lesson: RoadmapLesson,
    status: LessonUnlockState,
    timestamp: str
) -> LessonProgress {
    existing = _find_lesson_progress(learner.id, roadmap.id, lesson.id);
    if existing is not None {
        return existing;
    }
    unlocked_at = timestamp if status != LessonUnlockState.locked else "";
    progress = (root ++> LessonProgress(
        id=_progress_id(learner.id, roadmap.id, lesson.id),
        learner_id=learner.id,
        roadmap_id=roadmap.id,
        roadmap_lesson_id=lesson.id,
        status=status,
        completed_at="",
        unlocked_at=unlocked_at,
        updated_at=timestamp
    ))[0];
    learner +>:progresses:+> progress;
    roadmap +>:tracks:+> progress;
    lesson +>:tracks:+> progress;
    if status != LessonUnlockState.locked {
        lesson +>:unlocked:+> progress;
    }
    return progress;
}

def _get_or_create_roadmap_progress(
    learner: Learner,
    roadmap: Roadmap,
    timestamp: str
) -> RoadmapProgress {
    existing = _find_roadmap_progress(learner.id, roadmap.id);
    if existing is not None {
        return existing;
    }
    progress = (root ++> RoadmapProgress(
        id=_roadmap_progress_id(learner.id, roadmap.id),
        learner_id=learner.id,
        roadmap_id=roadmap.id,
        total_lessons=0,
        completed_lessons=0,
        available_lessons=0,
        locked_lessons=0,
        percent_complete=0,
        current_roadmap_lesson_id="",
        status=RoadmapProgressStatus.not_started,
        updated_at=timestamp
    ))[0];
    learner +>:progresses:+> progress;
    roadmap +>:tracks:+> progress;
    return progress;
}

def _find_event(
    learner_id: str,
    roadmap_id: str,
    roadmap_lesson_id: str,
    event_type: ProgressionEventType
) -> ProgressionEvent | None {
    for event in [root -->][?:ProgressionEvent] {
        if event.learner_id == learner_id and event.roadmap_id == roadmap_id and event.roadmap_lesson_id == roadmap_lesson_id and event.event_type == event_type {
            return event;
        }
    }
    return None;
}

def _event_id(
    learner_id: str,
    roadmap_id: str,
    roadmap_lesson_id: str,
    event_type: ProgressionEventType
) -> str {
    return f"progression-event-{learner_id}-{roadmap_id}-{roadmap_lesson_id}-{event_type.value}";
}

def _create_event_once(
    learner: Learner,
    roadmap: Roadmap,
    draft: ProgressionEventDraft,
    timestamp: str
) -> ProgressionEvent | None {
    lesson_id = draft.lesson.id if draft.lesson is not None else "roadmap";
    existing = _find_event(learner.id, roadmap.id, lesson_id, draft.event_type);
    if existing is not None {
        return None;
    }
    event = (root ++> ProgressionEvent(
        id=_event_id(learner.id, roadmap.id, lesson_id, draft.event_type),
        learner_id=learner.id,
        roadmap_id=roadmap.id,
        roadmap_lesson_id=lesson_id,
        event_type=draft.event_type,
        source_type=draft.source_type,
        source_id=draft.source_id,
        message=draft.message,
        created_at=timestamp
    ))[0];
    learner +>:belongs_to:+> event;
    roadmap +>:belongs_to:+> event;
    if draft.lesson is not None {
        (draft.lesson as RoadmapLesson) +>:belongs_to:+> event;
    }
    return event;
}

def _event_view(event: ProgressionEvent) -> ProgressionEventView {
    return ProgressionEventView(
        id=event.id,
        learner_id=event.learner_id,
        roadmap_id=event.roadmap_id,
        roadmap_lesson_id=event.roadmap_lesson_id,
        event_type=event.event_type.value,
        source_type=event.source_type,
        source_id=event.source_id,
        message=event.message,
        created_at=event.created_at
    );
}

def _lesson_view(
    lesson: RoadmapLesson,
    progress: LessonProgress,
    unlock_reason: str = "",
    locked_reason: str = ""
) -> LessonProgressView {
    return LessonProgressView(
        roadmap_lesson_id=lesson.id,
        title=lesson.title,
        status=progress.status.value,
        unlock_reason=unlock_reason,
        locked_reason=locked_reason,
        completed_at=progress.completed_at,
        unlocked_at=progress.unlocked_at
    );
}

def _roadmap_progress_view(progress: RoadmapProgress) -> RoadmapProgressView {
    return RoadmapProgressView(
        id=progress.id,
        learner_id=progress.learner_id,
        roadmap_id=progress.roadmap_id,
        total_lessons=progress.total_lessons,
        completed_lessons=progress.completed_lessons,
        available_lessons=progress.available_lessons,
        locked_lessons=progress.locked_lessons,
        percent_complete=progress.percent_complete,
        current_roadmap_lesson_id=progress.current_roadmap_lesson_id,
        status=progress.status.value,
        updated_at=progress.updated_at
    );
}

def _passing_evaluation_for_lesson(
    learner_id: str,
    roadmap_id: str,
    roadmap_lesson_id: str
) -> SubmissionEvaluation | None {
    for challenge in [root -->][?:GeneratedChallenge] {
        if challenge.learner_id == learner_id and challenge.roadmap_id == roadmap_id and challenge.roadmap_lesson_id == roadmap_lesson_id {
            for evaluation in [challenge ->:evaluated:->][?:SubmissionEvaluation] {
                if evaluation.learner_id == learner_id and evaluation.challenge_id == challenge.id and evaluation.passed {
                    return evaluation;
                }
            }
            for submission in [challenge ->:submitted_for:->][?:ChallengeSubmission] {
                if submission.learner_id == learner_id and submission.challenge_id == challenge.id and submission.status == ChallengeSubmissionStatus.submitted {
                    for evaluation in [submission ->:evaluated:->][?:SubmissionEvaluation] {
                        if evaluation.learner_id == learner_id and evaluation.challenge_id == challenge.id and evaluation.passed {
                            return evaluation;
                        }
                    }
                }
            }
            for evaluation in [root -->][?:SubmissionEvaluation] {
                if evaluation.learner_id == learner_id and evaluation.challenge_id == challenge.id and evaluation.passed {
                    return evaluation;
                }
            }
        }
    }
    return None;
}

def _completion_errors(
    learner_id: str,
    roadmap_id: str,
    lesson: RoadmapLesson
) -> list[ProgressionError] {
    errors: list[ProgressionError] = [];
    if generated_lesson_for(learner_id, roadmap_id, lesson.id) is None {
        errors = errors + [
            ProgressionError(
                code="missing_generated_lesson",
                message="Open and read this lesson before marking it complete."
            )
        ];
    }
    if _passing_evaluation_for_lesson(learner_id, roadmap_id, lesson.id) is None {
        errors = errors + [
            ProgressionError(
                code="missing_passing_evaluation",
                message="Pass this lesson's coding challenge before unlocking the next lesson."
            )
        ];
    }
    return errors;
}

def _find_skill(skill_id: str) -> Skill | None {
    for skill in [root -->][?:Skill, id == skill_id] {
        return skill;
    }
    return None;
}

def _add_unique(values: list[str], value: str) -> list[str] {
    if value.strip() == "" or value in values {
        return values;
    }
    return values + [value];
}

def _prerequisite_skill_ids(lesson: RoadmapLesson) -> list[str] {
    ids: list[str] = [];
    for skill in [lesson ->:Prerequisite:->][?:Skill] {
        ids = _add_unique(ids, skill.id);
    }
    return ids;
}

def _skill_name(skill_id: str) -> str {
    skill = _find_skill(skill_id);
    if skill is not None {
        return (skill as Skill).name;
    }
    return skill_id;
}

def _mastery_block_reason(learner_id: str, lesson: RoadmapLesson) -> str {
    for skill_id in _prerequisite_skill_ids(lesson) {
        mastery = skill_mastery_for(learner_id, skill_id);
        score = 0;
        if mastery is not None {
            score = (mastery as SkillMastery).score;
        }
        if score < MINIMUM_PREREQUISITE_MASTERY {
            return f"Build more confidence in {_skill_name(skill_id)} before starting this lesson.";
        }
    }
    return "";
}

def _meets_mastery_requirements(learner_id: str, lesson: RoadmapLesson) -> bool {
    return _mastery_block_reason(learner_id, lesson) == "";
}

def _previous_lesson(lessons: list[RoadmapLesson], index: int) -> RoadmapLesson | None {
    if index <= 0 {
        return None;
    }
    return lessons[index - 1];
}

def _unlock_progress(progress: LessonProgress, lesson: RoadmapLesson, timestamp: str) {
    progress.status = LessonUnlockState.available;
    progress.unlocked_at = timestamp if progress.unlocked_at == "" else progress.unlocked_at;
    progress.updated_at = timestamp;
    lesson +>:unlocked:+> progress;
}

def _mark_completed(progress: LessonProgress, timestamp: str) {
    progress.status = LessonUnlockState.completed;
    progress.completed_at = timestamp if progress.completed_at == "" else progress.completed_at;
    progress.updated_at = timestamp;
}

def _locked_reason_for(
    learner_id: str,
    lessons: list[RoadmapLesson],
    index: int
) -> str {
    lesson = lessons[index];
    mastery_reason = _mastery_block_reason(learner_id, lesson);
    if mastery_reason != "" {
        return mastery_reason;
    }
    previous = _previous_lesson(lessons, index);
    if previous is not None {
        return f"Complete {previous.title} first.";
    }
    return "Complete the previous lesson first.";
}

def _update_roadmap_progress(
    progress: RoadmapProgress,
    lessons: list[RoadmapLesson],
    progress_records: list[LessonProgress],
    timestamp: str
) {
    total = len(lessons);
    completed_count = 0;
    available_count = 0;
    locked_count = 0;
    current_id = "";
    for record in progress_records {
        if record.status == LessonUnlockState.completed {
            completed_count += 1;
        } elif record.status == LessonUnlockState.available or record.status == LessonUnlockState.in_progress {
            available_count += 1;
            if current_id == "" {
                current_id = record.roadmap_lesson_id;
            }
        } else {
            locked_count += 1;
        }
    }
    progress.total_lessons = total;
    progress.completed_lessons = completed_count;
    progress.available_lessons = available_count;
    progress.locked_lessons = locked_count;
    progress.percent_complete = 0 if total == 0 else int((completed_count * 100) / total);
    progress.current_roadmap_lesson_id = current_id;
    progress.status = RoadmapProgressStatus.completed if total > 0 and completed_count == total else RoadmapProgressStatus.in_progress;
    progress.updated_at = timestamp;
}

def _message_for(result: ProgressionResult) -> str {
    if result.roadmap_completed {
        return "You completed this roadmap.";
    }
    if len(result.newly_unlocked_lessons) > 0 {
        return f"Your next lesson is {result.newly_unlocked_lessons[0].title}.";
    }
    if result.current_lesson is not None {
        return f"Your current lesson is {(result.current_lesson as LessonProgressView).title}.";
    }
    return "No lesson is currently available.";
}

walker unlock_next_lesson {
    has learner_id: str;
    has roadmap_id: str;
    has completed_roadmap_lesson_id: str = "";
    has source_type: str = "manual_check";
    has source_id: str = "";
    has errors: list[ProgressionError] = [];
    has reports: list[ProgressionResult] = [];

    can unlock with Root entry {
        timestamp = _current_timestamp();
        if self.learner_id.strip() == "" {
            self.errors = self.errors + [ProgressionError(code="missing_learner", message="Log in again to update progression.")];
            return;
        }
        if self.roadmap_id.strip() == "" {
            self.errors = self.errors + [ProgressionError(code="missing_roadmap", message="No roadmap id was provided.")];
            return;
        }
        if self.source_type not in ["lesson_completion", "submission_evaluation", "manual_check"] {
            self.errors = self.errors + [ProgressionError(code="unsupported_source_type", message="Progression source must be lesson_completion, submission_evaluation, or manual_check.")];
            return;
        }

        learner = _find_learner(self.learner_id);
        if learner is None {
            self.errors = self.errors + [ProgressionError(code="missing_learner", message="Learner does not exist.")];
            return;
        }
        roadmap = _find_roadmap(self.roadmap_id);
        if roadmap is None {
            self.errors = self.errors + [ProgressionError(code="missing_roadmap", message="Roadmap does not exist.")];
            return;
        }
        if roadmap.learner_id != self.learner_id {
            self.errors = self.errors + [ProgressionError(code="roadmap_learner_mismatch", message="Roadmap does not belong to this learner.")];
            return;
        }

        lessons = _ordered_lessons(roadmap);
        if len(lessons) == 0 {
            self.errors = self.errors + [ProgressionError(code="roadmap_has_no_lessons", message="Roadmap has no lessons to unlock.")];
            return;
        }
        self.errors = _roadmap_order_errors(roadmap, lessons);
        if len(self.errors) > 0 {
            return;
        }

        progress_records: list[LessonProgress] = [];
        existing_count = 0;
        for lesson in lessons {
            existing = _find_lesson_progress(self.learner_id, roadmap.id, lesson.id);
            if existing is not None {
                existing_count += 1;
            }
        }

        created_events: list[ProgressionEventView] = [];
        first_progress_setup = existing_count == 0;
        for index in range(0, len(lessons)) {
            initial_status = LessonUnlockState.available if first_progress_setup and index == 0 else LessonUnlockState.locked;
            progress_records = progress_records + [_get_or_create_lesson_progress(learner, roadmap, lessons[index], initial_status, timestamp)];
        }
        roadmap_progress = _get_or_create_roadmap_progress(learner, roadmap, timestamp);

        if first_progress_setup {
            started = _create_event_once(
                learner,
                roadmap,
                ProgressionEventDraft(
                    event_type=ProgressionEventType.roadmap_started,
                    message="Roadmap started and the first lesson is available.",
                    source_type=self.source_type,
                    source_id=self.source_id
                ),
                timestamp
            );
            if started is not None {
                created_events = created_events + [_event_view(started as ProgressionEvent)];
            }
            unlocked_event = _create_event_once(
                learner,
                roadmap,
                ProgressionEventDraft(
                    event_type=ProgressionEventType.lesson_unlocked,
                    message="First lesson unlocked.",
                    lesson=lessons[0],
                    source_type=self.source_type,
                    source_id=self.source_id
                ),
                timestamp
            );
            if unlocked_event is not None {
                created_events = created_events + [_event_view(unlocked_event as ProgressionEvent)];
            }
        }

        if self.completed_roadmap_lesson_id.strip() != "" {
            completed_lesson = _find_lesson(lessons, self.completed_roadmap_lesson_id);
            if completed_lesson is None {
                self.errors = self.errors + [ProgressionError(code="completed_lesson_not_found", message="Completed lesson does not belong to this roadmap.")];
                return;
            }
            completed_progress = _find_lesson_progress(self.learner_id, roadmap.id, self.completed_roadmap_lesson_id) as LessonProgress;
            if completed_progress.status != LessonUnlockState.completed {
                completion_errors = _completion_errors(self.learner_id, roadmap.id, completed_lesson as RoadmapLesson);
                if len(completion_errors) > 0 {
                    self.errors = completion_errors;
                    return;
                }
                _mark_completed(completed_progress, timestamp);
                learner +>:completed:+> completed_lesson;
                completed_event = _create_event_once(
                    learner,
                    roadmap,
                    ProgressionEventDraft(
                        event_type=ProgressionEventType.lesson_completed,
                        message=f"{(completed_lesson as RoadmapLesson).title} completed.",
                        lesson=completed_lesson,
                        source_type=self.source_type,
                        source_id=self.source_id
                    ),
                    timestamp
                );
                if completed_event is not None {
                    created_events = created_events + [_event_view(completed_event as ProgressionEvent)];
                }
            }
        }

        newly_unlocked: list[LessonProgressView] = [];
        for index in range(0, len(lessons)) {
            lesson = lessons[index];
            progress = progress_records[index];
            if progress.status == LessonUnlockState.locked {
                previous = _previous_lesson(lessons, index);
                previous_complete = previous is None;
                if previous is not None {
                    previous_progress = _find_lesson_progress(self.learner_id, roadmap.id, (previous as RoadmapLesson).id);
                    previous_complete = previous_progress is not None and (previous_progress as LessonProgress).status == LessonUnlockState.completed;
                }
                if previous_complete and _meets_mastery_requirements(self.learner_id, lesson) {
                    _unlock_progress(progress, lesson, timestamp);
                    unlock_reason = "Previous lesson completed and required skills are developing or higher.";
                    newly_unlocked = newly_unlocked + [_lesson_view(lesson, progress, unlock_reason)];
                    unlock_event = _create_event_once(
                        learner,
                        roadmap,
                        ProgressionEventDraft(
                            event_type=ProgressionEventType.lesson_unlocked,
                            message=unlock_reason,
                            lesson=lesson,
                            source_type=self.source_type,
                            source_id=self.source_id
                        ),
                        timestamp
                    );
                    if unlock_event is not None {
                        created_events = created_events + [_event_view(unlock_event as ProgressionEvent)];
                    }
                    break;
                }
            }
        }

        _update_roadmap_progress(roadmap_progress, lessons, progress_records, timestamp);

        completed_views: list[LessonProgressView] = [];
        locked_views: list[LessonProgressView] = [];
        current_view: LessonProgressView | None = None;
        for index in range(0, len(lessons)) {
            lesson = lessons[index];
            progress = progress_records[index];
            if progress.status == LessonUnlockState.completed {
                completed_views = completed_views + [_lesson_view(lesson, progress)];
            } elif progress.status == LessonUnlockState.locked {
                locked_views = locked_views + [_lesson_view(lesson, progress, "", _locked_reason_for(self.learner_id, lessons, index))];
            } elif current_view is None {
                current_view = _lesson_view(lesson, progress);
            }
        }

        roadmap_completed = roadmap_progress.status == RoadmapProgressStatus.completed;
        if roadmap_completed {
            roadmap.status = RoadmapStatus.completed;
            completed_event = _create_event_once(
                learner,
                roadmap,
                ProgressionEventDraft(
                    event_type=ProgressionEventType.roadmap_completed,
                    message="Roadmap completed.",
                    source_type=self.source_type,
                    source_id=self.source_id
                ),
                timestamp
            );
            if completed_event is not None {
                created_events = created_events + [_event_view(completed_event as ProgressionEvent)];
            }
        }

        result = ProgressionResult(
            learner_id=self.learner_id,
            roadmap_id=roadmap.id,
            current_lesson=current_view,
            newly_unlocked_lessons=newly_unlocked,
            locked_lessons=locked_views,
            completed_lessons=completed_views,
            roadmap_completed=roadmap_completed,
            roadmap_progress=_roadmap_progress_view(roadmap_progress),
            events=created_events,
            message=""
        );
        result.message = _message_for(result);
        report result;
    }
}
