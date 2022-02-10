import RestModel from "discourse/models/rest";
import { ajax } from "discourse/lib/ajax";

const ATTRIBUTES = {
  id: {},
  name: {},
  starts_at: {},
  ends_at: {},
  raw_invitees: {},
  url: {},
  status: {
    transform(value) {
      return STATUSES[value];
    },
  },
};

const STATUSES = {
  standalone: 0,
  public: 1,
  private: 2,
};

const Event = RestModel.extend({
  init() {
    this._super(...arguments);

    this.__type = "discourse-post-event-event";
  },

  update(data) {
    return ajax(`/discourse-post-event/events/${this.id}.json`, {
      type: "PUT",
      dataType: "json",
      contentType: "application/json",
      data: JSON.stringify({ event: data }),
    });
  },

  updateProperties() {
    const attributesKeys = Object.keys(ATTRIBUTES);
    return this.getProperties(attributesKeys);
  },

  createProperties() {
    const attributesKeys = Object.keys(ATTRIBUTES);
    return this.getProperties(attributesKeys);
  },

  _transformProps(props) {
    const attributesKeys = Object.keys(ATTRIBUTES);
    attributesKeys.forEach((key) => {
      const attribute = ATTRIBUTES[key];
      if (attribute.transform) {
        props[key] = attribute.transform(props[key]);
      }
    });
  },

  beforeUpdate(props) {
    this._transformProps(props);
  },

  beforeCreate(props) {
    this._transformProps(props);
  },
});

export default Event;
