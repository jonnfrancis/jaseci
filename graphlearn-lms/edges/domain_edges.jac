"""Domain graph edge definitions."""

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
