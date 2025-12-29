import { motion, AnimatePresence } from "framer-motion";
import { CheckCircle } from "lucide-react";

export function LessonUnlockToast({ visible }: { visible: boolean }) {
  return (
    <AnimatePresence>
      {visible && (
        <motion.div
          initial={{ opacity: 0, y: 20, scale: 0.95 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          exit={{ opacity: 0, y: 10 }}
          transition={{ duration: 0.35, ease: "easeOut" }}
          className="fixed bottom-6 right-6 z-50
                     bg-emerald-500/15 backdrop-blur-xl
                     border border-emerald-500/30
                     px-4 py-3 rounded-xl
                     flex items-center gap-3 shadow-xl"
        >
          <CheckCircle className="text-emerald-400" size={18} />
          <span className="text-sm font-semibold text-emerald-300">
            New lesson unlocked 🎉
          </span>
        </motion.div>
      )}
    </AnimatePresence>
  );
}
