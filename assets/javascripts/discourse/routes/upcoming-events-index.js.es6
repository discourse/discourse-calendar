import Route from "@ember/routing/route";

export default Route.extend({
  queryParams: {
    invited: { refreshModel: true, replace: true }
  },

  model(params) {
    return params;
  },

  setupController(controller, params) {
    controller.loadPostEvents(params);
  }
});
