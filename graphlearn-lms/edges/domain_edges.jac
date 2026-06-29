"""Domain graph edge definitions."""

# Represents Skill -> Skill and Lesson -> Lesson.
edge Prerequisite {}

# Represents Lesson -> Skill and Challenge -> Skill.
edge teaches {}

# Represents Learner -> Skill.
edge mastered {}

# Represents Learner -> Roadmap and Roadmap -> Lesson.
edge assigned {}

# Represents Roadmap -> RoadmapWeek, RoadmapWeek -> RoadmapLesson, and RoadmapWeek -> RoadmapMilestone.
edge contains {}

# Represents RoadmapLesson -> Skill.
edge targets {}

# Represents GeneratedChallenge -> Skill.
edge evaluates {}

# Represents Learner -> ChallengeSubmission.
edge attempted {}

# Represents ChallengeSubmission -> GeneratedChallenge and GeneratedChallenge -> ChallengeSubmission.
edge submitted_for {}

# Represents RoadmapMilestone -> Skill.
edge requires {}

# Represents Learner -> Lesson, Learner -> Challenge, and Learner -> Assessment.
edge completed {}
