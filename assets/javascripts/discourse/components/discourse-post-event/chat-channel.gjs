import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";

export default class DiscoursePostEventChatChannel extends Component {
  get chatChannelUrl() {
    return `/chat/c/${this.args.event.chatChannelSlug}/${this.args.event.chatChannelId}`;
  }

  get chatChannelColorCss() {
    return `color: #${this.args.event.chatChannelColor};`;
  }

  <template>
    <section class="event__section event-chat-channel">
      {{icon "comments"}}<a href={{this.chatChannelUrl}}><span
          style={{this.chatChannelColorCss}}
        >{{icon "comment"}}</span><span
          class="event__chat-channel-name"
        >{{@event.chatChannelName}}</span></a></section>
  </template>
}
