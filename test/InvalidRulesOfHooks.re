[@react.component]
module MyComponent = {
  let make = () => {
    if (cond) {
      useConditionalHook();
    }
  };
};

[@react.component]
module MyComponent = {
  let make = () => {
    if (cond) {
      MyModulo.useConditionalHook();
    }
  };
};


let useHookWithConditionalHook = () =>{
  if (cond) {
    useConditionalHook();
  }
};

let useHookWithConditionalHook = () =>{
  cond ? useTernaryHook() : ();
};

[@react.component]
module MyComponent = {
  let make = () => {
    let handleClick = () => {
      React.useState();
    };

    <div handleClick />
  };
};
