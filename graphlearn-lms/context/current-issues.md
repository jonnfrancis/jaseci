
We're fixing the current Phase 1 workflow issues.

Current problems:

1. After completing the assessment, the app only shows assessment results.
2. There is no way to continue into roadmap/course outline generation.
3. The assessment journey sometimes fails with an "unable to load assessment journey" error, a 401 error for the `load-assessment_journey` walker, with a unauthenticated error in the network tab.
4. Authentication is not wired into the frontend workflow.
5. Walkers that require learner/user context do not consistently receive authenticated user information.

This feature connects authentication, assessment, evaluation, roadmap generation, and roadmap navigation into one working user journey.

Do not build new LMS features.

Do not generate lesson content.

Do not implement mastery updates.

Do not implement dashboard analytics.

---

## Goal

Make this workflow work end-to-end:

```text
Landing Page
→ Register/Login
→ Select Python or Jac
→ Initialize Assessment
→ Complete Assessment
→ Submit Assessment
→ Evaluate Assessment
→ Generate Roadmap
→ View Roadmap/Course Outline
```

The learner should never get stuck on the assessment results page with no next action.

---

## Backend Auth Endpoints

Jac already exposes:

```text
POST /user/register
POST /user/login
```

Use these existing endpoints.

Do not create a custom authentication backend.

Do not add third-party auth.

Do not add Clerk/Auth.js.

---

## Frontend Auth Integration

Create a small frontend auth layer.

Suggested files:

```text
lib/auth/
├── auth-client
├── auth-storage
├── auth-types
└── index
```

The auth client should support:

* register
* login
* logout
* get current token
* get current user id if returned by backend
* check authenticated state

Store the returned auth token securely enough for the current development stage.

For now, use localStorage unless the existing Jac Client setup already provides a better pattern.

Do not over-engineer auth.

---

## Auth Types

Create frontend types for auth responses.

Support possible backend response fields:

```ts
type AuthResponse = {
  token?: string;
  access_token?: string;
  user_id?: string;
  username?: string;
  email?: string;
};
```

Normalize the response inside the auth client so the rest of the app can use a consistent shape.

---

## Auth UI

Add simple authentication screens or modal flow.

Minimum required:

* register form
* login form
* logout action

Fields:

Register:

* username or name
* email if required by backend
* password

Login:

* username/email
* password

Adapt fields to the actual Jac endpoint requirements.

Do not add password reset.

Do not add email verification.

Do not add social login.

---

## Landing Page Auth Behavior

Update the landing page CTA behavior.

If the user is not authenticated:

* show login/register prompt
* after successful auth, continue the selected language flow

If the user is authenticated:

* allow direct language selection
* allow starting assessment immediately

Supported languages remain:

* Python
* Jac

Do not expose more languages.

---

## Authenticated Walker Calls

Update all frontend calls that need learner context to include the authenticated token.

This includes calls to:

* initialize_assessment
* submit_assessment
* evaluate_assessment
* generate_roadmap
* roadmap retrieval used by roadmap UI

Use the existing Jac Client / Spawn pattern already established in the project.

Do not replace Spawn with unrelated REST wrappers unless the project already uses endpoint calls for auth only.

---

## User/Learner Context Mapping

Fix learner identity flow.

After login/register:

1. Store auth token.
2. Store user id / learner id if returned.
3. Use that id when calling assessment and roadmap walkers.
4. Avoid hardcoded learner ids.
5. Avoid anonymous fallback learner ids unless explicitly needed for local dev.

If the backend returns `user_id`, use it as the learner identifier.

If the backend uses a different field name, normalize it in the auth client.

---

## Fix Assessment Journey Loading Error

Investigate and fix the "unable to load assessment journey" issue.

Likely causes to check:

* missing auth token
* missing learner id
* assessment id not persisted after initialization
* route reload loses assessment state
* frontend expects data shape different from walker output
* walker call missing required args
* protected backend call receives no token

The fix should ensure:

* assessment journey can load after page refresh
* assessment id is stored after initialization
* attempt id is stored after submission
* evaluation id is stored after evaluation
* roadmap id is stored after roadmap generation

Do not rely only on in-memory React state for critical journey ids.

---

## Assessment Results Page Update

Update the assessment results screen.

After evaluation succeeds, display:

* overall score
* skill signals
* summary

Add a primary CTA:

```text
Generate My Roadmap
```

When clicked:

