const calendarRule = {
  tag: "calendar",

  wrap(token, info) {
    token.attrs = [
      ["class", "calendar"],
      ["data-calendar-type", info.attrs.type || "dynamic"]
    ];

    if (info.attrs.weekends) {
      token.attrs.push(["data-weekends", info.attrs.weekends]);
    }

    if (info.attrs.hiddenDays) {
      token.attrs.push(["data-hidden-days", info.attrs.hiddenDays]);
    }

    return true;
  }
};

export function setup(helper) {
  helper.whiteList([
    "div.calendar",
    "div[data-calendar-type]",
    "div[data-weekends]",
    "div[data-hidden-days]"
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features["discourse-calendar-enabled"] = !!siteSettings.calendar_enabled;
  });

  helper.registerPlugin(md => {
    const features = md.options.discourse.features;
    if (features["discourse-calendar-enabled"]) {
      md.block.bbcode.ruler.push("discourse-calendar", calendarRule);
    }
  });
}
