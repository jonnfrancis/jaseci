"""Read-only skill map UI components."""

import from "lucide-react" {
    AlertCircle,
    Brain,
    CheckCircle2,
    Circle,
    Lock,
    Network,
    RefreshCcw,
    Target,
    TrendingUp
}
import from "@jac/runtime" { Link }
import from "....lib.utils" { format_datetime }
import from "....components.ui.button" { Button }
import from "....components.ui.card" {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle
}
sv import from ....services.skill_map {
    SkillMapEdge,
    SkillMapSkill,
    SkillMapSummary,
    SkillMapView
}

def _language_label(language: str) -> str {
    if language == "python" {
        return "Python";
    }
    if language == "jac" {
        return "Jac";
    }
    return "Learning";
}

def _level_label(level: str) -> str {
    if level == "beginner" {
        return "Beginner";
    }
    if level == "developing" {
        return "Developing";
    }
    if level == "proficient" {
        return "Proficient";
    }
    if level == "mastered" {
        return "Mastered";
    }
    return "Unknown";
}

def _status_label(status: str) -> str {
    if status == "locked" {
        return "Locked";
    }
    if status == "available" {
        return "Available";
    }
    if status == "in_progress" {
        return "In progress";
    }
    if status == "mastered" {
        return "Mastered";
    }
    return "Unknown";
}

def _level_class(level: str) -> str {
    if level == "mastered" {
        return "border-state-success text-state-success";
    }
    if level == "proficient" {
        return "border-brand text-brand";
    }
    if level == "developing" {
        return "border-state-warning text-state-warning";
    }
    return "border-surface-border-subtle text-copy-secondary";
}

def _status_icon(status: str) -> JsxElement {
    if status == "locked" {
        return <Lock className="size-4 text-copy-muted" />;
    }
    if status == "mastered" {
        return <CheckCircle2 className="size-4 text-state-success" />;
    }
    if status == "in_progress" {
        return <TrendingUp className="size-4 text-brand" />;
    }
    return <Circle className="size-4 text-copy-muted" />;
}

def _skill_selected(skill: SkillMapSkill, selected_skill_id: str) -> bool {
    return skill.skill_id == selected_skill_id;
}

def _find_skill(skills: list[SkillMapSkill], skill_id: str) -> SkillMapSkill | None {
    for skill in skills {
        if skill.skill_id == skill_id {
            return skill;
        }
    }
    return None;
}

def _skill_name(skills: list[SkillMapSkill], skill_id: str) -> str {
    skill = _find_skill(skills, skill_id);
    if skill is None {
        return skill_id;
    }
    return (skill as SkillMapSkill).name;
}

def _edge_label(edge_type: str) -> str {
    if edge_type == "prerequisite" {
        return "Prerequisite";
    }
    if edge_type == "teaches" {
        return "Teaches";
    }
    if edge_type == "reinforces" {
        return "Reinforces";
    }
    return "Related";
}

def _filtered_skills(skills: list[SkillMapSkill], filter: str) -> list[SkillMapSkill] {
    if filter == "all" {
        return skills;
    }
    return [skill for skill in skills if skill.mastery_level == filter];
}

