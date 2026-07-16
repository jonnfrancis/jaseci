
## Current problems:

Problems occuring after implementing the expand, Features 29 - 34
1. On learners who had already started: Generating new lessons doesn't open, I got this output in my network tab for function open_lesson: [{
    "ok": true,
    "type": "response",
    "data": {
        "result": {
            "_jac_type": "LessonOpenState",
            "_jac_id": "1507a999bb9e49e4a809cb81ad7bde37",
            "_jac_archetype": "archetype",
            "generated_now": false,
            "lesson": null,
            "message": "The registered track graph is incomplete.",
            "next_lesson": {
                "_jac_type": "LessonLinkView",
                "_jac_id": "ca93594c32dd488aa00d82cdd6cdd03d",
                "_jac_archetype": "archetype",
                "order_label": "Week 2 - Lesson 1",
                "roadmap_lesson_id": "roadmap-c04ebbfe19644d34a6bd75cad8da7381-python-c04ebbfe19644d34a6bd75cad8da7381-assessment-4-attempt-1-evaluation-week-2-lesson-1",
                "title": "Lambdas and Higher-Order Functions"
            },
            "previous_lesson": {
                "_jac_type": "LessonLinkView",
                "_jac_id": "54da375380e84f89bc72ccdc5879e643",
                "_jac_archetype": "archetype",
                "order_label": "Week 1 - Lesson 1",
                "roadmap_lesson_id": "roadmap-c04ebbfe19644d34a6bd75cad8da7381-python-c04ebbfe19644d34a6bd75cad8da7381-assessment-4-attempt-1-evaluation-week-1-lesson-1",
                "title": "Function Fundamentals and Scope"
            },
            "status": "generation_failed"
        },
        "reports": []
    },
    "error": null,
    "meta": {
        "extra": {
            "http_status": 200
        }
    }
}]

2. Registered a new account, on the assessment page I got a 500 error: [{
    "ok": false,
    "type": "error",
    "data": null,
    "error": {
        "code": "EXECUTION_ERROR",
        "message": "Unsupported assessment language."
    },
    "meta": {
        "extra": {
            "http_status": 500
        }
    }
}]