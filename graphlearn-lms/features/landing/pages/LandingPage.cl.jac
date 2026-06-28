"""Informational landing page for GraphLearn LMS."""

import from "lucide-react" {
    BookOpen,
    CheckCircle2,
    Code2,
    LogIn,
    Map,
    Sparkles
}
import from "@jac/runtime" { Link }
import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
}

def:pub LandingPage() -> JsxElement {
    return
        <main className="min-h-screen bg-base text-copy-primary">
            <div className="mx-auto flex max-w-7xl flex-col gap-8 px-6 py-6">
                <header className="flex flex-wrap items-center justify-between gap-3 border-b border-surface-border pb-4">
                    <div className="flex items-center gap-3">
                        <div className="flex size-9 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                            <BookOpen className="size-5 text-brand" />
                        </div>
                        <div>
                            <p className="text-sm text-copy-muted">GraphLearn LMS</p>
                            <h1 className="text-xl font-semibold">Assessment launchpad</h1>
                        </div>
                    </div>
                    <div className="flex flex-wrap items-center gap-2">
                        <Link to="/login">
                            <Button variant="outline">
                                <LogIn className="size-4" />
                                Login
                            </Button>
                        </Link>
                        <Link to="/register"><Button>Register</Button></Link>
                    </div>
                </header>

                <section className="grid gap-6 lg:grid-cols-[1.1fr_0.9fr]">
                    <div className="flex flex-col justify-center gap-5 rounded-2xl border border-surface-border bg-surface p-6">
                        <div className="flex w-fit items-center gap-2 rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-sm text-copy-secondary">
                            <Sparkles className="size-4 text-ai-text" />
                            Phase 1 assessment pipeline
                        </div>
                        <div className="flex max-w-3xl flex-col gap-3">
                            <h2 className="text-3xl font-semibold leading-tight md:text-4xl">Adaptive programming mastery, mapped as you learn.</h2>
                            <p className="text-base leading-7 text-copy-secondary">
                                GraphLearn turns assessment evidence into a personalized roadmap, then uses graph-based progress to guide what comes next.
                            </p>
                        </div>
                        <div className="flex flex-wrap gap-3">
                            <Link to="/register"><Button>Start learning</Button></Link>
                            <Link to="/login"><Button variant="outline">Continue assessment</Button></Link>
                        </div>
                    </div>

                    <Card className="border-surface-border bg-surface">
                        <CardHeader>
                            <CardTitle>Learning loop</CardTitle>
                            <CardDescription>The application flow stays focused on assessment, roadmap generation, and progress recovery.</CardDescription>
                        </CardHeader>
                        <CardContent className="grid gap-3">
                            {for step in ["Authenticate", "Assess", "Evaluate", "Generate roadmap", "Learn"] {
                                <div key={step} className="flex items-center gap-3 rounded-xl border border-surface-border-subtle bg-elevated p-3 text-sm">
                                    <CheckCircle2 className="size-4 text-state-success" />
                                    <span>{step}</span>
                                </div>
                            }}
                        </CardContent>
                    </Card>
                </section>

                <section className="grid gap-4 md:grid-cols-3" aria-label="Product capabilities">
                    <InfoCard key="adaptive-assessments" title="Adaptive assessments" description="Measure current skill evidence before generating a learning plan." icon="assessment" />
                    <InfoCard key="graph-roadmaps" title="Graph roadmaps" description="Represent topics, dependencies, milestones, and learner progress as connected knowledge." icon="roadmap" />
                    <InfoCard key="ai-generated-lessons" title="AI generated lessons" description="Use the roadmap to produce focused lessons and challenges when the learner needs them." icon="ai" />
                </section>
            </div>
        </main>;
}

def:pub InfoCard(title: str, description: str, icon: str, key: str) -> JsxElement {
    return
        <Card key={key} className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex size-10 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                    {if icon == "roadmap" {
                        <Map className="size-5 text-brand" />
                    } elif icon == "ai" {
                        <Sparkles className="size-5 text-ai-text" />
                    } else {
                        <Code2 className="size-5 text-brand" />
                    }}
                </div>
                <CardTitle>{title}</CardTitle>
                <CardDescription className="leading-6">{description}</CardDescription>
            </CardHeader>
        </Card>;
}
