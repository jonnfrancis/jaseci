"""Coverage for the Scale-compatible function discovery endpoint."""

import from services.system { list_registered_functions }


test "function discovery includes application service endpoints" {
    functions = list_registered_functions();

    assert "load_dashboard" in functions;
    assert "generate_roadmap_for_journey" in functions;
    assert "open_lesson" in functions;
}
