"""Focused graph repositories for shared curriculum and enrollment state."""

import from edges.domain_edges {
    CONTAINS_MODULE, CONTAINS_SKILL, HAS_ACTIVITY_TEMPLATE, HAS_ASSESSMENT_ATTEMPT,
    HAS_ENROLLMENT, HAS_LEARNING_TRACK, HAS_LESSON_PROGRESS, HAS_LESSON_TEMPLATE,
    HAS_MASTERY, HAS_RECOMMENDATION, HAS_ROADMAP, HAS_ROADMAP_ITEM, HAS_SUBMISSION,
    HAS_TRACK_VERSION, LESSON_HAS_ACTIVITY, PREREQUISITE
}
import from lib.learning_track.repository_types { ActorContext, PageRequest, PageResult }
import from lib.learning_track.service { existing_catalogue }
import from nodes.assessment { AssessmentAttempt }
import from nodes.curriculum { ActivityTemplate, CourseModule, LessonTemplate }
import from nodes.enrollment { Enrollment, RoadmapItem, Submission }
import from nodes.learning_track {
    LearningCatalogue, LearningTrack, LearningTrackStatus, LearningTrackVisibility,
    TrackVersion, TrackVersionStatus
}
import from nodes.learner { Learner }
import from nodes.mastery { MasteryUpdateResult }
import from nodes.progression { LessonProgress }
import from nodes.roadmap { Roadmap }
import from nodes.skill { Skill }
import from nodes.track_context { Recommendation }

glob MAX_PAGE_SIZE: int = 100;

def normalize_page(page: PageRequest) -> PageRequest {
    limit = page.limit;
    if limit < 1 { limit = 1; }
    if limit > MAX_PAGE_SIZE { limit = MAX_PAGE_SIZE; }
    return PageRequest(limit=limit, cursor=page.cursor);
}

def page_values(values: list[object], page: PageRequest) -> PageResult {
    normalized = normalize_page(page);
    offset = 0;
    if normalized.cursor is not None {
        try { offset = int(normalized.cursor); } except ValueError { offset = 0; }
    }
    if offset < 0 { offset = 0; }
    end = offset + normalized.limit;
    has_more = end < len(values);
    next_cursor = str(end) if has_more else None;
    return PageResult(items=values[offset:end], next_cursor=next_cursor, has_more=has_more);
}

# LearningTrackRepository
def repository_catalogue -> LearningCatalogue | None { return existing_catalogue(); }

def repository_find_track(track_id: str) -> LearningTrack | None {
    catalogue = repository_catalogue();
    if catalogue is None { return None; }
    for track in [catalogue ->:HAS_LEARNING_TRACK:->][?:LearningTrack] {
        if track.track_id == track_id { return track; }
    }
    return None;
}

def repository_find_track_by_slug(slug: str) -> LearningTrack | None {
    catalogue = repository_catalogue();
    if catalogue is None { return None; }
    for track in [catalogue ->:HAS_LEARNING_TRACK:->][?:LearningTrack] {
        if track.slug == slug { return track; }
    }
    return None;
}

def repository_has_catalogue_membership(track: LearningTrack) -> bool {
    catalogue = repository_catalogue();
    return catalogue is not None and track in [catalogue ->:HAS_LEARNING_TRACK:->][?:LearningTrack];
}

def repository_list_owned(owner_id: str, page: PageRequest) -> PageResult {
    catalogue = repository_catalogue();
    if catalogue is None { return PageResult(items=[]); }
    tracks: list[LearningTrack] = [t for t in [catalogue ->:HAS_LEARNING_TRACK:->][?:LearningTrack] if t.owner_id == owner_id];
    tracks.sort(key=lambda t: LearningTrack : t.title.lower());
    return page_values(tracks as list[object], page);
}

def repository_list_visible(actor: ActorContext, page: PageRequest) -> PageResult {
    catalogue = repository_catalogue();
    if catalogue is None { return PageResult(items=[]); }
    tracks: list[LearningTrack] = [];
    for track in [catalogue ->:HAS_LEARNING_TRACK:->][?:LearningTrack] {
        public = track.status == LearningTrackStatus.PUBLISHED and track.visibility == LearningTrackVisibility.PUBLIC;
        owned = track.owner_id is not None and actor.lecturer_id is not None and track.owner_id == actor.lecturer_id;
        institution = track.visibility == LearningTrackVisibility.INSTITUTION and track.institution_id is not None and track.institution_id in actor.institution_ids;
        if public or owned or institution { tracks.append(track); }
    }
    tracks.sort(key=lambda t: LearningTrack : t.title.lower());
    return page_values(tracks as list[object], page);
}

