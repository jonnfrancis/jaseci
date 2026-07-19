"""Safe client-facing course build error mapping."""
obj CourseBuildErrorView { has message: str; has action_label: str; }

def:pub map_course_build_error(code: str | None) -> CourseBuildErrorView {
    current = code or "";
    messages: dict[str, list[str]] = {
        "BLUEPRINT_SOURCE_NOT_READY": ["Source processing must finish before generation.", "View source"],
        "BLUEPRINT_GENERATION_ALREADY_RUNNING": ["Blueprint generation is already running.", "View progress"],
        "BLUEPRINT_REVIEW_REVISION_CONFLICT": ["This blueprint changed in another session.", "Refresh review"],
        "BLUEPRINT_REVIEW_APPROVAL_BLOCKED": ["Resolve blocking validation issues before approval.", "View issues"],
        "COURSE_PUBLICATION_APPROVAL_STALE": ["The course changed after approval. Approve the latest revision again.", "Return to review"],
        "COURSE_PUBLICATION_SOURCE_STALE": ["The approved source no longer matches this version.", "View source"],
        "COURSE_PUBLICATION_VERSION_CONFLICT": ["Publication readiness changed. Refresh before publishing.", "Refresh readiness"],
        "COURSE_VERSION_IMMUTABLE": ["Published curriculum cannot be edited. Create a new version.", "Create version"],
    };
    if current in messages { value = messages[current]; return CourseBuildErrorView(message=value[0], action_label=value[1]); }
    return CourseBuildErrorView(message="This course operation could not be completed safely. Refresh the current state and try again.", action_label="Refresh");
}
def:pub safe_course_build_message(code: str | None) -> str { return map_course_build_error(code).message; }
