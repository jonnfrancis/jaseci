"""AI tutor recommendation read service for the client UI."""

import from walkers.recommend_next_action {
    TutorRecommendationError,
    TutorRecommendationView as WalkerTutorRecommendationView,
    recommend_next_action
}

obj TutorRecommendationView {
    has learner_id: str;
    has roadmap_id: str;
    has language: str;
    has recommendation_type: str;
    has title: str;
    has recommended_action: str;
    has explanation: str;
    has confidence: float;
    has priority: str;
    has suggested_cta_label: str;
    has created_at: str;
    has related_roadmap_lesson_id: str = "";
    has related_challenge_id: str = "";
    has related_skill_ids: list[str] = [];
}

obj TutorRecommendationLoadState {
    has status: str;
    has recommendation: TutorRecommendationView | None = None;
    has message: str = "";
}

def _first_error_message(errors: list[TutorRecommendationError]) -> str {
    if len(errors) == 0 {
        return "AI Tutor recommendation could not be loaded.";
    }
    return str(errors[0].message);
}

def _first_error_code(errors: list[TutorRecommendationError]) -> str {
    if len(errors) == 0 {
        return "failed";
    }
    return str(errors[0].code);
}

def _recommendation_to_view(raw: WalkerTutorRecommendationView) -> TutorRecommendationView {
    return TutorRecommendationView(
        learner_id=raw.learner_id,
        roadmap_id=raw.roadmap_id,
        language=raw.language,
        recommendation_type=raw.recommendation_type,
        title=raw.title,
        recommended_action=raw.recommended_action,
        explanation=raw.explanation,
        confidence=raw.confidence,
        priority=raw.priority,
        suggested_cta_label=raw.suggested_cta_label,
        created_at=raw.created_at,
        related_roadmap_lesson_id=raw.related_roadmap_lesson_id,
        related_challenge_id=raw.related_challenge_id,
        related_skill_ids=raw.related_skill_ids
    );
}

def:pub load_tutor_recommendation(
    learner_id: str,
    roadmap_id: str = "",
    language: str = ""
) -> TutorRecommendationLoadState {
    if learner_id.strip() == "" {
        return TutorRecommendationLoadState(
            status="missing_learner",
            message="Log in again to load an AI Tutor recommendation."
        );
    }

    result = root spawn recommend_next_action(
        learner_id=learner_id,
        roadmap_id=roadmap_id,
        language=language
    );
    if len(result.errors) > 0 {
        return TutorRecommendationLoadState(
            status=_first_error_code(result.errors),
            message=_first_error_message(result.errors)
        );
    }
    if len(result.reports) == 0 {
        return TutorRecommendationLoadState(
            status="empty",
            message="No tutor recommendation yet."
        );
    }

    return TutorRecommendationLoadState(status="ready", recommendation=_recommendation_to_view(result.reports[0]));
}
