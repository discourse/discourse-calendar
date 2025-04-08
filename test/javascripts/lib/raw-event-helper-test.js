import { module, test } from "qunit";
import { replaceRaw } from "discourse/plugins/discourse-calendar/discourse/lib/raw-event-helper";

module("Unit | Lib | raw-event-helper", function () {
  test("replaceRaw", function (assert) {
    const raw = "Some text [event param1=\"value1\"] more text";
    const params = { 
      param1: "newValue1",
      param2: "value2"
    };

    assert.strictEqual(
      replaceRaw(params, raw),
      "Some text [event param1=\"newValue1\" param2=\"value2\"] more text",
      "it updates existing parameters and adds new ones"
    );

    assert.strictEqual(
      replaceRaw(params, "No event tag here"),
      false,
      "returns false when no event tag is found"
    );

    assert.strictEqual(
      replaceRaw({ foo: "bar\"quoted" }, "[event original=\"value\"]"),
      "[event foo=\"barquoted\"]",
      "it properly escapes quotes in parameter values"
    );

    assert.strictEqual(
      replaceRaw({}, "[event param1=\"value1\"]"),
      "[event ]",
      "it handles empty params object"
    );
  });
});
