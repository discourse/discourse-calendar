import Controller from "@ember/controller";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend({
  selectedRegion: null,
  loading: false,

  @action
  async renderCalendar() {
    if (this.loading) {
      return;
    }
  },
});

