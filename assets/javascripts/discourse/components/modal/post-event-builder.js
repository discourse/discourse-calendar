import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";
import { cook } from "discourse/lib/text";
import Group from "discourse/models/group";
import { i18n } from "discourse-i18n";
import { buildParams, replaceRaw } from "../../lib/raw-event-helper";

export default class PostEventBuilder extends Component {
  @service dialog;
  @service siteSettings;
  @service store;

  @tracked flash = null;
  @tracked isSaving = false;

  @tracked startsAt = moment(this.event.startsAt).tz(
    this.event.timezone || "UTC"
  );

  @tracked
  endsAt =
    this.event.endsAt &&
    moment(this.event.endsAt).tz(this.event.timezone || "UTC");

  get event() {
    return this.args.model.event;
  }

  get reminderTypes() {
    return [
      {
        value: "notification",
        name: i18n(
          "discourse_post_event.builder_modal.reminders.types.notification"
        ),
      },
      {
        value: "bumpTopic",
        name: i18n(
          "discourse_post_event.builder_modal.reminders.types.bump_topic"
        ),
      },
    ];
  }

  get reminderUnits() {
    return [
      {
        value: "minutes",
        name: i18n(
          "discourse_post_event.builder_modal.reminders.units.minutes"
        ),
      },
      {
        value: "hours",
        name: i18n("discourse_post_event.builder_modal.reminders.units.hours"),
      },
      {
        value: "days",
        name: i18n("discourse_post_event.builder_modal.reminders.units.days"),
      },
      {
        value: "weeks",
        name: i18n("discourse_post_event.builder_modal.reminders.units.weeks"),
      },
    ];
  }

  get reminderPeriods() {
    return [
      {
        value: "before",
        name: i18n(
          "discourse_post_event.builder_modal.reminders.periods.before"
        ),
      },
      {
        value: "after",
        name: i18n(
          "discourse_post_event.builder_modal.reminders.periods.after"
        ),
      },
    ];
  }

  get availableRecurrences() {
    return [
      {
        id: "every_day",
        name: i18n("discourse_post_event.builder_modal.recurrence.every_day"),
      },
      {
        id: "every_month",
        name: i18n("discourse_post_event.builder_modal.recurrence.every_month"),
      },
      {
        id: "every_weekday",
        name: i18n(
          "discourse_post_event.builder_modal.recurrence.every_weekday"
        ),
      },
      {
        id: "every_week",
        name: i18n("discourse_post_event.builder_modal.recurrence.every_week"),
      },
      {
        id: "every_two_weeks",
        name: i18n(
          "discourse_post_event.builder_modal.recurrence.every_two_weeks"
        ),
      },
      {
        id: "every_four_weeks",
        name: i18n(
          "discourse_post_event.builder_modal.recurrence.every_four_weeks"
        ),
      },
    ];
  }

  get allowedCustomFields() {
    return this.siteSettings.discourse_post_event_allowed_custom_fields
      .split("|")
      .filter(Boolean);
  }

  get addReminderDisabled() {
    return this.event.reminders?.length >= 5;
  }

