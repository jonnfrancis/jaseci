"""Compatibility discovery endpoints for the Scale server."""

import from http { HTTPMethod }


@restspec(method=HTTPMethod.GET, path="/functions")
def:pub list_registered_functions() -> list[str] {
    return [
        "admin_approve_lecturer_onboarding",
        "admin_grant_course_reviewer",
        "admin_revoke_course_reviewer",
        "admin_set_lecturer_capabilities",
        "authorize_my_application_admin_management",
        "bootstrap_application_admin_for_development",
        "execute_programming_track_migration",
        "generate_roadmap_for_journey",
        "get_learning_track",
        "list_learning_tracks",
        "load_assessment",
        "load_assessment_journey",
        "load_dashboard",
        "load_roadmap",
        "load_skill_map",
        "load_tutor_recommendation",
        "list_pending_lecturer_onboarding",
        "migrate_learning_tracks",
        "open_challenge",
        "open_lesson",
        "resolve_current_learner",
        "resolve_legacy_learning_track",
        "retry_assessment_evaluation",
        "rollback_programming_track_migration_v1",
        "start_assessment_journey",
        "start_challenge",
        "submit_and_evaluate_assessment",
        "submit_assessment_responses",
        "submit_challenge_solution",
        "supported_language_tracks",
        "supported_programming_tracks"
    ];
}
