import { tracked } from "@glimmer/tracking";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import User from "discourse/models/user";
import DiscoursePostEventEventStats from "./discourse-post-event-event-stats";
import DiscoursePostEventInvitee from "./discourse-post-event-invitee";

export default class DiscoursePostEventEvent {
  static create(args = {}) {
    return new DiscoursePostEventEvent(args);
  }

  @tracked title;
  @tracked name;
  @tracked startsAt;
  @tracked endsAt;
  @tracked rawInvitees;
  @tracked url;
  @tracked timezone;
  @tracked post;
  @tracked minimal;
  @tracked canUpdateAttendance;
  @tracked canActOnDiscoursePostEvent;
  @tracked shouldDisplayInvitees;
  @tracked isClosed;
  @tracked isExpired;
  @tracked isStandalone;
  @tracked recurrenceRule;

  @tracked _watchingInvitee;
  @tracked _sampleInvitees;
  @tracked _stats;
  @tracked _creator;
  @tracked _reminders;

  constructor(args = {}) {
    console.log(args);
    this.id = args.id;
    this.name = args.name;
    this.startsAt = args.starts_at;
    this.endsAt = args.ends_at;
    this.rawInvitees = args.raw_invitees;
    this.sampleInvitees = args.sample_invitees;
    this.url = args.url;
    this.timezone = args.timezone;
    this.status = args.status;
    this.creator = args.creator;
    this.post = args.post;
    this.isClosed = args.is_closed;
    this.isExpired = args.is_expired;
    this.isStandalone = args.is_standalone;
    this.minimal = args.minimal;
    this.recurrenceRule = args.recurrence_rule;
    this.canUpdateAttendance = args.can_update_attendance;
    this.canActOnDiscoursePostEvent = args.can_act_on_discourse_post_event;
    this.shouldDisplayInvitees = args.should_display_invitees;
    this.watchingInvitee = args.watching_invitee;
    this.stats = args.stats;
    this.reminders = args.reminders;
  }

  get watchingInvitee() {
    return this._watchingInvitee;
  }

  set watchingInvitee(invitee) {
    this._watchingInvitee = invitee
      ? DiscoursePostEventInvitee.create(invitee)
      : null;
  }

  get sampleInvitees() {
    return this._sampleInvitees;
  }

  set sampleInvitees(invitees) {
    this._sampleInvitees = new TrackedArray(
      (invitees || []).map((u) => DiscoursePostEventInvitee.create(u))
    );
  }

  get stats() {
    return this._stats;
  }

  set stats(stats) {
    this._stats = this.#initStatsModel(stats);
  }

  get reminders() {
    return this._reminders;
  }

  set reminders(reminders = []) {
    this._reminders = new TrackedArray(reminders);
  }

  get creator() {
    return this._creator;
  }

  set creator(user) {
    this._creator = this.#initUserModel(user);
  }

  get isPublic() {
    return this.status === "public";
  }

  get isPrivate() {
    return this.status === "private";
  }

  updateFromEvent(event) {
    this.name = event.name;
    this.startsAt = event.startsAt;
    this.endsAt = event.endsAt;
    this.url = event.url;
    this.timezone = event.timezone;
    this.status = event.status;
    this.creator = event.creator;
    this.isClosed = event.isClosed;
    this.isExpired = event.isExpired;
    this.isStandalone = event.isStandalone;
    this.minimal = event.minimal;
    this.recurrenceRule = event.recurrenceRule;
    this.canUpdateAttendance = event.canUpdateAttendance;
    this.canActOnDiscoursePostEvent = event.canActOnDiscoursePostEvent;
    this.shouldDisplayInvitees = event.shouldDisplayInvitees;
    this.stats = event.stats;
    this.sampleInvitees = event.sampleInvitees;
    this.reminders = event.reminders;
  }

  #initUserModel(user) {
    if (!user || user instanceof User) {
      return user;
    }

    return User.create(user);
  }

  #initStatsModel(stats) {
    if (!stats || stats instanceof DiscoursePostEventEventStats) {
      return stats;
    }

    return DiscoursePostEventEventStats.create(stats);
  }
}

// TODO: get rid of all the following
const DEFAULT_REMINDER = {
  type: "notification",
  value: 15,
  unit: "minutes",
  period: "before",
};

function replaceTimezone(val, newTimezone) {
  return moment.tz(val.format("YYYY-MM-DDTHH:mm"), newTimezone);
}
export function updateEventStatus(event, status) {
  event.status = status;
}

export function updateEventRawInvitees(event, rawInvitees) {
  event.rawInvitees = rawInvitees;
}

export function updateCustomField(event, field, value) {
  event.custom_fields[field] = value;
}

export function removeReminder(event, reminder) {
  return event.reminders.removeObject(reminder);
}

export function addReminder(event) {
  event.reminders.push(Object.assign({}, DEFAULT_REMINDER));
}
export function onChangeDates(event, changes) {
  event.startsAt = changes.from;
  event.endsAt = changes.to;
}
export function updateTimezone(event, newTz, startsAt, endsAt) {
  event.timezone = newTz;
  event.startsAt = replaceTimezone(startsAt, newTz);
  event.endsAt = replaceTimezone(endsAt, newTz);
}
