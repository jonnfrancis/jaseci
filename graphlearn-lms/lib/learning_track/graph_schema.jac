"""Feature 32 graph-boundary validation shared by later repositories."""

import from nodes.graph_integrity { GraphIntegrityIssue, GraphIntegrityReport }

glob TRACK_GRAPH_MISMATCH: str = "TRACK_GRAPH_MISMATCH";
glob CURRICULUM_NODE_VERSION_MISMATCH: str = "CURRICULUM_NODE_VERSION_MISMATCH";
glob PREREQUISITE_SELF_REFERENCE: str = "PREREQUISITE_SELF_REFERENCE";
glob PREREQUISITE_VALUE_INVALID: str = "PREREQUISITE_VALUE_INVALID";

obj GraphNodeContext {
    has node_id: str;
    has track_id: str;
    has track_version_id: str;
}

def validate_graph_context(
    source_track_id: str,
    source_track_version_id: str,
    target_track_id: str,
    target_track_version_id: str
) -> GraphIntegrityReport {
    issues: list[GraphIntegrityIssue] = [];
    if source_track_id != target_track_id {
        issues.append(GraphIntegrityIssue(
            code=TRACK_GRAPH_MISMATCH,
            severity="ERROR",
            message="Connected nodes must belong to the same learning track."
        ));
    } elif source_track_version_id != target_track_version_id {
        issues.append(GraphIntegrityIssue(
            code=CURRICULUM_NODE_VERSION_MISMATCH,
            severity="ERROR",
            message="Connected nodes must belong to the same track version."
        ));
    }
    return GraphIntegrityReport(
        valid=len(issues) == 0,
        issues=issues,
        checked_nodes=2,
        checked_edges=0
    );
}

def validate_prerequisite(
    prerequisite: GraphNodeContext,
    dependent: GraphNodeContext,
    strength: float,
    required_mastery: float
) -> GraphIntegrityReport {
    context = validate_graph_context(
        prerequisite.track_id, prerequisite.track_version_id,
        dependent.track_id, dependent.track_version_id
    );
    issues = context.issues;
    if prerequisite.node_id == dependent.node_id {
        issues.append(GraphIntegrityIssue(
            code=PREREQUISITE_SELF_REFERENCE,
            severity="ERROR",
            message="A skill cannot be its own prerequisite."
        ));
    }
    if strength < 0.0 or required_mastery < 0.0 or required_mastery > 1.0 {
        issues.append(GraphIntegrityIssue(
            code=PREREQUISITE_VALUE_INVALID,
            severity="ERROR",
            message="Prerequisite strength and mastery threshold are outside allowed bounds."
        ));
    }
    return GraphIntegrityReport(
        valid=len(issues) == 0,
        issues=issues,
        checked_nodes=2,
        checked_edges=1
    );
}
