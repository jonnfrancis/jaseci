import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import { v4 as uuidv4 } from 'uuid';
import { User, Lock, ArrowRight, Sparkles } from "lucide-react";

import Button from "../components/Button";
import { createUser, login } from "../lib/auth";
import { spawn } from "../lib/jaseci";

// 1. Define Validation Schema with Zod
const authSchema = z.object({
  username: z.string().min(3, "Username must be at least 3 characters"),
  password: z.string().min(6, "Password must be at least 6 characters"),
});

type AuthFormData = z.infer<typeof authSchema>;

export default function UserAuth() {
  const [isLogin, setIsLogin] = useState(true);
  const [serverError, setServerError] = useState("");
  const [isLoading, setIsLoading] = useState(false);
  const navigate = useNavigate();

  // 2. Initialize React Hook Form
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<AuthFormData>({
    resolver: zodResolver(authSchema),
  });

  const onSubmit = async (values: AuthFormData) => {
    setIsLoading(true);
    setServerError("");
    
    try {
      if (isLogin) {
        // Login Logic
        const userId = localStorage.getItem("userId") || "";
        const data = await login(userId, values.username, values.password);
        
        if (data?.token) {
          localStorage.setItem("token", data.token);

          await spawn("initialize_learning_graph", { 
            user_id: userId,
            name: values.username
          });
          
          navigate("/learn");
        }
      } else {
        // Register Logic
        const userId = uuidv4();
        const data = await createUser(userId, values.username, values.password);
        
        if (userId) localStorage.setItem("userId", userId);
        if (data?.token) {
          localStorage.setItem("token", data.token);
          
          // Initialize Graph
          await spawn("initialize_learning_graph", { 
            user_id: userId,
            name: values.username
          });
          
          navigate("/learn");
        }
      }
    } catch (err) {
      setServerError("Authentication failed. Please check your credentials.");
      console.error(err);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen w-full flex items-center justify-center bg-slate-950 relative overflow-hidden px-4 font-sans">
      {/* Background Decor */}
      <div className="absolute top-1/4 left-1/4 w-64 h-64 bg-primary/20 blur-[120px] rounded-full" />
      <div className="absolute bottom-1/4 right-1/4 w-64 h-64 bg-blue-500/10 blur-[120px] rounded-full" />

      <div className="w-full max-w-md z-10">
        <div className="bg-white/5 border border-white/10 backdrop-blur-xl rounded-3xl p-8 shadow-2xl">
          
          {/* Header */}
          <div className="text-center mb-8">
            <div className="inline-flex p-3 rounded-2xl bg-primary/10 text-primary mb-4">
              <Sparkles size={28} />
            </div>
            <h1 className="text-3xl font-satoshi font-bold text-white mb-2">
              {isLogin ? "Welcome Back" : "Create Account"}
            </h1>
            <p className="text-slate-400 text-sm">
              {isLogin ? "Continue your learning journey" : "Start your path to mastery today"}
            </p>
          </div>

          <form onSubmit={handleSubmit(onSubmit)} className="space-y-5">
            {/* Username Input */}
            <div className="space-y-2">
              <label className="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">Username</label>
              <div className="relative group">
                <User className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500 group-focus-within:text-primary transition-colors" size={18} />
                <input
                  {...register("username")}
                  type="text"
                  placeholder="johndoe"
                  className="w-full bg-white/5 border border-white/10 rounded-xl py-3 pl-12 pr-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all"
                />
              </div>
              {errors.username && <p className="text-red-400 text-xs mt-1 ml-1">{errors.username.message}</p>}
            </div>

            {/* Password Input */}
            <div className="space-y-2">
              <label className="text-xs font-bold text-slate-400 uppercase tracking-widest ml-1">Password</label>
              <div className="relative group">
                <Lock className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500 group-focus-within:text-primary transition-colors" size={18} />
                <input
                  {...register("password")}
                  type="password"
                  placeholder="••••••••"
                  className="w-full bg-white/5 border border-white/10 rounded-xl py-3 pl-12 pr-4 text-white placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-primary/50 focus:border-primary transition-all"
                />
              </div>
              {errors.password && <p className="text-red-400 text-xs mt-1 ml-1">{errors.password.message}</p>}
            </div>

            {serverError && (
              <div className="p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-400 text-xs text-center">
                {serverError}
              </div>
            )}

            <Button 
              type="submit" 
              className="w-full py-4 rounded-xl mt-2" 
              isLoading={isLoading}
              variant="primary"
              icon={ArrowRight}
            >
              {isLogin ? "Sign In" : "Register Now"}
            </Button>
          </form>

          {/* Toggle */}
          <div className="mt-8 text-center">
            <button 
              onClick={() => setIsLogin(!isLogin)}
              className="text-slate-400 text-sm hover:text-white transition-colors"
            >
              {isLogin ? "Don't have an account? " : "Already have an account? "}
              <span className="text-primary font-bold">{isLogin ? "Sign Up" : "Log In"}</span>
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
