"""Global application shell for GraphLearn LMS."""

import from "@jac/runtime" { AuthGuard, Route, Router, Routes }
import from "..features.auth.pages.LoginPage" { LoginPage }
import from "..features.auth.pages.RegisterPage" { RegisterPage }
import from "..features.assessment.pages.AssessmentJourneyPage" { AssessmentJourneyPage }
import from "..features.landing.pages.LandingPage" { LandingPage }
import from "..features.roadmap.pages.RoadmapPage" { RoadmapPage }

def:pub AppShell() -> JsxElement {
    return
        <Router>
            <Routes>
                <Route path="/" element={<LandingPage />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/register" element={<RegisterPage />} />
                <Route path="/assessment" element={<AssessmentJourneyPage />} />
                <Route path="/roadmap/:roadmapId" element={<RoadmapPage />} />
            </Routes>
        </Router>;
}
