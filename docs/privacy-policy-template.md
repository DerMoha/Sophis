# Sophis Privacy Policy (publication draft)

**Effective date:** [DATE]

**Developer:** [LEGAL NAME]

**Contact:** [SUPPORT EMAIL AND POSTAL/LEGAL CONTACT AS REQUIRED]

Sophis is a local-first nutrition tracking application. Core tracking does not require an account. Optional partner sharing uses
Firebase Authentication and Cloud Firestore. Sophis does not use advertising,
cross-app tracking, or third-party analytics.

This policy explains what is processed on the device and what leaves the
device when a user chooses an external feature. The final published version
must include the developer's legal identity, contact details, applicable
jurisdictional rights, and links to the current policies of each external
provider.

## Information processed locally

Sophis stores nutrition goals and logs, water and weight entries, workouts,
meal plans, recipes, supplement records, preferences, barcode results, and
progress photos locally on the device. The app uses SQLite and local
preferences for app data and the operating system's secure credential storage
for a user-provided AI provider API key and optional Open Food Facts
credentials.

Nutrition-label scanning is local by default. Google ML Kit performs on-device
text recognition, and Sophis applies a local parser and validation rules to
the OCR result. The original label image is not sent to a cloud AI provider
during this local pass. Captured label images are currently also saved to the
device's Photos library; users can manage or delete those copies there.

Apple Health data is read or written only after the user grants the relevant
HealthKit permission. Notifications and progress-photo biometric protection
are handled locally by the operating system.

## Optional partner sharing

Creating a partner account sends your email address and authentication
credentials to Firebase Authentication. Your profile includes a display name
and account identifier. Connecting a partner shares your last seven diary
days, including food entries, nutrition goals, and burned calories, through
Cloud Firestore. Your connected partner can access this information.

Disconnecting removes the shared day documents and connection. Account deletion
in the app also removes your profile, invitations, and Firebase account.
Deleting only local app data does not delete the remote partner account or
copies another person has already retained. Firebase processing and retention
are governed by Google's terms and privacy policy.

## Optional external features

- Food search sends the search term to Open Food Facts. Barcode lookup sends
  the barcode to Open Food Facts and, if needed, Brocade to find product
  information. Returned results may be cached locally.
- AI food, recipe, and image features send the image or text selected by the
  user directly from the app to their selected provider (Google Gemini, OpenAI,
  OpenRouter, Anthropic, or a custom OpenAI-compatible endpoint) using the
  user's own API key.
- If local nutrition-label parsing is uncertain and the user has configured a
  cloud AI API key, Sophis may send the label image and/or OCR text to
  that provider as an optional fallback. AI results are estimates and must be reviewed.
- If the user submits a product to Open Food Facts, the entered Open Food
  Facts credentials and product data are sent to that service.

AI and food lookup requests are sent directly to the selected services.
Partner sharing separately uses the Firebase backend described above.
The selected AI providers, Google Firebase, Open Food Facts, Brocade, and Apple
control their own processing and
retention under their respective terms and privacy policies. Sophis does not
use health, fitness, or photo data for advertising, marketing, or tracking.

## Photos, camera, sharing, and export

Camera and photo-library access is used for barcode, nutrition-label, meal,
and progress-photo features. Progress photos remain local unless the user
chooses to export or share them. The operating system's share sheet can send
user-selected content to an app or recipient chosen by the user.

Users can export a versioned backup containing their nutrition records and
progress-photo files. Exported files are controlled by the user after they
leave Sophis.

## Deletion, retention, and security

“Delete All Local Data” removes Sophis records, Sophis-owned progress-photo
files, settings, reminders, and saved credentials from the app. It does not
remove copies that the user has exported, shared, or that the label scanner
has saved to the system Photos library; users can manage those copies in
Photos. Users can also remove their saved API keys and Open Food Facts
credentials from Settings. Device or cloud backups controlled by the
operating system may follow the platform's retention rules.

Sophis does not retain external requests on a developer-operated server.
Requests sent to external providers may be retained or processed by those
providers according to their current terms; users should review those terms
before enabling an external feature.

## Children, medical use, changes, and contact

[ADD THE AGE POLICY, SECURITY PRACTICES, JURISDICTION-SPECIFIC RIGHTS, POLICY
CHANGE PROCESS, AND CONTACT/COMPLAINT PROCESS REVIEWED FOR THE DEVELOPER'S
ACTUAL LOCATION AND TARGET MARKETS.]

Sophis provides general nutrition tracking and is not medical advice. Users
should consult a qualified professional before making medical or dietary
decisions.
