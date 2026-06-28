export type AssessmentStatus = "draft" | "active" | "completed";
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

export interface Challenge {
  id: string;
  title: string;
  description: string;
  skillId: string;
  difficulty: Difficulty;
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
