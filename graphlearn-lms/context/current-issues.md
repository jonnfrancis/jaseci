
## Current problems:

Status: issues 1 and 2 were implemented in the current issue-fix unit. Issue 3 now has admin-protected onboarding, publishing-capability, and course-reviewer endpoints plus a development invocation script documented in `context/approval-publication-test-plan.md`; authorization-aware action-state UX remains a required follow-up before production launch.

Problems occuring after implementing the expand, Features 29 - 34
1. the document’s processing_status remains ANALYZING even after reaching READY_FOR_BLUEPRINT. That field is stale/confusing, although the authoritative processing state and completed jobs show success. 

The blueprint status endpoint also hardcodes warning_count=0, so it cannot report the three validation warnings. See [generation_service.jac (line 87)].

2. In the route /courses/:courseId, the Curriculum and Publishing tabs are empty I need them to show their respective data, like their Source Material counterpart. 

3. I need a gameplan on how I can test approval and publication of the blueprint and how I will handle the same test and approval in production. I need you to investigate and document the way forward here. Here is the current issue: [Why approval fails
Your account owns this course. The authorization policy allows blueprint approval only when:
The actor has the assigned REVIEWER role, or
The actor owns the course and ALLOW_LECTURER_SELF_APPROVAL=true.
Self-approval defaults to false, both in the code and .env.example. See [policy.jac (line 153)].
Therefore, the request is rejected before the validation-based approval service runs. The UI incorrectly enables the button because approval_available only checks validation freshness and blocking issues; it does not incorporate the current actor’s approval permission. See [blueprint review service (line 54)].
The client then catches every possible exception and replaces the real authorization error with:
  `Approval was blocked. Refresh the review and resolve validation issues.`

That message is misleading here. See [BlueprintReviewPage.cl.jac (line 36)].
One additional blocker awaits publication: the persisted lecturer profile has can_publish_courses: false. Even after a reviewer approves the blueprint, this owner cannot publish until that server-controlled capability is enabled; publication authorization checks it in [policy.jac (line 158)]]

Documented resolution: follow `context/approval-publication-test-plan.md`. The production-equivalent test uses separate owner and reviewer accounts; the single-account self-approval flag is a development-only shortcut.


I have experience an irregularity, although not consistently, my course dashboard function get_lecturer_course_dashboard has been giving me this error. Investigate and ignore if everything is okay, but if not suggest, then implement a fix. [{
    "ok": false,
    "type": "error",
    "data": null,
    "error": {
        "code": "EXECUTION_ERROR",
        "message": "DASHBOARD_LOAD_FAILED"
    },
    "meta": {
        "extra": {
            "http_status": 500
        }
    }
}]