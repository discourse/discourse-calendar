import { updateCurrentUser } from "helpers/qunit-helpers";
import selectKit from "helpers/select-kit-helper";
import discoursePostEventAcceptance from "./discourse-post-event-helper";

discoursePostEventAcceptance("composer-toolbar");

test("replying to a post", async assert => {
  updateCurrentUser({ can_create_discourse_post_event: true });

  await visit("/t/internationalization-localization/280");
  await click("#post_1 button.create");
  const popupMenu = selectKit(".toolbar-popup-menu-options");
  await popupMenu.expand();
  assert.notOk(
    popupMenu.rowByValue("insertEvent").exists(),
    "it doesn’t show the option"
  );

  await click(".save-or-cancel .cancel");
});

test("edit the op", async assert => {
  updateCurrentUser({ can_create_discourse_post_event: true });

  await visit("/t/internationalization-localization/280");
  await click("#post_1 .actions .show-more-actions");
  await click("#post_1 .actions button.edit");

  const popupMenu = selectKit(".toolbar-popup-menu-options");
  await popupMenu.expand();
  assert.ok(
    popupMenu.rowByValue("insertEvent").exists(),
    "it shows the option"
  );

  await click(".save-or-cancel .cancel");
});
