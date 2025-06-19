import CookText from "discourse/components/cook-text";
import icon from "discourse/helpers/d-icon";

const DiscoursePostEventDescription = <template>
  {{#if @description}}
    <section class="event__section event-description">
      {{icon "circle-info"}}

      <CookText @rawText={{@description}} />
    </section>
  {{/if}}
</template>;

export default DiscoursePostEventDescription;
