# Portion and meal selection update

- Portion picker uses one slider plus an exact amount field. Serving presets and
  saved portions share a single horizontal strip instead of wrapping cards.
  Selecting a larger preset/typing a larger amount expands the slider range.
- AI result actions are selection checkboxes. All start selected, the bottom
  button adds checked unsaved foods, and successful items remain marked in place.
  Partial-write retry skips already committed results. Undo resets a successful
  row only after removing its saved entry.
- Home meal headers expose a compact repeat action for that meal category.
  Breakfast repeats the latest breakfast, independent of the latest logged meal.
- Recent food limits increase from 20 to 100 consistently in memory, SQLite
  cache and legacy storage. Older scanned items can also be recovered from their
  logged portion/nutrition snapshots, preserving units and previous amounts.
- Search tabs remain unchanged per user preference. Saved-entry feedback uses a
  short Added message and Undo, including repeat/batch operations.

Verification: real SQLite partial failure/retry, selection exclusion, historical
food recovery after reload, repeat/undo widget test, and 200% text light/dark
portion layouts with keyboard insets. Final logs:
/tmp/sophis-selection-final-suite.log and
/tmp/sophis-selection-final-analysis.log.
