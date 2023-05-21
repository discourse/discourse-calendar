const addCalendarTooltipDivToState = (state) => {

     // Open div.calendar-tooltip
    let tooltipDivToken = state.push("div_calendar_tooltip_open", "div", 1);
    tooltipDivToken.attrs = [["class", "calendar-tooltip"],["role", "tooltip"]];

        // Open div.tooltip-content
        let tooltipContentDivToken = state.push("div_tooltip_content_open", "div", 1);
        tooltipContentDivToken.attrs = [["class", "tooltip-content"]];

            // Open/Close div.category
            let tooltipCategoryDivToken = state.push("div_category_open", "div", 1);
            tooltipCategoryDivToken.attrs = [["class", "category"]];
            state.push("div_category_close", "div", -1);

            // Open/Close div.title
            let tooltipTitleDivToken = state.push("div_title_open", "div", 1);
            tooltipTitleDivToken.attrs = [["class", "title"]];
            state.push("div_title_close", "div", -1);

            // Open div.starts
            let tooltipStartsDivToken = state.push("div_starts_open", "div", 1);
            tooltipStartsDivToken.attrs = [["class", "starts"]];

                // Open/close div.date
                let tooltipStartsDateDivToken = state.push("div_starts_date_open", "div", 1);
                tooltipStartsDateDivToken.attrs = [["class", "date"]];
                state.push("div_starts_date_close", "div", -1);

                // Open/close div.time
                let tooltipStartsTimeDivToken = state.push("div_starts_time_open", "div", 1);
                tooltipStartsTimeDivToken.attrs = [["class", "time"]];
                state.push("div_starts_time_close", "div", -1);

            // Close div.starts
            state.push("div_starts_close", "div", -1);

            // Open/close div.date-to with "→" in content
            let tooltipDateToDivToken = state.push("div_date_to_open", "div", 1);
            tooltipDateToDivToken.attrs = [["class", "date-to"]];
            tooltipDateToDivToken = state.push('text', '', 0);
            tooltipDateToDivToken.content = "→";
            state.push("div_date_to_close", "div", -1);

            // Open div.ends
            let tooltipEndsDivToken = state.push("div_ends_open", "div", 1);
            tooltipEndsDivToken.attrs = [["class", "ends"]];

                // Open/close div.date
                let tooltipEndsDateDivToken = state.push("div_ends_date_open", "div", 1);
                tooltipEndsDateDivToken.attrs = [["class", "date"]];
                state.push("div_ends_date_close", "div", -1);

                // Open/close div.time
                let tooltipEndsTimeDivToken = state.push("div_ends_time_open", "div", 1);
                tooltipEndsTimeDivToken.attrs = [["class", "time"]];
                state.push("div_ends_time_close", "div", -1);

            // Close div.ends
            state.push("div_ends_close", "div", -1);

        // Close div.tooltip-content
        state.push("div_tooltip_content_close", "div", -1);

        // Open/close div.tooltip-arrow
        let tooltipArrowDivToken = state.push("div_tooltip_arrow_open", "div", 1);
        tooltipArrowDivToken.attrs = [["class", "tooltip-arrow"], ["data-popper-arrow",""]];
        state.push("div_tooltip_arrow_close", "div", -1);

    // Close div.calendar-tooltip
    state.push("div_calendar_tooltip_close", "div", -1);

    return state;
}

const calendarRule = {
  tag: "calendar",

  before: function (state, info) {

    // Open div.discourse-calendar-wrap
    let wrapperDivToken = state.push("div_calendar_wrap", "div", 1);
    wrapperDivToken.attrs = [["class", "discourse-calendar-wrap"]];

    // Add full div.calendar-tooltip node
    addCalendarTooltipDivToState(state);

    let headerDivToken = state.push("div_calendar_header", "div", 1);
    headerDivToken.attrs = [["class", "discourse-calendar-header"]];

    let titleH2Token = state.push("h2_open", "h2", 1);
    titleH2Token.attrs = [["class", "discourse-calendar-title"]];
    state.push("h2_close", "h2", -1);

    let timezoneWrapToken = state.push("span_open", "span", 1);
    timezoneWrapToken.attrs = [["class", "discourse-calendar-timezone-wrap"]];
    if (info.attrs.tzPicker === "true") {
      _renderTimezonePicker(state);
    }
    state.push("span_close", "span", -1);

    state.push("div_calendar_header", "div", -1);

    let mainCalendarDivToken = state.push("div_calendar", "div", 1);
    mainCalendarDivToken.attrs = [
      ["class", "calendar"],
      ["data-calendar-type", info.attrs.type || "dynamic"],
      ["data-calendar-default-timezone", info.attrs.defaultTimezone],
    ];

    if (info.attrs.defaultView) {
      mainCalendarDivToken.attrs.push([
        "data-calendar-default-view",
        info.attrs.defaultView,
      ]);
    }

    if (info.attrs.weekends) {
      mainCalendarDivToken.attrs.push(["data-weekends", info.attrs.weekends]);
    }

    if (info.attrs.showAddToCalendar) {
      mainCalendarDivToken.attrs.push([
        "data-calendar-show-add-to-calendar",
        info.attrs.showAddToCalendar === "true",
      ]);
    }

    if (info.attrs.fullDay) {
      mainCalendarDivToken.attrs.push([
        "data-calendar-full-day",
        info.attrs.fullDay === "true",
      ]);
    }

    if (info.attrs.hiddenDays) {
      mainCalendarDivToken.attrs.push([
        "data-hidden-days",
        info.attrs.hiddenDays,
      ]);
    }
  },

  after: function (state) {
    state.push("div_calendar", "div", -1);
    state.push("div_calendar_wrap", "div", -1);
  },
};

const groupTimezoneRule = {
  tag: "timezones",

  before: function (state, info) {
    const wrapperDivToken = state.push("div_group_timezones", "div", 1);
    wrapperDivToken.attrs = [
      ["class", "group-timezones"],
      ["data-group", info.attrs.group],
      ["data-size", info.attrs.size || "medium"],
    ];
  },

  after: function (state) {
    state.push("div_group_timezones", "div", -1);
  },
};

function _renderTimezonePicker(state) {
  const timezoneSelectToken = state.push("select_open", "select", 1);
  timezoneSelectToken.attrs = [["class", "discourse-calendar-timezone-picker"]];

  state.push("select_close", "select", -1);
}

export function setup(helper) {
  helper.allowList([
    "div.calendar",
    "div.discourse-calendar-header",
    "div.calendar-tooltip",
    "div.tooltip-content",
    "div.category",
    "div.starts",
    "div.date-to",
    "div.ends",
    "div.date",
    "div.time",
    "div.tooltip-arrow",
    "div.discourse-calendar-wrap",
    "select.discourse-calendar-timezone-picker",
    "span.discourse-calendar-timezone-wrap",
    "h2.discourse-calendar-title",
    "div[data-calendar-type]",
    "div[data-calendar-default-view]",
    "div[data-calendar-default-timezone]",
    "div[data-weekends]",
    "div[data-hidden-days]",
    "div.group-timezones",
    "div[data-group]",
    "div[data-size]",
  ]);

  helper.registerOptions((opts, siteSettings) => {
    opts.features["discourse-calendar-enabled"] =
      !!siteSettings.calendar_enabled;
  });

  helper.registerPlugin((md) => {
    const features = md.options.discourse.features;
    if (features["discourse-calendar-enabled"]) {
      md.block.bbcode.ruler.push("discourse-calendar", calendarRule);
      md.block.bbcode.ruler.push(
        "discourse-group-timezones",
        groupTimezoneRule
      );
    }
  });
}