def:pub SkillMapHeader(skillMap: SkillMapView, roadmapTitle: str = "") -> JsxElement {
    back_url = "/roadmap/" + skillMap.roadmap_id if skillMap.roadmap_id != "" else "/assessment";
    return
        <header className="rounded-2xl border border-surface-border bg-surface p-6">
            <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
                <div className="flex max-w-3xl flex-col gap-3">
                    <div className="flex w-fit items-center gap-2 rounded-xl border border-surface-border-subtle bg-elevated px-3 py-2 text-sm text-copy-secondary">
                        <Network className="size-4 text-brand" />
                        Mastery graph
                    </div>
                    <div>
                        <h1 className="text-3xl font-semibold leading-tight text-copy-primary md:text-4xl">
                            {_language_label(skillMap.language)} Skill Map
                        </h1>
                        <p className="mt-3 text-base leading-7 text-copy-secondary">
                            Your current mastery graph based on assessment and coding challenge evidence.
                        </p>
                    </div>
                </div>
                <div className="flex flex-wrap gap-2 lg:justify-end">
                    <span className="inline-flex items-center gap-1 rounded-xl border border-brand bg-elevated px-2.5 py-1 text-xs font-medium text-brand">
                        {_language_label(skillMap.language)}
                    </span>
                    {roadmapTitle != "" and
                        <span className="inline-flex max-w-xs items-center gap-1 truncate rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs text-copy-secondary">
                            {roadmapTitle}
                        </span>
                    }
                    <span className="inline-flex items-center gap-1 rounded-xl border border-surface-border-subtle bg-elevated px-2.5 py-1 text-xs text-copy-muted">
                        Generated {format_datetime(skillMap.generated_at)}
                    </span>
                    <Button asChild={True} variant="outline">
                        <Link to={back_url}>
                            <Target className="size-4" />
                            { "Back to roadmap" if skillMap.roadmap_id != "" else "Back to assessment" }
                        </Link>
                    </Button>
                </div>
            </div>
        </header>;
}

def:pub SkillMapSummaryCards(summary: SkillMapSummary) -> JsxElement {
    weak_count = summary.developing_count + summary.beginner_count;
    return
        <section className="grid gap-4 md:grid-cols-2 xl:grid-cols-4" aria-label="Skill map summary">
            <SkillMapSummaryCard icon="skills" label="Total skills" value={str(summary.total_skills)} detail="Roadmap-filtered coverage" />
            <SkillMapSummaryCard icon="average" label="Average mastery" value={f"{summary.average_mastery}%"} detail="Backend mastery score" />
            <SkillMapSummaryCard icon="mastered" label="Mastered skills" value={str(summary.mastered_count)} detail={f"{summary.proficient_count} proficient"} />
            <SkillMapSummaryCard icon="weak" label="Needs practice" value={str(weak_count)} detail={f"{summary.developing_count} developing, {summary.beginner_count} beginner"} />
        </section>;
}

def:pub SkillMapSummaryCard(icon: str, label: str, value: str, detail: str) -> JsxElement {
    return
        <Card className="border-surface-border bg-surface">
            <CardContent className="flex items-start gap-4">
                <div className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                    {if icon == "skills" {
                        <Network className="size-5 text-brand" />
                    } elif icon == "average" {
                        <TrendingUp className="size-5 text-brand" />
                    } elif icon == "mastered" {
                        <CheckCircle2 className="size-5 text-state-success" />
                    } else {
                        <AlertCircle className="size-5 text-state-warning" />
                    }}
                </div>
                <div className="min-w-0">
                    <p className="text-sm text-copy-muted">{label}</p>
                    <p className="mt-1 text-2xl font-semibold text-copy-primary">{value}</p>
                    <p className="mt-1 text-sm leading-5 text-copy-secondary">{detail}</p>
                </div>
            </CardContent>
        </Card>;
}

def:pub SkillMapFilters(activeFilter: str, onFilter: Callable[[str], None]) -> JsxElement {
    filters: list[str] = ["all", "beginner", "developing", "proficient", "mastered"];
    return
        <div className="flex flex-wrap items-center gap-2" aria-label="Skill filters">
            {for filter in filters {
                <Button
                    key={filter}
                    variant={"default" if activeFilter == filter else "outline"}
                    onClick={lambda (_e: MouseEvent) { onFilter(filter); }}
                >
                    {_level_label(filter) if filter != "all" else "All skills"}
                </Button>
            }}
        </div>;
}

