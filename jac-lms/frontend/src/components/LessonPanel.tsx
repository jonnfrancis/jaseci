import { BookOpen, MessageSquare, Sparkles, GraduationCap, CheckCircle } from "lucide-react";
import type { Lesson } from "../types/lesson";
import type { Quiz } from "../types/quiz";

interface Props {
  lesson: Lesson | null;
  quiz: Quiz | null;
}

export default function LessonPanel({ lesson, quiz }: Props) {
  if (!lesson) return <EmptyLessonState />;

  return (
    <aside className="col-span-12 md:col-span-3 flex flex-col gap-5 h-full overflow-y-auto custom-scrollbar pr-2">
      
      {/* Lesson Title Card */}
      <section className="bg-white/5 border border-white/10 rounded-2xl p-5 backdrop-blur-md relative overflow-hidden group">
        <div className="absolute -right-2 -top-2 opacity-10 group-hover:scale-110 group-hover:opacity-20 transition-all">
          <GraduationCap size={80} />
        </div>
        
        <div className="flex items-center gap-2 text-primary mb-2">
          <Sparkles size={16} className="animate-pulse" />
          <span className="text-[10px] font-black uppercase tracking-widest">Active Lesson</span>
        </div>
        
        <h2 className="text-xl font-satoshi font-bold text-white leading-tight">
          {lesson.title}
        </h2>
      </section>

      {/* Content Area */}
      <section className="flex-1 space-y-4">
        <div className="flex items-center gap-2 px-1 text-slate-400">
          <BookOpen size={18} />
          <h3 className="font-jakarta font-bold text-sm tracking-wide uppercase">Content</h3>
        </div>
        
        <div className="bg-white/3 border border-white/5 rounded-2xl p-5">
          <p className="text-slate-300 leading-relaxed font-sans text-[15px] selection:bg-primary/30">
            {lesson.content}
          </p>
        </div>
      </section>

      {/* Interactive Questions Section */}
      {quiz?.questions && quiz.questions.length > 0 && (
        <section className="mt-auto pt-4 border-t border-white/10 space-y-4">
          <div className="flex items-center justify-between px-1">
            <div className="flex items-center gap-2 text-slate-400">
              <MessageSquare size={18} />
              <h3 className="font-jakarta font-bold text-sm tracking-wide uppercase">Reflection</h3>
            </div>
            <span className="text-[10px] bg-primary/20 text-primary px-2 py-0.5 rounded-full font-bold">
              {quiz.questions.length} Qs
            </span>
          </div>

          <div className="space-y-3">
            {quiz.questions.map((q, idx) => (
              <div 
                key={idx} 
                className="flex gap-3 p-3 rounded-xl bg-white/5 border border-white/5 hover:border-white/20 transition-all cursor-default group"
              >
                <div className="mt-1 shrink-0">
                  <CheckCircle size={14} className="text-slate-600 group-hover:text-primary transition-colors" />
                </div>
                <p className="text-sm text-slate-400 group-hover:text-slate-200 transition-colors leading-snug">
                  {q}
                </p>
              </div>
            ))}
          </div>
        </section>
      )}
    </aside>
  );
}

function EmptyLessonState() {
  return (
    <aside className="col-span-3 flex flex-col items-center justify-center text-center p-10 bg-white/5 rounded-2xl border border-dashed border-white/10">
      <div className="bg-white/5 p-4 rounded-full mb-4">
        <BookOpen className="text-slate-600" size={32} />
      </div>
      <p className="text-slate-500 font-medium italic">Select a lesson to begin</p>
    </aside>
  );
}
