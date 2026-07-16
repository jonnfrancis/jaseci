export type AssessmentStatus = "draft" | "active" | "completed";

export interface LearningTrackOption {
  trackId: string;
  trackVersionId: string;
  slug: string;
  title: string;
  trackType: "PROGRAMMING_LANGUAGE" | "LECTURER_COURSE";
  legacyLanguage?: string | null;
}
export type AssessmentQuestionType = "multiple_choice" | "short_answer";
export type AssessmentDifficulty = "beginner" | "intermediate" | "advanced";

export interface AssessmentOption {
  id: string;
  label: string;
  value: string;
}

export interface AssessmentQuestion {
  id: string;
  question_text: string;
  question_type: AssessmentQuestionType;
  skill: string;
  difficulty: AssessmentDifficulty;
  options: AssessmentOption[];
}

export interface Assessment {
  id: string;
  learner_id: string;
  title: string;
  description: string;
  status: AssessmentStatus;
  created_at: string;
  questions: AssessmentQuestion[];
}

export interface Learner {
  id: string;
  name: string;
  createdAt: string;
  updatedAt: string;
}

export type Difficulty = "beginner" | "intermediate" | "advanced";

export interface Lesson {
  id: string;
  title: string;
  summary: string;
  skillId: string;
  difficulty: Difficulty;
  estimatedMinutes: number;
}

export type LessonGenerationStatus = "pending" | "generated";

export interface LessonSectionView {
  id: string;
  title: string;
  content: string;
  order_index: number;
}

export interface LessonExampleView {
  id: string;
  title: string;
  code: string;
  explanation: string;
  order_index: number;
}

export interface LessonMiniExerciseView {
  id: string;
  prompt: string;
  expected_concept: string;
  order_index: number;
}

export interface LessonTakeawayView {
  id: string;
  content: string;
  order_index: number;
}

export interface GeneratedLessonView {
  id: string;
  roadmap_id: string;
  roadmap_lesson_id: string;
  learner_id: string;
  language: "python" | "jac";
  title: string;
  summary: string;
  difficulty: Difficulty;
  estimated_minutes: number;
  sections: LessonSectionView[];
  examples: LessonExampleView[];
  mini_exercises: LessonMiniExerciseView[];
  key_takeaways: LessonTakeawayView[];
  generation_status: LessonGenerationStatus;
  created_at: string;
  updated_at: string;
}

export interface Challenge {
  id: string;
  title: string;
  description: string;
  skillId: string;
  difficulty: Difficulty;
}

export interface ChallengeInstructionView {
  id: string;
  content: string;
  order_index: number;
}

export interface ChallengeExpectedOutcomeView {
  id: string;
  content: string;
  order_index: number;
}

export interface ChallengeConstraintView {
  id: string;
  content: string;
  order_index: number;
}

export interface ChallengeHintView {
  id: string;
  content: string;
  order_index: number;
}

export interface ChallengeEvaluationCriterionView {
  id: string;
  skill_id: string;
  description: string;
  weight: number;
  order_index: number;
}

export interface GeneratedChallengeView {
  id: string;
  learner_id: string;
  roadmap_id: string;
  roadmap_lesson_id: string;
  generated_lesson_id: string;
  language: "python" | "jac";
  title: string;
  prompt: string;
  difficulty: Difficulty;
  starter_code: string;
  created_at: string;
  updated_at?: string;
  instructions: ChallengeInstructionView[];
  expected_outcomes: ChallengeExpectedOutcomeView[];
  constraints: ChallengeConstraintView[];
  hints: ChallengeHintView[];
  evaluation_criteria: ChallengeEvaluationCriterionView[];
}

export type ChallengeSubmissionStatus = "draft" | "submitted";

export interface ChallengeSubmissionDraft {
  challenge_id: string;
  learner_id: string;
  code: string;
  language: "python" | "jac";
  status: ChallengeSubmissionStatus;
  updated_at?: string;
}

export interface ChallengeSubmissionView {
  id: string;
  challenge_id: string;
  learner_id: string;
  code: string;
  language: "python" | "jac";
  status: "submitted";
  submitted_at: string;
}

export interface CriterionResultView {
  id: string;
  criterion_id: string;
  skill_id: string;
  score: number;
  feedback: string;
  met: boolean;
  order_index: number;
}

export interface SubmissionSkillSignalView {
  id: string;
  skill_id: string;
  score: number;
  confidence: number;
  evidence: string;
  order_index: number;
}

export type FeedbackItemType = "strength" | "improvement" | "suggestion";

export interface FeedbackItemView {
  id: string;
  feedback_type: FeedbackItemType;
  content: string;
  order_index: number;
}

export interface SubmissionEvaluationView {
  id: string;
  learner_id: string;
  challenge_id: string;
  submission_id: string;
  language: "python" | "jac";
  score: number;
  passed: boolean;
  feedback_summary: string;
  criterion_results: CriterionResultView[];
  skill_signals: SubmissionSkillSignalView[];
  strengths: string[];
  improvement_areas: string[];
  suggested_next_step: string;
  evaluated_at: string;
}

