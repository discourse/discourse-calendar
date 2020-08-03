const rule = {
  tag: "event",

  wrap(token, info) {
    if (!info.attrs.start) {
      return false;
    }

    token.attrs = [
      ["class", "discourse-post-event"],
      ["data-start", info.attrs.start]
    ];

    if (info.attrs["status"]) {
      token.attrs.push(["data-status", info.attrs.status]);
    }

    if (info.attrs["end"]) {
      token.attrs.push(["data-end", info.attrs.end]);
    }

    if (info.attrs.name) {
      token.attrs.push(["data-name", info.attrs.name]);
    }

    if (info.attrs.allowedGroups) {
      token.attrs.push(["data-allowed-groups", info.attrs.allowedGroups]);
    }

    if (info.attrs.url) {
      token.attrs.push(["data-url", info.attrs.url]);
    }

    return true;
  }
};

export function setup(helper) {
  helper.whiteList(["div.discourse-post-event"]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.discourse_post_event =
      siteSettings.calendar_enabled &&
      siteSettings.discourse_post_event_enabled;
  });

  helper.registerPlugin(md =>
    md.block.bbcode.ruler.push("discourse-post-event", rule)
  );
}
