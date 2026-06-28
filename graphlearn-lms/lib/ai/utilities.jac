"""Centralized byLLM utilities and error handling policy for GraphLearn LMS."""

import from byllm.lib {
    AuthenticationError,
    ByLLMError,
    ConfigurationError,
    ModelNotFoundError,
    OutputConversionError,
    RateLimitError
}
import from byllm.plugin { JacRuntime }

glob llm = JacRuntime.default_llm();

enum SkillConfidence: str {
    LOW = "low",
    MEDIUM = "medium",
    HIGH = "high"
}
sem SkillConfidence.LOW = "The evidence for this skill is weak or inferred from limited learner context.";
sem SkillConfidence.MEDIUM = "The evidence for this skill is reasonable but may need confirmation.";
sem SkillConfidence.HIGH = "The evidence for this skill is strong and directly supported by learner context.";

enum RecommendationPriority: str {
    LOW = "low",
    MEDIUM = "medium",
    HIGH = "high"
}
sem RecommendationPriority.LOW = "Helpful but not urgent for the learner's immediate progress.";
sem RecommendationPriority.MEDIUM = "Useful for near-term progress and should be considered soon.";
sem RecommendationPriority.HIGH = "Important for the learner's next step and should be prioritized.";

obj ExtractedSkill {
    has name: str;
    has category: str;
    has evidence: str;
    has confidence: SkillConfidence;
}
sem ExtractedSkill = "A skill signal extracted from learner context for LMS personalization.";
sem ExtractedSkill.name = "The concise name of a programming or platform skill shown in the learner context.";
sem ExtractedSkill.category = "The skill grouping, such as language fundamentals, Jac OSP, frontend, backend, testing, or tooling.";
sem ExtractedSkill.evidence = "A short explanation of the learner signal that supports this extracted skill.";
sem ExtractedSkill.confidence = "How strongly the learner context supports this extracted skill.";

obj SkillAnalysis {
    has learner_level: str;
    has strengths: list[ExtractedSkill];
    has gaps: list[ExtractedSkill];
    has next_focus: list[str];
    has summary: str;
}
sem SkillAnalysis = "Structured analysis of a learner's current skills, strengths, gaps, and recommended focus areas.";
sem SkillAnalysis.learner_level = "A concise label for the learner's current level based only on the supplied context.";
sem SkillAnalysis.strengths = "Skills the learner appears to understand or apply successfully.";
sem SkillAnalysis.gaps = "Skills that appear missing, weak, confused, or worth validating later.";
sem SkillAnalysis.next_focus = "A short ordered list of skill names the learner should focus on next.";
sem SkillAnalysis.summary = "A brief plain-language synthesis of the skill analysis.";

obj LearningRecommendation {
    has title: str;
    has recommendation: str;
    has reason: str;
    has suggested_next_action: str;
    has priority: RecommendationPriority;
    has related_skills: list[str];
}
sem LearningRecommendation = "A single structured recommendation for the learner's next useful learning action.";
sem LearningRecommendation.title = "A short title for the recommendation.";
sem LearningRecommendation.recommendation = "The concrete learning recommendation for the learner.";
sem LearningRecommendation.reason = "Why this recommendation fits the learner's stated goal and current context.";
sem LearningRecommendation.suggested_next_action = "One clear action the learner can take next.";
sem LearningRecommendation.priority = "The priority level for acting on this recommendation.";
sem LearningRecommendation.related_skills = "Skill names connected to this recommendation.";

obj LearningSummary {
    has goal: str;
    has current_context: str;
    has constraints: list[str];
    has success_criteria: list[str];
    has summary: str;
}
sem LearningSummary = "A reusable structured summary of the learner's goal, context, constraints, and success criteria.";
sem LearningSummary.goal = "The learner's primary learning goal in concise form.";
sem LearningSummary.current_context = "The learner's relevant background, current state, or stated situation.";
sem LearningSummary.constraints = "Relevant limits, preferences, deadlines, or practical constraints from the learner context.";
sem LearningSummary.success_criteria = "Observable outcomes that would indicate progress toward the learner's goal.";
sem LearningSummary.summary = "A concise learner-facing summary that future LMS features can reuse.";

