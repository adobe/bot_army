%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "web/", "apps/"],
        excluded: []
      },
      checks: [
        # don't fail on TODOs in code
        {Credo.Check.Design.TagTODO, exit_status: 0},
        # because correctly ordered logging is critical to analyzing the logs, don't fail here
        {Credo.Check.Warning.LazyLogging, exit_status: 0}
      ]
    }
  ]
}
