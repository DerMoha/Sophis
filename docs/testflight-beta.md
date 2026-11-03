# Sophis TestFlight beta release

## Repository setup already present

- iOS app ID: `com.sophis.sophis`; widget ID: `com.sophis.sophis.SophisWidget`.
- Automatic signing and a developer team are configured in the Xcode project.
- The app includes its icon, HealthKit and App Group entitlements, and an iOS
  privacy manifest.
- `scripts/build_testflight.sh` creates a signed App Store IPA and embeds the
  public policy, support, and terms URLs in the build.

## Before the first upload

1. Replace every placeholder in `privacy-policy-template.md`; publish the
   privacy policy, support page, and terms page over HTTPS.
2. Confirm the Apple Developer account owns the app ID, widget App ID, App
   Group, HealthKit capability, and signing certificates for team `M8869GQ6Z6`.
3. Create the app record in App Store Connect with bundle ID
   `com.sophis.sophis` and complete its contact, age-rating, export-compliance,
   and App Privacy information.
4. Review the current provider terms and the App Privacy declarations for
   every AI provider enabled in the beta. AI requests send the selected image
   or text directly to that provider using the user's key.
5. Test the release build on a physical iPhone, including fresh install,
   camera/photo access, HealthKit permission, widget, deep links, backup/restore,
   and delete-all-data.
6. Add English and German TestFlight notes, screenshots, tester groups, and a
   reviewer path that works without an AI key. Never put a real API key in the
   app bundle or review notes.

## Build and upload

Replace the example domains with the three published URLs and run the release
script. The script defaults the build number to the current Unix timestamp;
pass an explicit number when you need a predictable build identifier.

```bash
export SOPHIS_PRIVACY_POLICY_URL=https://example.com/privacy
export SOPHIS_SUPPORT_URL=https://example.com/support
export SOPHIS_TERMS_URL=https://example.com/terms
scripts/build_testflight.sh 2026110301
```

The IPA is written to `build/ios/ipa/`. Upload it with Transporter or Xcode
Organizer, then choose internal or external testers in App Store Connect.
External testing requires Apple's beta review.

## Still needs account-owner input

- Legal developer name, support contact, published URL domain, and final policy
  wording.
- Apple Developer/App Store Connect access and verification that signing works
  for this machine.
- Final App Privacy and export-compliance answers based on the exact providers
  and production build.
