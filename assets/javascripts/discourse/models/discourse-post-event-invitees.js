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