enum GeneratedQuestionType: str {
    MULTIPLE_CHOICE = "multiple_choice",
    SHORT_ANSWER = "short_answer"
}
sem GeneratedQuestionType.MULTIPLE_CHOICE = "A question answered by choosing one option from a small option set.";
sem GeneratedQuestionType.SHORT_ANSWER = "A question answered in a short free-form text response.";

enum GeneratedQuestionDifficulty: str {
    BEGINNER = "beginner",
    INTERMEDIATE = "intermediate",
    ADVANCED = "advanced"
}
sem GeneratedQuestionDifficulty.BEGINNER = "Appropriate for a learner with limited prior exposure to the target skill.";
sem GeneratedQuestionDifficulty.INTERMEDIATE = "Appropriate for a learner who knows basics and needs applied understanding checked.";
sem GeneratedQuestionDifficulty.ADVANCED = "Appropriate for a learner who may already have practical experience with the target skill.";

obj GeneratedOption {
    has label: str;
    has value: str;
}
sem GeneratedOption = "One answer option generated for an assessment question.";
sem GeneratedOption.label = "A concise learner-facing option label.";
sem GeneratedOption.value = "The stable value to persist for the option; do not include correctness or score information.";

obj GeneratedQuestion {
    has question_text: str;
    has question_type: GeneratedQuestionType;
    has skill: str;
    has difficulty: GeneratedQuestionDifficulty;
    has options: list[GeneratedOption];
}
sem GeneratedQuestion = "One structured assessment question generated to establish a learner's current skill level.";
sem GeneratedQuestion.question_text = "The learner-facing question text, skill-oriented and useful for later evaluation.";
sem GeneratedQuestion.question_type = "Whether the question is multiple choice or short answer.";
sem GeneratedQuestion.skill = "The target skill this question is intended to assess.";
sem GeneratedQuestion.difficulty = "The intended difficulty for the learner's stated experience level.";
sem GeneratedQuestion.options = "Answer options for multiple choice questions; use an empty list for short answer questions.";

obj AssessmentTitleResult {
    has title: str;
}
sem AssessmentTitleResult = "Structured title result for a generated assessment.";
sem AssessmentTitleResult.title = "A short specific assessment title aligned to the learner's goal and target skills.";

obj AssessmentDescriptionResult {
    has description: str;
}
sem AssessmentDescriptionResult = "Structured description result for a generated assessment.";
sem AssessmentDescriptionResult.description = "A concise learner-facing description of what the assessment will establish.";

obj AssessmentGenerationResult {
    has title: str;
    has description: str;
    has questions: list[GeneratedQuestion];
}
sem AssessmentGenerationResult = "Complete structured AI result for initializing a learner assessment.";
sem AssessmentGenerationResult.title = "The generated assessment title.";
sem AssessmentGenerationResult.description = "The generated assessment description.";
sem AssessmentGenerationResult.questions = "The generated assessment questions, including options where appropriate.";

obj RoadmapSkillSignalContext {
    has skill_id: str;
    has correct_count: int;
    has incorrect_count: int;
    has accuracy: float;
}
sem RoadmapSkillSignalContext = "A structured assessment skill signal used to adapt roadmap generation.";
sem RoadmapSkillSignalContext.skill_id = "The stable skill identifier from the persisted assessment evaluation.";
sem RoadmapSkillSignalContext.correct_count = "How many evaluated assessment items for this skill were answered correctly.";
sem RoadmapSkillSignalContext.incorrect_count = "How many evaluated assessment items for this skill were answered incorrectly.";
sem RoadmapSkillSignalContext.accuracy = "The learner's accuracy for this skill from 0.0 to 1.0.";