1. Call `generate_roadmap`
2. Pass learner id
3. Pass assessment id
4. Pass assessment attempt id
5. Pass assessment evaluation id
6. Pass selected language
7. Persist returned roadmap id
8. Navigate to roadmap page

Do not generate roadmap automatically unless the current UX already does that intentionally.

Prefer explicit CTA so the learner understands the transition.

---

## Optional Auto-Continue Behavior

If the project already uses a single guided journey flow, it is acceptable to automatically generate the roadmap after evaluation.

If doing so, still show clear loading UI:

```text
Creating your personalized course outline...
```

Do not leave the user on a blank screen.

---

## Roadmap Navigation

After `generate_roadmap` succeeds, navigate to:

```text
/roadmap/:roadmapId
```

or the existing route convention used by the app.

The roadmap page should load the persisted roadmap.

Do not pass the entire roadmap only through navigation state.

A page refresh on the roadmap page should still work.

---

## Loading States

Add helpful loading states for each phase:

Assessment initialization:

```text
Preparing your assessment...
```

Assessment submission:

```text
Saving your answers...
```

Assessment evaluation:

```text
Evaluating your skill profile...
```

Roadmap generation:

```text
Creating your personalized course outline...
```

Roadmap loading:

```text
Loading your roadmap...
```

Use skeletons where layout is known.

Use spinners only where generation/evaluation is actually running.

---

## Error Handling

Handle:

* unauthenticated user
* login failure
* register failure
* expired/missing token
* assessment initialization failure
* assessment loading failure
* submission failure
* evaluation failure
* roadmap generation failure
* roadmap loading failure

Each error state should provide a clear next action.

Examples:

* Try again
* Log in again
* Return to landing page
* Restart assessment

Do not expose raw backend stack traces.

---

## Duplicate Prevention

Prevent accidental duplicate actions.

Disable buttons while calls are in progress:

* Start Assessment
* Submit Assessment
* Evaluate Assessment
* Generate Roadmap

If a roadmap already exists for the same learner, language, and evaluation, reuse the existing roadmap if the backend supports that behavior.

Do not create multiple active roadmaps from repeated clicks.

---

## Journey State Persistence

Create a small journey state helper.

Persist:

* selected language
* assessment id
* attempt id
* evaluation id
* roadmap id

This is frontend recovery state only.

The graph/backend remains the source of truth.

---

## Integration With Existing Features

This should connect previously implemented features:

* 05 initialize_assessment
* 06 assessment UI
* 07 submit_assessment
* 08 evaluate_assessment
* 09 landing page
* 10 generate_roadmap
* 11 roadmap UI

Do not rewrite these systems unless required to fix integration bugs.

Prefer minimal changes.

---

## Testing

Add integration tests or manual verification steps for:

### Register Flow

```text
Landing
→ Register
→ Select Python
→ Assessment
→ Submit
→ Results
→ Generate Roadmap
→ Roadmap Page
```

### Login Flow

```text
Landing
→ Login
→ Select Jac
→ Assessment
→ Submit
→ Results
→ Generate Roadmap
→ Roadmap Page
```

### Refresh Recovery

Verify refresh works on:

* assessment page
* results page
* roadmap page

### Error Recovery

Verify:

* unauthenticated user is redirected or prompted
* failed roadmap generation can be retried
* duplicate roadmap generation is prevented

---

## Explicitly Out of Scope

Do not implement:

* lesson generation
* challenge generation
* mastery updates
* unlock logic
* dashboard analytics
* skill map visualization
* AI tutor
* certificates
* password reset
* email verification
* social login
* admin users
* role-based permissions

This feature only fixes authentication and connects the assessment-to-roadmap workflow.

---

## Check When Done

* User can register through the frontend
* User can login through the frontend
* Auth token is stored and reused
* Logout works
* Landing CTA respects auth state
* Python assessment flow works end-to-end
* Jac assessment flow works end-to-end
* Assessment journey no longer fails from missing user context
* Assessment can be initialized after auth
* Assessment can be submitted after auth
* Assessment can be evaluated after auth
* Results page shows a Generate My Roadmap CTA
* generate_roadmap is called with the correct ids
* Roadmap id is persisted after generation
* User is navigated to roadmap page
* Roadmap page loads the generated roadmap
* Page refresh does not break the journey
* Duplicate submissions/generations are prevented
* No lesson generation exists
* No mastery update exists
* No dashboard logic exists
