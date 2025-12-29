import { Link } from "react-router-dom";
import { ArrowRight, Code2, Cpu, Globe, Sparkles } from "lucide-react";
import Button from "../components/Button";

export default function Home() {
  return (
    <div className="min-h-[calc(100vh-64px)] bg-slate-950 text-white relative overflow-hidden font-sans">
      
      {/* Background SVG Pattern & Glows */}
      <div className="absolute inset-0 z-0">
        <div className="absolute top-0 left-0 w-full h-full opacity-20 bg-[radial-gradient(#2e1065_1px,transparent_1px)] [background-size:40px_40px]" />
        <div className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-primary/20 blur-[120px]" />
        <div className="absolute bottom-[10%] right-[-5%] w-[40%] h-[40%] rounded-full bg-blue-600/10 blur-[100px]" />
      </div>

      <div className="max-w-7xl mx-auto px-6 py-20 relative z-10 grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
        
        {/* Left Column: Copy & CTA */}
        <div className="space-y-8 animate-in fade-in slide-in-from-left-8 duration-700">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/10 border border-primary/20 text-primary text-xs font-bold uppercase tracking-widest">
            <Sparkles size={14} />
            Powered by Jaseci & AI
          </div>
          
          <h1 className="text-5xl md:text-7xl font-satoshi font-black leading-[1.1] tracking-tight">
            Master the Art of <br />
            <span className="bg-linear-to-r from-primary via-blue-400 to-indigo-500 bg-clip-text text-transparent">
              Agentic Coding
            </span>
          </h1>
          
          <p className="text-lg text-slate-400 max-w-lg leading-relaxed font-jakarta">
            A Scrimba-style interactive learning platform. Build complex AI workflows and OSP graphs with hands-on, real-time feedback.
          </p>

          <div className="flex flex-wrap gap-4">
            <Link to="/signin">
              <Button variant="primary" size="lg" icon={ArrowRight}>
                Start Learning Now
              </Button>
            </Link>
            <Link to="/signin">
              <Button variant="glass" size="lg">
                Explore Docs
              </Button>
            </Link>
          </div>

          {/* Social Proof / Stats Strip */}
          <div className="pt-8 border-t border-white/5 flex gap-8">
            <Stat label="Active Learners" value="1.2k+" />
            <Stat label="Lessons" value="50+" />
            <Stat label="AI Models" value="24/7" />
          </div>
        </div>

        {/* Right Column: Abstract SVG Illustration / Feature Cards */}
        <div className="relative animate-in fade-in zoom-in duration-1000 delay-200">
          <div className="grid grid-cols-2 gap-4">
            <FeatureCard 
              icon={<Code2 className="text-blue-400" />} 
              title="Graph-Native" 
              desc="Visualize OSP graphs as you code."
              className="mt-8"
            />
            <FeatureCard 
              icon={<Cpu className="text-purple-400" />} 
              title="AI Tutors" 
              desc="Real-time evaluation for every lesson."
            />
            <FeatureCard 
              icon={<Globe className="text-green-400" />} 
              title="Deployment" 
              desc="One-click ship your walkers to production."
              className="mt-8"
            />
            <FeatureCard 
              icon={<Sparkles className="text-yellow-400" />} 
              title="Interactive" 
              desc="Hands-on coding directly in the browser."
            />
          </div>
          
          {/* Floating Orb Illustration */}
          <div className="absolute -z-10 top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-64 h-64 bg-primary/30 rounded-full blur-3xl animate-pulse" />
        </div>
      </div>
    </div>
  );
}

// Sub-components for clean code
function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-2xl font-satoshi font-black text-white">{value}</p>
      <p className="text-xs text-slate-500 uppercase tracking-widest">{label}</p>
    </div>
  );
}

function FeatureCard({ icon, title, desc, className = "" }: { icon: any; title: string; desc: string; className?: string }) {
  return (
    <div className={`p-6 rounded-3xl bg-white/5 border border-white/10 backdrop-blur-xl transition-all hover:-translate-y-2 hover:bg-white/[0.08] hover:border-primary/30 ${className}`}>
      <div className="mb-4 bg-white/5 w-fit p-3 rounded-2xl">{icon}</div>
      <h3 className="font-jakarta font-bold text-white mb-2">{title}</h3>
      <p className="text-sm text-slate-400 leading-relaxed">{desc}</p>
    </div>
  );
}
