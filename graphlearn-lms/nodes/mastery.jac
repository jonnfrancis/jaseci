"""Mastery domain node."""

type MasteryScore = Literal[
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
    20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
    30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
    40, 41, 42, 43, 44, 45, 46, 47, 48, 49,
    50, 51, 52, 53, 54, 55, 56, 57, 58, 59,
    60, 61, 62, 63, 64, 65, 66, 67, 68, 69,
    70, 71, 72, 73, 74, 75, 76, 77, 78, 79,
    80, 81, 82, 83, 84, 85, 86, 87, 88, 89,
    90, 91, 92, 93, 94, 95, 96, 97, 98, 99,
    100
];

node Mastery {
    has learnerId: str;
    has skillId: str;
    has score: MasteryScore;
    has updatedAt: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}

enum MasteryLevel: str {
    beginner = "beginner",
    developing = "developing",
    proficient = "proficient",
    mastered = "mastered"
}

enum MasterySourceType: str {
    assessment_evaluation = "assessment_evaluation",
    submission_evaluation = "submission_evaluation"
}

obj UpdatedSkillMasteryRecord {
    has skill_id: str;
    has previous_score: int;
    has new_score: int;
    has delta: int;
    has mastery_level: str;
    has evidence_count: int;
}

node SkillMastery {
    has id: str;
    has learner_id: str;
    has skill_id: str;
    has score: int;
    has level: MasteryLevel;
    has evidence_count: int;
    has last_source_type: str;
    has last_source_id: str;
    has updated_at: str;
    has created_at: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}

node MasteryEvidence {
    has id: str;
    has learner_id: str;
    has skill_id: str;
    has source_type: MasterySourceType;
    has source_id: str;
    has signal_score: float;
    has confidence: float;
    has weighted_score: float;
    has evidence_summary: str;
    has created_at: str;
    has track_id: str | None = None;
    has track_version_id: str | None = None;
}

node MasteryUpdateResult {
    has id: str;
    has learner_id: str;
    has source_type: MasterySourceType;
    has source_id: str;
    has updated_at: str;
    has updated_skills: list[UpdatedSkillMasteryRecord] = [];
    has track_id: str | None = None;
    has track_version_id: str | None = None;
    has mastery_id: str | None = None;
    has enrollment_id: str | None = None;
    has confidence: float = 0.0;
    has evidence_count: int = 0;
    has status: str = "NOT_STARTED";
    has last_evidence_at: str | None = None;
}
