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

obj GeneratedLessonSection {
    has title: str;
    has content: str;
}
sem GeneratedLessonSection = "One short readable section in a generated LMS lesson.";
sem GeneratedLessonSection.title = "A concise section title aligned to the lesson objective.";
sem GeneratedLessonSection.content = "Learner-facing explanatory content for this section, focused and readable.";

obj GeneratedLessonExample {
    has title: str;
    has code: str;
    has explanation: str;
}
sem GeneratedLessonExample = "One practical code example for a generated lesson.";
sem GeneratedLessonExample.title = "A concise learner-facing example title.";
sem GeneratedLessonExample.code = "Valid code for the requested language that demonstrates the lesson concept.";
sem GeneratedLessonExample.explanation = "A short explanation of what the code shows and why it matters.";

obj GeneratedLessonMiniExercise {
    has prompt: str;
    has expected_concept: str;
}
sem GeneratedLessonMiniExercise = "A lightweight ungraded reading-check exercise, not a coding challenge.";
sem GeneratedLessonMiniExercise.prompt = "A short practice prompt that reinforces the lesson without grading, rubrics, or submission evaluation.";
sem GeneratedLessonMiniExercise.expected_concept = "The single concept the mini exercise is meant to reinforce.";

obj GeneratedLessonTakeaway {
    has content: str;
}
sem GeneratedLessonTakeaway = "One concise key takeaway from the generated lesson.";
sem GeneratedLessonTakeaway.content = "A memorable sentence summarizing a concept the learner should retain.";

obj LessonGenerationResult {
    has sections: list[GeneratedLessonSection];
    has examples: list[GeneratedLessonExample];
    has mini_exercises: list[GeneratedLessonMiniExercise];
    has key_takeaways: list[GeneratedLessonTakeaway];
}
sem LessonGenerationResult = "Complete structured content for one on-demand LMS lesson. It must not include final coding challenges, grading rubrics, submission evaluation, mastery updates, unlock instructions, dashboard analytics, or tutor recommendations.";
sem LessonGenerationResult.sections = "Ordered lesson sections following this structure: brief introduction, concept explanation, practical example, common mistake or misconception, mini exercise, and key takeaways.";
sem LessonGenerationResult.examples = "Ordered practical code examples aligned to the persisted roadmap lesson outline and target language.";
sem LessonGenerationResult.mini_exercises = "Ordered ungraded reading-check prompts that reinforce concepts without becoming coding challenges.";
sem LessonGenerationResult.key_takeaways = "Ordered concise lesson takeaways.";

obj LessonContentContext {
    has language: str;
    has lesson_title: str;
    has lesson_summary: str;
    has difficulty: str;
    has estimated_minutes: int;
    has target_skills: list[str];
    has learner_assessment_summary: str;
    has weak_skills: list[str];
    has strong_skills: list[str];
    has previous_lesson_titles: list[str];
}
sem LessonContentContext = "The complete persisted context for generating one on-demand lesson from a roadmap lesson outline.";
sem LessonContentContext.language = "The selected learning language. Supported values are python and jac.";
sem LessonContentContext.lesson_title = "The persisted roadmap lesson title; use it as the source of truth.";
sem LessonContentContext.lesson_summary = "The persisted roadmap lesson summary; use it as the scope boundary.";
sem LessonContentContext.difficulty = "The persisted lesson difficulty: beginner, intermediate, or advanced.";
sem LessonContentContext.estimated_minutes = "The persisted estimated lesson duration in minutes. Beginner lessons should target 8 to 12 minutes, intermediate 10 to 15 minutes, and advanced 12 to 18 minutes.";
sem LessonContentContext.target_skills = "Persisted skill identifiers targeted by this roadmap lesson.";
sem LessonContentContext.learner_assessment_summary = "A concise summary of persisted assessment evaluation signals available for personalization, or a note that no evaluation summary was found.";
sem LessonContentContext.weak_skills = "Skill identifiers where the learner showed weak evidence and may need extra clarity.";
sem LessonContentContext.strong_skills = "Skill identifiers where the learner showed stronger evidence and can move faster.";
sem LessonContentContext.previous_lesson_titles = "Earlier lesson titles from the same roadmap that can provide continuity without repeating content.";

