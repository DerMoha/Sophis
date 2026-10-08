# Partner sharing

Status: revised 2026-10-07. This replaces the earlier private social network plan.

## Purpose

Let partners see each other’s nutrition goals, daily intake and logged food,
then copy all or selected shared items into their own diary. The central view
is a partner’s day, using the same calorie and macro language as Today.
Local tracking remains available without an account.

## Scope

- Optional email/password account, recovery and display name.
- Private partner invitations, mutual acceptance and explicit outgoing consent.
- Partner day: calorie/protein/carbohydrate/fat targets, shared daily totals and
  logged meals for the same calendar day in the partner’s time zone.
- Today by default, with a date picker for previously shared days.
- Copy a single shared meal or select items across the loaded day. All items
  start selected; the recipient can deselect food they did not eat and adjust
  servings, destination date and meal category before saving.
- Independent local copies, with retry-safe imports. Editing or deleting the
  original does not change a recipient’s diary.
- Separate controls for goals, daily intake and meals, plus pause and disconnect.
- Existing multiple-partner support stays, with consent independent per partner.

Posts, feeds, followers, reactions, captions, recipe publishing, social photos,
activity feeds and push notifications are out of scope. Existing local recipe
features are unchanged. Do not add these back as prerequisites for sharing food.

## Navigation and UI

1. Today’s heart button or Settings → Partner sharing opens the feature.
2. Guests see a short explanation and sign-in/account creation.
3. Signed-in users see their partners directly, with Invite a partner and refresh
   actions. No social feed or intermediate social hub.
4. Invite a partner creates an expiring link/QR code or accepts a received link.
   The inviter approves the request; neither person shares anything by default.
5. View today opens the partner’s calorie and macro summary followed by that
   day’s meals grouped into Breakfast, Lunch, Dinner and Snacks using the diary’s
   existing meal cards and food rows. The name/date and nutrition values appear
   once. Sharing settings and the eligibility explanation sit below the day,
   collapsed by default.
6. Choose items from this day opens an editable import review after all pages
   load. Days above the existing 50-item import limit use individual meal import.

Use existing theme, cards, radial nutrition indicators and settings switches.
Make unavailable, unshared and paused values explicit. A partner’s day is a
read-only view; adding food always opens the recipient’s local import review.

## Privacy and daily semantics

- Goals, intake and meals require separate consent from each person.
- Only food logged after activation is eligible. Earlier meals and meals logged
  during a pause are excluded, including from daily totals. This is explained in
  the day view; shared intake may differ from the author’s full Today screen.
- Pause freezes previously shared content. Turning off a category revokes that
  category; disconnect revokes the whole connection. Revocations and deletions
  still run while paused.
- Date filtering happens before server pagination and includes author and time
  zone, so another day’s entries never fill the requested day’s page.
- Historical days show the currently shared goals, not historical goal versions.
- No weight, health source records, progress photos, credentials or API keys are
  implicitly shared. Accounts do not enable diary backup or multi-device sync.
- Sign-out/account changes clear account-specific caches and queued work. Local
  diary entries remain on the device. Imported copies cannot be recalled.

## Implementation and compatibility

Keep SQLite/NutritionStore authoritative. Reuse the existing partner projection,
consent, callable repository, account-scoped queue and portion-aware import.
Shared meals include the author’s meal category; summary-only payloads do not.
Older eligible snapshots are upgraded on the next author sync, with uncategorized
records remaining visible under Other meals until then.

Internal `Social*` type names remain for compatibility; they are not a product
commitment to a social network.

The application no longer exposes publication screens or fetches a feed.
The callable endpoint no longer exposes publishing, feeds, follows, reactions
or photo operations. New invitations are partner-only. Old follow invitations
are rejected in the invitation UI. On runtime startup, discard pending post
publication/edit/reaction work and cached feeds, preserving partner work and
cleanup commands. Legacy backend records and deletion routines remain so an
upgrade does not silently destroy hosted data or prevent account cleanup.

Deployment requires the updated function and partner-day Firestore index.
Production deployment and billing are not part of this local revision.
Existing Firebase operating controls remain: no-cost target, bounded pages,
rate limits, App Check and an explicit production enablement gate. The old
backend spike is historical context, not the current product scope.

## Acceptance checks

- Guest/local tracking and existing diary data survive the change.
- Today and Settings lead to the same partner sharing entry point.
- No posting/follower/recipe-sharing controls appear in the app.
- Two people can invite, approve, enable consent and view each other’s day.
- Meals, totals and selected date agree; pagination stays within that day.
- Unshared/paused states are clear; disconnect and consent revocation remove
  access, and a third account cannot read the data.
- A recipient can import all or selected items with their own portion, date and
  meal category; retry does not duplicate an import.
- Account switching cannot expose stale content or send work as another user.
- Narrow screens, large text, light/dark themes and both phone platforms remain
  usable. Live two-device verification is required before release.
