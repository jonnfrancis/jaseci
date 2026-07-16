"""Feature 32 OSP schema topology and boundary tests."""

import from edges.domain_edges { CONTAINS_SKILL, HAS_ROADMAP, HAS_ROADMAP_ITEM }
import from lib.learning_track.graph_schema { GraphNodeContext, validate_graph_context, validate_prerequisite }
import from nodes.enrollment { Enrollment, RoadmapItem }
import from nodes.learning_track { TrackSourceKind, TrackVersion }
import from nodes.roadmap { Roadmap, RoadmapStatus }
import from nodes.skill { Skill }

test "track version curriculum is reachable through named edges" {
    version = TrackVersion("v1", "t1", 1, "Track", TrackSourceKind.MANUAL, "owner", "now", "now");
    skill = Skill("legacy-s1", "Variables", "", "core", "t1", "v1", "s1", "Variables");
    version +>:CONTAINS_SKILL(order_index=0):+> skill;
    assert skill in [version ->:CONTAINS_SKILL:->];
}

test "enrollment graph remains learner scoped and version explicit" {
    enrollment = Enrollment("e1", "l1", "t1", "v1", "now");
    roadmap = Roadmap("r1", "l1", "Python", "Roadmap", "", 1, RoadmapStatus.active, "now", "a1", "aa1", "ae1", [], [], [], "t1", "v1");
    item = RoadmapItem("ri1", "r1", "t1", "v1", 0, "s1");
    enrollment +>:HAS_ROADMAP(active=True):+> roadmap;
    roadmap +>:HAS_ROADMAP_ITEM(order_index=0):+> item;
    assert roadmap in [enrollment ->:HAS_ROADMAP:->];
    assert item in [roadmap ->:HAS_ROADMAP_ITEM:->];
}

test "cross-track and cross-version graph context is rejected" {
    cross_track = validate_graph_context("t1", "v1", "t2", "v2");
    cross_version = validate_graph_context("t1", "v1", "t1", "v2");
    assert not cross_track.valid and cross_track.issues[0].code == "TRACK_GRAPH_MISMATCH";
    assert not cross_version.valid and cross_version.issues[0].code == "CURRICULUM_NODE_VERSION_MISMATCH";
}

test "prerequisite boundaries reject self links and invalid thresholds" {
    skill_one = GraphNodeContext("s1", "t1", "v1");
    skill_two = GraphNodeContext("s2", "t1", "v1");
    self_link = validate_prerequisite(skill_one, skill_one, 1.0, 0.8);
    invalid_value = validate_prerequisite(skill_one, skill_two, -1.0, 1.1);
    assert not self_link.valid and self_link.issues[0].code == "PREREQUISITE_SELF_REFERENCE";
    assert not invalid_value.valid and invalid_value.issues[0].code == "PREREQUISITE_VALUE_INVALID";
}
