
We're fixing the current Phase 1 workflow issues.

Current problems:

1. I tried heading to my api server specifically the /functions and 2 very important functions do not appear, generate_roadmap_for_journey and load_roadmap. Additionally, I noticed an error: "WARNING - cross-boundary endpoint 'generate_roadmap_for_journey' unavailable: ses\\assessment_journey.sv.jac' failed to import (ModuleNotFoundError: No module n
WARNING - cross-boundary endpoint 'load_roadmap' unavailable: server module 'C:\c' failed to import (ModuleNotFoundError: No module named 'roadmap.sv'; 'roadmap".
2. There is no way to continue into roadmap/course outline generation.
3. The assessment journey sometimes fails with an "unable to load assessment journey" error, a 401 error for the `load-assessment_journey` walker, with a unauthenticated error in the network tab.
4. Authentication is not wired into the frontend workflow.
5. Walkers that require learner/user context do not consistently receive authenticated user information.

