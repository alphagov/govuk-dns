#!/usr/bin/env groovy

library("govuk")

node ("terraform") {
  govuk.buildProject(
    sassLint: false,
    rubyLintDiff: false,
    skipDeployToIntegration: true,
  )
}
