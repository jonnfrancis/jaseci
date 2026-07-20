"""Authorization boundary for lecturer blueprint review operations."""
import from lib.authorization.actor { resolve_authorization_actor }
import from lib.authorization.policy { AuthorizationPolicyService, public_error_code }
import from lib.authorization.repositories { version_resource_context }
import from lib.blueprint_review.service { LecturerBlueprintReviewService }
import from lib.course_document.processing_workers { DocumentProcessingWorkerService }
import from lib.course_document.repositories { CourseDocumentRepository }
import from lib.learning_track.repositories { repository_find_track, repository_find_version }
import from nodes.authorization { AuthorizationActor, AuthorizationDecisionType, LecturerPermission }
import from nodes.curriculum { BlueprintApproval, BlueprintApprovalRequest, BlueprintEntityPatchRequest, LecturerBlueprintReviewView }
import from nodes.learning_track { LearningTrack }

def _actor(track_id: str, track_version_id: str, permission: LecturerPermission) -> AuthorizationActor { actor = resolve_authorization_actor(); resource = version_resource_context(track_id, track_version_id, actor.lecturer_id); if resource is None { raise PermissionError("BLUEPRINT_REVIEW_NOT_AUTHORIZED"); } decision = AuthorizationPolicyService().authorize_lecturer_action(actor, permission, resource); if decision.decision == AuthorizationDecisionType.DENY { raise PermissionError(public_error_code(decision)); } return actor; }
def get_authorized_lecturer_blueprint_review(track_id: str, track_version_id: str) -> LecturerBlueprintReviewView { actor = _actor(track_id, track_version_id, LecturerPermission.VIEW_BLUEPRINT); track = repository_find_track(track_id); version = repository_find_version(track as LearningTrack, track_version_id) if track is not None else None; document = CourseDocumentRepository().find_active_for_version(version) if version is not None else None; if document is not None { _ = DocumentProcessingWorkerService().run_blueprint_validation(document, "blueprint-review-recovery:" + actor.user_id); } return LecturerBlueprintReviewService().get_review(track_id, track_version_id, actor.lecturer_id or actor.user_id); }
def update_authorized_blueprint_entity(track_id: str, track_version_id: str, request: BlueprintEntityPatchRequest) -> LecturerBlueprintReviewView { actor = _actor(track_id, track_version_id, LecturerPermission.EDIT_BLUEPRINT); return LecturerBlueprintReviewService().update_entity(track_id, track_version_id, actor.user_id, request); }
def approve_authorized_course_blueprint(track_id: str, track_version_id: str, request: BlueprintApprovalRequest) -> BlueprintApproval { actor = _actor(track_id, track_version_id, LecturerPermission.APPROVE_BLUEPRINT); return LecturerBlueprintReviewService().approve(track_id, track_version_id, actor.user_id, request); }
