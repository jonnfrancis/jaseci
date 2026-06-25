"""Global application shell for GraphLearn LMS."""

import from ".ui.button" { Button }
import from ".ui.card" {
    Card,
    CardHeader,
    CardTitle,
    CardDescription,
    CardContent,
    CardFooter
}
import from ".ui.dialog" {
    Dialog,
    DialogTrigger,
    DialogContent,
    DialogHeader,
    DialogTitle,
    DialogDescription,
    DialogFooter
}
import from ".ui.input" { Input }
import from ".ui.tabs" { Tabs, TabsList, TabsTrigger, TabsContent }
import from ".ui.textarea" { Textarea }
import from ".ui.scroll_area" { ScrollArea }
import from "lucide-react" { CheckCircle2, Palette, Sparkles }

def:pub AppShell() -> JsxElement {
    nav_items: list[str] = ["Dashboard", "Roadmap", "Workspace", "Skill Map"];
    foundation_items: list[str] = [
        "Jac client",
        "Tailwind tokens",
        "shadcn/ui ready",
        "OSP folders"
    ];

    return
        <div className="min-h-screen bg-base text-copy-primary font-sans antialiased">
            <header className="border-b border-surface-border bg-surface">
                <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-6">
                    <div className="flex items-center gap-3">
                        <div className="flex size-9 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated text-sm font-semibold text-brand">
                            GL
                        </div>
                        <div className="flex flex-col">
                            <span className="text-sm font-semibold">GraphLearn LMS</span>
                            <span className="text-xs text-copy-muted">Adaptive learning workspace</span>
                        </div>
                    </div>
                    <nav className="hidden items-center gap-2 md:flex">
                        {[
                            <span
                                key={item}
                                className="rounded-xl px-3 py-2 text-sm text-copy-secondary"
                            >
                                {item}
                            </span>
                            for item in nav_items
                        ]}
                    </nav>
                </div>
            </header>

            <main className="mx-auto grid max-w-7xl gap-6 px-6 py-6 lg:grid-cols-[16rem_1fr]">
                <aside className="rounded-2xl border border-surface-border bg-surface p-4">
                    <div className="flex flex-col gap-4">
                        <div>
                            <h2 className="text-sm font-semibold">Foundation</h2>
                            <p className="mt-1 text-sm text-copy-muted">Project setup is ready for feature work.</p>
                        </div>
                        <div className="flex flex-col gap-2">
                            {[
                                <div
                                    key={item}
                                    className="flex items-center justify-between rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-sm"
                                >
                                    <span>{item}</span>
                                    <span className="text-xs text-brand">Ready</span>
                                </div>
                                for item in foundation_items
                            ]}
                        </div>
                    </div>
                </aside>

                <section className="rounded-2xl border border-surface-border bg-surface p-6">
                    <div className="grid gap-6 lg:grid-cols-[1fr_20rem]">
                        <div className="flex flex-col gap-6">
                            <div className="flex flex-col gap-2">
                                <p className="text-sm font-medium text-brand">Project foundation</p>
                                <h1 className="max-w-3xl text-3xl font-semibold">A dark technical workspace shell for adaptive learning.</h1>
                                <p className="max-w-2xl text-sm leading-6 text-copy-secondary">
                                    The app shell is intentionally static at this phase so domain walkers, graph nodes, lessons, and assessments can be added in focused feature units.
                                </p>
                            </div>

                            <div className="grid gap-4 md:grid-cols-3">
                                <div className="rounded-2xl border border-surface-border-subtle bg-elevated p-4">
                                    <p className="text-sm text-copy-muted">Current phase</p>
                                    <p className="mt-2 text-xl font-semibold">Design system</p>
                                </div>
                                <div className="rounded-2xl border border-surface-border-subtle bg-elevated p-4">
                                    <p className="text-sm text-copy-muted">Business logic</p>
                                    <p className="mt-2 text-xl font-semibold">Deferred</p>
                                </div>
                                <div className="rounded-2xl border border-surface-border-subtle bg-elevated p-4">
                                    <p className="text-sm text-copy-muted">Next unit</p>
                                    <p className="mt-2 text-xl font-semibold">Domain models</p>
                                </div>
                            </div>

                            <Tabs defaultValue="components" className="gap-4">
                                <TabsList>
                                    <TabsTrigger value="components">
                                        <Palette className="size-4" />
                                        Components
                                    </TabsTrigger>
                                    <TabsTrigger value="forms">
                                        <Sparkles className="size-4" />
                                        Forms
                                    </TabsTrigger>
                                </TabsList>
                                <TabsContent value="components">
                                    <Card className="border-surface-border-subtle bg-elevated">
                                        <CardHeader>
                                            <CardTitle>shadcn/ui primitives</CardTitle>
                                            <CardDescription>Generated Jac primitives are available for feature work.</CardDescription>
                                        </CardHeader>
                                        <CardContent>
                                            <ScrollArea className="h-24 rounded-xl border border-surface-border-subtle bg-surface p-3">
                                                <div className="flex flex-col gap-2 text-sm text-copy-secondary">
                                                    {[
                                                        <div key={item} className="flex items-center gap-2">
                                                            <CheckCircle2 className="size-4 text-brand" />
                                                            <span>{item}</span>
                                                        </div>
                                                        for item in [
                                                            "Button",
                                                            "Card",
                                                            "Dialog",
                                                            "Input",
                                                            "Tabs",
                                                            "Textarea",
                                                            "ScrollArea"
                                                        ]
                                                    ]}
                                                </div>
                                            </ScrollArea>
                                        </CardContent>
                                        <CardFooter className="justify-between">
                                            <span className="text-sm text-copy-muted">Dark-token mapped</span>
                                            <Dialog>
                                                <DialogTrigger asChild={True}>
                                                    <Button variant="outline">Inspect</Button>
                                                </DialogTrigger>
                                                <DialogContent className="bg-subtle">
                                                    <DialogHeader>
                                                        <DialogTitle>Design system ready</DialogTitle>
                                                        <DialogDescription>
                                                            The required primitives import through the Jac client and inherit the dark CSS variables.
                                                        </DialogDescription>
                                                    </DialogHeader>
                                                    <DialogFooter>
                                                        <Button variant="secondary">Ready</Button>
                                                    </DialogFooter>
                                                </DialogContent>
                                            </Dialog>
                                        </CardFooter>
                                    </Card>
                                </TabsContent>
                                <TabsContent value="forms">
                                    <Card className="border-surface-border-subtle bg-elevated">
                                        <CardHeader>
                                            <CardTitle>Form controls</CardTitle>
                                            <CardDescription>Inputs use shared surface, border, and focus tokens.</CardDescription>
                                        </CardHeader>
                                        <CardContent className="grid gap-3">
                                            <Input value="graphlearn-lms" readOnly={True} />
                                            <Textarea value="Foundation-only implementation; domain behavior remains deferred." readOnly={True} />
                                        </CardContent>
                                    </Card>
                                </TabsContent>
                            </Tabs>
                        </div>

                        <div className="rounded-2xl border border-surface-border-subtle bg-elevated p-4">
                            <h2 className="text-sm font-semibold">Global Layout</h2>
                            <div className="mt-4 flex flex-col gap-3 text-sm text-copy-secondary">
                                <p>Top navigation anchors the workspace.</p>
                                <p>Left foundation panel reserves room for learning context.</p>
                                <p>Main content uses tokenized dark surfaces.</p>
                            </div>
                        </div>
                    </div>
                </section>
            </main>
        </div>;
}