export interface Skill {
  id: string;
  name: string;
  description: string;
  category: string;
}

export type MasteryScore =
  | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
  | 10 | 11 | 12 | 13 | 14 | 15 | 16 | 17 | 18 | 19
  | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29
  | 30 | 31 | 32 | 33 | 34 | 35 | 36 | 37 | 38 | 39
  | 40 | 41 | 42 | 43 | 44 | 45 | 46 | 47 | 48 | 49
  | 50 | 51 | 52 | 53 | 54 | 55 | 56 | 57 | 58 | 59
  | 60 | 61 | 62 | 63 | 64 | 65 | 66 | 67 | 68 | 69
  | 70 | 71 | 72 | 73 | 74 | 75 | 76 | 77 | 78 | 79
  | 80 | 81 | 82 | 83 | 84 | 85 | 86 | 87 | 88 | 89
  | 90 | 91 | 92 | 93 | 94 | 95 | 96 | 97 | 98 | 99
  | 100;

export interface Mastery {
  learnerId: string;
  skillId: string;
  score: MasteryScore;
  updatedAt: string;
}

export type MasteryLevel = "beginner" | "developing" | "proficient" | "mastered";
export type MasterySourceType = "assessment_evaluation" | "submission_evaluation";

export interface UpdatedSkillMastery {
  skill_id: string;
  previous_score: number;
  new_score: number;
  delta: number;
  mastery_level: MasteryLevel;
  evidence_count: number;
}

export interface MasteryUpdateSummary {
  learner_id: string;
  source_type: MasterySourceType;
  source_id: string;
  updated_at: string;
  updated_skills: UpdatedSkillMastery[];
}

export interface SkillMasteryView {
  id: string;
  learner_id: string;
  skill_id: string;
  score: number;
  level: MasteryLevel;
  evidence_count: number;
  last_source_type: MasterySourceType | "";
  last_source_id: string;
  updated_at: string;
  created_at: string;
}

export interface MasteryEvidenceView {
  id: string;
  learner_id: string;
  skill_id: string;
  source_type: MasterySourceType;
  source_id: string;
  signal_score: number;
  confidence: number;
  weighted_score: number;
  evidence_summary: string;
  created_at: string;
}

export type SkillMapStatus = "locked" | "available" | "in_progress" | "mastered";
export type SkillMapEdgeType = "prerequisite" | "teaches" | "reinforces";

export interface SkillMapSummary {
  total_skills: number;
  mastered_count: number;
  proficient_count: number;
  developing_count: number;
  beginner_count: number;
  average_mastery: number;
}

export interface SkillMapSkill {
  skill_id: string;
  name: string;
  description: string;
  category: string;
  mastery_score: number;
  mastery_level: MasteryLevel;
  status: SkillMapStatus;
  evidence_count: number;
  target_lesson_ids: string[];
}

export interface SkillMapEdge {
  from_skill_id: string;
  to_skill_id: string;
  type: SkillMapEdgeType;
}

export interface SkillMapView {
  learner_id: string;
  language: "python" | "jac";
  roadmap_id: string;
  summary: SkillMapSummary;
  skills: SkillMapSkill[];
  edges: SkillMapEdge[];
  generated_at: string;
}

export type RoadmapStatus = "draft" | "active" | "completed";
export type RoadmapLessonGenerationStatus = "pending" | "generated";

export interface RoadmapLessonOutline {
  id: string;
  roadmap_id: string;
  week_id: string;
  title: string;
  summary: string;
  target_skill_ids: string[];
  difficulty: Difficulty;
  estimated_minutes: number;
  order_index: number;
  generation_status: RoadmapLessonGenerationStatus;
}

export interface RoadmapMilestone {
  id: string;
  roadmap_id: string;
  week_id: string;
  title: string;
  description: string;
  required_skill_ids: string[];
}

export interface RoadmapWeek {
  id: string;
  roadmap_id: string;
  week_number: number;
  title: string;
  summary: string;
  lessons: RoadmapLessonOutline[];
  milestones: RoadmapMilestone[];
}

export interface RoadmapSummary {
  id: string;
  learner_id: string;
  language: "python" | "jac";
  title: string;
  description: string;
  estimated_weeks: number;
  status: RoadmapStatus;
  created_at: string;
  weeks: RoadmapWeek[];
  lessons: RoadmapLessonOutline[];
  milestones: RoadmapMilestone[];
}

export type RoadmapLessonView = RoadmapLessonOutline;
export type RoadmapMilestoneView = RoadmapMilestone;
export type RoadmapWeekView = RoadmapWeek;
export type RoadmapView = RoadmapSummary;

