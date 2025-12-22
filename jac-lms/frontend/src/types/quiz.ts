export interface QuizResponse {
  topic: string;
  difficulty: "easy" | "medium" | "hard";
  questions: string[];
}

export interface EvaluationResponse {
  score: number;
  feedback: string;
}

export interface Quiz {
  difficulty: string;
  questions: string[];
}