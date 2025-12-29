import { Link } from "react-router-dom";
import Button from "../components/Button";
import { ArrowRight } from "lucide-react";

export default function Home() {
  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-center max-w-xl">
        <h1 className="text-4xl font-bold mb-6">
          Learn Jaseci Interactively
        </h1>
        <p className="text-slate-400 mb-8">
          A Scrimba-style learning platform powered by Jaseci + AI.
        </p>
        <Link
          to="/signin"
          className="inline-block bg-accent text-black px-6 py-3 rounded-xl font-semibold"
        >
          <Button variant="glass" icon={ArrowRight}>
            Get Started
          </Button>
        </Link>
      </div>
    </div>
  );
}
