import { CheckCircle2, XCircle, Sparkles, Loader2, Target, Lightbulb } from "lucide-react";
import type { EvaluateAnswerResponse } from "../types/evaluation";

interface Props {
  feedback: EvaluateAnswerResponse | null;
  loading: boolean;
}

export default function QuizPanel({ feedback, loading }: Props) {
  return (
    <aside className="col-span-12 md:col-span-3 flex flex-col h-full bg-white/5 border border-white/10 rounded-3xl p-6 backdrop-blur-md">
      <div className="flex items-center gap-2 mb-6">
        <Target className="text-primary w-5 h-5" />
        <h2 className="text-xl font-satoshi font-bold text-white">Evaluation</h2>
      </div>

      <div className="flex-1 flex flex-col justify-center">
        {loading ? (
          <div className="flex flex-col items-center justify-center py-10 animate-in fade-in zoom-in duration-300">
            <div className="relative mb-4">
              <Loader2 className="w-12 h-12 text-primary animate-spin" />
              <Sparkles className="absolute -top-1 -right-1 w-4 h-4 text-yellow-500 animate-pulse" />
            </div>
            <p className="text-slate-400 font-jakarta font-medium text-center animate-pulse">
              AI is analyzing your code...
            </p>
          </div>
        ) : !feedback ? (
          <div className="text-center py-10 border border-dashed border-white/10 rounded-2xl bg-white/2">
            <Lightbulb className="mx-auto text-slate-600 mb-3" size={28} />
            <p className="text-slate-500 text-sm italic font-sans px-4">
              Submit your reflection answers to receive real-time feedback.
            </p>
          </div>
        ) : (
          <div className="animate-in slide-in-from-bottom-4 duration-500 space-y-6">
            {/* Status Badge */}
            <div
              className={`flex items-center gap-3 p-4 rounded-2xl border-2 transition-all ${
                feedback.correct
                  ? "bg-green-500/10 border-green-500/20 text-green-400"
                  : "bg-red-500/10 border-red-500/20 text-red-400"
              }`}
            >
              {feedback.correct ? (
                <CheckCircle2 className="w-6 h-6 shrink-0" />
              ) : (
                <XCircle className="w-6 h-6 shrink-0" />
              )}
              <span className="font-jakarta font-bold text-lg">
                {feedback.correct ? "Excellent Work!" : "Almost There"}
              </span>
            </div>

            {/* Score Ring Section */}
            <div className="flex items-center justify-center py-4">
              <div className="relative flex items-center justify-center">
                <svg className="w-24 h-24 transform -rotate-90">
                  <circle
                    cx="48" cy="48" r="40"
                    stroke="currentColor" strokeWidth="6" fill="transparent"
                    className="text-white/5"
                  />
                  <circle
                    cx="48" cy="48" r="40"
                    stroke="currentColor" strokeWidth="6" fill="transparent"
                    strokeDasharray={251.2}
                    strokeDashoffset={251.2 - (251.2 * feedback.score)}
                    strokeLinecap="round"
                    className={`transition-all duration-1000 ease-out ${
                        feedback.correct ? "text-green-500" : "text-amber-500"
                    }`}
                  />
                </svg>
                <div className="absolute flex flex-col items-center">
                  <span className="text-2xl font-satoshi font-black text-white">
                    {(feedback.score * 100).toFixed(0)}
                  </span>
                  <span className="text-[10px] text-slate-500 uppercase font-bold tracking-tighter">Score</span>
                </div>
              </div>
            </div>

            {/* Feedback Message */}
            <div className="bg-white/5 rounded-2xl p-4 border border-white/5">
              <div className="flex items-center gap-2 mb-2 text-slate-400">
                <Sparkles size={14} className="text-primary" />
                <span className="text-[10px] font-black uppercase tracking-widest">Tutor Notes</span>
              </div>
              <p className="text-sm text-slate-300 leading-relaxed font-sans">
                {feedback.feedback}
              </p>
            </div>
          </div>
        )}
      </div>

      {/* Persistence Tip */}
      {!loading && feedback && !feedback.correct && (
        <div className="mt-6 p-3 bg-blue-500/10 border border-blue-500/20 rounded-xl">
           <p className="text-[11px] text-blue-300 text-center font-medium">
             💡 Pro Tip: Check your logic for syntax errors and try again!
           </p>
        </div>
      )}
    </aside>
  );
}