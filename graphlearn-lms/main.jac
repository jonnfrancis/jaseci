"""graphlearn-lms - Entry Point.

Combines server-side endpoints with the client-side UI.
"""

import type from lib.domain.index { Learner }
import from services.challenge { open_challenge, start_challenge, submit_challenge_solution }
import from services.course_management {
    archive_lecturer_course, create_lecturer_course, load_lecturer_course,
    load_lecturer_courses, get_lecturer_course_dashboard, restore_lecturer_course,
    save_lecturer_configuration, save_lecturer_course,
    load_course_source_document, load_course_source_workspace,
    retry_lecturer_course_document, cancel_lecturer_course_document,
    upload_lecturer_course_document, generate_course_blueprint,
    get_course_blueprint_generation_status, retry_course_blueprint_generation,
    dispatch_course_blueprint_generation,
    get_lecturer_blueprint_review, update_blueprint_entity, approve_course_blueprint,
    get_course_publication_readiness, publish_approved_course_version,
    create_course_draft_version, rollback_course_publication,
    list_course_publication_history, audit_course_publication_state,
    get_course_build_workflow, get_learner_integration_handoff
}
import from services.authorization { list_my_authorized_tracks, migrate_my_lecturer_track_ownership }
import from services.admin { admin_approve_lecturer_onboarding, admin_grant_course_reviewer, admin_revoke_course_reviewer, admin_set_lecturer_capabilities, bootstrap_application_admin_for_development, list_pending_lecturer_onboarding }
import from services.assessment_journey { generate_roadmap_for_journey }
import from services.dashboard { load_dashboard }
import from services.lesson { open_lesson }
import from services.learning_track { execute_programming_track_migration, get_learning_track, list_learning_tracks, migrate_learning_tracks, resolve_legacy_learning_track, rollback_programming_track_migration_v1, supported_programming_tracks }
import from services.identity {
    activate_my_pending_lecturer_for_development, authorize_my_application_admin_management, get_current_identity,
    get_my_lecturer_profile, migrate_current_learner_roles,
    request_lecturer_role, resolve_current_learner,
    update_my_lecturer_profile
}
import from services.roadmap { load_roadmap }
import from services.skill_map { load_skill_map }
import from services.system { list_registered_functions }
import from services.tutor { load_tutor_recommendation }
import from walkers.evaluate_assessment { evaluate_assessment }
import from walkers.evaluate_submission { evaluate_submission }
import from walkers.generate_challenge { generate_challenge }
import from walkers.generate_lesson { generate_lesson }
import from walkers.generate_roadmap { generate_roadmap }
import from walkers.get_dashboard { get_dashboard }
import from walkers.get_skill_map { get_skill_map }
import from walkers.initialize_assessment { initialize_assessment }
import from walkers.recommend_next_action { recommend_next_action }
import from walkers.submit_challenge { submit_challenge }
import from walkers.submit_assessment { submit_assessment }
import from walkers.unlock_next_lesson { unlock_next_lesson }
import from walkers.update_mastery { update_mastery }
import from walkers.course_track_management {
    archive_course_track, create_course_track, duplicate_course_track,
    get_lecturer_course, list_lecturer_courses, restore_course_track,
    update_course_track, update_course_track_configuration
}
import from walkers.lecturer_course_dashboard { get_lecturer_course_dashboard as lecturer_course_dashboard_walker }
import from walkers.course_document_upload { upload_course_document }
import from walkers.course_document_processing { cancel_course_document_processing, get_course_document_processing_status, retry_course_document_processing }

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return <ClientApp/>;
    }
}
