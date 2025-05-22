import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";

export default class DiscoursePostEventChatChannel extends Component {
  get chatChannel() {
    return this.args.event.chatChannel;
  }

  get chatChannelName() {
    return this.chatChannel.name;
  }

  get chatChannelId() {
    return this.chatChannel.id;
  }

  <template>
    <section class="event__section event-chat-channel">
      {{icon "comments"}}TODO</section>
  </template>
}
