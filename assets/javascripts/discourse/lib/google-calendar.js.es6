import EmberObject from "@ember/object";

export default EmberObject.extend({
  init(params = {}) {
    this.title = params.title;
    this.startsAt = moment(params.startsAt);
    this.endsAt = params.endsAt ? moment(params.endsAt) : null;
  },

  generateLink() {
    const title = encodeURIComponent(this.title);
    let dates = [this._formatDate(this.startsAt)];
    if (this.endsAt) {
      dates.push(this._formatDate(this.endsAt));
      dates = `dates=${dates.join("/")}`;
    } else {
      dates = `date=${dates.join("")}`;
    }

    return `https://www.google.com/calendar/event?action=TEMPLATE&text=${title}&${dates}`;
  },

  _formatDate(date) {
    return date.toISOString().replace(/-|:|\.\d\d\d/g, "");
  }
});
