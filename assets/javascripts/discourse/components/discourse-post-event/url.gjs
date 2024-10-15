import Component from "@glimmer/component";
import icon from "discourse-common/helpers/d-icon";

export default class DiscoursePostEventUrl extends Component {
  get url() {
    return this.args.url.indexOf("://") === -1 &&
      this.args.url.indexOf("mailto:") === -1
      ? "https://" + this.args.url
      : this.args.url;
  }

  <template>
    <section class="event-url">
      {{icon "link"}}
      <a
        class="url"
        href={{this.url}}
        target="_blank"
        rel="noopener noreferrer"
      >
        {{@url}}
      </a>
    </section>
  </template>
}