export type LessonUnlockState = "locked" | "available" | "in_progress" | "completed";
export type RoadmapProgressStatus = "not_started" | "in_progress" | "completed";
export type ProgressionEventType =
  | "lesson_unlocked"
  | "lesson_completed"
  | "roadmap_started"
  | "roadmap_completed";
export type ProgressionSourceType = "lesson_completion" | "submission_evaluation" | "manual_check";

export interface LessonProgressView {
  roadmap_lesson_id: string;
  title: string;
  status: LessonUnlockState;
  unlock_reason: string;
  locked_reason: string;
  completed_at: string;
  unlocked_at: string;
}

export interface RoadmapProgressView {
  id: string;
  learner_id: string;
  roadmap_id: string;
  total_lessons: number;
  completed_lessons: number;
  available_lessons: number;
  locked_lessons: number;
  percent_complete: number;
  current_roadmap_lesson_id: string;
  status: RoadmapProgressStatus;
  updated_at: string;
}

export interface ProgressionEventView {
  id: string;
  learner_id: string;
  roadmap_id: string;
  roadmap_lesson_id: string;
  event_type: ProgressionEventType;
  source_type: ProgressionSourceType | "";
  source_id: string;
  message: string;
  created_at: string;
}

export interface ProgressionResult {
  learner_id: string;
  roadmap_id: string;
  current_lesson: LessonProgressView | null;
  newly_unlocked_lessons: LessonProgressView[];
  locked_lessons: LessonProgressView[];
  completed_lessons: LessonProgressView[];
  roadmap_progress: RoadmapProgressView | null;
  events: ProgressionEventView[];
  roadmap_completed: boolean;
  message: string;
}

export type DashboardState =
  | "no_assessment"
  | "assessment_started"
  | "assessment_completed"
  | "roadmap_missing"
  | "roadmap_ready"
  | "in_progress"
  | "completed"
  | "ready";

export interface DashboardLearnerSummary {
  learner_id: string;
  name: string;
}

export interface DashboardRoadmapSummary {
  roadmap_id: string;
  language: "python" | "jac";
  title: string;
  status: RoadmapStatus;
}

export interface DashboardRoadmapProgress {
  total_lessons: number;
  completed_lessons: number;
  available_lessons: number;
  locked_lessons: number;
  percent_complete: number;
  current_roadmap_lesson_id: string;
}

export interface DashboardSkillSummary {
  skill_id: string;
  name: string;
  score: number;
  level: MasteryLevel;
}

export interface DashboardMasterySummary {
  average_mastery: number;
  mastered_count: number;
  proficient_count: number;
  developing_count: number;
  beginner_count: number;
  strongest_skills: DashboardSkillSummary[];
  weakest_skills: DashboardSkillSummary[];
}

export interface DashboardLessonSummary {
  total_lessons: number;
  generated_lessons: number;
  pending_lessons: number;
  completed_lessons: number;
  available_lessons: number;
  locked_lessons: number;
  in_progress_lessons: number;
}

export interface DashboardChallengeSummary {
  generated_challenges: number;
  draft_submissions: number;
  submitted_challenges: number;
  evaluated_submissions: number;
  passed_challenges: number;
  failed_challenges: number;
}

export interface DashboardCurrentLesson {
  roadmap_lesson_id: string;
  title: string;
  summary: string;
  week_number: number;
  order_index: number;
  status: LessonUnlockState;
  generation_status: RoadmapLessonGenerationStatus;
  generated_lesson_id: string;
  challenge_id: string;
}

export interface DashboardRecentActivity {
  type: string;
  title: string;
  description: string;
  timestamp: string;
  related_entity_id: string;
}

export interface DashboardView {
  learner: DashboardLearnerSummary;
  active_roadmap: DashboardRoadmapSummary | null;
  roadmap_progress: DashboardRoadmapProgress;
  mastery_summary: DashboardMasterySummary;
  lesson_summary: DashboardLessonSummary;
  challenge_summary: DashboardChallengeSummary;
  current_lesson: DashboardCurrentLesson | null;
  recent_activity: DashboardRecentActivity[];
  dashboard_state: DashboardState;
}

export type TutorRecommendationType =
  | "start_assessment"
  | "generate_roadmap"
  | "start_roadmap"
  | "continue_lesson"
  | "generate_lesson"
  | "start_challenge"
  | "retry_challenge"
  | "review_lesson"
  | "practice_weak_skill"
  | "view_skill_map"
  | "completed";

export type TutorRecommendationPriority = "low" | "medium" | "high";

export interface TutorRecommendationView {
  learner_id: string;
  roadmap_id: string;
  language: "python" | "jac" | "";
  recommendation_type: TutorRecommendationType;
  title: string;
  recommended_action: string;
  explanation: string;
  confidence: number;
  priority: TutorRecommendationPriority;
  related_roadmap_lesson_id: string;
  related_challenge_id: string;
  related_skill_ids: string[];
  suggested_cta_label: string;
  created_at: string;
}
