import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import concatClass from "discourse/helpers/concat-class";
import i18n from "discourse-common/helpers/i18n";
import { debounce } from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import renderInvitee from "../../helpers/render-invitee";
import ToggleInvitees from "../toggle-invitees";

export default class PostEventInvitees extends Component {
  @service store;

  @tracked invitees;
  @tracked filter;
  @tracked isLoading = false;
  @tracked type = "going";
  @tracked possibleInvitees = [];

  constructor() {
    super(...arguments);
    this._fetchInvitees();
  }

  get hasPossibleInvitees() {
    return this.possibleInvitees.length > 0;
  }

  get hasResults() {
    return this.invitees?.length > 0 || this.hasPossibleInvitees;
  }

  get title() {
    return I18n.t(
      `discourse_calendar.discourse_post_event.invitees_modal.${
        this.args.model.title || "title_invited"
      }`
    );
  }

  @action
  toggleType(type) {
    this.type = type;
    this._fetchInvitees(this.filter);
  }

  @debounce(250)
  onFilterChanged() {
    this._fetchInvitees(this.filter);
  }

  @action
  async removeInvitee(invitee) {
    await invitee.destroyRecord();
    this._fetchInvitees(this.filter);
  }

  @action
  async addInvitee(user) {
    const invitee = this.store.createRecord("discourse-post-event-invitee");
    await invitee.save({
      post_id: this.args.model.event.id,
      user_id: user.id,
      status: this.type,
    });

    this.invitees.pushObject(invitee);
    this.possibleInvitees = this.possibleInvitees.filter(
      (i) => i.id !== user.id
    );
  }

  async _fetchInvitees(filter) {
    try {
      this.isLoading = true;
      const invitees = await this.store.findAll(
        "discourse-post-event-invitee",
        {
          filter,
          post_id: this.args.model.event.id,
          type: this.type,
        }
      );

      this.possibleInvitees = invitees.resultSetMeta?.possible_invitees || [];
      this.invitees = invitees;
    } finally {
      this.isLoading = false;
    }
  }
  <template>
    <DModal
      @title={{this.title}}
      @closeModal={{@closeModal}}
      class={{concatClass
        (or @model.extraClass "invited")
        "post-event-invitees-modal"
      }}
    >
      <:body>
        <Input
          @value={{this.filter}}
          {{on "input" this.onFilterChanged}}
          class="filter"
          placeholder={{i18n
            "discourse_calendar.discourse_post_event.invitees_modal.filter_placeholder"
          }}
        />
        <ToggleInvitees @viewType={{this.type}} @toggle={{this.toggleType}} />
        <ConditionalLoadingSpinner @condition={{this.isLoading}}>
          {{#if this.hasResults}}
            <ul class="invitees">
              {{#each this.invitees as |invitee|}}
                <li class="invitee">
                  {{renderInvitee invitee}}
                  {{#if @model.event.can_act_on_discourse_post_event}}
                    <DButton
                      @icon="trash-alt"
                      @action={{fn this.removeInvitee invitee}}
                    />
                  {{/if}}
                </li>
              {{/each}}
            </ul>
            {{#if this.hasPossibleInvitees}}
              <ul class="possible-invitees">
                {{#each this.possibleInvitees as |invitee|}}
                  <li class="invitee">
                    {{renderInvitee invitee}}
                    <DButton
                      @icon="plus"
                      @action={{fn this.addInvitee invitee}}
                    />
                  </li>
                {{/each}}
              </ul>
            {{/if}}
          {{else}}
            <p class="no-users">
              {{i18n
                "discourse_calendar.discourse_post_event.models.invitee.no_users"
              }}
            </p>
          {{/if}}
        </ConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
