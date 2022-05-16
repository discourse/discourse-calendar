import I18n from "I18n";
import guessDateFormat from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";

function _displayCurrentEvent(container, endsAt) {
  const indicator = document.createElement("div");
  indicator.classList.add("indicator");

  const text = document.createElement("span");
  text.classList.add("text");
  text.innerText = I18n.t("discourse_post_event.topic_title.ends_in_duration", {
    duration: endsAt.from(moment()),
  });

  container.appendChild(indicator);
  container.appendChild(text);
}

function _displayEvent(container, date) {
  container.innerText = date.from(moment());
}

export default function eventRelativeDate(container) {
  container.classList.remove("past", "current", "future");
  container.innerHTML = "";

  const userTimezone = moment.tz.guess();
  const dateTimezone = container.dataset.timezone || "UTC";
  const startsAt = moment.tz(container.dataset.starts_at, dateTimezone).tz(userTimezone);

  let endsAt;

  if (container.dataset.ends_at) {
    endsAt = moment.tz(container.dataset.ends_at, dateTimezone).tz(userTimezone);
  }

  const format = guessDateFormat(startsAt);

  const title = [startsAt, endsAt]
    .filter(Boolean)
    .map(d => d.format(format))
    .join(" → ");

  container.setAttribute("title", title);

  if (moment().isBefore(startsAt)) {
    container.classList.add("future");
    _displayEvent(container, startsAt);
  } else if (moment().isBefore(endsAt)) {
    container.classList.add("current");
    _displayCurrentEvent(container, endsAt);
  } else {
    container.classList.add("past");
    // event might not have an end date
    _displayEvent(container, endsAt ?? startsAt);
  }
}
