import { Link, NavLink } from "react-router-dom";
import { BookOpen, Activity, GraduationCap } from "lucide-react";

export default function Navbar() {
  return (
    <nav className="sticky top-0 z-50 h-16 w-full border-b border-white/10 bg-surface/80 backdrop-blur-md px-6 flex items-center justify-between">
      {/* Brand Section */}
      <Link to="/" className="flex items-center gap-2 group transition-all duration-300 hover:opacity-80">
        <div className="bg-primary/20 p-2 rounded-xl group-hover:scale-110 transition-transform">
          <GraduationCap className="w-6 h-6 text-primary" />
        </div>
        <span className="font-bold text-lg tracking-tight text-white">
          Jaseci <span className="text-primary">Learn</span>
        </span>
      </Link>

      {/* Navigation Links */}
      <div className="flex gap-1 items-center bg-white/5 p-1 rounded-full border border-white/5">
        <NavButton to="/learn" label="Learn" icon={<BookOpen size={18} />} />
        <NavButton to="/progress" label="Progress" icon={<Activity size={18} />} />
      </div>
    </nav>
  );
}

// Sub-component for clean, reusable link styling
function NavButton({ to, label, icon }: { to: string; label: string; icon: React.ReactNode }) {
  return (
    <NavLink
      to={to}
      className={({ isActive }) => `
        flex items-center gap-2 px-4 py-2 rounded-full text-sm font-medium transition-all duration-300
        ${isActive 
          ? "bg-white/10 text-white shadow-lg shadow-black/10 ring-1 ring-white/20" 
          : "text-slate-400 hover:text-white hover:bg-white/5"
        }
      `}
    >
      <span className="opacity-70">{icon}</span>
      {label}
    </NavLink>
  );
}