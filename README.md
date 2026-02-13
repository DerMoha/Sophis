# Sophis

Sophis is a Flutter nutrition tracker with local-first storage (SQLite + SharedPreferences).

## Development

- Install dependencies: `flutter pub get`
- Run app: `flutter run`
- Analyze: `flutter analyze`
- Run tests: `flutter test`

## OS Backup Restore (No Login, No Backend)

Sophis now relies on native OS backup/restore to recover local data after uninstall/reinstall.

### What Is Covered

- App database (SQLite)
- SharedPreferences data
- App files in the backed-up app sandbox
- Secure storage restore is attempted; if key restoration fails, the app continues and the user can re-enter the key

### Important Limits

- This is best-effort behavior from iCloud/Google backup, not a guaranteed restore for every reinstall.
- Restore usually requires the same platform account and backup to be enabled before uninstall.
- Debug/local development reinstalls are not a reliable signal of real restore behavior.

### Why Debug Reinstall Can Differ

- Debug builds and local install/uninstall cycles often bypass normal cloud backup/restore timing.
- Production-like channels (Play release/internal testing, TestFlight/App Store) better represent real user restore behavior.

## QA Checklist For Restore Validation

Use release-like builds when validating restore behavior.

1. Install app and add representative data (goals, profile, food, water, weight, workouts, settings).
2. Confirm OS backup is enabled.
3. Trigger/allow device backup completion.
4. Uninstall and reinstall the same app package/bundle.
5. Open app and verify persisted data restored, including weight history.
6. Verify app still starts if secure storage key restore fails (API key may require re-entry).
7. Repeat with backup disabled to confirm expected clean-state reinstall behavior.
