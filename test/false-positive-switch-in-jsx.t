  $ cat > input.mlx << 'EOF'
  > let[@react.component] make ~route ~profile ~org =
  >   let currentRoute = Route.useUrl () |> Route.ofUrl in
  >   let sidebar = <Sidebar currentRoute org /> in
  >   let page = match route with
  >     | General -> <Profile.ProfileGeneralPage profile />
  >     | Security -> <Profile.ProfileSecurityPage />
  >     | API -> <Profile.ProfileApiPage />
  >   in
  >   <DashboardTemplate sidebar>
  >     {page}
  >   </DashboardTemplate>
  > EOF

Hook at top level with switch inside JSX for conditional rendering should be valid
  $ mlx-pp -print-ml input.mlx > input.ml

  $ ../src/standalone.exe input.ml
  let make ~route ~profile ~org =
    let currentRoute = (Route.useUrl ()) |> Route.ofUrl in
    let sidebar = ((Sidebar.createElement () ~children:[] ~currentRoute ~org)
      [@JSX ]) in
    let page =
      match route with
      | General ->
          ((Profile.ProfileGeneralPage.createElement () ~children:[] ~profile)
          [@JSX ])
      | Security ->
          ((Profile.ProfileSecurityPage.createElement () ~children:[])[@JSX ])
      | API -> ((Profile.ProfileApiPage.createElement () ~children:[])[@JSX ]) in
    ((DashboardTemplate.createElement () ~children:[{ page }] ~sidebar)
      [@JSX ])[@@react.component ]
