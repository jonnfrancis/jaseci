"""Immutable validation-report history and batched issue persistence."""
import from edges.domain_edges { HAS_VALIDATION_ISSUE, HAS_VALIDATION_REPORT }
import from nodes.curriculum { BlueprintValidationIssue, BlueprintValidationReport, BlueprintValidationStatus, CourseBlueprint }

obj BlueprintValidationRepository {
    def list_reports(blueprint: CourseBlueprint) -> list[BlueprintValidationReport] { reports: list[BlueprintValidationReport] = [blueprint ->:HAS_VALIDATION_REPORT:->[?:BlueprintValidationReport]]; reports.sort(key=lambda item: BlueprintValidationReport : item.created_at); return reports; }
    def find_matching_report(blueprint: CourseBlueprint, identity: str) -> BlueprintValidationReport | None { for item in self.list_reports(blueprint) { if item.validation_identity == identity and item.status in [BlueprintValidationStatus.VALID, BlueprintValidationStatus.VALID_WITH_WARNINGS, BlueprintValidationStatus.INVALID] { return item; } } return None; }
    def find_latest_report(blueprint: CourseBlueprint) -> BlueprintValidationReport | None { reports = self.list_reports(blueprint); for index in range(len(reports) - 1, -1, -1) { if reports[index].is_latest { return reports[index]; } } return reports[len(reports) - 1] if len(reports) > 0 else None; }
    def save_report(blueprint: CourseBlueprint, item: BlueprintValidationReport) -> bool { if item.blueprint_id != blueprint.blueprint_id or item.track_id != blueprint.track_id or item.track_version_id != blueprint.track_version_id { return False; } for old in self.list_reports(blueprint) { old.is_latest = False; } blueprint +>:HAS_VALIDATION_REPORT:+> item; item.is_latest = True; return True; }
    def save_issues(item: BlueprintValidationReport, issues: list[BlueprintValidationIssue]) { for issue in issues { item +>:HAS_VALIDATION_ISSUE:+> issue; } }
    def list_issues(item: BlueprintValidationReport) -> list[BlueprintValidationIssue] { return [item ->:HAS_VALIDATION_ISSUE:->[?:BlueprintValidationIssue]]; }
}
