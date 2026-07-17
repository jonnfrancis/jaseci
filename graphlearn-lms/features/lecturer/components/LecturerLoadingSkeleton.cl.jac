"""Layout-preserving skeleton for lecturer workspace routes."""

import from "....components.ui.card" { Card, CardContent, CardHeader }

def:pub LecturerLoadingSkeleton(compact: bool = False) -> JsxElement {
    return <main className="min-h-screen bg-base pt-8 pb-8 pl-6 pr-6 text-copy-primary" aria-busy="true" aria-label="Loading lecturer workspace">
        <div className={"mx-auto flex flex-col gap-6 " + ("max-w-xl" if compact else "max-w-6xl")}>
            <div className="flex animate-pulse flex-col gap-3">
                <div className="h-4 w-32 rounded-xl bg-elevated" />
                <div className="h-9 w-72 max-w-full rounded-xl bg-elevated" />
                <div className="h-4 w-full max-w-xl rounded-xl bg-elevated" />
            </div>
            <div className={"grid gap-6 " + ("" if compact else "lg:grid-cols-[minmax(0,2fr)_minmax(16rem,1fr)]")}>
                <Card className="animate-pulse border-surface-border bg-surface">
                    <CardHeader className="flex flex-col gap-3"><div className="h-6 w-48 rounded-xl bg-elevated" /><div className="h-4 w-full max-w-md rounded-xl bg-elevated" /></CardHeader>
                    <CardContent className="grid gap-4">{for i in range(4) { <div key={str(i)} className="grid gap-2"><div className="h-3 w-24 rounded-xl bg-elevated" /><div className="h-11 w-full rounded-xl bg-elevated" /></div> }}</CardContent>
                </Card>
                {not compact and <Card className="h-52 animate-pulse border-surface-border bg-surface"><CardHeader className="flex flex-col gap-3"><div className="h-6 w-40 rounded-xl bg-elevated" /><div className="h-4 w-full rounded-xl bg-elevated" /></CardHeader></Card>}
            </div>
            <span className="sr-only" role="status">Loading lecturer workspace</span>
        </div>
    </main>;
}
