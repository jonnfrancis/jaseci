"""Global application shell for GraphLearn LMS."""

import from "..features.assessment.pages.AssessmentPage" { AssessmentPage }

def:pub AppShell() -> JsxElement {
    return <AssessmentPage />;
}
