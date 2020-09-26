[@bs.val] external document: Js.t({..}) = "document";

ReactDOMRe.render(<Test randomProp="3" />, document##body);