def:pub SkillGraphView(
    skillMap: SkillMapView,
    activeFilter: str,
    selectedSkillId: str,
    onSelectSkill: Callable[[str], None]
) -> JsxElement {
    visible_skills = _filtered_skills(skillMap.skills, activeFilter);
    return
        <section className="grid gap-4 lg:grid-cols-[1fr_18rem]" aria-label="Read-only skill graph">
            <Card className="border-surface-border bg-surface">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Network className="size-5 text-brand" />
                        Skill graph
                    </CardTitle>
                    <CardDescription>Read-only mastery nodes. Select a skill to inspect evidence and dependencies.</CardDescription>
                </CardHeader>
                <CardContent className="grid gap-4">
                    {if len(visible_skills) == 0 {
                        <div className="rounded-xl border border-surface-border-subtle bg-elevated p-4 text-sm text-copy-secondary">
                            No skills match this filter.
                        </div>
                    } else {
                        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-3" role="list" aria-label="Skills">
                            {for skill in visible_skills {
                                <SkillNodeCard
                                    key={skill.skill_id}
                                    skill={skill}
                                    selected={_skill_selected(skill, selectedSkillId)}
                                    onSelectSkill={onSelectSkill}
                                />
                            }}
                        </div>
                    }}
                    <SkillEdgeList skills={skillMap.skills} edges={skillMap.edges} />
                </CardContent>
            </Card>
            <Card className="border-surface-border bg-surface">
                <CardHeader>
                    <CardTitle className="text-base">Dependency paths</CardTitle>
                    <CardDescription>Secondary links from the persisted learning graph.</CardDescription>
                </CardHeader>
                <CardContent>
                    <SkillEdgeListCompact skills={skillMap.skills} edges={skillMap.edges} />
                </CardContent>
            </Card>
        </section>;
}

def:pub SkillNodeCard(
    skill: SkillMapSkill,
    selected: bool,
    onSelectSkill: Callable[[str], None]
) -> JsxElement {
    selected_class = "border-brand bg-accent-dim" if selected else "border-surface-border-subtle bg-elevated";
    return
        <button
            type="button"
            role="listitem"
            aria-pressed={selected}
            onClick={lambda (_e: MouseEvent) { onSelectSkill(skill.skill_id); }}
            className={"min-h-44 rounded-xl border p-4 text-left outline-none transition focus-visible:ring-2 focus-visible:ring-brand " + selected_class}
        >
            <div className="flex items-start justify-between gap-3">
                <div className="min-w-0">
                    <h3 className="break-words text-base font-semibold text-copy-primary">{skill.name}</h3>
                    <p className="mt-1 text-xs text-copy-muted">{skill.category}</p>
                </div>
                {_status_icon(skill.status)}
            </div>
            <div className="mt-4 flex flex-wrap gap-2">
                <span className={"rounded-xl border bg-surface px-2 py-1 text-xs font-medium " + _level_class(skill.mastery_level)}>
                    {_level_label(skill.mastery_level)}
                </span>
                <span className="rounded-xl border border-surface-border-subtle bg-surface px-2 py-1 text-xs text-copy-secondary">
                    {_status_label(skill.status)}
                </span>
            </div>
            <div className="mt-4">
                <div className="flex items-center justify-between gap-2 text-sm">
                    <span className="text-copy-muted">Mastery</span>
                    <span className="font-semibold text-brand">{skill.mastery_score}%</span>
                </div>
                <div className="mt-2 h-2 overflow-hidden rounded-xl bg-surface">
                    <div className="h-full rounded-xl bg-brand" style={{"width": f"{skill.mastery_score}%"}} />
                </div>
            </div>
        </button>;
}

