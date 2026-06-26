"""graphlearn-lms - Entry Point.

Combines server-side endpoints with the client-side UI.
"""

import type from lib.domain.index { Learner }
import from walkers.evaluate_assessment { evaluate_assessment }
import from walkers.initialize_assessment { initialize_assessment }
import from walkers.submit_assessment { submit_assessment }

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return <ClientApp/>;
    }
}