obj GeneratedChallengeInstruction {
    has content: str;
}
sem GeneratedChallengeInstruction = "One ordered learner-facing instruction for a generated hands-on coding challenge.";
sem GeneratedChallengeInstruction.content = "A concise imperative instruction the learner can follow while writing or modifying code.";

obj GeneratedChallengeExpectedOutcome {
    has content: str;
}
sem GeneratedChallengeExpectedOutcome = "One observable outcome expected from a learner's challenge solution.";
sem GeneratedChallengeExpectedOutcome.content = "A concrete behavior, code structure, or output that should be visible in a correct solution.";

obj GeneratedChallengeConstraint {
    has content: str;
}
sem GeneratedChallengeConstraint = "One safety or scope constraint for a generated coding challenge.";
sem GeneratedChallengeConstraint.content = "A clear limitation that keeps the task small, local, safe, and aligned to the lesson.";

obj GeneratedChallengeHint {
    has content: str;
}
sem GeneratedChallengeHint = "One optional hint for a generated coding challenge.";
sem GeneratedChallengeHint.content = "A helpful nudge that supports the learner without giving away the full solution.";

obj GeneratedChallengeEvaluationCriterion {
    has skill_id: str;
    has description: str;
    has weight: float;
}
sem GeneratedChallengeEvaluationCriterion = "One structured criterion future AI evaluation can use to grade a submitted coding challenge solution.";
sem GeneratedChallengeEvaluationCriterion.skill_id = "The stable skill identifier this criterion evaluates; prefer one of the persisted target skills.";
sem GeneratedChallengeEvaluationCriterion.description = "A specific observable standard for judging learner code.";
sem GeneratedChallengeEvaluationCriterion.weight = "Relative criterion weight from 0.0 to 1.0; all returned criteria should sum close to 1.0.";

obj ChallengeGenerationResult {
    has title: str;
    has prompt: str;
    has difficulty: str;
    has starter_code: str;
    has instructions: list[GeneratedChallengeInstruction];
    has expected_outcomes: list[GeneratedChallengeExpectedOutcome];
    has constraints: list[GeneratedChallengeConstraint];
    has hints: list[GeneratedChallengeHint];
    has evaluation_criteria: list[GeneratedChallengeEvaluationCriterion];
}
sem ChallengeGenerationResult = "Complete structured result for one persisted hands-on coding challenge. It must ask the learner to write or modify code and must not include submissions, code execution, grading results, mastery updates, unlock logic, dashboard analytics, tutor recommendations, filesystem tasks, network calls, package installation, credentials, or system-level operations.";
sem ChallengeGenerationResult.title = "A concise learner-facing challenge title aligned to the generated lesson.";
sem ChallengeGenerationResult.prompt = "A practical coding task prompt that requires writing or modifying code in the requested language.";
sem ChallengeGenerationResult.difficulty = "The challenge difficulty: beginner, intermediate, or advanced.";
sem ChallengeGenerationResult.starter_code = "Safe starter code in the requested language. Python starter code must be valid Python; Jac starter code should use Jac syntax where practical.";
sem ChallengeGenerationResult.instructions = "Ordered steps the learner should follow to complete the coding challenge.";
sem ChallengeGenerationResult.expected_outcomes = "Ordered observable outcomes that a correct solution should satisfy.";
sem ChallengeGenerationResult.constraints = "Ordered constraints that keep the challenge safe, local, and focused on the lesson.";
sem ChallengeGenerationResult.hints = "Ordered hints that help without solving the challenge.";
sem ChallengeGenerationResult.evaluation_criteria = "Ordered weighted criteria future evaluation can apply to a learner's submitted code.";

