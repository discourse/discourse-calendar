const calendarRule = {
  tag: "calendar",

  wrap: function(token, info) {
    token.attrs = [
      ["class", "calendar"],
      ["data-calendar-type", info.attrs.type || "dynamic"],
    ];

    return true;
  },
};

export function setup(helper) {
  helper.whiteList(["div.calendar"]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features.discourse_simple_calendar = !!siteSettings.discourse_simple_calendar_enabled;
  });

  helper.registerPlugin(md => {
    md.block.bbcode.ruler.push("discourse-simple-calendar", calendarRule);
  });
}
