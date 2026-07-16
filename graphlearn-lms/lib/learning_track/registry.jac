"""Canonical registry for fully supported built-in programming tracks."""

obj BuiltinProgrammingTrackDefinition {
    has canonical_language: str;
    has track_id: str;
    has track_version_id: str;
    has configuration_id: str;
    has slug: str;
    has title: str;
    has description: str;
    has subject_area: str;
    has aliases: list[str];
    has supports_code_challenge: bool = True;
    has enabled: bool = True;
}

glob BUILTIN_PROGRAMMING_TRACKS: list[BuiltinProgrammingTrackDefinition] = [
    BuiltinProgrammingTrackDefinition(
        canonical_language="python",
        track_id="trk_builtin_python",
        track_version_id="trv_builtin_python_v1",
        configuration_id="cfg_builtin_python",
        slug="python-programming",
        title="Python Programming",
        description="Fundamentals, syntax, functions, and control flow.",
        subject_area="Computer Science",
        aliases=["python", "python3", "py"]
    ),
    BuiltinProgrammingTrackDefinition(
        canonical_language="jaseci",
        track_id="trk_builtin_jaseci",
        track_version_id="trv_builtin_jaseci_v1",
        configuration_id="cfg_builtin_jaseci",
        slug="jaseci-programming",
        title="Jaseci Programming",
        description="Graph-native programming with walkers, nodes, edges, and traversal concepts.",
        subject_area="Computer Science",
        aliases=["jaseci", "jac", "jaclang"]
    )
];

def normalize_legacy_language(value: str | None) -> str | None {
    if value is None { return None; }
    normalized = value.strip().lower().replace("_", "-").replace(" ", "-");
    while "--" in normalized { normalized = normalized.replace("--", "-"); }
    normalized = normalized.strip("-");
    return normalized if normalized != "" else None;
}

def builtin_track_by_id(track_id: str) -> BuiltinProgrammingTrackDefinition | None {
    for definition in BUILTIN_PROGRAMMING_TRACKS {
        if definition.enabled and definition.track_id == track_id { return definition; }
    }
    return None;
}

def builtin_track_by_version_id(track_version_id: str) -> BuiltinProgrammingTrackDefinition | None {
    for definition in BUILTIN_PROGRAMMING_TRACKS {
        if definition.enabled and definition.track_version_id == track_version_id { return definition; }
    }
    return None;
}

def builtin_track_by_language(value: str | None) -> BuiltinProgrammingTrackDefinition | None {
    normalized = normalize_legacy_language(value);
    if normalized is None { return None; }
    for definition in BUILTIN_PROGRAMMING_TRACKS {
        if definition.enabled and normalized in definition.aliases { return definition; }
    }
    return None;
}

def registry_is_valid -> bool {
    track_ids: list[str] = [];
    version_ids: list[str] = [];
    configuration_ids: list[str] = [];
    slugs: list[str] = [];
    aliases: list[str] = [];
    for definition in BUILTIN_PROGRAMMING_TRACKS {
        if not definition.track_id.startswith("trk_builtin_") or not definition.track_version_id.startswith("trv_builtin_") or not definition.configuration_id.startswith("cfg_builtin_") {
            return False;
        }
        if definition.track_id in track_ids or definition.track_version_id in version_ids or definition.configuration_id in configuration_ids or definition.slug in slugs {
            return False;
        }
        track_ids.append(definition.track_id);
        version_ids.append(definition.track_version_id);
        configuration_ids.append(definition.configuration_id);
        slugs.append(definition.slug);
        for alias in definition.aliases {
            if alias in aliases { return False; }
            aliases.append(alias);
        }
    }
    return True;
}
