import Component from "@glimmer/component";
import { action } from "@ember/object";
import { applyLocalDates } from "discourse/lib/local-dates";
import { inject as service } from "@ember/service";
import { tracked } from "@glimmer/tracking";

export default class EventTimestamp extends Component {
  @service siteSettings;

  @action
  applyLocalDates(element) {
    applyLocalDates([element], this.siteSettings);
  }
}