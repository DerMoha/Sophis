# Streamlined food flow

Implemented the five agreed changes:

1. Home, today's diary and meal details use the same quick-add sheet. The choices
   are Search food, Photograph food, Scan product and Manual entry, in that order.
   Meal details opened for today's explicit date also offer this menu. Historical
   entries keep their date and do not expose a misleading add-to-today action.
2. Photograph food opens the existing camera/gallery screen under the same plain
   language title. A short Google Gemini disclosure remains beside the choice.
3. Scan product opens one chooser for barcode or nutrition label. Cancellation
   returns without opening a camera; both choices preserve the selected meal.
   Native camera permissions still belong to the operating system.
4. Tapping a local food log entry in Home, diary or meal details opens the editor.
   Long pressing opens the same actions, including share, copy and delete/undo.
5. AI result cards show name, portion and calories first. Notes and nutrient
   details expand on demand; comments survive collapse and rebuild. The keyboard
   loses focus on collapse. Cards without comments show the Nutrition label.

Verification:

- quick_add_actions_test: photograph entry and both scan destinations/meal context.
- streamlined_add_menu_test: actual Home, diary and dated-today meal surfaces,
  320x640 with 200% text, all four choices reachable and no separate AI section.
- home_meal_direct_edit_test: edit/save from each Home meal.
- meal_detail_screen_test and past_day_meal_test: direct edit plus long-press
  actions, deletion/undo and historical copy behavior.
- ai_food_analysis_edit_test: notes survive collapse/rebuild.
- ai_food_compact_layout_test: collapsed details, compact expanded input, preserved
  comments and add action with normal/200% German text. Rendered screenshots with
  real fonts were inspected at /tmp/sophis-ai-collapsed-{1.0,2.0}.png.
- Full suite: /tmp/sophis-streamline-final-tests.log.
- Static analysis: /tmp/sophis-streamline-final-analysis.log.

This change was verified in Flutter tests/rendered artifacts. The latest flow has
not been reinstalled on the user's phone. Existing scanner/social/platform work
in the working tree remains separate and was preserved.

## Home and More cleanup

- Default home shortcuts now focus on meal planning, weight and recipes. Activity,
  workouts and progress photos remain available in More and can be enabled as
  custom shortcuts. Existing custom choices/order are preserved; the diary
  shortcut is retired because Diary remains a main navigation destination.
- More separates planning, logging, insights and settings. Water, workouts and
  supplements are logging tools; weight, photos and activity are under insights.
- Untouched built-in meal names follow the interface language without changing
  stored IDs/names. Custom names remain intact. Opening and saving the category
  editor without a rename preserves its original stored name.
- Food correction/edit buttons consistently say Save. Secondary entry actions
  remain in the shared long-press menu.
- Verification: 551 Flutter tests passed, static analysis clean, standard Android
  debug build succeeded using the existing Java 21 runtime. Logs:
  /tmp/sophis-cleanup-final-tests.log, /tmp/sophis-cleanup-final-analysis.log and
  /tmp/sophis-commit-android.log.

The existing worktree changes were committed in feature groups: common save/form
primitives, scanner/OCR, partner sync/cache, food/planner forms, photo analysis,
tracking, and navigation/localization. Setup documentation and simulator review
are kept in a separate final commit. No push or device reinstall was requested.
