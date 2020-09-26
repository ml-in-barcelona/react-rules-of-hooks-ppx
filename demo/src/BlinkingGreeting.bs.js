'use strict';

var React = require("react");

function BlinkingGreeting(Props) {
  Props.randomProp;
  var match = React.useState((function () {
          return "sTatE";
        }));
  var show = match[0];
  React.useEffect((function () {
          console.log(show);
          
        }), [show]);
  return React.createElement("div", undefined);
}

var make = BlinkingGreeting;

exports.make = make;
/* react Not a pure module */
