
We're fixing the current Phase 1 workflow issues.

Current problems:

1. When I run `jac run`, and try accessing these 2 endpoints in my client, I get a 404, not found error. I tried heading to my api server specifically the /functions and these 2 very important endpoints do not appear I managed to get a workaround so I could test but every time I close then startup the server they aren't there, generate_roadmap_for_journey and load_roadmap are the culprits. When I pasted this in my assessment_journey.sv.jac
```
def:pub generate_roadmap_for_journey(
    learner_id: str,
    assessment_id: str,
    attempt_id: str,
    evaluation_id: str,
    language: str
) -> dict {
    return {
        "ok": True,
        "learner_id": learner_id,
        "assessment_id": assessment_id,
        "attempt_id": attempt_id,
        "evaluation_id": evaluation_id,
        "language": language
    };
}
``` and saved then refreshed the api server, the endpoints appeared then I reverted it to the original and I could access it.
 Additionally, I noticed an error: "WARNING - cross-boundary endpoint 'generate_roadmap_for_journey' unavailable: ses\\assessment_journey.sv.jac' failed to import (ModuleNotFoundError: No module n
WARNING - cross-boundary endpoint 'load_roadmap' unavailable: server module 'C:\c' failed to import (ModuleNotFoundError: No module named 'roadmap.sv'; 'roadmap".
2. The input fields aren't visible when typing, the color is too similar to the background, text color is black on the already dark background. Noticed this especially during the assessment.


