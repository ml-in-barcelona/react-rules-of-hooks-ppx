React.useEffect2(
  () => {
    Document.addMouseDownEventListener(onClickHandler, document);
    Some(
      () => Document.removeMouseDownEventListener(onClickHandler, document),
    );
  },
  (onClick, outsideContainer.React.current),
);