obj GeneratedRoadmapLesson {
    has title: str;
    has summary: str;
    has target_skill_ids: list[str];
    has difficulty: str;
    has estimated_minutes: int;
    has order_index: int;
}
sem GeneratedRoadmapLesson = "A lesson outline for a personalized roadmap; it must not include full lesson content.";
sem GeneratedRoadmapLesson.title = "A concise learner-facing lesson title.";
sem GeneratedRoadmapLesson.summary = "A short lesson outline describing what the learner will study, without full lesson content.";
sem GeneratedRoadmapLesson.target_skill_ids = "Stable skill identifiers this lesson prepares or practices.";
sem GeneratedRoadmapLesson.difficulty = "The lesson difficulty, usually beginner, intermediate, or advanced.";
sem GeneratedRoadmapLesson.estimated_minutes = "Estimated learner time for this lesson in minutes.";
sem GeneratedRoadmapLesson.order_index = "The one-based order of this lesson within its week.";

obj GeneratedRoadmapMilestone {
    has title: str;
    has description: str;
    has required_skill_ids: list[str];
}
sem GeneratedRoadmapMilestone = "A practice-oriented milestone that checks readiness without generating a coding challenge.";
sem GeneratedRoadmapMilestone.title = "A concise milestone title.";
sem GeneratedRoadmapMilestone.description = "A short description of the milestone outcome or checkpoint.";
sem GeneratedRoadmapMilestone.required_skill_ids = "Stable skill identifiers the learner should demonstrate for this milestone.";

obj GeneratedRoadmapWeek {
    has week_number: int;
    has title: str;
    has summary: str;
    has lessons: list[GeneratedRoadmapLesson];
    has milestones: list[GeneratedRoadmapMilestone];
}
sem GeneratedRoadmapWeek = "One ordered week in a personalized learning roadmap.";
sem GeneratedRoadmapWeek.week_number = "The one-based week number; weeks must be returned in learning order.";
sem GeneratedRoadmapWeek.title = "A concise learner-facing title for this week.";
sem GeneratedRoadmapWeek.summary = "A short overview of the week's learning focus.";
sem GeneratedRoadmapWeek.lessons = "Ordered lesson outlines for this week, with no full lesson content.";
sem GeneratedRoadmapWeek.milestones = "Milestones or checkpoints for this week.";

obj RoadmapGenerationResult {
    has title: str;
    has description: str;
    has estimated_weeks: int;
    has target_level: str;
    has weeks: list[GeneratedRoadmapWeek];
}
sem RoadmapGenerationResult = "A complete personalized roadmap outline generated from assessment evaluation results.";
sem RoadmapGenerationResult.title = "The roadmap title personalized to the learner's language and current level.";
sem RoadmapGenerationResult.description = "A concise description of the roadmap's learning arc.";
sem RoadmapGenerationResult.estimated_weeks = "The estimated duration in whole weeks.";
sem RoadmapGenerationResult.target_level = "The learner level this roadmap is designed to reach.";
sem RoadmapGenerationResult.weeks = "The ordered weeks containing lesson outlines and milestones.";

enum AIErrorKind: str {
    AUTHENTICATION = "authentication",
    CONFIGURATION = "configuration",
    MODEL_NOT_FOUND = "model_not_found",
    OUTPUT_CONVERSION = "output_conversion",
    RATE_LIMIT = "rate_limit",
    UNKNOWN_BYLLM = "unknown_byllm"
}

obj AIErrorPolicy {
    has kind: AIErrorKind;
    has retryable: bool;
    has developer_action: str;
    has user_message: str;
}