# TrackVersionRepository: ownership is proven by HAS_TRACK_VERSION, never scalar fields alone.
def repository_versions(track: LearningTrack) -> list[TrackVersion] {
    versions: list[TrackVersion] = [track ->:HAS_TRACK_VERSION:->][?:TrackVersion];
    versions.sort(key=lambda v: TrackVersion : v.version_number);
    return versions;
}

def repository_find_version(track: LearningTrack, track_version_id: str) -> TrackVersion | None {
    for version in repository_versions(track) {
        if version.track_version_id == track_version_id { return version; }
    }
    return None;
}

def repository_version_belongs_to(track: LearningTrack, version: TrackVersion) -> bool {
    return version in [track ->:HAS_TRACK_VERSION:->][?:TrackVersion] and version.track_id == track.track_id;
}

def repository_active_version(track: LearningTrack) -> TrackVersion | None {
    if track.active_version_id is None { return None; }
    return repository_find_version(track, track.active_version_id);
}

def repository_save_draft(version: TrackVersion) -> bool {
    if version.status != TrackVersionStatus.DRAFT { return False; }
    return True;
}

# CurriculumRepository: all entry points begin at a validated TrackVersion.
def repository_modules(track: LearningTrack, track_version_id: str) -> list[CourseModule] {
    version = repository_find_version(track, track_version_id);
    if version is None { return []; }
    modules: list[CourseModule] = [version ->:CONTAINS_MODULE:->][?:CourseModule];
    modules = [m for m in modules if m.track_id == track.track_id and m.track_version_id == track_version_id];
    modules.sort(key=lambda m: CourseModule : m.order_index);
    return modules;
}

def repository_skills(track: LearningTrack, track_version_id: str) -> list[Skill] {
    version = repository_find_version(track, track_version_id);
    if version is None { return []; }
    skills: list[Skill] = [version ->:CONTAINS_SKILL:->][?:Skill];
    skills = [s for s in skills if s.track_id == track.track_id and s.track_version_id == track_version_id];
    skills.sort(key=lambda s: Skill : s.order_hint if s.order_hint is not None else 2147483647);
    return skills;
}

def repository_find_skill(track: LearningTrack, track_version_id: str, skill_id: str) -> Skill | None {
    for skill in repository_skills(track, track_version_id) {
        if (skill.skill_id or skill.id) == skill_id { return skill; }
    }
    return None;
}

def repository_prerequisites(track: LearningTrack, track_version_id: str, skill_id: str) -> list[Skill] {
    dependent = repository_find_skill(track, track_version_id, skill_id);
    if dependent is None { return []; }
    allowed = repository_skills(track, track_version_id);
    prerequisites: list[Skill] = [s for s in [dependent <-:PREREQUISITE:<-][?:Skill] if s in allowed];
    prerequisites.sort(key=lambda s: Skill : s.order_hint if s.order_hint is not None else 2147483647);
    return prerequisites;
}

def repository_prerequisite_cycle(track: LearningTrack, track_version_id: str) -> list[str] {
    skills = repository_skills(track, track_version_id);
    indegree: dict[str, int] = {};
    dependents: dict[str, list[str]] = {};
    for skill in skills {
        sid = skill.skill_id or skill.id;
        indegree[sid] = 0;
        dependents[sid] = [];
    }
    for dependent in skills {
        did = dependent.skill_id or dependent.id;
        for prerequisite in repository_prerequisites(track, track_version_id, did) {
            pid = prerequisite.skill_id or prerequisite.id;
            indegree[did] = indegree[did] + 1;
            dependents[pid].append(did);
        }
    }
    queue: list[str] = sorted([sid for sid in indegree if indegree[sid] == 0]);
    visited: list[str] = [];
    while len(queue) > 0 {
        sid = queue.pop(0);
        visited.append(sid);
        for dependent_id in dependents[sid] {
            indegree[dependent_id] = indegree[dependent_id] - 1;
            if indegree[dependent_id] == 0 { queue.append(dependent_id); queue.sort(); }
        }
    }
    return sorted([sid for sid in indegree if indegree[sid] > 0]) if len(visited) != len(skills) else [];
}