  @action
  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  }

  @action
  setCustomField(field, e) {
    this.event.customFields[field] = e.target.value;
  }

  @action
  onChangeDates(dates) {
    this.event.startsAt = dates.from;
    this.event.endsAt = dates.to;
    this.startsAt = dates.from;
    this.endsAt = dates.to;
  }

  @action
  onChangeStatus(newStatus) {
    this.event.rawInvitees = [];
    this.event.status = newStatus;
  }

  @action
  setRawInvitees(_, newInvitees) {
    this.event.rawInvitees = newInvitees;
  }

  @action
  setNewTimezone(newTz) {
    this.event.timezone = newTz;
    this.event.startsAt = moment.tz(
      this.startsAt.format("YYYY-MM-DDTHH:mm"),
      newTz
    );
    this.event.endsAt = this.endsAt
      ? moment.tz(this.endsAt.format("YYYY-MM-DDTHH:mm"), newTz)
      : null;
    this.startsAt = moment(this.event.startsAt).tz(newTz);
    this.endsAt = this.event.endsAt
      ? moment(this.event.endsAt).tz(newTz)
      : null;
  }

  @action
  async destroyPostEvent() {
    try {
      const confirmResult = await this.dialog.yesNoConfirm({
        message: "Confirm delete",
      });

      if (confirmResult) {
        const post = await this.store.find("post", this.event.id);
        const raw = post.raw;
        const newRaw = this._removeRawEvent(raw);
        const props = {
          raw: newRaw,
          edit_reason: "Destroy event",
        };

        const cooked = await cook(newRaw);
        props.cooked = cooked.string;

        const result = await post.save(props);
        if (result) {
          this.args.closeModal();
        }
      }
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  @action
  createEvent() {
    if (!this.startsAt) {
      this.args.closeModal();
      return;
    }

    const eventParams = buildParams(
      this.startsAt,
      this.endsAt,
      this.event,
      this.siteSettings
    );
    const markdownParams = [];
    Object.keys(eventParams).forEach((key) => {
      let value = eventParams[key];
      markdownParams.push(`${key}="${value}"`);
    });

    // Check if we are from toolbar or composer
    if (this.args.model.toolbarEvent) {
    this.args.model.toolbarEvent.addText(
      `[event ${markdownParams.join(" ")}]\n[/event]`
    );
  } else {
    this.insertTextIntoComposer(
      `[event ${markdownParams.join(" ")}]\n[/event]`
    );
  }
    this.args.closeModal();
  }

  insertTextIntoComposer(text) {
    const composerController = this.args.model.api.container.lookup('controller:composer');
    if (composerController && composerController.model) {
      const composerModel = composerController.get('model');
      const currentText = composerModel.get('reply') || '';
      composerModel.set('reply', `${text}\n${currentText}`);
      const textarea = document.querySelector('.d-editor-input');
      textarea.focus();
    } else {
      console.error('Composer controller or model not found');
    }
  }

  // to insert text at the current cursor position
  // insertTextIntoComposer(text) {
  //   const composerController = this.args.model.api.container.lookup('controller:composer');
  //   if (composerController && composerController.model) {
  //     const composerModel = composerController.get('model');
  //     const textarea = document.querySelector('.d-editor-input');
  
  //     if (textarea) {
  //       const startPos = textarea.selectionStart;
  //       const endPos = textarea.selectionEnd;
  //       const currentText = composerModel.get('reply') || '';
  
  //       const newText = `${currentText.substring(0, startPos)}${text}${currentText.substring(endPos)}`;
  //       composerModel.set('reply', newText);
  
  //       // Réfocaliser la zone de texte et repositionner le curseur
  //       textarea.focus();
  //       textarea.setSelectionRange(startPos + text.length, startPos + text.length);
  //     } else {
  //       console.error('Textarea not found');
  //     }
  //   } else {
  //     console.error('Composer controller or model not found');
  //   }
  // }
  
  @action
  async updateEvent() {
    try {
      this.isSaving = true;

      const post = await this.store.find("post", this.event.id);
      const raw = post.raw;
      const eventParams = buildParams(
        this.startsAt,
        this.endsAt,
        this.event,
        this.siteSettings
      );

      const newRaw = replaceRaw(eventParams, raw);
      if (newRaw) {
        const props = {
          raw: newRaw,
          edit_reason: i18n("discourse_post_event.edit_reason"),
        };

        const cooked = await cook(newRaw);
        props.cooked = cooked.string;

        const result = await post.save(props);
        if (result) {
          this.args.closeModal();
        }
      }
    } catch (e) {
      this.flash = extractError(e);
    } finally {
      this.isSaving = false;
    }
  }

  _removeRawEvent(raw) {
    const eventRegex = new RegExp(`\\[event\\s(.*?)\\]\\n\\[\\/event\\]`, "m");
    return raw.replace(eventRegex, "");
  }
}
