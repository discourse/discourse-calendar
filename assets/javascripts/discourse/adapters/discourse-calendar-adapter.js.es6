import RestAdapter from "discourse/adapters/rest";

export default RestAdapter.extend({
  basePath() {
    return "/discourse-calendar/";
  },

  pathFor() {
    return this._super(...arguments).replace("_", "-");
  }
});
