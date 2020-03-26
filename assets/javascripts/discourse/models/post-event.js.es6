import RestModel from "discourse/models/rest";

const ATTRIBUTES = {
  id: {},
  name: {},
  starts_at: {},
  ends_at: {},
  raw_invitees: {},
  display_invitees: {
    transform(value) {
      return DISPLAY_INVITEES_OPTIONS[value];
    }
  },
  status: {
    transform(value) {
      return STATUSES[value];
    }
  }
};

const DISPLAY_INVITEES_OPTIONS = {
  everyone: 0,
  invitees_only: 1,
  none: 2
};

const STATUSES = {
  standalone: 0,
  public: 1,
  private: 2
};

const PostEvent = RestModel.extend({
  init() {
    this._super(...arguments);

    this.__type = "post-event";
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
    attributesKeys.forEach(key => {
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
  }
});

export default PostEvent;
