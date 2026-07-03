
 I tried running the lesson workflow that is "lesson generate -> lesson view-> challenge-workspace -> evaluate-submission -> update-mastery -> get-skill-map" and we have 2 main issues I need help fixing. 

Current problems:

1. After the earlier fix, the Initial starter code still doesn't show up in the code challenge workspace, but is available in the data, there might be a parsing error because the starter code is in the response of the function open-challenge. here is how the data came in: ["starter_code": "user_name = 'Alex'\ncurrent_year = 2024\nage_input = '25'\n\n# TODO: Convert age_input to an integer\n# TODO: Calculate birth_year\n# TODO: Print the user's information",]
2. When I try to load my skill-map page, I get a "Skill map is not ready" error then I get a [Client error: Exception: Function SkillMapLoadState failed: {"ok": false, "type": "error", "data": null, "error": {"code": "NOT_FOUND", "message": "Function 'SkillMapLoadState' not found"}, "meta": {"extra": {"http_status": 404}}}] in my terminal. Could you help fix it.

