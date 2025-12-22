import { useEffect, useState } from "react";
import LearningWorkspace from "../components/LearningWorkspace";
import LessonPanel from "../components/LessonPanel";
import CodeWorkspace from "../components/CodeWorkspace";
import QuizPanel from "../components/QuizPanel";
import { spawn } from "../lib/jaseci";
import type { EvaluateAnswerResponse } from "../types/evaluation";
import type { Lesson } from "../types/lesson";
import type { Quiz } from "../types/quiz";

interface UnlockLessonResponse {
  reports: {
    unlocked_lessons: {
      topic: string;
      topic_difficulty: number;
      lesson_id: string;
      lesson_title: string;
      lesson_content: string;
      starter_code: string;
    }[];
  }[];
}

export default function Learn() {
  const [feedback, setFeedback] = useState<EvaluateAnswerResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [lesson, setLesson] = useState<Lesson | null>(null);
  const [quiz, setQuiz] = useState<Quiz | null>(null);

  useEffect(() => {
    async function loadLesson() {
      const response = await spawn<UnlockLessonResponse[]>(
        "unlock_next_lesson",
        {
          "user": {
            "user_id": "user_123",
            "name": "John Doe"
          }
        }
      );


      const lessonData = response?.reports[0]?.unlocked_lessons[0]

      if (!lessonData) {
        throw new Error("No unlocked lesson returned");
      }

      setLesson({
        lesson_id: lessonData.lesson_id,
        topic: lessonData.topic,
        title: lessonData.lesson_title,
        content: lessonData.lesson_content,
        starter_code: lessonData.starter_code,
      });
    }

    loadLesson();
  }, []);

  useEffect(() => {
    if (!lesson) return;

    async function loadQuiz() {
      const quizData = await spawn<Quiz>(
        "generate_quiz",
        {
          topic: lesson?.topic,
          lesson_id: lesson?.lesson_id,
        }
      );

      setQuiz(quizData);
    }

    loadQuiz();
  }, [lesson]);




  async function handleRun(code: string) {
    setLoading(true);
    try {
      const result = await spawn<EvaluateAnswerResponse>(
        "evaluate_answer",
        {
          user_id: "demo_user",
          lesson_id: "walkers_intro",
          code,
        }
      );
      setFeedback(result);
    } catch (err) {
      console.error(err);
      setFeedback({
        score: 0,
        correct: false,
        feedback: "An error occurred while evaluating your answer.",
      });
    } finally {
      setLoading(false);
    }
  }

  return (
    <LearningWorkspace>
      <LessonPanel lesson={lesson} quiz={quiz} />
      <CodeWorkspace starterCode={lesson?.starter_code} onRun={handleRun} loading={loading} />
      <QuizPanel feedback={feedback} loading={loading} />
    </LearningWorkspace>
  );
}
