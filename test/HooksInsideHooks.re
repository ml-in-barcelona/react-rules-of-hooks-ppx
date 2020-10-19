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
          ~onData=
            data =>
              switch (
                data##createCheckoutOrBillingPortalSession##checkoutSessionId,
                data##createCheckoutOrBillingPortalSession##billingPortalSessionUrl,
              ) {
              | (Some(checkoutSessionId), None) =>
                Stripe.redirectToCheckout(checkoutSessionId)
              | (None, Some(billingPortalSessionUrl)) =>
                Utils.setLocationUrl(billingPortalSessionUrl)
              | _ =>
                Js.Exn.raiseError(
                  "Exactly one of checkoutSessionId or billingPortalSessionUrl must be defined (not both)",
                )
              },
          (),
        )
      ->ignore;
    };
  };
};