obj ChallengeGenerationContext {
    has language: str;
    has lesson_title: str;
    has lesson_summary: str;
    has lesson_difficulty: str;
    has lesson_sections: list[str];
    has lesson_examples: list[str];
    has lesson_mini_exercises: list[str];
    has target_skills: list[str];
    has learner_weak_skills: list[str];
    has learner_strong_skills: list[str];
    has previous_challenge_titles: list[str];
}
sem ChallengeGenerationContext = "Persisted source-of-truth context for generating one hands-on coding challenge from an already generated lesson.";
sem ChallengeGenerationContext.language = "The selected learning language. Supported values are python and jac.";
sem ChallengeGenerationContext.lesson_title = "The generated lesson title to align the challenge with.";
sem ChallengeGenerationContext.lesson_summary = "The generated lesson summary to scope the challenge.";
sem ChallengeGenerationContext.lesson_difficulty = "The generated lesson difficulty: beginner, intermediate, or advanced.";
sem ChallengeGenerationContext.lesson_sections = "Ordered generated lesson section titles and content summaries that the challenge should practice.";
sem ChallengeGenerationContext.lesson_examples = "Ordered generated lesson example titles, code, and explanations to ground starter code and task design.";
sem ChallengeGenerationContext.lesson_mini_exercises = "Ordered generated lesson mini exercises and expected concepts to build upon without duplicating exactly.";
sem ChallengeGenerationContext.target_skills = "Persisted roadmap lesson target skill identifiers the challenge should evaluate.";
sem ChallengeGenerationContext.learner_weak_skills = "Skill identifiers where available assessment evidence suggests the learner may need extra practice.";
sem ChallengeGenerationContext.learner_strong_skills = "Skill identifiers where available assessment evidence suggests the learner is stronger.";
sem ChallengeGenerationContext.previous_challenge_titles = "Previously generated challenge titles for this roadmap to avoid repetition.";

obj SubmissionEvaluationCriterionContext {
    has criterion_id: str;
    has skill_id: str;
    has description: str;
    has weight: float;
}
sem SubmissionEvaluationCriterionContext = "A persisted coding challenge evaluation criterion that the submission evaluator must score.";
sem SubmissionEvaluationCriterionContext.criterion_id = "The stable persisted criterion identifier to echo in the criterion result.";
sem SubmissionEvaluationCriterionContext.skill_id = "The skill identifier this criterion evaluates.";
sem SubmissionEvaluationCriterionContext.description = "The persisted observable standard for judging the submitted code.";
sem SubmissionEvaluationCriterionContext.weight = "The persisted relative importance of this criterion.";

obj SubmissionEvaluationContext {
    has language: str;
    has challenge_title: str;
    has challenge_prompt: str;
    has starter_code: str;
    has instructions: list[str];
    has expected_outcomes: list[str];
    has constraints: list[str];
    has hints: list[str];
    has evaluation_criteria: list[SubmissionEvaluationCriterionContext];
    has submitted_code: str;
    has lesson_title: str;
    has lesson_summary: str;
    has target_skills: list[str];
}
sem SubmissionEvaluationContext = "Persisted source-of-truth context for statically evaluating one submitted coding challenge solution without executing code.";
sem SubmissionEvaluationContext.language = "The submitted challenge language. Supported values are python and jac.";
sem SubmissionEvaluationContext.challenge_title = "The persisted challenge title.";
sem SubmissionEvaluationContext.challenge_prompt = "The persisted learner-facing challenge prompt.";
sem SubmissionEvaluationContext.starter_code = "The original safe starter code shown to the learner.";
sem SubmissionEvaluationContext.instructions = "Ordered persisted challenge instructions the learner was asked to follow.";
sem SubmissionEvaluationContext.expected_outcomes = "Ordered persisted outcomes a correct solution should satisfy.";
sem SubmissionEvaluationContext.constraints = "Ordered persisted constraints the submitted code should respect, especially safety and scope limits.";
sem SubmissionEvaluationContext.hints = "Ordered persisted hints that were available to the learner; use them only as challenge context.";
sem SubmissionEvaluationContext.evaluation_criteria = "Ordered persisted criteria that must be scored individually.";
sem SubmissionEvaluationContext.submitted_code = "The learner's persisted submitted code to review statically; do not execute it.";
sem SubmissionEvaluationContext.lesson_title = "The generated lesson title linked to this challenge.";
sem SubmissionEvaluationContext.lesson_summary = "The generated lesson summary linked to this challenge.";
sem SubmissionEvaluationContext.target_skills = "Persisted target skill identifiers for this challenge and roadmap lesson.";

