"""Persistence for mutable review sessions and immutable review history."""
import from edges.domain_edges { HAS_BLUEPRINT_APPROVAL, HAS_BLUEPRINT_ISSUE_RESOLUTION, HAS_BLUEPRINT_REVIEW_CHANGE, HAS_BLUEPRINT_REVIEW_SESSION }
import from nodes.curriculum { BlueprintApproval, BlueprintIssueResolution, BlueprintReviewChange, BlueprintReviewSession, CourseBlueprint }

obj BlueprintReviewRepository {
    def sessions(blueprint: CourseBlueprint) -> list[BlueprintReviewSession] { return [blueprint ->:HAS_BLUEPRINT_REVIEW_SESSION:->[?:BlueprintReviewSession]]; }
    def current(blueprint: CourseBlueprint) -> BlueprintReviewSession | None { for item in self.sessions(blueprint) { if str(item.status) != "SUPERSEDED" { return item; } } return None; }
    def save_session(blueprint: CourseBlueprint, item: BlueprintReviewSession) -> bool { if item.blueprint_id != blueprint.blueprint_id or item.track_version_id != blueprint.track_version_id { return False; } blueprint +>:HAS_BLUEPRINT_REVIEW_SESSION:+> item; return True; }
    def changes(item: BlueprintReviewSession) -> list[BlueprintReviewChange] { values: list[BlueprintReviewChange] = [item ->:HAS_BLUEPRINT_REVIEW_CHANGE:->[?:BlueprintReviewChange]]; values.sort(key=lambda value: BlueprintReviewChange : value.created_at); return values; }
    def save_change(item: BlueprintReviewSession, change: BlueprintReviewChange) { item +>:HAS_BLUEPRINT_REVIEW_CHANGE:+> change; }
    def find_idempotent_change(item: BlueprintReviewSession, key: str) -> BlueprintReviewChange | None { for change in self.changes(item) { if change.idempotency_key == key { return change; } } return None; }
    def resolutions(item: BlueprintReviewSession) -> list[BlueprintIssueResolution] { return [item ->:HAS_BLUEPRINT_ISSUE_RESOLUTION:->[?:BlueprintIssueResolution]]; }
    def save_resolution(item: BlueprintReviewSession, resolution: BlueprintIssueResolution) { item +>:HAS_BLUEPRINT_ISSUE_RESOLUTION:+> resolution; }
    def approvals(item: BlueprintReviewSession) -> list[BlueprintApproval] { return [item ->:HAS_BLUEPRINT_APPROVAL:->[?:BlueprintApproval]]; }
    def save_approval(item: BlueprintReviewSession, approval: BlueprintApproval) { item +>:HAS_BLUEPRINT_APPROVAL:+> approval; }
}
