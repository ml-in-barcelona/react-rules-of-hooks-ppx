# ESLint Rules of Hooks Test Cases

This document catalogs test cases from Facebook's React ESLint plugin (`eslint-plugin-react-hooks`) and annotates which ones are relevant for migration to the OCaml/Reason PPX (`react-rules-of-hooks-ppx`).

Source: https://github.com/facebook/react/tree/main/packages/eslint-plugin-react-hooks/__tests__

---

## Legend

- ✅ **Already implemented** - Test case exists in PPX
- 🎯 **Should migrate** - Relevant for mlx, worth implementing
- ⚠️ **Partial** - Partially covered or needs enhancement
- ❌ **Not applicable** - JS-specific or not relevant for mlx
- 🤔 **Consider** - May be worth implementing but lower priority

---

## Rules of Hooks (`ESLintRulesOfHooks-test.js`)

### Valid Cases

#### Basic Hook Usage in Components

| Case | Status | Notes |
|------|--------|-------|
| Hooks in function components (`function ComponentWithHook() { useHook(); }`) | ✅ | Core functionality |
| Hooks in custom hooks (`function useHookWithHook() { useHook(); }`) | ✅ | Core functionality |
| Nested component definitions with hooks | ✅ | Covered in existing tests |
| Multiple hooks in sequence | ✅ | `valid-sequence-hooks.t` |
| Hooks in `React.forwardRef` callbacks | 🎯 | Should work if component detected |
| Hooks in `React.memo` callbacks | 🎯 | Should work if component detected |

#### Non-Hook Functions (should NOT error)

| Case | Status | Notes |
|------|--------|-------|
| Normal functions calling normal functions | ✅ | PPX only checks hook calls |
| Functions starting with lowercase that aren't hooks (`userFetch`) | ✅ | Hook detection by name |
| `jest.useFakeTimers()` - not a hook | ❌ | JS testing framework specific |
| Class methods calling `this.useHook()` / `super.useHook()` | ❌ | No classes in mlx |

#### Conditional Returns Before Hooks (Valid)

| Case | Status | Notes |
|------|--------|-------|
| `throw` before hooks (exceptions abort rendering) | ✅ | `hooks-after-conditional-return.t` |
| Unreachable code after unconditional return | 🎯 | Edge case worth testing |

#### The `use()` Hook (React 19+)

| Case | Status | Notes |
|------|--------|-------|
| `use(Promise)` can be called conditionally | 🎯 | New React 19 feature |
| `use()` in loops | 🎯 | Different from other hooks |
| `use()` in callbacks | 🎯 | Different from other hooks |

#### useEffectEvent

| Case | Status | Notes |
|------|--------|-------|
| useEffectEvent callbacks can be called in useEffect | 🤔 | Complex feature, lower priority |
| useEffectEvent with custom effect hooks via settings | 🤔 | Requires configuration system |

---

### Invalid Cases

#### Conditional Hook Calls

| Case | Status | Notes |
|------|--------|-------|
| Hook in `if` statement | ✅ | `conditional-hooks.t` |
| Hook in ternary expression (`cond ? useHook() : null`) | ✅ | Should be covered |
| Hook after conditional return | ✅ | `hooks-after-conditional-return.t` |
| Hook in short-circuit (`a && useHook()`) | ✅ | `missing-hooks-in-short-circuit.t` |
| Hook in nullish coalescing (`bar ?? useHook()`) | 🎯 | Should migrate |
| Hook in try/catch block | ✅ | `missing-hooks-in-try.t` |
| Hook in labeled block with break | 🎯 | Edge case |

#### Hooks in Loops

| Case | Status | Notes |
|------|--------|-------|
| Hook in `while` loop | ✅ | `hooks-in-while-loop.t` |
| Hook in `for` loop | ✅ | `hooks-in-for-loop.t` |
| Hook in `do...while` loop | 🎯 | Should migrate (no do-while in OCaml but pattern exists) |
| Hook in loop condition | 🎯 | Edge case |

#### Hooks in Callbacks

| Case | Status | Notes |
|------|--------|-------|
| Hook in useEffect callback | ✅ | `hooks-in-useeffect-callback.t` |
| Hook in useMemo callback | ✅ | `hooks-in-usememo-callback.t` |
| Hook in useReducer callback | ✅ | `hooks-in-usereducer-callback.t` |
| Hook in useCallback callback | 🎯 | Should migrate |
| Hook in regular callback function | ✅ | `missing-hooks-in-callback.t` |
| Hook in event handler | ✅ | `missing-hooks-in-callback.t` |

