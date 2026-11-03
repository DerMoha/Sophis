# App Store Connect privacy working notes

This is a product-accuracy checklist for completing App Store Connect App
Privacy. It is not legal advice and must be checked against the current terms
of every enabled AI provider, Open Food Facts, and Brocade before publishing.

## What Sophis does not do

- Core tracking needs no account; optional partner sharing uses Firebase Auth
  and Cloud Firestore.
- No advertising, cross-app tracking, data broker, or analytics SDK.
- No transmission of the local nutrition database merely because the app is
  installed or used offline.
- No cloud AI request for a label scan when local OCR and parsing produce a
  high-confidence result.

## What can leave the device

- Partner account email, account identifier, display name, and authentication
  data sent to Firebase; shared diary entries, goals, and burned calories sent
  to Firestore and made available to the connected partner. Review these as
  linked to the user's identity for App Privacy.

- Selected meal or recipe images and text sent directly to the AI provider
  selected by the user (Gemini, OpenAI, OpenRouter, Anthropic, or a custom
  OpenAI-compatible endpoint) when the user invokes an AI feature.
- Label images and/or OCR text sent to the selected provider as the optional
  nutrition-label fallback when local parsing is uncertain and a user API key
  is configured.
- Search terms sent to Open Food Facts.
- Barcodes sent to Open Food Facts and, when needed, Brocade.
- Product data and optional Open Food Facts credentials sent when the user
  chooses to submit a product.
- HealthKit values exchanged with Apple only after the user grants the
  relevant permission.

## Likely App Privacy categories to review

The exact App Store Connect answers depend on the selected providers' current
data practices. Review at least:

- Health & Fitness: health, weight, nutrition, and workout information used
  for app functionality.
- Photos or Videos: user-selected images sent to the selected AI provider for
  AI processing.
- Other User Content: nutrition-label OCR text or other user-provided content
  sent to the selected provider.
- Identifiers or Contact Info only if a provider's SDK or request handling
  makes those available beyond what is necessary to service a request.

Do not select “we collect no data” solely because Sophis has no backend.
Apple's definition includes data transmitted off-device that a developer or
third-party partner can access beyond the time needed to service a request.
Conversely, data processed only on-device is not collected for this label.

## Release evidence to keep

- Final privacy policy URL and support contact.
- Screenshots or review notes showing that AI is optional and the label flow
  identifies local OCR versus cloud AI fallback.
- Current terms and privacy-policy links for every provider enabled in the
  release build, including custom endpoint operators where applicable.
- A record of the App Store Connect answers and the app build to which they
  apply.
