# Cloud AI provider architecture

Sophis now routes cloud food features through `AiFoodService`. The UI and
nutrition-label workflow consume the same feature contract for food photo
analysis, re-analysis, recipe extraction, and nutrition-label parsing.

`AiFoodServiceFactory` creates the provider adapter from the saved setting:

- Gemini uses the existing Gemini SDK adapter.
- OpenAI and OpenRouter use the OpenAI Chat Completions API shape.
- Anthropic uses its Messages API shape.
- Custom endpoints use an HTTPS OpenAI-compatible Chat Completions endpoint.

Provider IDs and model IDs are editable in Settings. Empty model IDs use the
adapter default. API keys are stored separately in iOS Keychain / Android
secure storage for each provider; the app continues to send requests directly
from the device using the user's own key. Requests are limited to 20 per
provider per day in the app. Provider billing, model availability, vision
support, and retention are controlled by the selected provider.

The common adapter normalizes responses into Sophis domain models. New
providers should implement `AiFoodService`, map requests and responses, and
register their factory branch without changing screen code. Custom endpoints
must support image input, JSON mode, and the OpenAI Chat Completions request
shape for image-based flows.
