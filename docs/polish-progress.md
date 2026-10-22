# Polish points 3–6 — completion audit

User preference: keep UI copy short and avoid clutter. No commit or PR was requested.

## 3. Empty, loading and error states

Recipes expose a concise create action, empty dashboard meals are compact add
rows, and diary/planner avoid redundant empty-day explanation blocks. Weight
history has a specific empty title. Search separates short query, in-flight,
no-result and error states, preserves the query, and offers manual entry/retry.
Debouncing invalidates stale requests immediately.

Evidence: core-flow, accessibility, meal-detail and planner widget tests; native
simulator screenshots of home, planner, water, recipes and planner entry.

## 4. Durable save, error recovery and undo

Food, water, weight, workout, recipe, supplement and planned-meal forms await
writes and retain failed inputs. Pending submissions are guarded. Shared food,
water, workout and planned-meal deletion feedback restores original entries on
undo. Planner copy/log confirmations follow persistence. Optional Health/cache
failures do not turn a successful durable food write into an apparent failure.
Food plus its optional custom-library copy commit atomically.

Evidence: real SQLite failure injection in polish_save_failure_test.dart,
polish_persistence_test.dart and planner_polish_test.dart; meal-detail delete/undo
regression. These verify rollback, retained drafts and exactly one retry write.

## 5. Sheets, input and draft protection

Shared sheet headers wrap and have localized close tooltips. Portion headers
scroll while the add action stays above the keyboard. Product editing avoids
double keyboard padding. Planner hides its selectors while the keyboard is open.
Measurement inputs accept comma/dot decimals and reject non-finite values.
Meaningful entry/edit drafts are protected on back, close, outside tap and sheet
drag; untouched/reverted forms close freely and successful writes bypass prompts.
Nested guards do not open duplicate prompts. Manual planner drafts survive tabs.

Evidence: draft_guard_test.dart, edit-food regressions, portion_sheet_layout_test,
planner_polish_test and German decimal parsing/core-flow tests.

## 6. Layout, accessibility and runtime review

320x640 layouts at 200% German text are exercised for primary forms/screens and
keyboard insets. Light/dark portion screenshots use actual fonts and were
inspected. Native iPhone 18 Pro/iOS 27 screenshots were inspected for home,
planner, water, recipes and manual planner input. Empty meals now fit all four
rows above the navigation. Water presets fill four columns when space allows and
two on narrow screens/large text.

Progress animations honor reduced motion, including dynamic changes to the
setting. Macro rings expose one localized value/goal/unit label, verified through
the Flutter semantics tree. Fade routes skip their transition for reduced motion.

Evidence: polish_accessibility_test.dart, portion_sheet_layout_test.dart,
polish_motion_semantics_test.dart and integration_test/polish_simulator_test.dart.
Native screenshots: /tmp/sophis-simulator-review. Final command logs:
/tmp/sophis-completion-analysis.log and /tmp/sophis-completion-tests.log.

## Practical limits and delivery

Native VoiceOver/TalkBack speech and camera/Health behavior were not manually
exercised. Native simulator input was focused but its software keyboard was not
visible; keyboard geometry is verified by widget tests instead. Visual review
covers representative screens, not every possible custom configuration.

Android debug APK was built using the existing Java 21 runtime and installed with
adb install -r on the connected phone. Launch and process were verified; existing
app data were preserved. The phone disconnected before the final semantics fix,
so that fix is in source/the next build rather than the installed phone version.

The workspace already contained scanner, platform and social changes. They were
preserved; the complete working diff must not be attributed solely to this task.
