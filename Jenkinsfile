#!/usr/bin/env groovy

REPOSITORY = 'govuk-dns'

node ("terraform-0.8.1") {
  def govuk = load '/var/lib/jenkins/groovy_scripts/govuk_jenkinslib.groovy'

  try {
    stage ("Checkout") {
      govuk.checkoutFromGitHubWithSSH(REPOSITORY)
    }

    stage ("Bundle Install") {
      govuk.bundleApp()
    }

    stage ("RSpec") {
      govuk.runRakeTask('rspec')
    }

  }
  catch (e) {
    currentBuild.result = "FAILED"
    step([$class: 'Mailer',
          notifyEveryUnstableBuild: true,
          recipients: 'govuk-ci-notifications@digital.cabinet-office.gov.uk',
          sendToIndividuals: true])
    throw e
  }

  // Wipe the workspace
  deleteDir()
}
