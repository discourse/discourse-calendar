// https://github.com/WebDevTmas/moment-round
if (typeof moment.fn.round !== "function") {
  moment.fn.round = function(precision, key, direction) {
    direction = direction || "round";
    var _this = this; //cache of this
    var methods = {
      hours: { name: "Hours", maxValue: 24 },
      minutes: { name: "Minutes", maxValue: 60 },
      seconds: { name: "Seconds", maxValue: 60 },
      milliseconds: { name: "Milliseconds", maxValue: 1000 }
    };
    var keys = {
      mm: methods.milliseconds.name,
      milliseconds: methods.milliseconds.name,
      Milliseconds: methods.milliseconds.name,
      s: methods.seconds.name,
      seconds: methods.seconds.name,
      Seconds: methods.seconds.name,
      m: methods.minutes.name,
      minutes: methods.minutes.name,
      Minutes: methods.minutes.name,
      H: methods.hours.name,
      h: methods.hours.name,
      hours: methods.hours.name,
      Hours: methods.hours.name
    };
    var value = 0;
    var rounded = false;
    var subRatio = 1;
    var maxValue;

    // make sure key is plural
    if (key.length > 1 && key !== "mm" && key.slice(-1) !== "s") {
      key += "s";
    }
    key = keys[key].toLowerCase();

    //control
    if (!methods[key]) {
      throw new Error(
        'The value to round is not valid. Possibles ["hours", "minutes", "seconds", "milliseconds"]'
      );
    }

    var get = "get" + methods[key].name;
    var set = "set" + methods[key].name;

    for (var k in methods) {
      if (k === key) {
        value = _this._d[get]();
        maxValue = methods[k].maxValue;
        rounded = true;
      } else if (rounded) {
        subRatio *= methods[k].maxValue;
        value += _this._d["get" + methods[k].name]() / subRatio;
        _this._d["set" + methods[k].name](0);
      }
    }

    value = Math[direction](value / precision) * precision;
    value = Math.min(value, maxValue);
    _this._d[set](value);

    return _this;
  };
}

if (typeof moment.fn.ceil !== "function") {
  moment.fn.ceil = function(precision, key) {
    return this.round(precision, key, "ceil");
  };
}

if (typeof moment.fn.floor !== "function") {
  moment.fn.floor = function(precision, key) {
    return this.round(precision, key, "floor");
  };
}

const STEP = 15;

export default function roundTime(date, negativeOffset = true) {
  return date.round(STEP, "minutes");
}
