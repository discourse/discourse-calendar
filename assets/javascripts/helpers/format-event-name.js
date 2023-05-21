import { htmlHelper } from "discourse-common/lib/helpers";

export function formatEventName(event) {
  function htmlDecode(input){
    var e = document.createElement('textarea');
    e.innerHTML = input;
    // handle case of empty input
    return e.childNodes.length === 0 ? "" : e.childNodes[0].nodeValue;
  }
  return htmlDecode(event.name || event.post.topic.title);
}

export default htmlHelper((event) => formatEventName(event));
