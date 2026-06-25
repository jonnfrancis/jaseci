"""Assessment domain node."""

enum AssessmentStatus: str {
    draft = "draft",
    active = "active",
    completed = "completed"
}

type AssessmentQuestion = dict[str, str];

node Assessment {
    has id: str;
    has title: str;
    has description: str;
    has status: AssessmentStatus;
    has questions: list[AssessmentQuestion];
    has createdAt: str;
}
