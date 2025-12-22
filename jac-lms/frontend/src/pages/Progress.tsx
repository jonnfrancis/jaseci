import { useEffect, useState } from "react";
import { spawn } from "../lib/jaseci";
import type { SkillNode } from "../types/skill";
import { CheckCircle2, Lock, LayoutGrid, Trophy } from "lucide-react";

interface JaseciResponse {
  reports: Array<{
    topics: SkillNode[];
  }>;
}

export default function Progress() {
  const [skills, setSkills] = useState<SkillNode[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function loadSkillMap() {
      try {
        // Calling your Jaseci walker
        const response = await spawn<JaseciResponse>("get_skill_map", {
          user: { user_id: "user_123", name: "John Doe" },
        });

        // Mapping logic: Accessing reports[0].topics from your JSON structure
        if (response.reports && response.reports[0]?.topics) {
          setSkills(response.reports[0].topics);
        }

        console.log("Skill map loaded:", skills);
      } catch (err) {
        console.error(err);
      } finally {
        setLoading(false);
      }
    }
    loadSkillMap();
  }, []);

  if (loading) return <ProgressSkeleton />;

  return (
    <div className="max-w-5xl h-dvh mx-auto p-6 lg:p-10">
      {/* Header Section */}
      <header className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-10">
        <div>
          <h1 className="text-3xl font-bold text-white tracking-tight flex items-center gap-3">
            <Trophy className="text-yellow-500" /> Skill Progress
          </h1>
          <p className="text-slate-400 mt-1">Track your mastery and unlock new learning paths.</p>
        </div>
        <div className="bg-white/5 px-4 py-2 rounded-2xl border border-white/10 text-sm">
          <span className="text-slate-400 font-medium">Unlocked Topics: </span>
          <span className="text-primary font-bold">{skills.filter(s => s.unlocked).length} / {skills.length}</span>
        </div>
      </header>

      {/* Skills Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {skills.length > 0 ? (
          skills.map((skill) => <SkillCard key={skill.topic_id} skill={skill} />)
        ) : (
          <div className="col-span-full text-center py-20 bg-white/5 rounded-3xl border border-dashed border-white/10">
            <LayoutGrid className="mx-auto text-slate-600 mb-4" size={48} />
            <p className="text-slate-400">No skill data available yet.</p>
          </div>
        )}
      </div>
    </div>
  );
}

// Sub-component for individual skill cards
function SkillCard({ skill }: { skill: SkillNode }) {
  const masteryPercentage = Math.round(skill.mastery * 100);

  return (
    <div className={`relative group p-5 rounded-2xl border transition-all duration-300 ${
      skill.unlocked 
      ? "bg-white/5 border-white/10 hover:border-primary/50 hover:bg-white/8" 
      : "bg-black/20 border-white/5 opacity-70"
    }`}>
      <div className="flex justify-between items-start mb-4">
        <div>
          <h3 className="font-bold text-lg text-white group-hover:text-primary transition-colors">
            {skill.title}
          </h3>
          <p className="text-xs text-slate-500 uppercase tracking-wider font-semibold mt-1">
            Topic ID: {skill.topic_id}
          </p>
        </div>
        
        {skill.unlocked ? (
          <CheckCircle2 className="text-green-500 w-5 h-5" />
        ) : (
          <Lock className="text-slate-600 w-5 h-5" />
        )}
      </div>

      {/* Progress Bar Section */}
      <div className="space-y-2">
        <div className="flex justify-between text-sm">
          <span className="text-slate-400">Mastery</span>
          <span className="text-white font-mono">{masteryPercentage}%</span>
        </div>
        <div className="h-2 w-full bg-slate-800 rounded-full overflow-hidden">
          <div 
            className="h-full bg-linear-to-r from-primary to-blue-500 transition-all duration-1000 ease-out"
            style={{ width: `${masteryPercentage}%` }}
          />
        </div>
      </div>

      {/* Subtle Status Badge */}
      {!skill.unlocked && (
        <div className="absolute inset-0 bg-slate-950/40 backdrop-blur-[1px] flex items-center justify-center rounded-2xl opacity-0 group-hover:opacity-100 transition-opacity">
          <span className="bg-white/10 px-3 py-1 rounded-full text-xs text-white border border-white/20">
            Keep learning to unlock
          </span>
        </div>
      )}
    </div>
  );
}

// Professional Loading State
function ProgressSkeleton() {
  return (
    <div className="max-w-5xl mx-auto p-10 animate-pulse h-dvh">
      <div className="h-8 w-48 bg-white/10 rounded-lg mb-10" />
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {[1, 2, 3, 4].map((i) => (
          <div key={i} className="h-32 bg-white/5 rounded-2xl border border-white/10" />
        ))}
      </div>
    </div>
  );
}