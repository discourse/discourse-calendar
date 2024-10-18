export function buildParams(startsAt, endsAt, event, siteSettings) {
  const params = {};

  const eventTz = event.timezone || "UTC";

  params.start = moment(startsAt).tz(eventTz).format("YYYY-MM-DD HH:mm");

  if (event.isClosed) {
    params.closed = "true";
  }

  if (event.status) {
    params.status = event.status;
  }

  if (event.name) {
    params.name = event.name;
  }

  if (event.url) {
    params.url = event.url;
  }

  if (event.timezone) {
    params.timezone = event.timezone;
  }

  if (event.recurrence) {
    params.recurrence = event.recurrence;
  }

  if (event.minimal) {
    params.minimal = "true";
  }

  if (endsAt) {
    params.end = moment(endsAt).tz(eventTz).format("YYYY-MM-DD HH:mm");
  }

  if (event.status === "private") {
    params.allowedGroups = (event.rawInvitees || []).join(",");
  }

  if (event.status === "public") {
    params.allowedGroups = "trust_level_0";
  }

  if (event.reminders && event.reminders.length) {
    params.reminders = event.reminders
      .map((r) => {
        // we create a new intermediate object to avoid changes in the UI while
        // we prepare the values for request
        const reminder = Object.assign({}, r);

        if (reminder.period === "after") {
          reminder.value = `-${Math.abs(parseInt(reminder.value, 10))}`;
        }
        if (reminder.period === "before") {
          reminder.value = Math.abs(parseInt(`${reminder.value}`, 10));
        }

        return `${reminder.type}.${reminder.value}.${reminder.unit}`;
      })
      .join(",");
  }

  siteSettings.discourse_post_event_allowed_custom_fields
    .split("|")
    .filter(Boolean)
    .forEach((setting) => {
      const param = camelCase(setting);
      if (typeof event.customFields[setting] !== "undefined") {
        params[param] = event.customFields[setting];
      }
    });

  return params;
}

export function replaceRaw(params, raw) {
  const eventRegex = new RegExp(`\\[event\\s(.*?)\\]`, "m");
  const eventMatches = raw.match(eventRegex);

  if (eventMatches && eventMatches[1]) {
    const markdownParams = [];
    Object.keys(params).forEach((param) => {
      const value = params[param];
      if (value && value.length) {
        markdownParams.push(`${param}="${params[param]}"`);
      }
    });

    return raw.replace(eventRegex, `[event ${markdownParams.join(" ")}]`);
  }

  return false;
}

function camelCase(input) {
  return input
    .toLowerCase()
    .replace(/-/g, "_")
    .replace(/_(.)/g, function (match, group1) {
      return group1.toUpperCase();
    });
}
