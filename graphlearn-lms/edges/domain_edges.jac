"""Domain graph edge definitions."""

# Represents Skill -> Skill and Lesson -> Lesson.
edge Prerequisite {}

# Represents Lesson -> Skill and Challenge -> Skill.
edge teaches {}

# Represents Learner -> Skill.
edge mastered {}

# Represents Learner -> Roadmap and Roadmap -> Lesson.
edge assigned {}

# Represents Learner -> Lesson, Learner -> Challenge, and Learner -> Assessment.
edge completed {}
