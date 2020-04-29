import guessDateFormat from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";
import { cookAsync } from "discourse/lib/text";
import WidgetGlue from "discourse/widgets/glue";
import { getRegister } from "discourse-common/lib/get-owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { schedule } from "@ember/runloop";

function _decorateEvent(api, cooked, post) {
  _attachWidget(api, cooked, post);
}

function _decorateEventPreview(api, cooked) {
  const eventContainer = cooked.querySelector(".discourse-post-event");

  if (eventContainer) {
    if (!eventContainer.dataset.start) {
      return;
    }

    const eventPreviewContainer = document.createElement("div");
    eventPreviewContainer.classList.add("discourse-post-event-preview");

    const statusLocaleKey = `discourse_post_event.models.event.status.${eventContainer
      .dataset.status || "public"}.title`;
    if (I18n.lookup(statusLocaleKey, { locale: "en" })) {
      const statusContainer = document.createElement("div");
      statusContainer.classList.add("event-preview-status");
      statusContainer.innerText = I18n.t(statusLocaleKey);
      eventPreviewContainer.appendChild(statusContainer);
    }

    const datesContainer = document.createElement("div");
    datesContainer.classList.add("event-preview-dates");

    const startsAt = moment
      .utc(eventContainer.dataset.start)
      .tz(moment.tz.guess());

    const endsAtValue = eventContainer.dataset.end;
    const format = guessDateFormat(
      startsAt,
      endsAtValue && moment.utc(endsAtValue).tz(moment.tz.guess())
    );

    let datesString = `<span class='start'>${startsAt.format(format)}</span>`;
    if (endsAtValue) {
      datesString += ` → <span class='start'>${moment
        .utc(endsAtValue)
        .tz(moment.tz.guess())
        .format(format)}</span>`;
    }
    datesContainer.innerHTML = datesString;

    eventPreviewContainer.appendChild(datesContainer);

    eventContainer.innerHTML = "";
    eventContainer.appendChild(eventPreviewContainer);
  }
}

let _glued = [];

function cleanUp() {
  _glued.forEach(g => g.cleanUp());
  _glued = [];
}

function _attachWidget(api, cooked, eventModel) {
  const eventContainer = cooked.querySelector(".discourse-post-event");

  if (eventModel && eventContainer) {
    eventContainer.innerHTML = "";

    const datesHeight = 50;
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

    eventContainer.classList.add("is-loading");
    eventContainer.style.height = `${widgetHeight}px`;

    const glueContainer = document.createElement("div");
    glueContainer.innerHTML = '<div class="spinner medium"></div>';
    eventContainer.appendChild(glueContainer);

    const dates = [];
    const startsAt = moment(eventModel.starts_at);
    const format = guessDateFormat(
      startsAt,
      eventModel.ends_at && moment(eventModel.ends_at)
    );

    dates.push(
      `[date=${moment
        .utc(eventModel.starts_at)
        .format("YYYY-MM-DD")} time=${moment
        .utc(eventModel.starts_at)
        .format("HH:mm")} format=${format}]`
    );

    if (eventModel.ends_at) {
      const endsAt = moment.utc(eventModel.ends_at);
      dates.push(
        `[date=${endsAt.format("YYYY-MM-DD")} time=${endsAt.format(
          "HH:mm"
        )} format=${format}]`
      );
    }

    cookAsync(dates.join(" → ")).then(result => {
      eventContainer.classList.remove("is-loading");
      eventContainer.classList.add("is-loaded");

      const glue = new WidgetGlue("discourse-post-event", getRegister(api), {
        eventModel,
        widgetHeight,
        localDates: $(result.string).html()
      });

      glue.appendTo(glueContainer);
      _glued.push(glue);

      schedule("afterRender", () =>
        $(
          ".discourse-local-date",
          $(`[data-post-id="${eventModel.id}"]`)
        ).applyLocalDates()
      );
    });
  } else if (!eventModel) {
    const loadedEventContainer = cooked.querySelector(".discourse-post-event");
    loadedEventContainer && loadedEventContainer.remove();
  }
}

function initializeDiscoursePostEventDecorator(api) {
  api.cleanupStream(cleanUp);

  api.decorateCooked(
    ($cooked, helper) => {
      if ($cooked[0].classList.contains("d-editor-preview")) {
        _decorateEventPreview(api, $cooked[0]);
        return;
      }

      if (helper) {
        const post = helper.getModel();

        if (post.event) {
          _decorateEvent(api, $cooked[0], post.event);
        }
      }
    },
    {
      id: "discourse-post-event-decorator"
    }
  );

  api.replaceIcon(
    "notification.discourse_calendar.invite_user_notification",
    "calendar-day"
  );

  api.modifyClass("controller:topic", {
    subscribe() {
      this._super(...arguments);

      this.messageBus.subscribe(
        "/discourse-post-event/" + this.get("model.id"),
        msg => {
          const postNode = document.querySelector(
            `.onscreen-post[data-post-id="${msg.id}"] .cooked`
          );

          if (postNode) {
            this.store
              .find("discourse-post-event-event", msg.id)
              .then(eventModel => _decorateEvent(api, postNode, eventModel))
              .catch(() => _decorateEvent(api, postNode));
          }
        }
      );
    },
    unsubscribe() {
      this.messageBus.unsubscribe("/discourse-post-event/*");
      this._super(...arguments);
    }
  });
}

export default {
  name: "discourse-post-event-decorator",

  initialize(container) {
    const siteSettings = container.lookup("site-settings:main");
    if (siteSettings.discourse_post_event_enabled) {
      withPluginApi("0.8.7", initializeDiscoursePostEventDecorator);
    }
  }
};
