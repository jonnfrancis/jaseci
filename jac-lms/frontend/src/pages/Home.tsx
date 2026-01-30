import { Link } from "react-router-dom";
import { motion } from "framer-motion";
import { ArrowRight, Code2, Cpu, Globe, Sparkles } from "lucide-react";
import Button from "../components/Button";

// Animation Variants
const fadeInUp = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.6, ease: "easeOut" } }
};

const staggerContainer = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.1, delayChildren: 0.2 }
  }
};

export default function Home() {
  return (
    <div className="min-h-[calc(100vh-64px)] bg-slate-950 text-white relative overflow-hidden font-sans">
      
      {/* Background Section with Floating Physics */}
      <div className="absolute inset-0 z-0">
        <div className="absolute top-0 left-0 w-full h-full opacity-20 bg-[radial-gradient(#2e1065_1px,transparent_1px)] [background-size:40px_40px]" />
        
        {/* Animated Glow Orbs */}
        <motion.div 
          animate={{ 
            scale: [1, 1.2, 1],
            x: [0, 30, 0],
            y: [0, -20, 0] 
          }}
          transition={{ duration: 8, repeat: Infinity, ease: "easeInOut" }}
          className="absolute top-[-10%] left-[-10%] w-[50%] h-[50%] rounded-full bg-primary/20 blur-[120px]" 
        />
        <motion.div 
          animate={{ 
            scale: [1, 1.1, 1],
            x: [0, -40, 0],
            y: [0, 30, 0] 
          }}
          transition={{ duration: 10, repeat: Infinity, ease: "easeInOut", delay: 1 }}
          className="absolute bottom-[10%] right-[-5%] w-[40%] h-[40%] rounded-full bg-blue-600/10 blur-[100px]" 
        />
      </div>

      <div className="max-w-7xl mx-auto px-6 py-20 relative z-10 grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
        
        {/* Left Column: Staggered Content */}
        <motion.div 
          initial="hidden"
          animate="visible"
          variants={staggerContainer}
          className="space-y-8"
        >
          <motion.div variants={fadeInUp} className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-primary/10 border border-primary/20 text-primary text-xs font-bold uppercase tracking-widest">
            <Sparkles size={14} />
            Powered by Jaseci & AI
          </motion.div>
          
          <motion.h1 variants={fadeInUp} className="text-5xl md:text-7xl font-satoshi font-black leading-[1.1] tracking-tight">
            Master the Art of <br />
            <motion.span 
              animate={{ backgroundPosition: ["0% 50%", "100% 50%", "0% 50%"] }}
              transition={{ duration: 5, repeat: Infinity, ease: "linear" }}
              style={{ backgroundSize: "200% auto" }}
              className="bg-gradient-to-r from-primary via-blue-400 to-indigo-500 bg-clip-text text-transparent"
            >
              Agentic Coding
            </motion.span>
          </motion.h1>
          
          <motion.p variants={fadeInUp} className="text-lg text-slate-400 max-w-lg leading-relaxed font-jakarta">
            A Scrimba-style interactive learning platform. Build complex AI workflows and OSP graphs with hands-on, real-time feedback.
          </motion.p>

          <motion.div variants={fadeInUp} className="flex flex-wrap gap-4">
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
          </motion.div>

          {/* Social Proof / Stats Strip */}
          <motion.div variants={fadeInUp} className="pt-8 border-t border-white/5 flex gap-8">
            <Stat label="Active Learners" value="1.2k+" />
            <Stat label="Lessons" value="50+" />
            <Stat label="AI Models" value="24/7" />
          </motion.div>
        </motion.div>

        {/* Right Column: Grid with Individual Hover Physics */}
        <motion.div 
          initial="hidden"
          animate="visible"
          variants={staggerContainer}
          className="relative"
        >
          <div className="grid grid-cols-2 gap-4">
            <FeatureCard 
              variants={fadeInUp}
              icon={<Code2 className="text-blue-400" />} 
              title="Graph-Native" 
              desc="Visualize OSP graphs as you code."
              className="mt-8"
            />
            <FeatureCard 
              variants={fadeInUp}
              icon={<Cpu className="text-purple-400" />} 
              title="AI Tutors" 
              desc="Real-time evaluation for every lesson."
            />
            <FeatureCard 
              variants={fadeInUp}
              icon={<Globe className="text-green-400" />} 
              title="Deployment" 
              desc="One-click ship your walkers to production."
              className="mt-8"
            />
            <FeatureCard 
              variants={fadeInUp}
              icon={<Sparkles className="text-yellow-400" />} 
              title="Interactive" 
              desc="Hands-on coding directly in the browser."
            />
          </div>
          
          {/* Floating Orb Illustration */}
          <motion.div 
            animate={{ 
              scale: [1, 1.1, 1],
              rotate: [0, 5, 0]
            }}
            transition={{ duration: 6, repeat: Infinity, ease: "easeInOut" }}
            className="absolute -z-10 top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-64 h-64 bg-primary/30 rounded-full blur-3xl" 
          />
        </motion.div>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <motion.div whileHover={{ y: -5 }} className="cursor-default">
      <p className="text-2xl font-satoshi font-black text-white">{value}</p>
      <p className="text-xs text-slate-500 uppercase tracking-widest">{label}</p>
    </motion.div>
  );
}

function FeatureCard({ icon, title, desc, className = "", variants }: any) {
  return (
    <motion.div 
      variants={variants}
      whileHover={{ 
        y: -10, 
        backgroundColor: "rgba(255, 255, 255, 0.08)",
        borderColor: "rgba(99, 102, 241, 0.4)" 
      }}
      className={`p-6 rounded-3xl bg-white/5 border border-white/10 backdrop-blur-xl transition-colors ${className}`}
    >
      <motion.div 
        whileHover={{ rotate: 15, scale: 1.1 }}
        className="mb-4 bg-white/5 w-fit p-3 rounded-2xl"
      >
        {icon}
      </motion.div>
      <h3 className="font-jakarta font-bold text-white mb-2">{title}</h3>
      <p className="text-sm text-slate-400 leading-relaxed">{desc}</p>
    </motion.div>
  );
}
