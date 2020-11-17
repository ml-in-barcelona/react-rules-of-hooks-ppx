module GQL = {
  let useMutation =
      (~redirectSuccess=None, ~redirectCancel=None, ~onboarding=false, ()) => {
    let (mutation, _, _) = ApolloHooks.useMutation(~variables, definition);

    () => {
      mutation()
      ->Utils.Promise.map(fst)
      ->Utils.Apollo.Mutation.trackResult(
          ~analyticsMessage=
            onboarding ? "Clicked Pro Plan" : "Clicked Manage Billing",
        )
      ->ignore;
    };
  };
};
