[@react.component]
let make = (~randomProp as _: string) => {
  let (show, _setShow) = React.useState(() => "sTatE");

  React.useEffect1(
    () => {
      Js.log(randomProp);
      None;
    },
    [|show|],
  );

  <div />;
};
