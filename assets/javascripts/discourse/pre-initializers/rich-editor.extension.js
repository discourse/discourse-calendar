import { isTesting } from "discourse/lib/environment";
import { withPluginApi } from "discourse/lib/plugin-api";
import I18n, { i18n } from "discourse-i18n";
import guessDateFormat from "discourse/plugins/discourse-calendar/discourse/lib/guess-best-date-format";

const EVENT_ATTRIBUTES = {
  name: { default: null },
  start: { default: null },
  end: { default: null },
  reminders: { default: null },
  minimal: { default: null },
  closed: { default: null },
  status: { default: "public" },
  timezone: { default: "UTC" },
  allowedGroups: { default: null },
};

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    event: {
      attrs: EVENT_ATTRIBUTES,
      group: "block",
      defining: true,
      isolating: true,
      draggable: true,
      parseDOM: [
        {
          tag: "div.discourse-post-event",
          getAttrs(dom) {
            return { ...dom.dataset };
          },
        },
      ],
      toDOM(node) {
        const dataAttrs = Object.entries(node.attrs).reduce(
          (acc, [key, value]) => {
            if (value !== null) {
              acc[`data-${key.replace(/([A-Z])/g, "-$1").toLowerCase()}`] =
                value;
            }
            return acc;
          },
          {}
        );

        const attrs = {
          class: "discourse-post-event-preview",
          ...dataAttrs,
        };

        const domSpec = ["div", attrs];

        const statusLocaleKey = `discourse_post_event.models.event.status.${node.attrs.status}.title`;
        if (I18n.lookup(statusLocaleKey, { locale: "en" })) {
          domSpec.push([
            "div",
            { class: "event-preview-status" },
            i18n(statusLocaleKey),
          ]);
        }

        const startsAt = moment.tz(node.attrs.start, node.attrs.timezone);
        const endsAt =
          node.attrs.end && moment.tz(node.attrs.end, node.attrs.timezone);
        const format = guessDateFormat(startsAt, endsAt);
        const formattedStartsAt = startsAt
          .tz(isTesting() ? "UTC" : moment.tz.guess())
          .format(format);
        const datesElement = ["div", { class: "event-preview-dates" }];
        datesElement.push(["span", { class: "start" }, formattedStartsAt]);
        domSpec.push(datesElement);

        return domSpec;
      },
    },
  },

  parse: {
    wrap_bbcode(state, token) {
      if (token.tag === "div") {
        if (token.nesting === -1 && state.top().type.name === "event") {
          state.closeNode();
          return true;
        }

        if (
          token.nesting === 1 &&
          token.attrGet("class") === "discourse-post-event"
        ) {
          const attrs = {};

          if (token.attrs) {
            const dataAttrs = token.attrs.reduce((acc, [key, value]) => {
              if (key.startsWith("data-")) {
                // Convert kebab-case to camelCase
                const attrName = key
                  .replace("data-", "")
                  .replace(/-([a-z])/g, (_, letter) => letter.toUpperCase());
                acc[attrName] = value;
              }
              return acc;
            }, {});

            Object.assign(attrs, dataAttrs);
          }

          state.openNode(state.schema.nodes.event, attrs);
          return true;
        }
      }

      return false;
    },
  },

  serializeNode: {
    event(state, node) {
      let bbcode = "[event";

      Object.entries(node.attrs).forEach(([key, value]) => {
        if (value !== null) {
          bbcode += ` ${key}="${value}"`;
        }
      });

      bbcode += "]\n[/event]";

      state.write(bbcode);
    },
  },
};

export default {
  initialize() {
    withPluginApi("2.1.1", (api) => {
      api.registerRichEditorExtension(extension);
    });
  },
};
