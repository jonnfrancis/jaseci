
## Current problems:

Problems occuring after implementing the expand, Features 29 - 34
1. Logged into the new account, was redirected to the Dashboard as I should but I got an error: load_dashboard functions returns the error:[{
    "ok": true,
    "type": "response",
    "data": {
        "result": {
            "_jac_type": "DashboardLoadState",
            "_jac_id": "bf823601a5124080825904a58d0ff159",
            "_jac_archetype": "archetype",
            "dashboard": null,
            "message": "Roadmap does not exist.",
            "status": "missing_roadmap"
        },
        "reports": []
    },
    "error": null,
    "meta": {
        "extra": {
            "http_status": 200
        }
    }
}] so I clicked the assessment was redirected to the "Choose your starting track and this time it doesn't quickly fail, because of the last issue fix I think, so I was able to start assessment, and even submit_and evaluate work as it should, but when I clicked the "Generate My Roadmap" button I got errors: [{
    "ok": false,
    "type": "error",
    "data": null,
    "error": {
        "code": "EXECUTION_ERROR",
        "message": "Unable to resolve learning track."
    },
    "meta": {
        "extra": {
            "http_status": 500
        }
    }
}]

2. my localhost:8001/functions endpoints doesnt work. I get a 503 service unavailable. what's that about.

## Resolution

1. Fixed the account-flow failures at both boundaries. The dashboard now loads only from the authenticated learner graph rather than passing potentially cross-account journey recovery values. Roadmap generation forwards the selected track identifiers and also derives them authoritatively from the persisted, learner-owned assessment when the client omits them.
2. Added a Scale-compatible `GET /functions` discovery route. Individual functions use `POST /function/<name>`. Port 8001 is the development client/proxy, so it returns 503 whenever the Jac backend is not running; the direct backend surface is normally port 8000. Production API docs remain intentionally disabled by `docs_enabled = false`.
