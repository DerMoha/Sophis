# App Store Connect privacy working notes

This is a product-accuracy checklist for completing App Store Connect App
Privacy. It is not legal advice and must be checked against the current terms
of Google Gemini, Open Food Facts, and Brocade before publishing.

## What Sophis does not do

- No user account or developer-operated backend.
- No advertising, cross-app tracking, data broker, or analytics SDK.
- No transmission of the local nutrition database merely because the app is
  installed or used offline.
- No Gemini request for a label scan when local OCR and parsing produce a
  high-confidence result.

## What can leave the device

- Selected meal or recipe images and text sent directly to Google Gemini when
  the user invokes an AI feature.
- OCR text sent to Google Gemini only as the optional nutrition-label fallback
  when local parsing is uncertain and a user API key is configured.
- Search terms sent to Open Food Facts.
- Barcodes sent to Open Food Facts and, when needed, Brocade.
- Product data and optional Open Food Facts credentials sent when the user
  chooses to submit a product.
- HealthKit values exchanged with Apple only after the user grants the
  relevant permission.

## Likely App Privacy categories to review

The exact App Store Connect answers depend on the providers' current data
practices. Review at least:

- Health & Fitness: health, weight, nutrition, and workout information used
  for app functionality.
- Photos or Videos: user-selected images sent to Gemini for AI processing.
- Other User Content: nutrition-label OCR text or other user-provided content
  sent to Gemini.
- Identifiers or Contact Info only if a provider's SDK or request handling
  makes those available beyond what is necessary to service a request.

Do not select “we collect no data” solely because Sophis has no backend.
Apple's definition includes data transmitted off-device that a developer or
third-party partner can access beyond the time needed to service a request.
Conversely, data processed only on-device is not collected for this label.

## Release evidence to keep

- Final privacy policy URL and support contact.
- Screenshots or review notes showing that AI is optional and the label flow
  identifies local OCR versus Gemini fallback.
- Current provider terms and privacy-policy links.
- A record of the App Store Connect answers and the app build to which they
  apply.
