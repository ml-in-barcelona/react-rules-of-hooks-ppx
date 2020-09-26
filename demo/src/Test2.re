[@react.component]
let make = (~randomProp: string, ~thirdProppp: int) => {
  let (show, setShow) = React.useState(() => "sTatE");

  React.useEffect2(
    () => {
      Js.log(show);
      Js.log(thirdProppp);
      setShow(_ => randomProp);
      None;
    },
    (show, randomProp),
  );

  <div />;
};
