import { useEffect, useState } from "react";
import LearningWorkspace from "../components/LearningWorkspace";
import LessonPanel from "../components/LessonPanel";
import CodeWorkspace from "../components/CodeWorkspace";
import QuizPanel from "../components/QuizPanel";
import { spawn } from "../lib/jaseci";
import type { EvaluateAnswerResponse } from "../types/evaluation";
import type { Lesson } from "../types/lesson";
import type { Quiz } from "../types/quiz";
import { LessonUnlockToast } from "../components/LessonUnlocked";

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
  const [mastery, setMastery] = useState<number | null>(null);
  const [previousLessonId, setPreviousLessonId] = useState<string | null>(null);
  const [lessonUnlocked, setLessonUnlocked] = useState(false);

  const userId = localStorage.getItem("userId");

  useEffect(() => {
    async function loadLesson() {
      const response = await spawn<UnlockLessonResponse>(
        "unlock_next_lesson",
        {
          user_id: userId || "user_123",
        }
      );

      const lessonData = response?.reports[0]?.unlocked_lessons?.[response?.reports[0]?.unlocked_lessons.length - 1];

      console.log("Unlocked lesson data:", lessonData);

      if (!lessonData) {
        throw new Error("No unlocked lesson returned");
      }

      setLesson({
        lesson_id: lessonData.lesson_id,
        topic: lessonData.topic,
        title: lessonData.lesson_title,
        content: lessonData.lesson_content,
        starter_code: lessonData.starter_code,
        topic_difficulty: lessonData.topic_difficulty,
      });
      setPreviousLessonId(lessonData.lesson_id);
    }

    loadLesson();
  }, []);

  useEffect(() => {
    async function fetchMastery() {
      if (!lesson) return;

      const response = await spawn<{ reports: { topics: { title: string; mastery: number }[] }[] }>(
        "get_skill_map",
        {
          user_id: userId || "user_123",
        }
      );
      const topics = response?.reports?.[0]?.topics || [];

      const currentTopic = topics.find(
        (topic) => topic.title === lesson.topic
      );


      if (currentTopic) {
        console.log(`Mastery for topic '${lesson.topic}':`, currentTopic.mastery);
        setMastery(currentTopic.mastery);
      } else {
        console.log(`No mastery data found for topic '${lesson.topic}'.`);
      }
    }

    fetchMastery();
  }, [lesson]);

  useEffect(() => {
    if (!lesson) return;
    if (mastery === null) return;
    console.log("Fetching quiz for lesson:", lesson.title, "with mastery:", mastery);

    async function loadQuiz() {
      const response = await spawn<{ reports: { quiz: { difficulty: string; questions: string[] } }[] }>(
        "generate_quiz",
        {
          topic: lesson?.topic,
          mastery_score: mastery,
        }
      );

      const quizData = response?.reports?.[0]?.quiz;

      if (quizData) {
        console.log("Generated quiz data:", quizData);
        setQuiz({
          difficulty: quizData.difficulty,
          questions: quizData.questions,
        });
      } else {
        console.log("No quiz data returned.");
      }
    }

    loadQuiz();
  }, [lesson, mastery]);

  async function handleRun(code: string) {
    if (!lesson || !quiz) return;

    setLoading(true);

    try {
      // 1. evaluate_answer
      const result = await spawn<EvaluateAnswerResponse>(
        "evaluate_answer",
        {
          topic: lesson.topic,
          questions: quiz.questions,
          learner_answer: code,
        }
      );
      setFeedback(result?.reports[0]);

      console.log("Evaluation result:", result);


      // 2. progress_tracker
      await spawn("progress_tracker", {
        user_id: userId || "user_123",
        lesson_id: lesson.lesson_id,
        score: result?.reports[0]?.score || 0,
        completed_at: new Date().toISOString(),
      });
      // 3. unlock_next_lesson
      const unlockResponse = await spawn<UnlockLessonResponse>(
        "unlock_next_lesson",
        {
          user_id: userId || "user_123",
        }
      );
      // 4. update UI
      const nextLesson =
        unlockResponse?.reports[0]?.unlocked_lessons?.[unlockResponse?.reports[0]?.unlocked_lessons.length - 1];

      if (nextLesson && nextLesson.lesson_id !== previousLessonId) {
        setPreviousLessonId(nextLesson.lesson_id);
        setLesson({
          lesson_id: nextLesson.lesson_id,
          topic: nextLesson.topic,
          title: nextLesson.lesson_title,
          content: nextLesson.lesson_content,
          starter_code: nextLesson.starter_code,
          topic_difficulty: nextLesson.topic_difficulty,
        });

        setLessonUnlocked(true);
        setTimeout(() => setLessonUnlocked(false), 1800);
      }
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
      <CodeWorkspace
        starterCode={lesson?.starter_code}
        onRun={handleRun}
        loading={loading}
      />
      <QuizPanel feedback={feedback} loading={loading} />
      <LessonUnlockToast visible={lessonUnlocked} />
    </LearningWorkspace>
  );
}