#### Hooks at Top Level (Outside Components)

| Case | Status | Notes |
|------|--------|-------|
| Hook call at module top level | ✅ | `hooks-at-top-level.t` |
| Hook in non-component function (lowercase name) | ✅ | `missing-hooks-outside-component.t` |
| Hook with namespace (`Hook.useState()`) at top level | 🎯 | Should migrate |

#### Hooks in Classes

| Case | Status | Notes |
|------|--------|-------|
| Hook in class render method | ❌ | No classes in mlx |
| Hook in class method | ❌ | No classes in mlx |
| Hook in class property | ❌ | No classes in mlx |

#### Async Functions

| Case | Status | Notes |
|------|--------|-------|
| Hook in async component | 🎯 | `async function AsyncComponent() { useState(); }` |
| Hook in async custom hook | 🎯 | Should warn |

#### Naming Convention Violations

| Case | Status | Notes |
|------|--------|-------|
| Hook in function not starting with `use` or uppercase | ✅ | Core functionality |
| Functions starting with `_use` | 🎯 | Should not be treated as hooks |

---

## Exhaustive Dependencies (`ESLintRuleExhaustiveDeps-test.js`)

### Valid Cases - No Missing Dependencies

| Case | Status | Notes |
|------|--------|-------|
| Local variable used and in deps | ✅ | `valid-correct-deps.t` |
| Props used and in deps | ✅ | Basic functionality |
| Nested property access (`props.foo.bar`) | ✅ | Should work |
| Optional chaining (`props?.foo`) | 🎯 | OCaml has different optional handling |
| useRef().current (static, can be omitted) | ✅ | `exhaustive-deps.t` |
| useState setter (static) | ✅ | Should be omittable |
| useReducer dispatch (static) | ✅ | Should be omittable |
| useCallback result (stable if deps stable) | 🎯 | Complex case |
| Constant primitives (`const x = 42`) | 🎯 | Can be omitted |
| Functions that don't use component scope | 🎯 | Can be omitted |

### Invalid Cases - Missing Dependencies

| Case | Status | Notes |
|------|--------|-------|
| Local variable used but not in deps | ✅ | `exhaustive-deps.t` |
| Props used but not in deps | ✅ | Basic functionality |
| Nested property missing | ✅ | `missing-useMemo-deps.t` etc. |
| Multiple missing deps | ✅ | `multiple-errors.t` |
| Missing in useEffect | ✅ | `exhaustive-deps.t` |
| Missing in useCallback | ✅ | `missing-useCallback-deps.t` |
| Missing in useMemo | ✅ | `missing-useMemo-deps.t` |
| Missing in useLayoutEffect | ✅ | `missing-useLayoutEffect.t` |
| Missing in useInsertionEffect | ✅ | `missing-useInsertionEffect.t` |

### Invalid Cases - Unnecessary Dependencies

| Case | Status | Notes |
|------|--------|-------|
| Outer scope value in deps (`window`) | 🎯 | Should warn |
| Module-level import in deps | 🎯 | Should warn |
| Duplicate dependency | 🎯 | Should warn |
| Dependency not used in callback | ⚠️ | Partial - effects can over-specify |

### Invalid Cases - Unstable Dependencies

| Case | Status | Notes |
|------|--------|-------|
| Object literal in deps | 🎯 | Changes every render |
| Array literal in deps | 🎯 | Changes every render |
| Function in deps (not wrapped in useCallback) | 🎯 | Changes every render |
| Regex literal in deps | 🎯 | Stateful, changes every render |
| JSX element in deps | 🎯 | Changes every render |

### Invalid Cases - ref.current in Cleanup

| Case | Status | Notes |
|------|--------|-------|
| `ref.current` read in cleanup function | ✅ | `missing-cleanup-deps.t` |
| `myRef.current` used in return cleanup | ✅ | Should warn |

### Invalid Cases - Assignments Inside Effects

| Case | Status | Notes |
|------|--------|-------|
| Assigning to outer variable in effect | 🤔 | JS-specific pattern |

### Invalid Cases - Missing Callback Argument

| Case | Status | Notes |
|------|--------|-------|
| `useEffect()` with no arguments | 🎯 | Should error |
| `useMemo()` with only one argument | 🎯 | Should error |
| `useCallback()` with only one argument | 🎯 | Should error |

### Invalid Cases - Non-Array Dependencies

