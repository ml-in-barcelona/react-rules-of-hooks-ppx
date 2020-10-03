open React;
let useMierda = () => {
  ();
};

[@react.component]
let make = (~randomProp as _: string) => {
  let (show, _setShow) = React.useState(() => "sTatE");

  if (show === "state") {
    useMierda();
    useEffect1(
      () => {
        Js.log(show);
        None;
      },
      [|show|],
    );
  };

  <div />;
};

/* React.useEffect2(
     () => {
       Document.addMouseDownEventListener(onClickHandler, document);
       Some(
         () => Document.removeMouseDownEventListener(onClickHandler, document),
       );
     },
     (onClick, outsideContainer.React.current),
   );
    */
/* This shoudn't complain about 'handler' */
/* let useDebounce = (value, delay) => {
     let (debouncedValue, setDebouncedValue) = React.useState(_ => value);

     React.useEffect2(
       () => {
         let handler =
           Js.Global.setTimeout(() => setDebouncedValue(_ => value), delay);

         Some(() => Js.Global.clearTimeout(handler));
       },
       (value, delay),
     );

     debouncedValue;
   };
    */
