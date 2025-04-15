import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { concat, fn, get, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import ConditionalLoadingSection from "discourse/components/conditional-loading-section";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DateTimeInputRange from "discourse/components/date-time-input-range";
import GroupSelector from "discourse/components/group-selector";
import PluginOutlet from "discourse/components/plugin-outlet";
import RadioButton from "discourse/components/radio-button";
import { extractError } from "discourse/lib/ajax-error";
import { cook } from "discourse/lib/text";
import Group from "discourse/models/group";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import TimezoneInput from "select-kit/components/timezone-input";
import EventField from "discourse/plugins/discourse-calendar/discourse/components/event-field";
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

    this.args.model.toolbarEvent.addText(
      `[event ${markdownParams.join(" ")}]\n[/event]`
    );
    this.args.closeModal();
  }

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

  <template>
    <DModal
      @title={{i18n
        (concat
          "discourse_post_event.builder_modal."
          (if @model.event.id "update_event_title" "create_event_title")
        )
      }}
      class="post-event-builder-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
    >
      <:body>
        <ConditionalLoadingSection @isLoading={{this.isSaving}}>
          <form>
            <PluginOutlet
              @name="post-event-builder-form"
              @outletArgs={{hash event=@model.event}}
              @connectorTagName="div"
            >
              <DateTimeInputRange
                @from={{this.startsAt}}
                @to={{this.endsAt}}
                @timezone={{@model.event.timezone}}
                @onChange={{this.onChangeDates}}
              />

              <EventField
                class="name"
                @label="discourse_post_event.builder_modal.name.label"
              >
                <Input
                  @value={{@model.event.name}}
                  placeholder={{i18n
                    "discourse_post_event.builder_modal.name.placeholder"
                  }}
                />
              </EventField>

              <EventField
                class="url"
                @label="discourse_post_event.builder_modal.url.label"
              >
                <Input
                  @value={{@model.event.url}}
                  placeholder={{i18n
                    "discourse_post_event.builder_modal.url.placeholder"
                  }}
                />
              </EventField>

              <EventField
                class="timezone"
                @label="discourse_post_event.builder_modal.timezone.label"
              >
                <TimezoneInput
                  @value={{@model.event.timezone}}
                  @onChange={{this.setNewTimezone}}
                  class="input-xxlarge"
                  @none="discourse_post_event.builder_modal.timezone.remove_timezone"
                />
              </EventField>

              <EventField
                @label="discourse_post_event.builder_modal.status.label"
              >
                <label class="radio-label">
                  <RadioButton
                    @name="status"
                    @value="public"
                    @selection={{@model.event.status}}
                    @onChange={{this.onChangeStatus}}
                  />
                  <span class="message">
                    <span class="title">
                      {{i18n
                        "discourse_post_event.models.event.status.public.title"
                      }}
                    </span>
                    <span class="description">
                      {{i18n
                        "discourse_post_event.models.event.status.public.description"
                      }}
                    </span>
                  </span>
                </label>
                <label class="radio-label">
                  <RadioButton
                    @name="status"
                    @value="private"
                    @selection={{@model.event.status}}
                    @onChange={{this.onChangeStatus}}
                  />
                  <span class="message">
                    <span class="title">
                      {{i18n
                        "discourse_post_event.models.event.status.private.title"
                      }}
                    </span>
                    <span class="description">
                      {{i18n
                        "discourse_post_event.models.event.status.private.description"
                      }}
                    </span>
                  </span>
                </label>
                <label class="radio-label">
                  <RadioButton
                    @name="status"
                    @value="standalone"
                    @selection={{@model.event.status}}
                    @onChange={{this.onChangeStatus}}
                  />
                  <span class="message">
                    <span class="title">
                      {{i18n
                        "discourse_post_event.models.event.status.standalone.title"
                      }}
                    </span>
                    <span class="description">
                      {{i18n
                        "discourse_post_event.models.event.status.standalone.description"
                      }}
                    </span>
                  </span>
                </label>
              </EventField>

              <EventField
                @enabled={{eq @model.event.status "private"}}
                @label="discourse_post_event.builder_modal.invitees.label"
              >
                <GroupSelector
                  @fullWidthWrap={{true}}
                  @groupFinder={{this.groupFinder}}
                  @groupNames={{@model.event.rawInvitees}}
                  @onChangeCallback={{this.setRawInvitees}}
                  @placeholderKey="topic.invite_private.group_name"
                />
              </EventField>

              <EventField
                class="reminders"
                @label="discourse_post_event.builder_modal.reminders.label"
              >
                <div class="reminders-list">
                  {{#each @model.event.reminders as |reminder|}}
                    <div class="reminder-item">
                      <ComboBox
                        class="reminder-type"
                        @value={{reminder.type}}
                        @nameProperty="name"
                        @valueProperty="value"
                        @content={{this.reminderTypes}}
                      />

                      <Input
                        class="reminder-value"
                        min={{0}}
                        @value={{reminder.value}}
                        placeholder={{i18n
                          "discourse_post_event.builder_modal.name.placeholder"
                        }}
                      />

                      <ComboBox
                        class="reminder-unit"
                        @value={{reminder.unit}}
                        @nameProperty="name"
                        @valueProperty="value"
                        @content={{this.reminderUnits}}
                      />

                      <ComboBox
                        class="reminder-period"
                        @value={{reminder.period}}
                        @nameProperty="name"
                        @valueProperty="value"
                        @content={{this.reminderPeriods}}
                      />

                      <DButton
                        class="remove-reminder"
                        @icon="xmark"
                        @action={{fn @model.event.removeReminder reminder}}
                      />

                    </div>
                  {{/each}}
                </div>

                <DButton
                  class="add-reminder"
                  @disabled={{this.addReminderDisabled}}
                  @icon="plus"
                  @label="discourse_post_event.builder_modal.add_reminder"
                  @action={{@model.event.addReminder}}
                />
              </EventField>

              <EventField
                class="recurrence"
                @label="discourse_post_event.builder_modal.recurrence.label"
              >
                <ComboBox
                  class="available-recurrences"
                  @value={{@model.event.recurrence}}
                  @content={{this.availableRecurrences}}
                  @options={{hash
                    none="discourse_post_event.builder_modal.recurrence.none"
                  }}
                />
              </EventField>

              <EventField
                class="minimal-event"
                @label="discourse_post_event.builder_modal.minimal.label"
              >
                <label class="checkbox-label">
                  <Input @type="checkbox" @checked={{@model.event.minimal}} />
                  <span class="message">
                    {{i18n
                      "discourse_post_event.builder_modal.minimal.checkbox_label"
                    }}
                  </span>
                </label>
              </EventField>

              {{#if this.allowedCustomFields.length}}
                <EventField
                  @label="discourse_post_event.builder_modal.custom_fields.label"
                >
                  <p class="event-field-description">
                    {{i18n
                      "discourse_post_event.builder_modal.custom_fields.description"
                    }}
                  </p>
                  {{#each this.allowedCustomFields as |allowedCustomField|}}
                    <span class="label custom-field-label">
                      {{allowedCustomField}}
                    </span>
                    <Input
                      class="custom-field-input"
                      @value={{readonly
                        (get @model.event.customFields allowedCustomField)
                      }}
                      placeholder={{i18n
                        "discourse_post_event.builder_modal.custom_fields.placeholder"
                      }}
                      {{on "input" (fn this.setCustomField allowedCustomField)}}
                    />
                  {{/each}}
                </EventField>
              {{/if}}
            </PluginOutlet>
          </form>
        </ConditionalLoadingSection>
      </:body>
      <:footer>
        {{#if @model.event.id}}
          <DButton
            class="btn-primary"
            @label="discourse_post_event.builder_modal.update"
            @icon="calendar-day"
            @action={{this.updateEvent}}
          />

          <DButton
            @icon="trash-can"
            class="btn-danger"
            @action={{this.destroyPostEvent}}
          />
        {{else}}
          <DButton
            class="btn-primary"
            @label="discourse_post_event.builder_modal.create"
            @icon="calendar-day"
            @action={{this.createEvent}}
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
