import type { Lesson } from "../types/lesson";
import type { Quiz } from "../types/quiz";

interface Props {
  lesson: Lesson | null;
  quiz: Quiz | null;
}


export default function LessonPanel({ lesson, quiz }: Props) {
  return (
    <aside className="col-span-3 bg-surface rounded-xl p-4 overflow-y-auto">
      <h2 className="text-lg font-semibold mb-4">{lesson?.title}</h2>

      <p className="text-slate-300 mb-4">
        {lesson?.content}
      </p>

      {quiz?.questions && quiz.questions.length > 0 && (
        <>
          <h3 className="text-sm font-semibold mb-2 text-slate-400">
            Key Questions
          </h3>
          <ul className="list-disc ml-5 text-slate-400 space-y-1">
            {quiz?.questions.map((q, idx) => (
              <li key={idx}>{q}</li>
            ))}
          </ul>
        </>
      )}
    </aside>
  );
}