obj GeneratedCriterionResult {
    has criterion_id: str;
    has skill_id: str;
    has score: float;
    has feedback: str;
    has met: bool;
}
sem GeneratedCriterionResult = "Structured score and feedback for one persisted challenge evaluation criterion.";
sem GeneratedCriterionResult.criterion_id = "The exact persisted criterion id being evaluated.";
sem GeneratedCriterionResult.skill_id = "The skill id connected to the criterion.";
sem GeneratedCriterionResult.score = "Criterion score from 0.0 to 1.0 based on static review of submitted code.";
sem GeneratedCriterionResult.feedback = "Specific, actionable feedback tied to this criterion and the submitted code.";
sem GeneratedCriterionResult.met = "Whether the submitted solution satisfies this criterion well enough to count as met.";

obj GeneratedSkillSignal {
    has skill_id: str;
    has score: float;
    has confidence: float;
    has evidence: str;
}
sem GeneratedSkillSignal = "Evidence-only signal about learner performance on one skill from this submitted challenge.";
sem GeneratedSkillSignal.skill_id = "The skill identifier this signal describes.";
sem GeneratedSkillSignal.score = "Skill performance score from 0.0 to 1.0 inferred from the submitted code.";
sem GeneratedSkillSignal.confidence = "Confidence from 0.0 to 1.0 that the submitted code supports this signal.";
sem GeneratedSkillSignal.evidence = "Concrete evidence from the submitted code and challenge requirements.";

obj GeneratedFeedbackItem {
    has feedback_type: str;
    has content: str;
}
sem GeneratedFeedbackItem = "One structured learner-facing feedback item.";
sem GeneratedFeedbackItem.feedback_type = "One of strength, improvement, or suggestion.";
sem GeneratedFeedbackItem.content = "Specific, encouraging, actionable feedback tied to the challenge requirements.";

obj SubmissionEvaluationResult {
    has score: int;
    has feedback_summary: str;
    has criterion_results: list[GeneratedCriterionResult];
    has skill_signals: list[GeneratedSkillSignal];
    has feedback_items: list[GeneratedFeedbackItem];
    has suggested_next_step: str;
}
sem SubmissionEvaluationResult = "Complete structured static review of a persisted coding challenge submission. It must not include mastery updates, lesson unlocking, roadmap progress, retry challenge generation, code execution output, shell operations, filesystem access, package installation, network calls, or tutor chat.";
sem SubmissionEvaluationResult.score = "Overall score from 0 to 100 representing how well the submitted solution meets the challenge requirements; 70 or higher means passed but not mastered.";
sem SubmissionEvaluationResult.feedback_summary = "A concise summary of what the learner did well and what to improve.";
sem SubmissionEvaluationResult.criterion_results = "One result for each persisted evaluation criterion, using the exact criterion ids.";
sem SubmissionEvaluationResult.skill_signals = "Evidence-only skill signals for future mastery and recommendation systems; do not claim mastery.";
sem SubmissionEvaluationResult.feedback_items = "Structured strengths, improvements, and suggestions for learner-facing feedback.";
sem SubmissionEvaluationResult.suggested_next_step = "One concrete next learning or revision action for the learner.";

enum TutorRecommendationType: str {
    start_assessment = "start_assessment",
    generate_roadmap = "generate_roadmap",
    start_roadmap = "start_roadmap",
    continue_lesson = "continue_lesson",
    generate_lesson = "generate_lesson",
    start_challenge = "start_challenge",
    retry_challenge = "retry_challenge",
    review_lesson = "review_lesson",
    practice_weak_skill = "practice_weak_skill",
    view_skill_map = "view_skill_map",
    completed = "completed"
}
sem TutorRecommendationType.start_assessment = "The learner should begin or continue the LMS assessment before roadmap work.";
sem TutorRecommendationType.generate_roadmap = "The learner has an evaluated assessment and should generate an LMS roadmap.";
sem TutorRecommendationType.start_roadmap = "The learner has a roadmap but progression has not started.";
sem TutorRecommendationType.continue_lesson = "The learner should continue the current unlocked lesson.";
sem TutorRecommendationType.generate_lesson = "The learner should open the existing LMS lesson flow so lesson content is generated.";
sem TutorRecommendationType.start_challenge = "The learner should start the challenge flow for the current lesson.";
sem TutorRecommendationType.retry_challenge = "The learner should retry a failed LMS challenge.";
sem TutorRecommendationType.review_lesson = "The learner should review an existing lesson before moving forward.";
sem TutorRecommendationType.practice_weak_skill = "The learner should practice a weak skill inside the LMS flow.";
sem TutorRecommendationType.view_skill_map = "The learner should view the skill map for orientation.";
sem TutorRecommendationType.completed = "The learner has completed the roadmap.";

