"""Focused ownership traversal coverage for assessment submission."""

import from edges.domain_edges { assigned }
import from nodes.assessment { Assessment, AssessmentStatus }
import from nodes.learner { Learner }
import from walkers.submit_assessment { _assessment_learner }

test "assessment learner resolves through assigned ownership edge" {
    learner = Learner(
        id="topology-only-learner",
        name="Topology Learner",
        createdAt="test",
        updatedAt="test"
    );
    assessment = Assessment(
        id="topology-only-assessment",
        learner_id=learner.id,
        title="Topology assessment",
        description="Ownership lookup coverage.",
        status=AssessmentStatus.active,
        created_at="test"
    );
    learner +>:assigned:+> assessment;

    resolved = _assessment_learner(assessment, learner.id);

    assert resolved is learner;
}
