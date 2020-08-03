import ModalFunctionality from "discourse/mixins/modal-functionality";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default Controller.extend(ModalFunctionality, {
  @action
  uploadDone() {
    bootbox.alert(
      I18n.t("discourse_post_event.bulk_invite_modal.success"),
      () => {
        this.send("closeModal");
      }
    );
  }
});
