'use strict';

var React = require("react");
var ReactDom = require("react-dom");
var BlinkingGreeting$ReasonReactExample = require("./BlinkingGreeting.bs.js");

function makeContainer(text) {
  var container = document.createElement("div");
  container.className = "container";
  var title = document.createElement("div");
  title.className = "containerTitle";
  title.innerText = text;
  var content = document.createElement("div");
  content.className = "containerContent";
  container.appendChild(title);
  container.appendChild(content);
  document.body.appendChild(container);
  return content;
}

ReactDom.render(React.createElement(BlinkingGreeting$ReasonReactExample.make, {
          randomProp: "3"
        }), makeContainer("Blinking Greeting"));

exports.makeContainer = makeContainer;
/*  Not a pure module */
