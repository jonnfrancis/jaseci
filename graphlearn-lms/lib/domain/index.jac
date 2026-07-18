"""Domain model barrel exports."""

import from edges.domain_edges {
    ASSESSES_SKILL, CONTAINS_MODULE, CONTAINS_SKILL, DEPENDS_ON_ROADMAP_ITEM,
    DERIVED_FROM, EVIDENCE_FOR_MASTERY, FOR_TRACK, FOR_TRACK_VERSION,
    HAS_ACTIVITY_TEMPLATE, HAS_ASSESSMENT_ATTEMPT, HAS_BLUEPRINT, HAS_CATALOGUE,
    HAS_CONTENT_CHUNK, HAS_ENROLLMENT, HAS_EXTRACTION, HAS_EXTRACTION_BLOCK, HAS_LEARNING_TRACK, HAS_LESSON_PROGRESS,
    HAS_LESSON_TEMPLATE, HAS_MASTERY, HAS_RECOMMENDATION, HAS_ROADMAP,
    HAS_ROADMAP_ITEM, HAS_SOURCE_DOCUMENT, HAS_SUBMISSION, HAS_TRACK_CONFIGURATION,
    HAS_TRACK_VERSION, LESSON_HAS_ACTIVITY, MASTERY_OF_SKILL, MODULE_CONTAINS_SKILL,
    MODULE_HAS_LESSON, OWNS_TRACK, PREREQUISITE, PROGRESS_FOR_LESSON,
    RECOMMENDS_ROADMAP_ITEM, RECOMMENDS_SKILL, SUBMISSION_FOR_ACTIVITY,
    TARGETS_SKILL, TEACHES_SKILL, USES_LESSON_TEMPLATE, Prerequisite, assigned,
    attempted, belongs_to, completed, contains, evaluated, evaluates, evidenced_by,
    mastered, progresses, requires, signals, submitted_for, targets, teaches, tracks,
    unlocked
}
import from nodes.identity {
    AuthenticatedActor, IdentityError, IdentityResult, LecturerProfile,
    LecturerProfileInput, LecturerProfileStatus, LecturerProfileSummary,
    LecturerVerificationStatus, RoleAssignmentResult, RoleAssignmentSource,
    RoleAssignmentStatus, UserIdentityProfile, UserRoleAssignment,
    UserRoleMigrationRecord, UserRoleType
}
import from nodes.curriculum {
    ActivityTemplate, CourseBlueprint, CourseContentChunk, CourseDocument, DocumentExtraction, ExtractionBlock,
    CourseDocumentError, CourseDocumentProcessingStatus, CourseDocumentUploadResult,
    CourseDocumentUploadStatus, CourseModule, DocumentExtractionResult, DocumentExtractionStatus,
    ExtractionBlockType, ExtractionQuality, ExtractionRequestContext, LessonTemplate, UploadCourseDocumentInput
}
import from nodes.authorization {
    AdministrativePermission, AuthorizationActor, AuthorizationAuditEvent,
    AuthorizationDecision, AuthorizationDecisionType, AuthorizationReasonCode,
    AuthorizationResourceContext, AuthorizationScope, LecturerPermission,
    OwnershipMigrationReport, TrackAccessRole
}
import from nodes.enrollment { Enrollment, RoadmapItem, Submission }
import from nodes.graph_integrity {
    GraphIntegrityIssue, GraphIntegrityReport, SkillGraphItem, SkillUnlockEvaluation
}
import from nodes.assessment {
    Assessment,
    AssessmentAttempt,
    AssessmentAttemptLink,
    AssessmentAttemptResponseLink,
    AssessmentAttemptStatus,
    AssessmentDifficulty,
    AssessmentEvaluation,
    AssessmentEvaluationLink,
    AssessmentOption,
    AssessmentOptionLink,
    AssessmentQuestion,
    AssessmentQuestionLink,
    AssessmentQuestionType,
    AssessmentResponse,
    AssessmentResponseQuestionLink,
    AssessmentScore,
    AssessmentStatus,
    QuestionResult,
    SkillSignal
}
import from nodes.challenge {
    Challenge,
    ChallengeConstraint,
    ChallengeEvaluationCriterion,
    ChallengeExpectedOutcome,
    ChallengeHint,
    ChallengeInstruction,
    ChallengeSubmission,
    ChallengeSubmissionStatus,
    CriterionResult,
    FeedbackItem,
    FeedbackType,
    GeneratedChallenge,
    SubmissionEvaluation,
    SubmissionSkillSignal
}
import from nodes.learner { Learner }
import from nodes.learning_track {
    CreateLearningTrackInput,
    LearningCatalogue,
    LearningTrack,
    LearningTrackDetail,
    LearningTrackError,
    LearningTrackMigrationReport,
    LearningTrackResult,
    LearningTrackStatus,
    LearningTrackSummary,
    LearningTrackType,
    LearningTrackVisibility,
    TrackConfiguration,
    TrackDifficultyLevel,
    TrackOwnershipType,
    TrackSourceKind,
    TrackVersion,
    TrackVersionStatus
}
import from nodes.lesson {
    Difficulty,
    GeneratedLesson,
    Lesson,
    LessonExample,
    LessonGenerationStatus,
    LessonMiniExercise,
    LessonSection,
    LessonTakeaway
}
import from nodes.mastery {
    Mastery,
    MasteryEvidence,
    MasteryLevel,
    MasteryScore,
    MasterySourceType,
    MasteryUpdateResult,
    SkillMastery,
    UpdatedSkillMasteryRecord
}
import from nodes.progression {
    LessonProgress,
    LessonUnlockState,
    ProgressionEvent,
    ProgressionEventType,
    RoadmapProgress,
    RoadmapProgressStatus
}
import from nodes.programming_track_migration {
    BuiltinTrackSeedOutcome,
    BuiltinTrackSeedReport,
    HAS_MIGRATION_RECORD,
    LegacyTrackResolution,
    ProgrammingTrackMigrationLedger,
    ProgrammingTrackMigrationRecord,
    ProgrammingTrackMigrationReport,
    TrackContext
}
import from nodes.roadmap {
    Roadmap,
    RoadmapLesson,
    RoadmapLessonGenerationStatus,
    RoadmapMilestone,
    RoadmapStatus,
    RoadmapWeek
}
import from nodes.skill { Skill }
import from nodes.track_context { DashboardSnapshot, Recommendation, SkillMapSnapshot, TrackValidationResult }
