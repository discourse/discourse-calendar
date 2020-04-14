import guessDateFormat from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";
import { cookAsync } from "discourse/lib/text";
import WidgetGlue from "discourse/widgets/glue";
import { getRegister } from "discourse-common/lib/get-owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { schedule } from "@ember/runloop";

function _decorateEvent(api, cooked, post) {
  _attachWidget(api, cooked, post);
}

let _glued = [];

function cleanUp() {
  _glued.forEach(g => g.cleanUp());
  _glued = [];
}

function _attachWidget(api, cooked, eventModel) {
  const existing = cooked.querySelector(".discourse-post-event");
  const wrap = cooked.querySelector("[data-wrap=event]");

  if (eventModel && wrap) {
    let widgetHeight = 175;

    if (eventModel.should_display_invitees) {
      widgetHeight += 125;
    }

    if (eventModel.can_update_attendance) {
      widgetHeight += 65;
    }

    const eventContainer = existing || document.createElement("div");
    eventContainer.classList.add("discourse-post-event");
    eventContainer.classList.add("is-loading");
    eventContainer.style.height = `${widgetHeight}px`;
    eventContainer.innerHTML = '<div class="spinner medium"></div>';
    wrap.prepend(eventContainer);

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
      const glue = new WidgetGlue("discourse-post-event", getRegister(api), {
        eventModel,
        widgetHeight,
        localDates: $(result.string).html()
      });

      glue.appendTo(eventContainer);
      _glued.push(glue);

      schedule("afterRender", () => {
        $(
          ".discourse-local-date",
          $(`[data-post-id="${eventModel.id}"]`)
        ).applyLocalDates();
      });
    });
  } else {
    existing && existing.remove();
  }
}

function initializeDiscoursePostEventDecorator(api) {
  api.cleanupStream(cleanUp);

  api.decorateCooked(($cooked, helper) => {
    if (helper) {
      const post = helper.getModel();
      if (post.event) {
        _decorateEvent(api, $cooked[0], post.event);
      }
    }
  });

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
