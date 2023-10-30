import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";

function prefixProtocol(url) {
  return url.indexOf("://") === -1 && url.indexOf("mailto:") === -1
    ? "https://" + url
    : url;
}

export default createWidget("discourse-post-event-url", {
  tagName: "section.event-url",

  html(attrs) {
    return [
      iconNode("link"),
      h(
        "a.url",
        {
          attributes: {
            href: prefixProtocol(attrs.url),
            target: "_blank",
            rel: "noopener noreferrer",
          },
        },
        attrs.url
      ),
    ];
  },
});
