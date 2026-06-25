"""graphlearn-lms - Entry Point.

Combines server-side endpoints with the client-side UI.
"""

import type from lib.domain.index { Learner }

# Client-side UI
cl {
    import from .frontend { app as ClientApp }

    def:pub app -> JsxElement {
        return <ClientApp/>;
    }
}
