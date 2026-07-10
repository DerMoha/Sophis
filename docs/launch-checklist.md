# Sophis iOS Launch Checklist

## Build configuration

- Install full Xcode, then run:
  - `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
  - `sudo xcodebuild -runFirstLaunch`
- Configure App Store distribution signing for `com.sophis.sophis` and the
  `SophisWidgetExtension` target.
- Verify the HealthKit entitlement, keychain access group, and
  `group.sophis.sophis` app group exist in the Apple Developer portal.
- Build with working public URLs:

  ```bash
  flutter build ipa --release \
    --dart-define=PRIVACY_POLICY_URL=https://YOUR-DOMAIN/privacy \
    --dart-define=SUPPORT_URL=https://YOUR-DOMAIN/support \
    --dart-define=TERMS_URL=https://YOUR-DOMAIN/terms
  ```

- Generate Xcode's privacy report and compare it with
  `ios/Runner/PrivacyInfo.xcprivacy` and every bundled dependency manifest.

## App Store Connect

- Publish the privacy, support, and terms pages before uploading the review
  build. Replace every bracketed placeholder in `privacy-policy-template.md`.
- Complete App Privacy consistently with actual behavior:
  - Nutrition history, settings, credentials, and progress photos are stored
    locally by default.
  - Food search/barcode terms are sent to Open Food Facts and Brocade.
  - Images/text are sent to Google Gemini only after the user selects an AI
    action and supplies an API key.
  - Health and fitness data is exchanged with Apple Health only after explicit
    permission.
  - Sophis has no account, advertising, tracking, analytics SDK, or data broker.
- Add localized English and German name/subtitle/description/keywords, privacy
  URL, support URL, review notes, screenshots, and the current version/build.
- State in review notes that AI is optional and explain how reviewers can test
  search, manual entry, barcode/label scanning, HealthKit, and the widget.

## Acceptance gates

- `flutter analyze` and `flutter test` pass.
- Upgrade tests prove v1/v2 data survives v3 reconciliation and relaunch.
- A signed archive installs on a physical iPhone and the widget shares data.
- Test camera, photos, notifications, biometrics, and Health permissions from a
  fresh install and after denial.
- Test backup/restore, delete-all-data, deep links, English/German, dark mode,
  200% text, VoiceOver, and the smallest supported iPhone width.
- Complete at least one week of TestFlight use with no open P0/P1 defects.

## Android follow-up

- Replace debug signing with a protected upload keystore.
- Add an adaptive launcher icon and complete Play Data Safety/Health forms.
- Build and test a signed app bundle. The optional ML Kit R8 references are
  already handled in `android/app/proguard-rules.pro`.
