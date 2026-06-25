Read `AGENTS.md` and `context/architecture-context.md` before starting.

We're establishing the LMS AI foundation using Jac's built-in byLLM integration.

Confirm byLLM is installed, configured, and available to the project.

Do not build custom OpenAI, Anthropic, Gemini, or provider wrapper classes.

Use byLLM as the single AI abstraction layer.

Create an AI module structure for reusable schemas and AI-powered functions.

Add:

* `lib/ai/schemas.jac`
* `lib/ai/utilities.jac`
* `lib/ai/tests/ai_test.jac`

Create reusable AI response objects for future LMS features.

Examples include:

* SkillAnalysis
* LearningRecommendation
* LearningSummary

All AI-visible fields must use `sem` descriptions.

All AI-powered functions must:

* use `by llm(...)`
* use typed return values
* use structured outputs whenever possible
* use `sem` descriptions for functions and parameters

Do not use raw prompt strings scattered throughout the codebase.

Centralize reusable AI functions inside `jac/ai/utilities.jac`.

Examples include:

* skill extraction
* learner goal summarization
* learning recommendation generation

Do not implement:

* assessment generation
* challenge generation
* roadmap generation
* walker orchestration
* agent workflows

These features will be implemented later.

Confirm project-level byLLM configuration exists.

Use environment variables for provider credentials.

Support whatever provider is configured through byLLM without provider-specific LMS code.

Add MockLLM test coverage.

Tests must run without API keys.

Use MockLLM structured outputs for all AI tests.

Document and standardize handling for:

* ByLLMError
* AuthenticationError
* RateLimitError
* ModelNotFoundError
* OutputConversionError
* ConfigurationError

Future walkers should be able to import AI functions directly and use them without additional setup.

### Check when done

* byLLM configuration is confirmed
* AI schemas compile successfully
* All AI-visible objects contain sem descriptions
* AI utility functions use by llm(...)
* Structured outputs validate correctly
* MockLLM tests pass without API keys
* No provider-specific wrapper layer exists
* Future walkers can consume AI functions directly
