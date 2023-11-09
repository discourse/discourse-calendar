import Component from "@glimmer/component";

const VIEWING_TYPES = ["going", "interested", "not_going"];

export default class ToggleInvitees extends Component {
  get buttonType() {
    return VIEWING_TYPES.includes(this.viewingType)
      ? "btn-danger"
      : "btn-default";
  }
}
