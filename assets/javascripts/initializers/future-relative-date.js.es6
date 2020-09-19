import { later, cancel } from "@ember/runloop";

export default {
  name: "relative-future-date",

  initialize() {
    this._tick();
  },

  teardown() {
    if (this._interval) {
      cancel(this._interval);
      this._interval = null;
    }
  },

  _tick() {
    this._interval && cancel(this._interval);

    this._interval = later(() => {
      document.querySelectorAll(".relative-future-date").forEach((date) => {
        date.innerText = moment(parseInt(date.dataset.time, 10))
          .tz(moment.tz.guess())
          .from(moment());
      });

      this._tick();
    }, 60 * 1000);
  },
};