| Case | Status | Notes |
|------|--------|-------|
| Deps passed as variable instead of array literal | 🎯 | Can't statically verify |
| Spread in deps array | 🎯 | Can't statically verify |
| Complex expression in deps | 🎯 | Can't statically verify |

### Invalid Cases - Async Effects

| Case | Status | Notes |
|------|--------|-------|
| `useEffect(async () => {})` | 🎯 | Effects must be synchronous |

### Invalid Cases - useEffectEvent

| Case | Status | Notes |
|------|--------|-------|
| useEffectEvent result in dependency array | 🤔 | Should not be in deps |

---

## Test Cases by Priority for Migration

### High Priority (Core Functionality)

1. **Hook in nullish coalescing** (`bar ?? useHook()`)
   ```ocaml
   let%component make () =
     let _ = match someOption with None -> useHook () | Some x -> x in
     ...
   ```

2. **Hook in async function**
   ```ocaml
   let%component make () =
     (* Should warn about async component patterns *)
     ...
   ```

3. **Namespace hook calls at top level** (`React.useState()` outside component)
   ```ocaml
   let _ = React.useState (fun () -> 0)  (* Should error *)
   ```

4. **Missing callback to useEffect/useMemo/useCallback**
   ```ocaml
   let%component make () =
     let _ = React.useEffect () in  (* Missing callback *)
     ...
   ```

5. **Unstable dependencies (objects/arrays/functions)**
   ```ocaml
   let%component make () =
     let obj = { foo = 1 } in
     let _ = React.useMemo (fun () -> obj) [| obj |] in  (* obj changes every render *)
     ...
   ```

### Medium Priority (Edge Cases)

1. **Duplicate dependencies**
2. **Outer scope values in deps (module-level)**
3. **Non-array literal deps** (variable or spread)
4. **Complex expressions in deps**
5. **Functions starting with `_use`** (not hooks)

### Lower Priority (JS-Specific or Rare)

1. **useEffectEvent patterns**
2. **Class-related checks** (not applicable)
3. **Jest/testing framework patterns** (not applicable)
4. **Flow/TypeScript specific syntax**

---

## OCaml/Reason Specific Considerations

### Patterns That Don't Apply

1. **Classes** - OCaml doesn't have classes in the same way
2. **`this`/`super`** - No equivalent in OCaml
3. **Prototype methods** - Not applicable
4. **JavaScript-specific async patterns** - Lwt/Async are different

### Patterns That Need OCaml Adaptation

1. **Optional chaining** - Use `Option.map` or pattern matching
2. **Nullish coalescing** - Use `Option.value ~default`
3. **Spread in arrays** - Use `Array.concat` or `@`
4. **Destructuring** - OCaml pattern matching is more powerful

### mlx Syntax Reference

The PPX uses `[@react.component]` attribute:

```ocaml
(* Valid component with hooks *)
let[@react.component] valid_component ~name =
  let state, _setState = React.useState (fun () -> 0) in
  React.useEffect1
    (fun () ->
      Js.log state;
      None)
    [| state |];
  <div><span>(React.string name)</span></div>
```

### mlx-Specific Patterns to Test

#### 1. Conditional Hook (INVALID)

```ocaml
(* Should error: hook called conditionally *)
let[@react.component] make ~condition =
  if condition then
    let _state, _ = React.useState (fun () -> 0) in
    ();
  <div />
```

**Expected error:**
```
Hooks can't be called conditionally and must be called at the top level
of your component.
```

#### 2. Missing Dependency (INVALID)

```ocaml
(* Should warn: randomProp missing from deps *)
let[@react.component] make ~randomProp:(_ : string) =
  let show, _setShow = React.useState (fun () -> "state") in
  React.useEffect1
    (fun () -> Js.log randomProp; None)
    [|show|];  (* Missing randomProp! *)
  <div />
```

**Expected warning:**
```
exhaustive-deps: Missing 'randomProp' in the dependency array.
```

#### 3. Hook in Pattern Match (INVALID)

```ocaml
(* Should error: hook in match branch is conditional *)
let[@react.component] make ~variant =
  let _ = match variant with
    | `A -> React.useState (fun () -> 0)
    | `B -> (0, fun _ -> ())
  in
  <div />
```

#### 4. Hook in For Loop (INVALID)

```ocaml
(* Should error: hook called in loop *)
let[@react.component] make ~count =
  for _i = 0 to count do
    let _ = React.useState (fun () -> 0) in ()
  done;
  <div />
```

