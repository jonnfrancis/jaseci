"""graphlearn-lms - Client-Side UI."""

import "./assets/globals.css";
import from .components.AppShell { AppShell }

def:pub app -> JsxElement {
    return <AppShell/>;
}