def:pub SkillEdgeList(skills: list[SkillMapSkill], edges: list[SkillMapEdge]) -> JsxElement {
    return
        <div className="rounded-xl border border-surface-border-subtle bg-elevated p-4">
            <h3 className="text-sm font-semibold text-copy-primary">Accessible dependency list</h3>
            {if len(edges) == 0 {
                <p className="mt-2 text-sm text-copy-muted">No prerequisite relationships are attached to these skills yet.</p>
            } else {
                <ul className="mt-3 grid gap-2 text-sm text-copy-secondary">
                    {for edge in edges {
                        <li key={edge.from_skill_id + edge.to_skill_id + edge.type} className="flex flex-wrap items-center gap-2">
                            <span className="font-medium text-copy-primary">{_skill_name(skills, edge.from_skill_id)}</span>
                            <span className="text-copy-muted">to</span>
                            <span className="font-medium text-copy-primary">{_skill_name(skills, edge.to_skill_id)}</span>
                            <span className="rounded-xl border border-surface-border-subtle bg-surface px-2 py-1 text-xs text-copy-muted">{_edge_label(edge.type)}</span>
                        </li>
                    }}
                </ul>
            }}
        </div>;
}

def:pub SkillEdgeListCompact(skills: list[SkillMapSkill], edges: list[SkillMapEdge]) -> JsxElement {
    if len(edges) == 0 {
        return <p className="text-sm leading-6 text-copy-muted">No dependencies to show yet.</p>;
    }
    return
        <div className="grid gap-2">
            {for edge in edges {
                <div key={edge.from_skill_id + edge.to_skill_id + edge.type} className="rounded-xl border border-surface-border-subtle bg-elevated p-3 text-sm">
                    <p className="font-medium text-copy-primary">{_skill_name(skills, edge.from_skill_id)}</p>
                    <p className="text-copy-muted">to</p>
                    <p className="font-medium text-copy-primary">{_skill_name(skills, edge.to_skill_id)}</p>
                    <p className="mt-2 text-xs text-brand">{_edge_label(edge.type)}</p>
                </div>
            }}
        </div>;
}

def:pub SelectedSkillPanel(skill: SkillMapSkill | None, skills: list[SkillMapSkill], edges: list[SkillMapEdge]) -> JsxElement {
    if skill is None {
        return
            <Card className="border-surface-border bg-surface">
                <CardHeader>
                    <CardTitle className="flex items-center gap-2">
                        <Brain className="size-5 text-ai-text" />
                        Skill details
                    </CardTitle>
                    <CardDescription>Select a skill node to inspect mastery evidence and dependencies.</CardDescription>
                </CardHeader>
            </Card>;
    }
    current = skill as SkillMapSkill;
    return
        <Card className="border-surface-border bg-surface">
            <CardHeader>
                <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                    <div>
                        <CardTitle className="text-xl">{current.name}</CardTitle>
                        <CardDescription className="mt-2 leading-6">{current.description}</CardDescription>
                    </div>
                    <span className={"inline-flex w-fit rounded-xl border bg-elevated px-2.5 py-1 text-xs font-medium " + _level_class(current.mastery_level)}>
                        {_level_label(current.mastery_level)}
                    </span>
                </div>
            </CardHeader>
            <CardContent className="grid gap-4 lg:grid-cols-3">
                <SkillDetailMetric label="Category" value={current.category} />
                <SkillDetailMetric label="Mastery score" value={f"{current.mastery_score}%"} />
                <SkillDetailMetric label="Evidence count" value={str(current.evidence_count)} />
                <div className="rounded-xl border border-surface-border-subtle bg-elevated p-4 lg:col-span-3">
                    <h3 className="text-sm font-semibold text-copy-primary">Related lessons</h3>
                    {if len(current.target_lesson_ids) == 0 {
                        <p className="mt-2 text-sm text-copy-muted">No related roadmap lessons are attached yet.</p>
                    } else {
                        <div className="mt-3 flex flex-wrap gap-2">
                            {for lesson_id in current.target_lesson_ids {
                                <span key={lesson_id} className="rounded-xl border border-surface-border-subtle bg-surface px-2.5 py-1 text-xs text-copy-secondary">
                                    Lesson {lesson_id}
                                </span>
                            }}
                        </div>
                    }}
                </div>
                <SkillConnections skill={current} skills={skills} edges={edges} />
            </CardContent>
        </Card>;
}