#### 5. Hook Outside Component (INVALID)

```ocaml
(* Should error: hook at top level *)
let _ = React.useState (fun () -> 0)

let[@react.component] make () = <div />
```

#### 6. Valid Sequence of Hooks

```ocaml
(* Should be valid: hooks called unconditionally in sequence *)
let[@react.component] make () =
  let state1, _ = React.useState (fun () -> 0) in
  let state2, _ = React.useState (fun () -> "") in
  let _ = React.useEffect1 (fun () -> None) [| state1 |] in
  <div>(React.string (string_of_int state1 ^ state2))</div>
```

#### 7. Hook in Callback (INVALID)

```ocaml
(* Should error: hook inside useEffect callback *)
let[@react.component] make () =
  React.useEffect (fun () ->
    let _ = React.useState (fun () -> 0) in  (* Error! *)
    None
  );
  <div />
```

#### 8. Custom Hook Definition (VALID)

```ocaml
(* Should be valid: custom hook can use hooks *)
let useCustomHook () =
  let state, setState = React.useState (fun () -> 0) in
  React.useEffect1 (fun () -> None) [| state |];
  (state, setState)

let[@react.component] make () =
  let state, _ = useCustomHook () in
  <div>(React.int state)</div>
```

#### 9. JSX in Switch (edge case)

```ocaml
(* Should be valid: hooks before switch, JSX in branches *)
let[@react.component] make ~variant =
  let state, _ = React.useState (fun () -> 0) in
  match variant with
  | `A -> <div>(React.int state)</div>
  | `B -> <span>(React.int state)</span>
```

#### 10. Nested Function with Hook (INVALID)

```ocaml
(* Should error: hook in nested function *)
let[@react.component] make () =
  let handleClick () =
    let _ = React.useState (fun () -> 0) in  (* Error! *)
    ()
  in
  <button onClick=handleClick />
```

---

## Summary Statistics

| Category | ESLint Tests | Already Implemented | Should Migrate | Not Applicable |
|----------|-------------|---------------------|----------------|----------------|
| Valid Rules of Hooks | ~45 | ~25 | ~15 | ~5 |
| Invalid Rules of Hooks | ~60 | ~30 | ~20 | ~10 |
| Valid Exhaustive Deps | ~100 | ~40 | ~40 | ~20 |
| Invalid Exhaustive Deps | ~120 | ~50 | ~50 | ~20 |
| **Total** | **~325** | **~145** | **~125** | **~55** |

---

## Migration Status (January 2026)

### New Tests Added

| Test File | Description | Result |
|-----------|-------------|--------|
| `underscore-use-not-hook.t` | `_useX`, `use_x`, `userX` not hooks | ⚠️ Bug: overly broad detection |
| `hooks-in-usecallback-callback.t` | Hooks inside useCallback | ⚠️ Missing feature |
| `hooks-in-ternary.t` | Hooks in if-else expressions | ✅ Working |
| `namespace-hooks-top-level.t` | `React.useState` at module level | ✅ Working |
| `static-deps-omittable.t` | setState/useRef omittable | ⚠️ Currently warns |
| `duplicate-deps.t` | Duplicate dependencies | ⚠️ Not detected |
| `outer-scope-deps.t` | Module-level deps | ⚠️ Not detected |
| `hooks-in-option-handling.t` | Hooks in Option branches | ✅ Working |

### Issues Found

1. **Hook detection too broad** (`ppx.ml:467`)
   - Current: `starts_with "use" name`
   - Should be: `use[A-Z]` pattern (ESLint behavior)
   - False positives: `userFetch`, `use_something`, etc.

2. **useCallback callbacks not checked** (`ppx.ml:270-288`)
   - `hooks_with_deps` includes useCallback
   - But callbacks aren't checked for nested hook calls
   - Should mirror useEffect/useMemo behavior

3. **Static dependencies not recognized**
   - `setState` from useState is stable
   - `useRef` result is stable
   - Should not warn when omitted from deps

4. **Duplicate dependencies not warned**
   - Same dep listed multiple times
   - ESLint warns about this

5. **Outer scope values not warned**
   - Module-level bindings in deps
   - Don't trigger re-renders

## Next Steps

1. Fix hook name detection to use `use[A-Z]` pattern
2. Add callback checking for useCallback (like useEffect)
3. Implement static dependency recognition
4. Add duplicate dependency detection
5. Add outer scope value detection