enum TutorRecommendationPriority: str {
    low = "low",
    medium = "medium",
    high = "high"
}
sem TutorRecommendationPriority.low = "Optional or reflective action that can wait.";
sem TutorRecommendationPriority.medium = "Useful near-term action for steady progress.";
sem TutorRecommendationPriority.high = "Most useful next action or an obvious blocker.";

obj TutorRecommendationReason {
    has signal: str;
    has explanation: str;
}
sem TutorRecommendationReason = "One compact reason supporting a tutor next-action recommendation.";
sem TutorRecommendationReason.signal = "The persisted learner signal considered, such as lesson status, challenge result, mastery score, or recent activity.";
sem TutorRecommendationReason.explanation = "Why this signal matters for the recommended LMS action.";

obj TutorRecommendedResource {
    has resource_type: str;
    has resource_id: str;
    has title: str;
}
sem TutorRecommendedResource = "A persisted LMS resource related to the recommendation.";
sem TutorRecommendedResource.resource_type = "The LMS resource kind: roadmap_lesson, generated_lesson, challenge, skill, roadmap, assessment, or skill_map.";
sem TutorRecommendedResource.resource_id = "The stable persisted id of the related LMS resource, or an empty string when none applies.";
sem TutorRecommendedResource.title = "A concise title or label for the related LMS resource.";

obj TutorRecommendationContext {
    has language: str;
    has roadmap_title: str;
    has roadmap_status: str;
    has roadmap_progress_summary: str;
    has current_lesson_summary: str;
    has lesson_status_summary: str;
    has challenge_status_summary: str;
    has mastery_summary: str;
    has weakest_skills: list[str];
    has strongest_skills: list[str];
    has recent_activity: list[str];
    has available_lessons: list[str];
    has locked_lessons: list[str];
    has completed_lessons: list[str];
}
sem TutorRecommendationContext = "Compact persisted LMS context for choosing the learner's next action. It must not include full lesson content or submitted code.";
sem TutorRecommendationContext.language = "The selected LMS language; supported values are python and jac.";
sem TutorRecommendationContext.roadmap_title = "The persisted roadmap title.";
sem TutorRecommendationContext.roadmap_status = "The persisted roadmap status.";
sem TutorRecommendationContext.roadmap_progress_summary = "A short summary of roadmap progress totals and current lesson id.";
sem TutorRecommendationContext.current_lesson_summary = "The current available or in-progress lesson title, status, generation state, and target skills.";
sem TutorRecommendationContext.lesson_status_summary = "Compact lesson status counts and important lesson states.";
sem TutorRecommendationContext.challenge_status_summary = "Compact challenge state including generated, submitted, passed, and failed counts.";
sem TutorRecommendationContext.mastery_summary = "Compact mastery state with average score and notable weak or strong skills.";
sem TutorRecommendationContext.weakest_skills = "Skill ids or names with the weakest persisted mastery evidence.";
sem TutorRecommendationContext.strongest_skills = "Skill ids or names with the strongest persisted mastery evidence.";
sem TutorRecommendationContext.recent_activity = "Recent LMS activity titles only, newest first.";
sem TutorRecommendationContext.available_lessons = "Unlocked lesson titles that can be opened inside the LMS.";
sem TutorRecommendationContext.locked_lessons = "Locked lesson titles that must not be recommended as startable.";
sem TutorRecommendationContext.completed_lessons = "Completed lesson titles.";

