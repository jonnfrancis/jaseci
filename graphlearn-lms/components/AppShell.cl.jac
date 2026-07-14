"""Global application shell for GraphLearn LMS."""

import from "@jac/runtime" { AuthGuard, Route, Router, Routes }
import from "..features.auth.pages.LoginPage" { LoginPage }
import from "..features.auth.pages.RegisterPage" { RegisterPage }
import from "..features.assessment.pages.AssessmentJourneyPage" { AssessmentJourneyPage }
import from "..features.challenge.pages.ChallengeWorkspacePage" { ChallengeWorkspacePage }
import from "..features.dashboard.pages.DashboardPage" { DashboardPage }
import from "..features.landing.pages.LandingPage" { LandingPage }
import from "..features.lesson.pages.LessonPage" { LessonPage }
import from "..features.roadmap.pages.RoadmapPage" { RoadmapPage }
import from "..features.skill_map.pages.SkillMapPage" { SkillMapPage }

def:pub AppShell() -> JsxElement {
    return
        <Router>
            <Routes>
                <Route path="/" element={<LandingPage />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/register" element={<RegisterPage />} />
                <Route path="/dashboard" element={<DashboardPage />} />
                <Route path="/assessment" element={<AssessmentJourneyPage />} />
                <Route path="/skill-map" element={<SkillMapPage />} />
                <Route path="/roadmap/:roadmapId" element={<RoadmapPage />} />
                <Route path="/roadmap/:roadmapId/skill-map" element={<SkillMapPage />} />
                <Route path="/roadmap/:roadmapId/lesson/:roadmapLessonId" element={<LessonPage />} />
                <Route path="/roadmap/:roadmapId/lesson/:roadmapLessonId/challenge/:challengeId" element={<ChallengeWorkspacePage />} />
            </Routes>
        </Router>;
}
