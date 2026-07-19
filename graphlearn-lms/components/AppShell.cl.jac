"""Global application shell for GraphLearn LMS."""

import from "@jac/runtime" { AuthGuard, Route, Router, Routes }
import from "..features.auth.pages.LoginPage" { LoginPage }
import from "..features.auth.pages.RegisterPage" { RegisterPage }
import from "..features.auth.pages.WorkspacePages" { IdentityRecoveryPage, WorkspaceChooserPage }
import from "..features.assessment.pages.AssessmentJourneyPage" { AssessmentJourneyPage }
import from "..features.challenge.pages.ChallengeWorkspacePage" { ChallengeWorkspacePage }
import from "..features.dashboard.pages.DashboardPage" { DashboardPage }
import from "..features.landing.pages.LandingPage" { LandingPage }
import from "..features.lesson.pages.LessonPage" { LessonPage }
import from "..features.roadmap.pages.RoadmapPage" { RoadmapPage }
import from "..features.skill_map.pages.SkillMapPage" { SkillMapPage }
import from "..features.lecturer.pages.CreateCoursePage" { CreateCoursePage }
import from "..features.lecturer.pages.CourseWorkspacePage" { CourseWorkspacePage }
import from "..features.lecturer.pages.CourseInterpretationPage" { CourseInterpretationPage }
import from "..features.lecturer.pages.BlueprintReviewPage" { BlueprintReviewPage }
import from "..features.lecturer.pages.CoursePublicationPage" { CoursePublicationPage }
import from "..features.lecturer.pages.CourseListPage" { CourseListPage }
import from "..features.lecturer.pages.LecturerOnboardingPage" { LecturerOnboardingPage }
import from "..features.lecturer.pages.LecturerStatusPage" { LecturerStatusPage }
import from "..features.lecturer.pages.LecturerRestrictedPage" { LecturerRestrictedPage }
import from "..features.lecturer.components.LecturerGuard" { LecturerGuard }

def:pub AppShell() -> JsxElement {
    return
        <Router>
            <Routes>
                <Route path="/" element={<LandingPage />} />
                <Route path="/login" element={<LoginPage />} />
                <Route path="/register" element={<RegisterPage />} />
                <Route path="/identity/recovery" element={<IdentityRecoveryPage />} />
                <Route path="/choose-workspace" element={<WorkspaceChooserPage />} />
                <Route path="/lecturer/onboarding" element={<LecturerOnboardingPage />} />
                <Route path="/lecturer/onboarding/status" element={<LecturerStatusPage />} />
                <Route path="/lecturer/restricted" element={<LecturerRestrictedPage />} />
                <Route path="/dashboard" element={<DashboardPage />} />
                <Route path="/assessment" element={<AssessmentJourneyPage />} />
                <Route path="/skill-map" element={<SkillMapPage />} />
                <Route path="/roadmap/:roadmapId" element={<RoadmapPage />} />
                <Route path="/roadmap/:roadmapId/skill-map" element={<SkillMapPage />} />
                <Route path="/roadmap/:roadmapId/lesson/:roadmapLessonId" element={<LessonPage />} />
                <Route path="/roadmap/:roadmapId/lesson/:roadmapLessonId/challenge/:challengeId" element={<ChallengeWorkspacePage />} />
                <Route path="/lecturer/courses/new" element={<LecturerGuard><CreateCoursePage /></LecturerGuard>} />
                <Route path="/lecturer/courses" element={<LecturerGuard><CourseListPage /></LecturerGuard>} />
                <Route path="/lecturer/courses/:trackId" element={<LecturerGuard><CourseWorkspacePage /></LecturerGuard>} />
                <Route path="/lecturer/courses/:trackId/documents" element={<LecturerGuard><CourseWorkspacePage /></LecturerGuard>} />
                <Route path="/lecturer/courses/:trackId/interpretation" element={<LecturerGuard><CourseInterpretationPage /></LecturerGuard>} />
                <Route path="/lecturer/courses/:trackId/blueprint" element={<LecturerGuard><BlueprintReviewPage /></LecturerGuard>} />
                <Route path="/lecturer/courses/:trackId/publication" element={<LecturerGuard><CoursePublicationPage /></LecturerGuard>} />
            </Routes>
        </Router>;
}