obj TutorRecommendationResult {
    has recommendation_type: TutorRecommendationType;
    has title: str;
    has recommended_action: str;
    has explanation: str;
    has confidence: float;
    has priority: TutorRecommendationPriority;
    has suggested_cta_label: str;
    has related_roadmap_lesson_id: str = "";
    has related_challenge_id: str = "";
    has related_skill_ids: list[str] = [];
    has reasons: list[TutorRecommendationReason] = [];
    has resources: list[TutorRecommendedResource] = [];
}
sem TutorRecommendationResult = "A single structured LMS-only tutor recommendation for what the learner should do next.";
sem TutorRecommendationResult.recommendation_type = "The stable recommendation type. Choose only one of the supported LMS next-action types.";
sem TutorRecommendationResult.title = "A short learner-facing title for the recommendation.";
sem TutorRecommendationResult.recommended_action = "One concrete next action inside the LMS flow.";
sem TutorRecommendationResult.explanation = "Why this is the best next step, based only on persisted LMS context.";
sem TutorRecommendationResult.confidence = "Confidence from 0.0 to 1.0 that this is the best next action.";
sem TutorRecommendationResult.priority = "The priority level for this action.";
sem TutorRecommendationResult.related_roadmap_lesson_id = "The related roadmap lesson id, or an empty string if none applies.";
sem TutorRecommendationResult.related_challenge_id = "The related generated challenge id, or an empty string if none applies.";
sem TutorRecommendationResult.related_skill_ids = "Related persisted skill ids. Use an empty list when no skill applies.";
sem TutorRecommendationResult.suggested_cta_label = "A concise LMS button label for this recommendation.";
sem TutorRecommendationResult.reasons = "Brief structured reasons supporting the recommendation.";
sem TutorRecommendationResult.resources = "Related LMS resources the UI may link later.";

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

def generate_lesson_content(context: LessonContentContext) -> LessonGenerationResult by llm(
    temperature=0.2,
    max_tokens=2200
);
sem generate_lesson_content = "Generate complete structured reading content for one persisted roadmap lesson outline. Personalize to the learner context, keep the lesson short and focused, use the requested language, and return only structured sections, examples, mini exercises, and takeaways. Do not generate coding challenges, grading rubrics, submission evaluation, mastery updates, unlock logic, dashboard analytics, or tutor recommendations.";
sem generate_lesson_content.context = "The complete persisted lesson-generation context built by the walker from roadmap, learner, skills, and assessment data.";

def generate_coding_challenge(context: ChallengeGenerationContext) -> ChallengeGenerationResult by llm(
    temperature=0.2,
    max_tokens=2200
);
sem generate_coding_challenge = "Generate one safe, hands-on coding challenge from a persisted generated lesson. The learner must write or modify code. Return only structured challenge content and future evaluation criteria; do not evaluate submissions, run code, update mastery, unlock lessons, create a workspace UI, require external packages, access files, use network calls, request credentials, or perform dangerous/system-level tasks.";
sem generate_coding_challenge.context = "The complete challenge-generation context built from the generated lesson, roadmap lesson, target skills, assessment signals, and previous challenges.";

def evaluate_code_submission(context: SubmissionEvaluationContext) -> SubmissionEvaluationResult by llm(
    temperature=0.1,
    max_tokens=2200
);
sem evaluate_code_submission = "Statically evaluate one persisted coding challenge submission against the persisted challenge definition. Return only structured scoring, feedback, criterion results, skill signals, and next-step guidance. Do not execute code, request execution, access files, use shell commands, install packages, make network calls, update mastery, unlock lessons, update roadmap progress, generate retry challenges, or create tutor chat.";
sem evaluate_code_submission.context = "The complete persisted submission-evaluation context built from the generated challenge, linked lesson, target skills, evaluation criteria, and submitted code.";

def generate_next_action_recommendation(context: TutorRecommendationContext) -> TutorRecommendationResult by llm(
    temperature=0.2,
    max_tokens=1200
);
sem generate_next_action_recommendation = "Choose one LMS-only next action for a learner from compact persisted roadmap, progression, lesson, challenge, mastery, and recent activity context. Prefer current available lessons, challenges, retries, weak-skill practice, skill-map orientation, or completion as appropriate. Do not recommend external websites, paid courses, downloads, contacting people, unsafe code execution, system tasks, graph mutation, lesson unlocking, lesson generation outside the existing LMS flow, challenge generation outside the existing LMS flow, evaluation, mastery updates, dashboard UI, or tutor chat.";
sem generate_next_action_recommendation.context = "The compact persisted LMS recommendation context. It intentionally excludes full lesson content and submitted code.";
