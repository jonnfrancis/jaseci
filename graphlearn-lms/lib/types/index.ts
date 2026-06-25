export type AssessmentStatus = "draft" | "active" | "completed";

export type AssessmentQuestion = Record<string, string>;

export interface Assessment {
  id: string;
  title: string;
  description: string;
  status: AssessmentStatus;
  questions: AssessmentQuestion[];
  createdAt: string;
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

export interface Roadmap {
  id: string;
  learnerId: string;
  title: string;
  lessonIds: string[];
  createdAt: string;
}
