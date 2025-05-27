import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";

export default class DiscoursePostEventChatChannel extends Component {
  get channelTitleComponent() {
    let channelTitleComponent;

    try {
      channelTitleComponent =
        require("discourse/plugins/chat/discourse/components/channel-title").default;
      // eslint-disable-next-line no-unused-vars
    } catch (e) {
      // chat not enabled
    }

    return channelTitleComponent;
  }

  get shouldRenderChatTitle() {
    return this.channelTitleComponent && this.args.event.channel;
  }

  <template>
    {{#if this.shouldRenderChatTitle}}
      <section class="event__section event-chat-channel">
        <span></span>
        <LinkTo @route="chat.channel" @models={{@event.channel.routeModels}}>
          <this.channelTitleComponent @channel={{@event.channel}} />
        </LinkTo>
      </section>
    {{/if}}
  </template>
}
