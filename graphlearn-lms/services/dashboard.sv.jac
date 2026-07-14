"""Dashboard read service for the client UI."""

import from walkers.get_dashboard {
    DashboardChallengeSummary as WalkerDashboardChallengeSummary,
    DashboardCurrentLesson as WalkerDashboardCurrentLesson,
    DashboardError,
    DashboardLearnerSummary as WalkerDashboardLearnerSummary,
    DashboardLessonSummary as WalkerDashboardLessonSummary,
    DashboardMasterySummary as WalkerDashboardMasterySummary,
    DashboardRecentActivity as WalkerDashboardRecentActivity,
    DashboardRoadmapProgress as WalkerDashboardRoadmapProgress,
    DashboardRoadmapSummary as WalkerDashboardRoadmapSummary,
    DashboardSkillSummary as WalkerDashboardSkillSummary,
    DashboardView as WalkerDashboardView,
    get_dashboard
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

obj DashboardLoadState {
    has status: str;
    has dashboard: DashboardView | None = None;
    has message: str = "";
}

def _first_error_message(errors: list[DashboardError]) -> str {
    if len(errors) == 0 {
        return "Dashboard could not be loaded.";
    }
    return str(errors[0].message);
}

def _first_error_code(errors: list[DashboardError]) -> str {
    if len(errors) == 0 {
        return "failed";
    }
    return str(errors[0].code);
}

def _learner_to_view(summary: WalkerDashboardLearnerSummary) -> DashboardLearnerSummary {
    return DashboardLearnerSummary(learner_id=summary.learner_id, name=summary.name);
}

def _roadmap_to_view(summary: WalkerDashboardRoadmapSummary) -> DashboardRoadmapSummary {
    return DashboardRoadmapSummary(
        roadmap_id=summary.roadmap_id,
        language=summary.language,
        title=summary.title,
        status=summary.status
    );
}

def _progress_to_view(progress: WalkerDashboardRoadmapProgress) -> DashboardRoadmapProgress {
    return DashboardRoadmapProgress(
        total_lessons=progress.total_lessons,
        completed_lessons=progress.completed_lessons,
        available_lessons=progress.available_lessons,
        locked_lessons=progress.locked_lessons,
        percent_complete=progress.percent_complete,
        current_roadmap_lesson_id=progress.current_roadmap_lesson_id
    );
}

def _skill_to_view(skill: WalkerDashboardSkillSummary) -> DashboardSkillSummary {
    return DashboardSkillSummary(
        skill_id=skill.skill_id,
        name=skill.name,
        score=skill.score,
        level=skill.level
    );
}

def _mastery_to_view(summary: WalkerDashboardMasterySummary) -> DashboardMasterySummary {
    strongest: list[DashboardSkillSummary] = [];
    weakest: list[DashboardSkillSummary] = [];
    for skill in summary.strongest_skills {
        strongest = strongest + [_skill_to_view(skill)];
    }
    for skill in summary.weakest_skills {
        weakest = weakest + [_skill_to_view(skill)];
    }
    return DashboardMasterySummary(
        average_mastery=summary.average_mastery,
        mastered_count=summary.mastered_count,
        proficient_count=summary.proficient_count,
        developing_count=summary.developing_count,
        beginner_count=summary.beginner_count,
        strongest_skills=strongest,
        weakest_skills=weakest
    );
}

def _lesson_to_view(summary: WalkerDashboardLessonSummary) -> DashboardLessonSummary {
    return DashboardLessonSummary(
        total_lessons=summary.total_lessons,
        generated_lessons=summary.generated_lessons,
        pending_lessons=summary.pending_lessons,
        completed_lessons=summary.completed_lessons,
        available_lessons=summary.available_lessons,
        locked_lessons=summary.locked_lessons,
        in_progress_lessons=summary.in_progress_lessons
    );
}

def _challenge_to_view(summary: WalkerDashboardChallengeSummary) -> DashboardChallengeSummary {
    return DashboardChallengeSummary(
        generated_challenges=summary.generated_challenges,
        draft_submissions=summary.draft_submissions,
        submitted_challenges=summary.submitted_challenges,
        evaluated_submissions=summary.evaluated_submissions,
        passed_challenges=summary.passed_challenges,
        failed_challenges=summary.failed_challenges
    );
}

def _current_lesson_to_view(lesson: WalkerDashboardCurrentLesson) -> DashboardCurrentLesson {
    return DashboardCurrentLesson(
        roadmap_lesson_id=lesson.roadmap_lesson_id,
        title=lesson.title,
        summary=lesson.summary,
        week_number=lesson.week_number,
        order_index=lesson.order_index,
        status=lesson.status,
        generation_status=lesson.generation_status,
        generated_lesson_id=lesson.generated_lesson_id,
        challenge_id=lesson.challenge_id
    );
}

def _activity_to_view(activity: WalkerDashboardRecentActivity) -> DashboardRecentActivity {
    return DashboardRecentActivity(
        type=activity.type,
        title=activity.title,
        description=activity.description,
        timestamp=activity.timestamp,
        related_entity_id=activity.related_entity_id
    );
}

def _dashboard_to_view(raw: WalkerDashboardView) -> DashboardView {
    recent: list[DashboardRecentActivity] = [];
    for activity in raw.recent_activity {
        recent = recent + [_activity_to_view(activity)];
    }
    return DashboardView(
        learner=_learner_to_view(raw.learner),
        active_roadmap=_roadmap_to_view(raw.active_roadmap as WalkerDashboardRoadmapSummary) if raw.active_roadmap is not None else None,
        roadmap_progress=_progress_to_view(raw.roadmap_progress),
        mastery_summary=_mastery_to_view(raw.mastery_summary),
        lesson_summary=_lesson_to_view(raw.lesson_summary),
        challenge_summary=_challenge_to_view(raw.challenge_summary),
        current_lesson=_current_lesson_to_view(raw.current_lesson as WalkerDashboardCurrentLesson) if raw.current_lesson is not None else None,
        recent_activity=recent,
        dashboard_state=raw.dashboard_state
    );
}

def:priv load_dashboard(
    learner_id: str,
    language: str = "",
    roadmap_id: str = ""
) -> DashboardLoadState {
    if learner_id.strip() == "" {
        return DashboardLoadState(
            status="missing_learner",
            message="Log in again to load your dashboard."
        );
    }

    result = root spawn get_dashboard(
        learner_id=learner_id,
        language=language,
        roadmap_id=roadmap_id
    );
    if len(result.errors) > 0 {
        return DashboardLoadState(
            status=_first_error_code(result.errors),
            message=_first_error_message(result.errors)
        );
    }
    if len(result.reports) == 0 {
        return DashboardLoadState(
            status="malformed",
            message="The dashboard response was empty."
        );
    }

    return DashboardLoadState(status="ready", dashboard=_dashboard_to_view(result.reports[0]));
}
