import type { EvaluateAnswerResponse } from "../types/evaluation";

interface Props {
  feedback: EvaluateAnswerResponse | null;
  loading: boolean;
}

export default function QuizPanel({ feedback, loading }: Props) {
  return (
    <aside className="col-span-3 bg-surface rounded-xl p-4">
      <h2 className="text-lg font-semibold mb-4">Feedback</h2>

      {loading && (
        <p className="text-slate-400">Evaluating your answer...</p>
      )}

      {!loading && !feedback && (
        <p className="text-slate-400">
          Run your code to get feedback.
        </p>
      )}

      {!loading && feedback && (
        <>
          <div
            className={`mb-3 p-3 rounded-md ${
              feedback.correct
                ? "bg-green-500/20 text-green-400"
                : "bg-red-500/20 text-red-400"
            }`}
          >
            {feedback.correct ? "Correct" : "Needs Improvement"}
          </div>

          <p className="text-sm text-slate-300 mb-3">
            {feedback.feedback}
          </p>

          <p className="text-sm text-slate-400">
            Score: {(feedback.score * 100).toFixed(0)}%
          </p>
        </>
      )}
    </aside>
  );
}