def repository_lessons(track: LearningTrack, track_version_id: str) -> list[LessonTemplate] {
    version = repository_find_version(track, track_version_id);
    if version is None { return []; }
    lessons: list[LessonTemplate] = [version ->:HAS_LESSON_TEMPLATE:->][?:LessonTemplate];
    return [lesson for lesson in lessons if lesson.track_id == track.track_id and lesson.track_version_id == track_version_id];
}

def repository_activities(track: LearningTrack, track_version_id: str, lesson_id: str) -> list[ActivityTemplate] {
    for lesson in repository_lessons(track, track_version_id) {
        if lesson.lesson_template_id == lesson_id {
            return [a for a in [lesson ->:LESSON_HAS_ACTIVITY:->][?:ActivityTemplate] if a.track_id == track.track_id and a.track_version_id == track_version_id];
        }
    }
    return [];
}

# Enrollment-scoped repositories. The enrollment node is the mandatory query root.
def repository_find_enrollment(learner: Learner, enrollment_id: str) -> Enrollment | None {
    for enrollment in [learner ->:HAS_ENROLLMENT:->][?:Enrollment] {
        if enrollment.enrollment_id == enrollment_id { return enrollment; }
    }
    return None;
}

def repository_find_active_enrollment(learner: Learner, track_id: str) -> Enrollment | None {
    for enrollment in [learner ->:HAS_ENROLLMENT:->][?:Enrollment] {
        if enrollment.track_id == track_id and enrollment.status == "ACTIVE" { return enrollment; }
    }
    return None;
}

def repository_roadmap(enrollment: Enrollment) -> Roadmap | None {
    for roadmap in [enrollment ->:HAS_ROADMAP:->][?:Roadmap] {
        if roadmap.enrollment_id == enrollment.enrollment_id and roadmap.track_version_id == enrollment.track_version_id { return roadmap; }
    }
    return None;
}

def repository_roadmap_items(enrollment: Enrollment) -> list[RoadmapItem] {
    roadmap = repository_roadmap(enrollment);
    if roadmap is None { return []; }
    items: list[RoadmapItem] = [roadmap ->:HAS_ROADMAP_ITEM:->][?:RoadmapItem];
    items = [i for i in items if i.track_id == enrollment.track_id and i.track_version_id == enrollment.track_version_id];
    items.sort(key=lambda i: RoadmapItem : i.order_index);
    return items;
}

def repository_attempts(enrollment: Enrollment) -> list[AssessmentAttempt] {
    return [a for a in [enrollment ->:HAS_ASSESSMENT_ATTEMPT:->][?:AssessmentAttempt] if a.enrollment_id == enrollment.enrollment_id and a.track_version_id == enrollment.track_version_id];
}

def repository_submissions(enrollment: Enrollment) -> list[Submission] {
    return [s for s in [enrollment ->:HAS_SUBMISSION:->][?:Submission] if s.enrollment_id == enrollment.enrollment_id and s.track_version_id == enrollment.track_version_id];
}

def repository_mastery(enrollment: Enrollment) -> list[MasteryUpdateResult] {
    return [m for m in [enrollment ->:HAS_MASTERY:->][?:MasteryUpdateResult] if m.enrollment_id == enrollment.enrollment_id and m.track_version_id == enrollment.track_version_id];
}

def repository_lesson_progress(enrollment: Enrollment) -> list[LessonProgress] {
    return [p for p in [enrollment ->:HAS_LESSON_PROGRESS:->][?:LessonProgress] if p.track_version_id == enrollment.track_version_id];
}

def repository_recommendations(enrollment: Enrollment, limit: int = 20) -> list[Recommendation] {
    bounded = 1 if limit < 1 else (100 if limit > 100 else limit);
    values: list[Recommendation] = [r for r in [enrollment ->:HAS_RECOMMENDATION:->][?:Recommendation] if r.enrollment_id == enrollment.enrollment_id and r.track_version_id == enrollment.track_version_id];
    values.sort(key=lambda r: Recommendation : r.generated_at, reverse=True);
    return values[:bounded];
}
