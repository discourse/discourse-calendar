import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import PostEventInvitees from "../modal/post-event-invitees";
import Invitee from "./invitee";

export default class DiscoursePostEventInvitees extends Component {
  @service modal;
  @service siteSettings;
  @service discoursePostEventApi;

  @tracked isLoading = false;
  @tracked inviteesList = {};

  constructor() {
    super(...arguments);
    this._fetchInvitees();
  }

  @action
  showAllInvitees() {
    this.modal.show(PostEventInvitees, {
      model: {
        event: this.args.event,
        title: this.args.event.title,
        extraClass: this.args.event.extraClass,
      },
    });
  }

  async _fetchInvitees() {
    try {
      this.isLoading = true;

      const [going, interested, notGoing] = await Promise.all([
        this.discoursePostEventApi.listEventInvitees(this.args.event, {
          type: "going",
        }),
        this.discoursePostEventApi.listEventInvitees(this.args.event, {
          type: "interested",
        }),
        this.discoursePostEventApi.listEventInvitees(this.args.event, {
          type: "not_going",
        }),
      ]);

      this.inviteesList["going"] = going;
      this.inviteesList["interested"] = interested;
      this.inviteesList["not_going"] = notGoing;
    } catch (error) {
      console.error("Error fetching invitees:", error);
    } finally {
      this.isLoading = false;
    }
  }

  <template>
    {{#unless @event.minimal}}
      {{#if @event.shouldDisplayInvitees}}
        <section class="event__section event-invitees">
          <ConditionalLoadingSpinner @condition={{this.isLoading}}>
            <ul class="event-invitees-avatars">
              {{#if this.inviteesList.going}}
                <li class="event-invitees-avatars-item">
                  {{icon "check"}}
                  <span class="event-invitees-count">
                    {{this.inviteesList.going.invitees.length}}
                  </span>
                  <ul class="event-invitees-avatars-sublist">
                    {{#each this.inviteesList.going.invitees as |invitee|}}
                      <Invitee @invitee={{invitee}} />
                    {{/each}}
                  </ul>
                </li>
              {{/if}}
              {{#if this.inviteesList.interested}}
                <li class="event-invitees-avatars-item">
                  {{icon "star"}}
                  <span class="event-invitees-count">
                    {{this.inviteesList.interested.invitees.length}}
                  </span>
                  <ul class="event-invitees-avatars-sublist">
                    {{#each this.inviteesList.interested.invitees as |invitee|}}
                      <Invitee @invitee={{invitee}} />
                    {{/each}}
                  </ul>
                </li>
              {{/if}}
              {{#if this.inviteesList.not_going}}
                <li class="event-invitees-avatars-item">
                  {{icon "times"}}
                  <span class="event-invitees-count">
                    {{this.inviteesList.not_going.invitees.length}}
                  </span>
                  <ul class="event-invitees-avatars-sublist">
                    {{#each this.inviteesList.not_going.invitees as |invitee|}}
                      <Invitee @invitee={{invitee}} />
                    {{/each}}
                  </ul>
                </li>
              {{/if}}
            </ul>
          </ConditionalLoadingSpinner>
        </section>
      {{/if}}
    {{/unless}}
  </template>
}
