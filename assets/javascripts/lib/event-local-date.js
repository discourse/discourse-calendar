import guessDateFormat from "discourse/plugins/discourse-calendar/lib/guess-best-date-format";

export default function eventLocalDate(container) {
  container.classList.remove("past", "current", "future");
  container.innerHTML = "";

  const startsAt = moment
    .utc(container.dataset.starts_at)
    .tz(moment.tz.guess());
  const endsAt = moment.utc(container.dataset.ends_at).tz(moment.tz.guess());

  const format = guessDateFormat(startsAt);
  let title = startsAt.format(format);
  if (endsAt) {
    title += ` → ${endsAt.format(format)}`;
  }
  container.setAttribute("title", title);
  container.classList.add("past");

  container.innerText = startsAt.format(format);
}
