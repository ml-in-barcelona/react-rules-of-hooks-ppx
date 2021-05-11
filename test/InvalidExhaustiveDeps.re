module MyComponent = {
  [@react.component]
  let make = (foo) => {
    React.useCallback(() => {
      console.log(foo);
    }, []);
  }
};

module MyComponent = {
  [@react.component]
  let make = () => {
    let local = someFunc();
    React.useEffect(() => {
      console.log(local);
    }, []);
  };
};
