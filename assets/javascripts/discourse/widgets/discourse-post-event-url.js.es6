import { iconNode } from "discourse-common/lib/icon-library";
import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";

export default createWidget("discourse-post-event-url", {
  tagName: "section.event-url",

  html(attrs) {
    return [
      iconNode("link"),
      h(
        "a.url",
        {
          attributes: {
            href: attrs.url,
            target: "_blank",
            rel: "noopener noreferrer",
          },
        },
        attrs.url
      ),
    ];
  },
});
