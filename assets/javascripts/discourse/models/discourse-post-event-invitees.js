import { TrackedArray } from "@ember-compat/tracked-built-ins";
import User from "discourse/models/user";
import DiscoursePostEventInvitee from "./discourse-post-event-invitee";

export default class DiscoursePostEventInvitees {
  static create(args = {}) {
    return new DiscoursePostEventInvitees(args);
  }

  constructor(args = {}) {
    this.invitees = args.invitees;
    this.suggestedUsers = args.meta?.suggested_users;
  }

  add(invitee) {
    this.invitees.push(invitee);

    const index = this.suggestedUsers.findIndex(
      (su) => su.id === invitee.user.id
    );
    if (index > -1) {
      this.suggestedUsers.splice(index, 1);
    }
  }

  remove(invitee) {
    const index = this.invitees.findIndex((i) => i.user.id === invitee.user.id);
    if (index > -1) {
      this.invitees.splice(index, 1);
    }
  }

  get suggestedUsers() {
    return this._suggestedUsers;
  }

  set suggestedUsers(suggestedUsers = []) {
    this._suggestedUsers = new TrackedArray(
      suggestedUsers.map((i) => User.create(i))
    );
  }

  get invitees() {
    return this._invitees;
  }

  set invitees(invitees = []) {
    this._invitees = new TrackedArray(
      invitees.map((i) => DiscoursePostEventInvitee.create(i))
    );
  }
}
