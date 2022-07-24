import I18n from "I18n";
import guessDateFormat from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";
import { cookAsync } from "discourse/lib/text";
import WidgetGlue from "discourse/widgets/glue";
import { getRegister } from "discourse-common/lib/get-owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { schedule } from "@ember/runloop";
import { applyLocalDates } from "discourse/lib/local-dates";

function _decorateEvent(api, cooked, post) {
  _attachWidget(api, cooked, post);
}

function _validEventPreview(eventContainer) {
  eventContainer.innerHTML = "";
  eventContainer.classList.add("discourse-post-event-preview");

  const statusLocaleKey = `discourse_post_event.models.event.status.${
    eventContainer.dataset.status || "public"
  }.title`;
  if (I18n.lookup(statusLocaleKey, { locale: "en" })) {
    const statusContainer = document.createElement("div");
    statusContainer.classList.add("event-preview-status");
    statusContainer.innerText = I18n.t(statusLocaleKey);
    eventContainer.appendChild(statusContainer);
  }

  const datesContainer = document.createElement("div");
  datesContainer.classList.add("event-preview-dates");

  const startsAt = moment.tz(
    eventContainer.dataset.start,
    eventContainer.dataset.timezone || "UTC"
  );

  const endsAt =
    eventContainer.dataset.end &&
    moment.tz(
      eventContainer.dataset.end,
      eventContainer.dataset.timezone || "UTC"
    );

  const format = guessDateFormat(startsAt, endsAt);

  let datesString = `<span class='start'>${startsAt
    .tz(moment.tz.guess())
    .format(format)}</span>`;
  if (endsAt) {
    datesString += ` → <span class='end'>${endsAt
      .tz(moment.tz.guess())
      .format(format)}</span>`;
  }
  datesContainer.innerHTML = datesString;

  eventContainer.appendChild(datesContainer);
}

function _invalidEventPreview(eventContainer) {
  eventContainer.classList.add(
    "discourse-post-event-preview",
    "alert",
    "alert-error"
  );
  eventContainer.classList.remove("discourse-post-event");
  eventContainer.innerText = I18n.t(
    "discourse_post_event.preview.more_than_one_event"
  );
}

function _decorateEventPreview(api, cooked) {
  const eventContainers = cooked.querySelectorAll(".discourse-post-event");

  eventContainers.forEach((eventContainer, index) => {
    if (index > 0) {
      _invalidEventPreview(eventContainer);
    } else {
      _validEventPreview(eventContainer);
    }
  });
}

let _glued = [];

function cleanUp() {
  _glued.forEach((g) => g.cleanUp());
  _glued = [];
}

function _attachWidget(api, cooked, eventModel) {
  const eventContainer = cooked.querySelector(".discourse-post-event");

  if (eventModel && eventContainer) {
    eventContainer.innerHTML = "";

    const datesHeight = 50;
    const urlHeight = 50;
    const headerHeight = 75;
    const bordersHeight = 10;
    const separatorsHeight = 4;
    const margins = 10;
    let widgetHeight =
      datesHeight + headerHeight + bordersHeight + separatorsHeight + margins;

    if (eventModel.should_display_invitees) {
      widgetHeight += 110;
    }

    if (eventModel.can_update_attendance) {
      widgetHeight += 60;
    }

    if (eventModel.url) {
      widgetHeight += urlHeight;
    }

    eventContainer.classList.add("is-loading");
    eventContainer.style.height = `${widgetHeight}px`;

    const glueContainer = document.createElement("div");
    glueContainer.innerHTML = '<div class="spinner medium"></div>';
    eventContainer.appendChild(glueContainer);

    const timezone = eventModel.timezone || "UTC";
    const startsAt = moment(eventModel.starts_at).tz(timezone);
    const endsAt =
      eventModel.ends_at && moment(eventModel.ends_at).tz(timezone);
    const format = guessDateFormat(startsAt, endsAt);

    const siteSettings = api.container.lookup("site-settings:main");
    if (siteSettings.discourse_local_dates_enabled) {
      const dates = [];
      dates.push(
        `[date=${startsAt.format("YYYY-MM-DD")} time=${startsAt.format(
          "HH:mm"
        )} format=${format} timezone=${timezone}]`
      );

      if (endsAt) {
        dates.push(
          `[date=${endsAt.format("YYYY-MM-DD")} time=${endsAt.format(
            "HH:mm"
          )} format=${format} timezone=${timezone}]`
        );
      }

      cookAsync(dates.join("<span> → </span>")).then((result) => {
        eventContainer.classList.remove("is-loading");
        eventContainer.classList.add("is-loaded");

        const glue = new WidgetGlue("discourse-post-event", getRegister(api), {
          eventModel,
          widgetHeight,
          localDates: $(result.string).html(),
          api,
        });

        glue.appendTo(glueContainer);
        _glued.push(glue);
        schedule("afterRender", () =>
          applyLocalDates(
            document.querySelectorAll(
              `[data-post-id="${eventModel.id}"] .discourse-local-date`
            ),
            siteSettings
          )
        );
      });
    } else {
      let localDates = `${startsAt.format(format)}`;
      if (eventModel.ends_at) {
        localDates += ` → ${moment(eventModel.ends_at).format(format)}`;
      }

      const glue = new WidgetGlue("discourse-post-event", getRegister(api), {
        eventModel,
        widgetHeight,
        localDates,
        api,
      });

      glue.appendTo(glueContainer);
      _glued.push(glue);
    }
  } else if (!eventModel) {
    const loadedEventContainer = cooked.querySelector(".discourse-post-event");
    loadedEventContainer && loadedEventContainer.remove();
  }
}

function initializeDiscoursePostEventDecorator(api) {
  api.cleanupStream(cleanUp);

  api.decorateCookedElement(
    (cooked, helper) => {
      if (cooked.classList.contains("d-editor-preview")) {
        _decorateEventPreview(api, cooked);
        return;
      }

      if (helper) {
        const post = helper.getModel();

        if (post && post.event) {
          _decorateEvent(api, cooked, post.event);
        }
      }
    },
    {
      id: "discourse-post-event-decorator",
    }
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.invite_user_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.invite_user_auto_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_calendar.invite_user_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.invite_user_predefined_attendance_notification",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.before_event_reminder",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.after_event_reminder",
    "calendar-day"
  );

  api.replaceIcon(
    "notification.discourse_post_event.notifications.ongoing_event_reminder",
    "calendar-day"
  );

  api.modifyClass("controller:topic", {
    pluginId: "discourse-calendar",

    subscribe() {
      this._super(...arguments);

      this.messageBus.subscribe(
        "/discourse-post-event/" + this.get("model.id"),
        (msg) => {
          const postNode = document.querySelector(
            `.onscreen-post[data-post-id="${msg.id}"] .cooked`
          );

          if (postNode) {
            this.store
              .find("discourse-post-event-event", msg.id)
              .then((eventModel) => _decorateEvent(api, postNode, eventModel))
              .catch(() => _decorateEvent(api, postNode));
          }
        }
      );
    },
    unsubscribe() {
      this.messageBus.unsubscribe("/discourse-post-event/*");
      this._super(...arguments);
    },
  });
}

export default {
  name: "discourse-post-event-decorator",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi("0.8.7", initializeDiscoursePostEventDecorator);
    }
  },
};
