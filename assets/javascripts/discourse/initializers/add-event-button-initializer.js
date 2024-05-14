import { withPluginApi } from 'discourse/lib/plugin-api';

export default {
  name: 'add-event-button-initializer',
  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");
    if (siteSettings.discourse_post_event_enabled) {
    withPluginApi('0.8.7', api => {
      api.modifyClass('component:add-event-button', {
        pluginId: 'discourse-calendar',

        init() {
          this._super(...arguments);
          this.api = api;
        }
      });
    });
  }
}
};
