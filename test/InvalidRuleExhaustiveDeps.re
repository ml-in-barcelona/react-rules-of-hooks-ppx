[@react.component]
module MyComponent = {
  let make = (foo) => {
    React.useCallback(() => {
      console.log(foo);
    }, []);
  }
};

[@react.component]
module MyComponent = {
  let make = () => {
    let local = someFunc();
    React.useEffect(() => {
      console.log(local);
    }, []);
  };
};

[@react.component]
module MyComponent = {
  let make = () => {
    let local = 42;
    React.useEffect(() => {
      console.log(local);
    }, []);
  }
};

// Invalid because they don't have a meaning without deps.
[@react.component]
module MyComponent = {
  let make = (props) => {
    let value = useMemo(() => 2 * 2);
    let fn = useCallback(() => { alert("foo"); });
  };
};

// Invalid because they don't have a meaning without deps.
[@react.component]
module MyComponent = {
  let make =({ fn1, fn2 }) => {
    let value = useMemo(fn1);
    let fn = useCallback(fn2);
  };
};

[@react.component]
module MyComponent = {
  let make = () => {
    let local = someFunc();
    React.useEffect(() => {
      if (true) {
        console.log(local);
      }
    }, []);
  };
};

[@react.component]
module MyComponent = {
  let make =  () => {
    let local = {};
    React.useEffect(() => {
      let inner = () => {
        console.log(local);
      };
      inner();
    }, []);
  };
};

[@react.component]
module MyComponent = {
  let make = () => {
    let local1 = { };
    let local2 = { };
    React.useEffect(() => {
      console.log(local1);
      console.log(local2);
    }, [local1]);
  };
};

[@react.component]
module MyComponent = {
  let make =  () => {
    let local1 = { };
    let local2 = { };
    React.useMemo(() => {
      console.log(local1);
    }, [local1, local2]);
  };
};

[@react.component]
module MyComponent = {
  let make = () => {
    let local = 23;
    React.useEffect(() => {
      console.log(local);
      console.log(local);
    }, [local, local]);
  };
};

[@react.component]
module MyComponent = {
  let make =(~foo, ~ bar, ~baz) => {
    React.useEffect(() => {
      console.log(foo, bar, baz);
    }, ["foo", "bar"]);
  };
};
