import { useState, useEffect } from "react";
import Editor from "@monaco-editor/react";
import { motion, AnimatePresence } from "motion/react";
import { Play, Code2, Terminal, Loader2 } from "lucide-react";
import Button from "./Button";

interface Props {
  onRun: (code: string) => void;
  loading: boolean;
  starterCode?: string;
}

export default function CodeWorkspace({ onRun, loading, starterCode }: Props) {
  const [code, setCode] = useState<string>(starterCode || `walker hello_world {
    can run with entry {
      report "Hello from Jaseci!";
    }
  }`);

  // Sync starter code if it changes via props
  useEffect(() => {
    if (starterCode) setCode(starterCode);
  }, [starterCode]);

  return (
    <main className="col-span-12 lg:col-span-6 flex flex-col h-full gap-3">
      {/* Editor Header */}
      <header className="flex justify-between items-center bg-white/5 border border-white/10 rounded-2xl px-4 py-2 backdrop-blur-md">
        <div className="flex items-center gap-3">
          <div className="bg-primary/20 p-1.5 rounded-lg">
            <Code2 size={18} className="text-primary" />
          </div>
          <div>
            <h2 className="text-sm font-jakarta font-bold text-white leading-none">Main.jac</h2>
            <span className="text-[10px] text-slate-500 font-medium uppercase tracking-widest">Jaseci Source</span>
          </div>
        </div>

        <Button
          onClick={() => onRun(code)}
          isLoading={loading}
          variant={loading ? "glass" : "primary"}
          size="sm"
          icon={Play}
          className="shadow-xl shadow-primary/20"
        >
          {loading ? "Running..." : "Evaluate Code"}
        </Button>
      </header>

      {/* Main Editor Container */}
      <div className="relative flex-1 group">
        {/* Animated Pulsing Border (Visible only when loading) */}
        <AnimatePresence>
          {loading && (
            <motion.div
              animate={{ scale: [1, 1.01, 1], opacity: [0.4, 0.8, 0.4] }}
              transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
              className="absolute -inset-0.5 rounded-[18px] z-0"
              style={{
                background: "linear-gradient(90deg, #3b82f6, #8b5cf6, #3b82f6)",
                backgroundSize: "200% 200%",
              }}
            >
              <motion.div 
                className="absolute inset-0 rounded-[18px] bg-primary/20 blur-md"
                animate={{ opacity: [0.3, 0.6, 0.3] }}
                transition={{ duration: 1.5, repeat: Infinity }}
              />
            </motion.div>
          )}
        </AnimatePresence>

        {/* Editor Body */}
        <div className={`relative z-10 h-full w-full bg-[#1e1e1e] rounded-2xl overflow-hidden border transition-all duration-500 ${
          loading ? "border-transparent" : "border-white/10 group-hover:border-white/20"
        }`}>
          {/* Editor Toolstrip */}
          <div className="h-8 bg-black/20 flex items-center px-4 justify-between border-b border-white/5">
             <div className="flex gap-1.5">
                <div className="w-2.5 h-2.5 rounded-full bg-red-500/20" />
                <div className="w-2.5 h-2.5 rounded-full bg-amber-500/20" />
                <div className="w-2.5 h-2.5 rounded-full bg-green-500/20" />
             </div>
             <Terminal size={14} className="text-slate-600" />
          </div>

          <Editor
            height="calc(100% - 32px)"
            theme="vs-dark"
            defaultLanguage="python" 
            value={code}
            onChange={(value) => setCode(value || "")}
            options={{
              fontSize: 14,
              fontFamily: "JetBrains Mono, Menlo, monospace",
              minimap: { enabled: false },
              automaticLayout: true,
              wordWrap: "on",
              padding: { top: 16 },
              smoothScrolling: true,
              cursorBlinking: "expand",
              lineNumbersMinChars: 3,
            }}
          />

          {/* Loading Overlay Micro-interaction */}
          {loading && (
            <div className="absolute inset-0 z-20 bg-slate-950/20 backdrop-blur-[1px] flex items-center justify-center">
               <div className="bg-slate-900/80 border border-white/10 px-4 py-2 rounded-full flex items-center gap-2 shadow-2xl">
                  <Loader2 size={16} className="text-primary animate-spin" />
                  <span className="text-xs font-jakarta text-white font-medium">Evaluating mastery...</span>
               </div>
            </div>
          )}
        </div>
      </div>
    </main>
  );
}
