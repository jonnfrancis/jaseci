"""Roadmap domain node."""

node Roadmap {
    has id: str;
    has learnerId: str;
    has title: str;
    has lessonIds: list[str];
    has createdAt: str;
}
