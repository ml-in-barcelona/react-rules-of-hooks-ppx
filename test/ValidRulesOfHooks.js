`
      // Valid because components can use hooks.
      function ComponentWithHook() {
        useHook();
      }
    `,
    `
      // Valid because components can use hooks.
      function createComponentWithHook() {
        return function ComponentWithHook() {
          useHook();
        };
      }
    `,
    `
      // Valid because hooks can use hooks.
      function useHookWithHook() {
        useHook();
      }
    `,
    `
      // Valid because hooks can use hooks.
      function createHook() {
        return function useHookWithHook() {
          useHook();
        }
      }
    `,
    `
      // Valid because components can call functions.
      function ComponentWithNormalFunction() {
        doSomething();
      }
    `,
    `
      // Valid because functions can call functions.
      function normalFunctionWithNormalFunction() {
        doSomething();
      }
    `,
    `
      // Valid because functions can call functions.
      function normalFunctionWithConditionalFunction() {
        if (cond) {
          doSomething();
        }
      }
    `,
    `
      // Valid because functions can call functions.
      function functionThatStartsWithUseButIsntAHook() {
        if (cond) {
          userFetch();
        }
      }
    `,
    `
      // Valid although unconditional return doesn't make sense and would fail other rules.
      // We could make it invalid but it doesn't matter.
      function useUnreachable() {
        return;
        useHook();
      }
    `,
    `
      // Valid because hooks can call hooks.
      function useHook() { useState(); }
      const whatever = function useHook() { useState(); };
      const useHook1 = () => { useState(); };
      let useHook2 = () => useState();
      useHook2 = () => { useState(); };
      ({useHook: () => { useState(); }});
      ({useHook() { useState(); }});
      const {useHook3 = () => { useState(); }} = {};
      ({useHook = () => { useState(); }} = {});
      Namespace.useHook = () => { useState(); };
    `,
    `
      // Valid because hooks can call hooks.
      function useHook() {
        useHook1();
        useHook2();
      }
    `,
    `
      // Valid because hooks can call hooks.
      function createHook() {
        return function useHook() {
          useHook1();
          useHook2();
        };
      }
    `,
    `
      // Valid because hooks can call hooks.
      function useHook() {
        useState() && a;
      }
    `,
    `
      // Valid because hooks can call hooks.
      function useHook() {
        return useHook1() + useHook2();
      }
    `,
    `
      // Valid because hooks can call hooks.
      function useHook() {
        return useHook1(useHook2());
      }
    `,
    `
      // Valid because hooks can be used in anonymous arrow-function arguments
      // to forwardRef.
      const FancyButton = React.forwardRef((props, ref) => {
        useHook();
        return <button {...props} ref={ref} />
      });
    `,
    `
      // Valid because hooks can be used in anonymous function arguments to
      // forwardRef.
      const FancyButton = React.forwardRef(function (props, ref) {
        useHook();
        return <button {...props} ref={ref} />
      });
    `,
    `
      // Valid because hooks can be used in anonymous function arguments to
      // forwardRef.
      const FancyButton = forwardRef(function (props, ref) {
        useHook();
        return <button {...props} ref={ref} />
      });
    `,
    `
      // Valid because hooks can be used in anonymous function arguments to
      // React.memo.
      const MemoizedFunction = React.memo(props => {
        useHook();
        return <button {...props} />
      });
    `,
    `
      // Valid because hooks can be used in anonymous function arguments to
      // memo.
      const MemoizedFunction = memo(function (props) {
        useHook();
        return <button {...props} />
      });
    `,
    `
      // Valid because classes can call functions.
      // We don't consider these to be hooks.
      class C {
        m() {
          this.useHook();
          super.useHook();
        }
      }
    `,
    `
      // Valid -- this is a regression test.
      jest.useFakeTimers();
      beforeEach(() => {
        jest.useRealTimers();
      })
    `,
    `
      // Valid because they're not matching use[A-Z].
      fooState();
      use();
      _use();
      _useState();
      use_hook();
      // also valid because it's not matching the PascalCase namespace
      jest.useFakeTimer()
    `,
    `
      // Regression test for some internal code.
      // This shows how the "callback rule" is more relaxed,
      // and doesn't kick in unless we're confident we're in
      // a component or a hook.
      function makeListener(instance) {
        each(pixelsWithInferredEvents, pixel => {
          if (useExtendedSelector(pixel.id) && extendedButton) {
            foo();
          }
        });
      }
    `,
    `
      // This is valid because "use"-prefixed functions called in
      // unnamed function arguments are not assumed to be hooks.
      React.unknownFunction((foo, bar) => {
        if (foo) {
          useNotAHook(bar)
        }
      });
    `,
    `
      // This is valid because "use"-prefixed functions called in
      // unnamed function arguments are not assumed to be hooks.
      unknownFunction(function(foo, bar) {
        if (foo) {
          useNotAHook(bar)
        }
      });
    `,
    `
      // Regression test for incorrectly flagged valid code.
      function RegressionTest() {
        const foo = cond ? a : b;
        useState();
      }
    `,
    `
      // Valid because exceptions abort rendering
      function RegressionTest() {
        if (page == null) {
          throw new Error('oh no!');
        }
        useState();
      }
    `,
    `
      // Valid because the loop doesn't change the order of hooks calls.
      function RegressionTest() {
        const res = [];
        const additionalCond = true;
        for (let i = 0; i !== 10 && additionalCond; ++i ) {
          res.push(i);
        }
        React.useLayoutEffect(() => {});
      }
    `,
    `
      // Is valid but hard to compute by brute-forcing
      function MyComponent() {
        // 40 conditions
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}
        if (c) {} else {}

        // 10 hooks
        useHook();
        useHook();
        useHook();
        useHook();
        useHook();
        useHook();
        useHook();
        useHook();
        useHook();
        useHook();
      }
    `,
    `
      // Valid because the neither the condition nor the loop affect the hook call.
      function App(props) {
        const someObject = {propA: true};
        for (const propName in someObject) {
          if (propName === true) {
          } else {
          }
        }
        const [myState, setMyState] = useState(null);
      }
    `,