def:pub SkillDetailMetric(label: str, value: str) -> JsxElement {
    return
        <div className="rounded-xl border border-surface-border-subtle bg-elevated p-4">
            <p className="text-sm text-copy-muted">{label}</p>
            <p className="mt-2 break-words text-sm font-semibold text-copy-primary">{value}</p>
        </div>;
}

def:pub SkillConnections(skill: SkillMapSkill, skills: list[SkillMapSkill], edges: list[SkillMapEdge]) -> JsxElement {
    return
        <div className="grid gap-3 rounded-xl border border-surface-border-subtle bg-elevated p-4 lg:col-span-3">
            <h3 className="text-sm font-semibold text-copy-primary">Connected prerequisite skills</h3>
            <div className="grid gap-3 md:grid-cols-2">
                <div>
                    <p className="text-xs font-medium uppercase text-copy-muted">Prerequisites</p>
                    <ul className="mt-2 grid gap-2 text-sm text-copy-secondary">
                        {for edge in edges {
                            if edge.type == "prerequisite" and edge.to_skill_id == skill.skill_id {
                                <li key={edge.from_skill_id + edge.to_skill_id} className="rounded-xl border border-surface-border-subtle bg-surface px-3 py-2">
                                    {_skill_name(skills, edge.from_skill_id)}
                                </li>
                            }
                        }}
                    </ul>
                </div>
                <div>
                    <p className="text-xs font-medium uppercase text-copy-muted">Unlocks or supports</p>
                    <ul className="mt-2 grid gap-2 text-sm text-copy-secondary">
                        {for edge in edges {
                            if edge.from_skill_id == skill.skill_id {
                                <li key={edge.from_skill_id + edge.to_skill_id + edge.type} className="rounded-xl border border-surface-border-subtle bg-surface px-3 py-2">
                                    {_skill_name(skills, edge.to_skill_id)}{" - "}{_edge_label(edge.type)}
                                </li>
                            }
                        }}
                    </ul>
                </div>
            </div>
        </div>;
}

def:pub SkillMapLoadingState() -> JsxElement {
    return
        <div className="flex flex-col gap-4" aria-label="Loading skill map">
            <div className="h-48 animate-pulse rounded-2xl border border-surface-border bg-surface" />
            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                {for index in [1, 2, 3, 4] {
                    <div key={str(index)} className="h-28 animate-pulse rounded-2xl border border-surface-border bg-surface" />
                }}
            </div>
            <div className="grid gap-4 lg:grid-cols-[1fr_22rem]">
                <div className="h-96 animate-pulse rounded-2xl border border-surface-border bg-surface" />
                <div className="h-96 animate-pulse rounded-2xl border border-surface-border bg-surface" />
            </div>
        </div>;
}

def:pub SkillMapStateCard(
    title: str,
    message: str,
    action_label: str,
    action_to: str,
    retry_label: str = "",
    onRetry: Callable[[], None] | None = None
) -> JsxElement {
    return
        <div className="flex min-h-[70vh] items-center justify-center">
            <Card className="w-full max-w-2xl border-surface-border bg-surface">
                <CardHeader>
                    <div className="flex items-start gap-3">
                        <div className="flex size-10 shrink-0 items-center justify-center rounded-xl border border-surface-border-subtle bg-elevated">
                            <AlertCircle className="size-5 text-state-warning" />
                        </div>
                        <div>
                            <CardTitle className="text-xl">{title}</CardTitle>
                            <CardDescription className="mt-2 leading-6">{message}</CardDescription>
                        </div>
                    </div>
                </CardHeader>
                <CardContent className="flex flex-wrap gap-3">
                    <Button asChild={True}>
                        <Link to={action_to}>
                            <Target className="size-4" />
                            {action_label}
                        </Link>
                    </Button>
                    {if onRetry is not None and retry_label != "" {
                        <Button variant="outline" onClick={lambda (_e: MouseEvent) { onRetry(); }}>
                            <RefreshCcw className="size-4" />
                            {retry_label}
                        </Button>
                    }}
                </CardContent>
            </Card>
        </div>;
}
