export function buildParams(startsAt, endsAt, eventModel, siteSettings) {
  const params = {};

  const eventTz = eventModel.timezone || "UTC";

  params.start = moment(startsAt).tz(eventTz).format("YYYY-MM-DD HH:mm");

  if (eventModel.status) {
    params.status = eventModel.status;
  }

  if (eventModel.name) {
    params.name = eventModel.name;
  }

  if (eventModel.url) {
    params.url = eventModel.url;
  }

  if (eventModel.timezone) {
    params.timezone = eventModel.timezone;
  }

  if (eventModel.recurrence) {
    params.recurrence = eventModel.recurrence;
  }

  if (endsAt) {
    params.end = moment(endsAt).tz(eventTz).format("YYYY-MM-DD HH:mm");
  }

  if (eventModel.status === "private") {
    params.allowedGroups = (eventModel.raw_invitees || []).join(",");
  }

  if (eventModel.status === "public") {
    params.allowedGroups = "trust_level_0";
  }

  if (eventModel.reminders && eventModel.reminders.length) {
    params.reminders = eventModel.reminders
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

        return `${reminder.value}.${reminder.unit}`;
      })
      .join(",");
  }

  siteSettings.discourse_post_event_allowed_custom_fields
    .split("|")
    .filter(Boolean)
    .forEach((setting) => {
      const param = camelCase(setting);
      if (typeof eventModel.custom_fields[setting] !== "undefined") {
        params[param] = eventModel.custom_fields[setting];
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
