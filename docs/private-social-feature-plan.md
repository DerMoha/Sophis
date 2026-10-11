# Partner sharing

Status: revised 2026-10-10. Connection acceptance enables full nutrition sharing
in both directions. This replaces the previous individual-consent and pause model.

## Experience

- Guests can keep tracking locally or create an optional account.
- A private invitation and mutual acceptance connect two people. The invitation
  explains that accepting shares the full food diary, nutrition goals and daily progress.
- One accepted partner opens directly to their day. Multiple partners retain a chooser;
  pending invitations remain visible for approval or cancellation.
- The day shows calories and macros, followed by food grouped into the author’s meal
  categories. A date picker opens earlier days in the partner’s time zone.
- Copy a meal or choose items from the fully loaded day, then adjust the portion,
  destination date and meal category. Days above the 50-item import limit use individual imports.
- There are no individual permission or pause switches. Disconnect is in the partner
  options menu and ends access for both people after confirmation.

## Data and security

SQLite/NutritionStore remains authoritative. Accepted connections automatically project
all available food history, current nutrition goals and numeric daily contributions.
The versioned projection checkpoint replays history for existing connections, including
those with old switches disabled or sharing paused. Both apps must sync before their
complete local diaries are available remotely. This is food and nutrition sharing;
weight, health source records, progress photos and credentials have no sharing transport.

Production uses Firebase Authentication and Firestore on Spark, without Functions or
Storage. The legacy callable backend stays isolated for historical regression tests.
Existing settings fields and generations remain for document compatibility; active
connection membership authorizes access, rather than category flags or activation dates.
Old toggle requests are compatibility no-ops in the production client.

Firestore rules enforce mutual acceptance, participant membership, author-only writes,
whitelisted nutrition payloads, monotonic source revisions and deletion tombstones.
Disconnect removes partner read and sync access. Imported entries remain independent
local copies. Sign-out clears account-specific caches and queued work, leaving the diary.
Authentication epochs and account generations prevent work crossing account switches.

Reads filter the selected date/time zone before pagination (20 records per page).
Daily summaries aggregate at most 200 contributions and fail instead of showing
truncated totals. Current goals are also used when viewing historical days.
Refresh and app resume sync queued changes; there is no remote polling.

## Release and verification

The updated `backend/firestore.rules` were published to `sophis-d2953` on
2026-10-10 at 12:56 Europe/Berlin and the release APK was installed on the connected
Android phone. See [Firebase setup](firebase-setup.md) for deployment verification.

Local coverage includes single/multiple/pending partner navigation, automatic full-history
projection, idempotent updates, account isolation, real Auth/Firestore transport,
third-account denial, deletion and disconnect. The native integration fixtures use the
new automatic model and retain independent portion imports. Run paired device checks
against the updated rules before release.