def standard_ai_error_policy(error: ByLLMError) -> AIErrorPolicy {
    if isinstance(error, AuthenticationError) {
        return AIErrorPolicy(
            kind=AIErrorKind.AUTHENTICATION,
            retryable=False,
            developer_action="Verify the provider credential environment variable configured for byLLM.",
            user_message="AI authentication is not configured correctly."
        );
    }
    if isinstance(error, ConfigurationError) {
        return AIErrorPolicy(
            kind=AIErrorKind.CONFIGURATION,
            retryable=False,
            developer_action="Verify jac.toml byLLM configuration and required environment variables.",
            user_message="AI configuration is incomplete."
        );
    }
    if isinstance(error, ModelNotFoundError) {
        return AIErrorPolicy(
            kind=AIErrorKind.MODEL_NOT_FOUND,
            retryable=False,
            developer_action="Verify the model name configured through byLLM.",
            user_message="The configured AI model is unavailable."
        );
    }
    if isinstance(error, OutputConversionError) {
        return AIErrorPolicy(
            kind=AIErrorKind.OUTPUT_CONVERSION,
            retryable=True,
            developer_action="Inspect structured output schema sem descriptions and raw_output when present.",
            user_message="AI returned a response that could not be converted into the expected LMS structure."
        );
    }
    if isinstance(error, RateLimitError) {
        return AIErrorPolicy(
            kind=AIErrorKind.RATE_LIMIT,
            retryable=True,
            developer_action="Retry with backoff or reduce request volume through the configured byLLM provider.",
            user_message="AI usage is temporarily rate limited."
        );
    }
    return AIErrorPolicy(
        kind=AIErrorKind.UNKNOWN_BYLLM,
        retryable=False,
        developer_action="Treat as a byLLM failure, log diagnostic context, and avoid graph mutation.",
        user_message="AI is temporarily unavailable."
    );
}

def extract_skill_analysis(learner_signal: str, target_track: str) -> SkillAnalysis by llm(
    temperature=0.1,
    max_tokens=900
);
sem extract_skill_analysis = "Extract a structured SkillAnalysis from learner-provided context for a programming learning track.";
sem extract_skill_analysis.learner_signal = "Learner context such as goals, experience, completed work, assessment notes, or self-described strengths and weaknesses.";
sem extract_skill_analysis.target_track = "The programming language, framework, or technology track the learner wants to study.";

def summarize_learner_goal(goal_context: str) -> LearningSummary by llm(
    temperature=0.1,
    max_tokens=700
);
sem summarize_learner_goal = "Summarize the learner's stated goal into a reusable structured LearningSummary.";
sem summarize_learner_goal.goal_context = "The learner's stated goal, background, motivations, constraints, and desired outcomes.";

def generate_learning_recommendation(
    learner_summary: LearningSummary,
    skill_analysis: SkillAnalysis
) -> LearningRecommendation by llm(
    temperature=0.2,
    max_tokens=800
);
sem generate_learning_recommendation = "Generate one structured LearningRecommendation from a learner summary and skill analysis.";
sem generate_learning_recommendation.learner_summary = "The structured summary of the learner's goal and current context.";
sem generate_learning_recommendation.skill_analysis = "The structured skill analysis containing strengths, gaps, and next focus areas.";

def generate_assessment_title(
    learner_goals: str,
    learner_interests: list[str],
    target_skills: list[str],
    target_role: str
) -> AssessmentTitleResult by llm(
    temperature=0.1,
    max_tokens=120
);
sem generate_assessment_title = "Generate a deterministic structured title for an initial LMS skill assessment.";
sem generate_assessment_title.learner_goals = "The learner's stated goals for the learning path.";
sem generate_assessment_title.learner_interests = "Learner interests that should make the assessment feel relevant.";
sem generate_assessment_title.target_skills = "Skills the assessment should focus on.";
sem generate_assessment_title.target_role = "The role or outcome the learner is targeting.";

def generate_assessment_description(
    learner_goals: str,
    learner_experience_level: str,
    target_skills: list[str],
    target_role: str
) -> AssessmentDescriptionResult by llm(
    temperature=0.1,
    max_tokens=220
);
sem generate_assessment_description = "Generate a concise structured description for an initial LMS skill assessment.";
sem generate_assessment_description.learner_goals = "The learner's stated goals for the learning path.";
sem generate_assessment_description.learner_experience_level = "The learner's self-described current experience level.";
sem generate_assessment_description.target_skills = "Skills the assessment should check.";
sem generate_assessment_description.target_role = "The role or outcome the learner is targeting.";

