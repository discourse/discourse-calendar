import { cookAsync } from "discourse/lib/text";
import WidgetGlue from "discourse/widgets/glue";
import { getRegister } from "discourse-common/lib/get-owner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { schedule } from "@ember/runloop";

function _decoratePostEvent(api, cooked, post) {
  _attachWidget(api, cooked, post);
}

let _glued = [];

function cleanUp() {
  _glued.forEach(g => g.cleanUp());
  _glued = [];
}

function _attachWidget(api, cooked, postEvent) {
  const existing = cooked.querySelector(".post-event");

  if (postEvent) {
    let widgetHeight = 170;
    if (postEvent.should_display_invitees) {
      widgetHeight += 125;
    }

    if (postEvent.can_update_attendance) {
      widgetHeight += 65;
    }

    const postEventContainer = existing || document.createElement("div");
    postEventContainer.classList.add("post-event");
    postEventContainer.classList.add("is-loading");
    postEventContainer.style.height = `${widgetHeight}px`;
    postEventContainer.innerHTML = '<div class="spinner medium"></div>';
    cooked.prepend(postEventContainer);

    const dates = [];
    let format;

    const startsAt = moment(postEvent.starts_at);
    if (
      startsAt.hours() > 0 ||
      startsAt.minutes() > 0 ||
      (postEvent.ends_at &&
        (moment(postEvent.ends_at).hours() > 0 ||
          moment(postEvent.ends_at).minutes() > 0))
    ) {
      format = "LLL";
    } else {
      format = "LL";
    }

    dates.push(
      `[date=${moment
        .utc(postEvent.starts_at)
        .format("YYYY-MM-DD")} time=${moment
        .utc(postEvent.starts_at)
        .format("HH:mm")} format=${format}]`
    );

    if (postEvent.ends_at) {
      const endsAt = moment.utc(postEvent.ends_at);
      dates.push(
        `[date=${endsAt.format("YYYY-MM-DD")} time=${endsAt.format(
          "HH:mm"
        )} format=${format}]`
      );
    }

    cookAsync(dates.join(" → ")).then(result => {
      const glue = new WidgetGlue("post-event", getRegister(api), {
        postEvent,
        widgetHeight,
        localDates: $(result.string).html()
      });

      glue.appendTo(postEventContainer);
      _glued.push(glue);

      schedule("afterRender", () => {
        $(
          ".discourse-local-date",
          $(`[data-post-id="${postEvent.id}"]`)
        ).applyLocalDates();
      });
    });
  } else {
    existing && existing.remove();
  }
}

function initializePostEventDecorator(api) {
  api.cleanupStream(cleanUp);

  api.decorateCooked(($cooked, helper) => {
    if (helper) {
      const post = helper.getModel();
      if (post.post_event) {
        _decoratePostEvent(api, $cooked[0], post.post_event);
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
      this.messageBus.subscribe("/post-events/" + this.get("model.id"), msg => {
        const postNode = document.querySelector(
          `.onscreen-post[data-post-id="${msg.id}"] .cooked`
        );

        if (postNode) {
          this.store
            .find("post-event", msg.id)
            .then(postEvent => _decoratePostEvent(api, postNode, postEvent))
            .catch(() => _decoratePostEvent(api, postNode));
        }
      });
    },
    unsubscribe() {
      this.messageBus.unsubscribe("/post-events/*");
      this._super(...arguments);
    }
  });
}

export default {
  name: "post-event-decorator",

  initialize() {
    withPluginApi("0.8.7", initializePostEventDecorator);
  }
};
