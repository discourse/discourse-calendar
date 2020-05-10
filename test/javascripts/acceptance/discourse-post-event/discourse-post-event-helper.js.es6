import { acceptance } from "helpers/qunit-helpers";

export function utcToLocal(date, format = "LLL") {
  return moment
    .utc(date)
    .local()
    .format(format);
}

export default function discoursePostEventAcceptance(moduleName, options = {}) {
  acceptance(
    `discourse-post-event/${moduleName}`,
    Object.assign(
      {},
      {
        settings: {
          calendar_enabled: true,
          discourse_post_event_enabled: true
        },

        loggedIn: true
      },
      options
    )
  );
}
