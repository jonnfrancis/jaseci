"""Bounded identity repositories rooted at the authenticated user's graph."""

import from edges.domain_edges { HAS_IDENTITY_PROFILE, HAS_LEARNER_PROFILE, HAS_LECTURER_PROFILE, HAS_ROLE_ASSIGNMENT }
import from nodes.identity { LecturerProfile, LecturerProfileStatus, UserIdentityProfile, UserRoleAssignment, UserRoleType, RoleAssignmentStatus }
import from nodes.learner { Learner }

obj IdentityRepository {
    def find_identity_profile_by_user_id(user_id: str) -> UserIdentityProfile | None {
        matches = [root ->:HAS_IDENTITY_PROFILE:->[?:UserIdentityProfile]];
        if len(matches) == 1 and matches[0].user_id == user_id { return matches[0]; }
        return None;
    }

    def list_role_assignments(user_id: str) -> list[UserRoleAssignment] {
        return [item for item in [root ->:HAS_ROLE_ASSIGNMENT:->[?:UserRoleAssignment]] if item.user_id == user_id];
    }

    def find_active_role_assignment(user_id: str, role_type: UserRoleType) -> UserRoleAssignment | None {
        matches = [item for item in self.list_role_assignments(user_id) if item.role_type == role_type and item.status == RoleAssignmentStatus.ACTIVE];
        return matches[0] if len(matches) == 1 else None;
    }

    def find_learner_profile(user_id: str) -> Learner | None {
        matches = [root ->:HAS_LEARNER_PROFILE:->[?:Learner]];
        if len(matches) == 1 and matches[0].auth_root_id == user_id { return matches[0]; }
        return None;
    }

    def find_lecturer_profile(user_id: str) -> LecturerProfile | None {
        matches = [root ->:HAS_LECTURER_PROFILE:->[?:LecturerProfile]];
        if len(matches) == 1 and matches[0].user_id == user_id { return matches[0]; }
        return None;
    }

    def save_role_assignment(assignment: UserRoleAssignment) {
        if assignment.user_id != jid(root) { raise Exception("IDENTITY_GRAPH_INVALID"); }
        if assignment not in [root ->:HAS_ROLE_ASSIGNMENT:->[?:UserRoleAssignment]] {
            root +>:HAS_ROLE_ASSIGNMENT(created_at=assignment.created_at):+> assignment;
        }
    }

    def save_lecturer_profile(profile: LecturerProfile) {
        if profile.user_id != jid(root) { raise Exception("IDENTITY_GRAPH_INVALID"); }
        if profile not in [root ->:HAS_LECTURER_PROFILE:->[?:LecturerProfile]] {
            root +>:HAS_LECTURER_PROFILE(created_at=profile.created_at):+> profile;
        }
    }
}

obj LecturerRepository {
    def find_by_lecturer_id(lecturer_id: str) -> LecturerProfile | None {
        matches = [profile for profile in [root ->:HAS_LECTURER_PROFILE:->[?:LecturerProfile]] if profile.lecturer_id == lecturer_id and profile.user_id == jid(root)];
        return matches[0] if len(matches) == 1 else None;
    }

    def find_by_user_id(user_id: str) -> LecturerProfile | None {
        return IdentityRepository().find_lecturer_profile(user_id);
    }

    def list_by_status(status: LecturerProfileStatus) -> list[LecturerProfile] {
        return [profile for profile in [root ->:HAS_LECTURER_PROFILE:->[?:LecturerProfile]] if profile.status == status and profile.user_id == jid(root)];
    }

    def save(profile: LecturerProfile) { IdentityRepository().save_lecturer_profile(profile); }
}
