const calendarRule = {
  tag: "calendar",

  wrap: function(token, info) {
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
    opts.features.calendar_enabled = !!siteSettings.calendar_enabled;
  });

  helper.registerPlugin(md => {
    md.block.bbcode.ruler.push("discourse-calendar", calendarRule);
  });
}
