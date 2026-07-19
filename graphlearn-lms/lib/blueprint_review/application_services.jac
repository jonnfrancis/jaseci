"""Authorization boundary for lecturer blueprint review operations."""
import from lib.authorization.actor { resolve_authorization_actor }
import from lib.authorization.policy { AuthorizationPolicyService, public_error_code }
import from lib.authorization.repositories { version_resource_context }
import from lib.blueprint_review.service { LecturerBlueprintReviewService }
import from nodes.authorization { AuthorizationActor, AuthorizationDecisionType, LecturerPermission }
import from nodes.curriculum { BlueprintApproval, BlueprintApprovalRequest, BlueprintEntityPatchRequest, LecturerBlueprintReviewView }

def _actor(track_id: str, track_version_id: str, permission: LecturerPermission) -> AuthorizationActor { actor = resolve_authorization_actor(); resource = version_resource_context(track_id, track_version_id, actor.lecturer_id); if resource is None { raise PermissionError("BLUEPRINT_REVIEW_NOT_AUTHORIZED"); } decision = AuthorizationPolicyService().authorize_lecturer_action(actor, permission, resource); if decision.decision == AuthorizationDecisionType.DENY { raise PermissionError(public_error_code(decision)); } return actor; }
def get_authorized_lecturer_blueprint_review(track_id: str, track_version_id: str) -> LecturerBlueprintReviewView { actor = _actor(track_id, track_version_id, LecturerPermission.VIEW_BLUEPRINT); return LecturerBlueprintReviewService().get_review(track_id, track_version_id, actor.lecturer_id or actor.user_id); }
def update_authorized_blueprint_entity(track_id: str, track_version_id: str, request: BlueprintEntityPatchRequest) -> LecturerBlueprintReviewView { actor = _actor(track_id, track_version_id, LecturerPermission.EDIT_BLUEPRINT); return LecturerBlueprintReviewService().update_entity(track_id, track_version_id, actor.user_id, request); }
def approve_authorized_course_blueprint(track_id: str, track_version_id: str, request: BlueprintApprovalRequest) -> BlueprintApproval { actor = _actor(track_id, track_version_id, LecturerPermission.APPROVE_BLUEPRINT); return LecturerBlueprintReviewService().approve(track_id, track_version_id, actor.user_id, request); }
