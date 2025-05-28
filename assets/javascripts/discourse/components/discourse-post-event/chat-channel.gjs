import { LinkTo } from "@ember/routing";
import ChannelTitle from "discourse/plugins/chat/discourse/components/channel-title";

const DiscoursePostEventChatChannel = <template>
  {{#if @event.channel}}
    <section class="event__section event-chat-channel">
      <span></span>
      <LinkTo @route="chat.channel" @models={{@event.channel.routeModels}}>
        <ChannelTitle @channel={{@event.channel}} />
      </LinkTo>
    </section>
  {{/if}}
</template>;

export default DiscoursePostEventChatChannel;
