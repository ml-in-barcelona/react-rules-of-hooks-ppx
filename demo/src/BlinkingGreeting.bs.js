'use strict';

var Curry = require("bs-platform/lib/js/curry.js");
var React = require("react");

function BlinkingGreeting(Props) {
  var randomProp = Props.randomProp;
  var match = React.useState((function () {
          return "sTaTe";
        }));
  var setShow = match[1];
  var show = match[0];
  React.useEffect((function () {
          console.log(show);
          Curry._1(setShow, (function (param) {
                  return randomProp;
                }));
          
        }), [show]);
  return React.createElement("div", undefined);
}

var make = BlinkingGreeting;

exports.make = make;
/* react Not a pure module */
