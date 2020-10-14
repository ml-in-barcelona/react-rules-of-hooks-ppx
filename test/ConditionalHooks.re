let useMouseHook = () => ();

[@react.component]
let make = (~randomProp) => {
  if (randomProp === "state") {
    useMouseHook();
  };

  <div />;
};
