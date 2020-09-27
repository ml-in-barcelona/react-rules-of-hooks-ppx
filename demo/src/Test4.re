/* This shoudn't complain about 'handler' */
let useDebounce = (value, delay) => {
  let (debouncedValue, setDebouncedValue) = React.useState(_ => value);

  React.useEffect1(
    () => {
      let handler =
        Js.Global.setTimeout(() => setDebouncedValue(_ => value), delay);

      None;
    },
    [|value|],
  );

  debouncedValue;
};