def generate_assessment_questions(
    learner_goals: str,
    learner_interests: list[str],
    learner_experience_level: str,
    target_skills: list[str],
    target_role: str,
    assessment_length: int
) -> list[GeneratedQuestion] by llm(
    temperature=0.1,
    max_tokens=1600
);
sem generate_assessment_questions = "Generate structured initial assessment questions with no scoring or answer evaluation.";
sem generate_assessment_questions.learner_goals = "The learner's stated goals for the learning path.";
sem generate_assessment_questions.learner_interests = "Learner interests that can contextualize questions.";
sem generate_assessment_questions.learner_experience_level = "The learner's self-described current experience level.";
sem generate_assessment_questions.target_skills = "Skills the assessment should check.";
sem generate_assessment_questions.target_role = "The role or outcome the learner is targeting.";
sem generate_assessment_questions.assessment_length = "The exact number of questions to generate when possible.";

def generate_answer_options(
    question_text: str,
    skill: str,
    difficulty: GeneratedQuestionDifficulty
) -> list[GeneratedOption] by llm(
    temperature=0.1,
    max_tokens=500
);
sem generate_answer_options = "Generate answer options for a multiple-choice assessment question without correctness labels.";
sem generate_answer_options.question_text = "The question text that needs options.";
sem generate_answer_options.skill = "The skill the question assesses.";
sem generate_answer_options.difficulty = "The intended difficulty for the question.";

def generate_initial_assessment(
    learner_goals: str,
    learner_interests: list[str],
    learner_experience_level: str,
    target_skills: list[str],
    target_role: str,
    assessment_length: int
) -> AssessmentGenerationResult {
    title_result = generate_assessment_title(
        learner_goals,
        learner_interests,
        target_skills,
        target_role
    );
    description_result = generate_assessment_description(
        learner_goals,
        learner_experience_level,
        target_skills,
        target_role
    );
    questions = generate_assessment_questions(
        learner_goals,
        learner_interests,
        learner_experience_level,
        target_skills,
        target_role,
        assessment_length
    );
    return AssessmentGenerationResult(
        title=title_result.title,
        description=description_result.description,
        questions=questions
    );
}
sem generate_initial_assessment = "Compose structured title, description, and question generation for initial assessment creation.";
sem generate_initial_assessment.learner_goals = "The learner's stated goals for the learning path.";
sem generate_initial_assessment.learner_interests = "Learner interests that can contextualize assessment generation.";
sem generate_initial_assessment.learner_experience_level = "The learner's self-described current experience level.";
sem generate_initial_assessment.target_skills = "Skills the assessment should check.";
sem generate_initial_assessment.target_role = "The role or outcome the learner is targeting.";
sem generate_initial_assessment.assessment_length = "The number of assessment questions requested.";

def generate_learning_roadmap_outline(
    language: str,
    learner_assessment_summary: str,
    overall_score: int,
    skill_signals: list[RoadmapSkillSignalContext],
    weak_skills: list[str],
    strong_skills: list[str],
    target_level: str
) -> RoadmapGenerationResult by llm(
    temperature=0.2,
    max_tokens=2200
);
sem generate_learning_roadmap_outline = "Generate a personalized course roadmap outline from persisted assessment evaluation results. Return only structured roadmap metadata, weeks, lesson outlines, and milestones; do not generate full lesson content, coding challenges, mastery updates, unlocks, or dashboard recommendations.";
sem generate_learning_roadmap_outline.language = "The selected learning language. Supported values are python and jac.";
sem generate_learning_roadmap_outline.learner_assessment_summary = "A concise summary of the persisted assessment, attempt, score, strong skills, and weak skills.";
sem generate_learning_roadmap_outline.overall_score = "The learner's overall assessment percentage from 0 to 100.";
sem generate_learning_roadmap_outline.skill_signals = "Structured skill-level evaluation signals copied from the persisted assessment evaluation.";
sem generate_learning_roadmap_outline.weak_skills = "Skill identifiers with weak evidence that should be prioritized early.";
sem generate_learning_roadmap_outline.strong_skills = "Skill identifiers with strong evidence that may allow the roadmap to skip unnecessary basics.";
sem generate_learning_roadmap_outline.target_level = "The target level the roadmap should help the learner reach.";
