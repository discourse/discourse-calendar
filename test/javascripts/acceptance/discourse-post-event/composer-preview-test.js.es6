import discoursePostEventAcceptance, {
  utcToLocal
} from "./discourse-post-event-helper";

discoursePostEventAcceptance("composer-preview");

QUnit.skip("an event with a start date", async assert => {
  await visit("/");
  await click("#create-topic");
  await fillIn(".d-editor-input", '[event start="2020-02-03"]\n[/event]');

  const preview = find(".d-editor-preview .discourse-post-event");
  assert.ok(exists(preview), "it creates the preview");
  assert.equal(
    preview.find(".event-preview-status").text(),
    I18n.t("discourse_post_event.models.event.status.public.title"),
    "it displays the status"
  );
  assert.equal(
    preview.find(".event-preview-dates .start").text(),
    utcToLocal("2020-02-03"),
    "it displays the start date"
  );
});

QUnit.skip("an event with a start date and end date", async assert => {
  await visit("/");
  await click("#create-topic");
  await fillIn(
    ".d-editor-input",
    '[event start="2020-02-03" end="2002-03-04"]\n[/event]'
  );

  const preview = find(".d-editor-preview .discourse-post-event");
  assert.equal(
    preview.find(".event-preview-dates .start").text(),
    utcToLocal("2020-02-03"),
    "it displays the start date"
  );
  assert.equal(
    preview.find(".event-preview-dates .end").text(),
    utcToLocal("2002-03-04"),
    "it displays the start date"
  );
});

QUnit.skip("an event with a status", async assert => {
  await visit("/");
  await click("#create-topic");
  await fillIn(
    ".d-editor-input",
    '[event status="private" start="2020-02-03"]\n[/event]'
  );

  const preview = find(".d-editor-preview .discourse-post-event");
  assert.equal(
    preview.find(".event-preview-status").text(),
    I18n.t("discourse_post_event.models.event.status.private.title"),
    "it displays the status"
  );
});

QUnit.skip("more than one event", async assert => {
  await visit("/");
  await click("#create-topic");
  await fillIn(
    ".d-editor-input",
    '[event start="2020-02-03"]\n[/event]\n\n[event start="2021-04-03"]\n[/event]'
  );

  const preview = find(
    ".d-editor-preview .discourse-post-event-preview[data-start=2020-02-03]"
  );
  assert.ok(exists(preview), "it displays the first event");

  const errorPreview = find(
    ".d-editor-preview .discourse-post-event-preview.alert-error"
  );
  assert.ok(exists(errorPreview), "it displays the error");
  assert.equal(
    errorPreview.text(),
    I18n.t("discourse_post_event.preview.more_than_one_event"),
    "it displays the error"
  );
});
