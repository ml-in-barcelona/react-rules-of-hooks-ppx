[@react.component]
let make = (~randomProp: string) => {
  let (show, setShow) = React.useState(() => "sTatE");

  React.useEffect1(
    () => {
      Js.log(show);
      setShow(_ => randomProp);

      None;
    },
    [|show|],
  );

  <div />;
};
