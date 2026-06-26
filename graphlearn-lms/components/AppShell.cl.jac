"""Global application shell for GraphLearn LMS."""

import from "..features.landing.pages.LandingPage" { LandingPage }

def:pub AppShell() -> JsxElement {
    return <LandingPage />;
}
