"""Domain graph edge definitions."""

import from nodes.authorization { TrackAccessRole }

# Represents Skill -> Skill and Lesson -> Lesson.
edge Prerequisite {}

# Represents Lesson -> Skill and Challenge -> Skill.
edge teaches {}

# Represents Learner -> Skill.
edge mastered {}

# Represents Learner -> MasteryEvidence, MasteryEvidence -> AssessmentEvaluation,
# and MasteryEvidence -> SubmissionEvaluation.
edge evidenced_by {}

# Represents Learner -> Roadmap and Roadmap -> Lesson.
edge assigned {}

# Represents Roadmap -> RoadmapWeek, RoadmapWeek -> RoadmapLesson, and RoadmapWeek -> RoadmapMilestone.
edge contains {}

# Represents RoadmapLesson -> Skill.
edge targets {}

# Represents GeneratedChallenge -> Skill.
edge evaluates {}

# Represents Learner -> SubmissionEvaluation, GeneratedChallenge -> SubmissionEvaluation,
# and ChallengeSubmission -> SubmissionEvaluation.
edge evaluated {}

# Represents SubmissionEvaluation -> SubmissionSkillSignal.
edge signals {}

# Represents Learner -> ChallengeSubmission.
edge attempted {}

# Represents ChallengeSubmission -> GeneratedChallenge and GeneratedChallenge -> ChallengeSubmission.
edge submitted_for {}

# Represents RoadmapMilestone -> Skill.
edge requires {}

# Represents Learner -> Lesson, Learner -> Challenge, and Learner -> Assessment.
edge completed {}

# Represents Learner -> LessonProgress and Learner -> RoadmapProgress.
edge progresses {}

# Represents Roadmap -> LessonProgress, RoadmapLesson -> LessonProgress,
# and Roadmap -> RoadmapProgress.
edge tracks {}

# Represents RoadmapLesson -> LessonProgress when a lesson becomes available.
edge unlocked {}

# Represents ProgressionEvent ownership/context links.
edge belongs_to {}

# Shared catalogue and versioned curriculum relationships.
edge HAS_LEARNING_TRACK {
    has created_at: str;
}

edge HAS_TRACK_VERSION {
    has version_number: int;
    has created_at: str;
}

edge HAS_TRACK_CONFIGURATION {}

# Feature 32 graph-native curriculum and enrollment relationships.
edge HAS_CATALOGUE {}
edge OWNS_TRACK { has granted_at: str; }
edge HAS_TRACK_ACCESS {
    has access_role: TrackAccessRole;
    has granted_by: str;
    has granted_at: str;
    has expires_at: str | None = None;
    has revoked_at: str | None = None;
}
edge CONTAINS_MODULE { has order_index: int; }
edge CONTAINS_SKILL { has order_index: int | None = None; has primary: bool = True; has graph_generation_id: str | None = None; }
edge MODULE_CONTAINS_SKILL { has order_index: int; }
edge PREREQUISITE {
    has strength: float = 1.0;
    has required_mastery: float = 0.80;
    has relation_type: str = "REQUIRED";
    has rationale: str | None = None;
    has confidence: str | None = None;
    has source_blueprint_prerequisite_id: str | None = None;
    has evidence_json: str = "[]";
    has graph_generation_id: str | None = None;
    has created_at: str = "";
}
edge HAS_LESSON_TEMPLATE { has order_index: int | None = None; }
edge MODULE_HAS_LESSON { has order_index: int; }
edge TEACHES_SKILL {
    has coverage_weight: float = 1.0;
    has role: str = "PRIMARY";
}
edge HAS_ACTIVITY_TEMPLATE { has order_index: int | None = None; }
edge LESSON_HAS_ACTIVITY {
    has order_index: int;
    has required: bool = True;
}
edge ASSESSES_SKILL { has assessment_weight: float = 1.0; }
edge HAS_SOURCE_DOCUMENT {
    has attached_at: str;
    has attached_by: str;
    has order_index: int = 0;
}
edge HAS_STORAGE_ORPHAN {}
edge HAS_EXTRACTION { has created_at: str; }
edge HAS_EXTRACTION_BLOCK { has order_index: int; }
edge HAS_CHUNK_SET { has created_at: str; }
edge HAS_CONTENT_CHUNK { has order_index: int; }
edge HAS_PROCESSING_JOB { has stage: str; has created_at: str; }
edge HAS_JOB_ATTEMPT { has attempt_number: int; }
edge HAS_BLUEPRINT {}
edge HAS_BLUEPRINT_CONCEPT {}
edge HAS_BLUEPRINT_OUTCOME {}
edge HAS_BLUEPRINT_MODULE { has order_index: int; }
edge HAS_BLUEPRINT_PREREQUISITE {}
edge HAS_BLUEPRINT_WARNING {}
edge HAS_BLUEPRINT_GENERATION_RUN {}
edge HAS_CURRICULUM_GRAPH_GENERATION {}
edge HAS_LEARNING_OUTCOME {}
edge TARGETS_OUTCOME {}
edge HAS_BLUEPRINT_DOMAIN_MAPPING {}
edge HAS_VALIDATION_REPORT {}
edge HAS_VALIDATION_ISSUE {}
edge HAS_CHUNK_ANALYSIS_ARTIFACT {}
edge HAS_MERGED_CONCEPT_ARTIFACT {}
edge DERIVED_FROM {
    has page_start: int | None = None;
    has page_end: int | None = None;
    has confidence: float = 1.0;
}
edge HAS_ENROLLMENT { has enrolled_at: str; }
edge FOR_TRACK {}
edge FOR_TRACK_VERSION {}
edge HAS_ASSESSMENT_ATTEMPT { has created_at: str; }
edge HAS_ROADMAP { has active: bool = True; }
edge HAS_MASTERY {}
edge HAS_LESSON_PROGRESS {}
edge HAS_SUBMISSION {}
edge HAS_RECOMMENDATION {}
 
# Feature 35 authenticated identity relationships. The authenticated root is
# the canonical parent for all private identity records.
edge HAS_IDENTITY_PROFILE { has created_at: str; }
edge HAS_ROLE_ASSIGNMENT { has created_at: str; }
edge HAS_LEARNER_PROFILE { has created_at: str; }
edge HAS_LECTURER_PROFILE { has created_at: str; }
edge HAS_ROADMAP_ITEM { has order_index: int; }
edge TARGETS_SKILL {}
edge USES_LESSON_TEMPLATE {}
edge DEPENDS_ON_ROADMAP_ITEM { has required: bool = True; }
edge PROGRESS_FOR_LESSON {}
edge SUBMISSION_FOR_ACTIVITY {}
edge MASTERY_OF_SKILL {}
edge EVIDENCE_FOR_MASTERY { has contribution_weight: float = 1.0; }
edge RECOMMENDS_SKILL {}
edge RECOMMENDS_ROADMAP_ITEM {}
