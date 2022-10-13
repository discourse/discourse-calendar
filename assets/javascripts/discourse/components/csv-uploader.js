import Component from "@ember/component";
import I18n from "I18n";
import UppyUploadMixin from "discourse/mixins/uppy-upload";
import { inject as service } from "@ember/service";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend(UppyUploadMixin, {
  type: "csv",
  tagName: "span",
  dialog: service(),
  uploadUrl: null,
  i18nPrefix: null,
  autoStartUploads: false,

  validateUploadedFilesOptions() {
    return { csvOnly: true };
  },

  @discourseComputed("uploading")
  uploadButtonText(uploading) {
    return uploading ? I18n.t("uploading") : I18n.t(`${this.i18nPrefix}.text`);
  },

  @discourseComputed("uploading", "processing")
  uploadButtonDisabled(uploading, processing) {
    // https://github.com/emberjs/ember.js/issues/10976#issuecomment-132417731
    return uploading || processing ? true : null;
  },

  uploadDone() {
    this.dialog.alert(I18n.t(`${this.i18nPrefix}.success`));
  },

  _uppyReady() {
    this._uppyInstance.on("file-added", () => {
      this.dialog.confirm({
        message: I18n.t(`${this.i18nPrefix}.confirmation_message`),
        didConfirm: () => this._startUpload(),
        didCancel: () => this._reset(),
      });
    });
  },
});
