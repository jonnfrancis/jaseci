"""graphlearn-lms - Entry Point.

Combines server-side endpoints with the client-side UI.
"""

import type from lib.domain.index { Learner }
import from services.challenge { open_challenge, start_challenge, submit_challenge_solution }
import from services.assessment_journey { generate_roadmap_for_journey }
import from services.dashboard { load_dashboard }
import from services.lesson { open_lesson }
import from services.learning_track { get_learning_track, list_learning_tracks, migrate_learning_tracks, resolve_legacy_learning_track }
import from services.identity { resolve_current_learner }
import from services.roadmap { load_roadmap }
import from services.skill_map { load_skill_map }
import from services.tutor { load_tutor_recommendation }
import from walkers.evaluate_assessment { evaluate_assessment }
import from walkers.evaluate_submission { evaluate_submission }
import from walkers.generate_challenge { generate_challenge }
import from walkers.generate_lesson { generate_lesson }
import from walkers.generate_roadmap { generate_roadmap }
import from walkers.get_dashboard { get_dashboard }
import from walkers.get_skill_map { get_skill_map }
import from walkers.initialize_assessment { initialize_assessment }
import from walkers.recommend_next_action { recommend_next_action }
import from walkers.submit_challenge { submit_challenge }
import from walkers.submit_assessment { submit_assessment }
import from walkers.unlock_next_lesson { unlock_next_lesson }
import from walkers.update_mastery { update_mastery }

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return <ClientApp/>;
    }
}
