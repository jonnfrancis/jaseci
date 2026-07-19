"""Publication snapshots and immutable publication event history."""
import from edges.domain_edges { HAS_COURSE_PUBLICATION, HAS_PUBLICATION_EVENT }
import from nodes.curriculum { CoursePublication, CoursePublicationEvent }
import from nodes.learning_track { LearningTrack, TrackVersion, TrackVersionStatus }

obj CoursePublicationRepository {
    def list_for_track(track: LearningTrack) -> list[CoursePublication] { values: list[CoursePublication] = [track ->:HAS_COURSE_PUBLICATION:->[?:CoursePublication]]; values.sort(key=lambda item: CoursePublication : item.version_number); return values; }
    def find_for_version(track: LearningTrack, version_id: str) -> CoursePublication | None { for item in self.list_for_track(track) { if item.track_version_id == version_id and item.publication_status in ["PUBLISHED", "SUPERSEDED", "REACTIVATED"] { return item; } } return None; }
    def find_idempotent(track: LearningTrack, key: str) -> CoursePublication | None { for item in self.list_for_track(track) { if item.idempotency_key == key { return item; } } return None; }
    def save(track: LearningTrack, item: CoursePublication) -> bool { if item.track_id != track.track_id { return False; } track +>:HAS_COURSE_PUBLICATION:+> item; return True; }
    def events(track: LearningTrack) -> list[CoursePublicationEvent] { values: list[CoursePublicationEvent] = [track ->:HAS_PUBLICATION_EVENT:->[?:CoursePublicationEvent]]; values.sort(key=lambda item: CoursePublicationEvent : item.created_at); return values; }
    def save_event(track: LearningTrack, item: CoursePublicationEvent) { track +>:HAS_PUBLICATION_EVENT:+> item; }
}

def assert_version_editable(version: TrackVersion) { if version.status not in [TrackVersionStatus.DRAFT, TrackVersionStatus.PROCESSING, TrackVersionStatus.REVIEW_REQUIRED, TrackVersionStatus.APPROVED, TrackVersionStatus.PUBLICATION_FAILED] { raise ValueError("COURSE_VERSION_IMMUTABLE"); } }
