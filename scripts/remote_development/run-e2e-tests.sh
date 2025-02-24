#!/usr/bin/env zsh

# frozen_string_literal: true

# This is a convenience script to run the Remote Development category E2E spec(s) against a local
# GDK environment. It sets default values for the necessary environment variables, but allows
# them to be overridden.
#
# For details on how to run this, see the documentation comments at the top of
# qa/qa/specs/features/ee/browser_ui/3_create/remote_development/create_new_workspace_and_terminate_spec.rb

DEFAULT_PASSWORD='5iveL!fe'

export WEBDRIVER_HEADLESS="${WEBDRIVER_HEADLESS:-0}"
export QA_SUPER_SIDEBAR_ENABLED="${QA_SUPER_SIDEBAR_ENABLED:-1}" # This is currently necessary for the test to pass
export GITLAB_USERNAME="${GITLAB_USERNAME:-root}"
export GITLAB_PASSWORD="${GITLAB_PASSWORD:-${DEFAULT_PASSWORD}}"
export DEVFILE_PROJECT="${DEVFILE_PROJECT:-Gitlab Org / Gitlab Shell}"
export AGENT_NAME="${AGENT_NAME:-remotedev}"
export TEST_INSTANCE_URL="${TEST_INSTANCE_URL:-http://gdk.test:3000}"

echo "WEBDRIVER_HEADLESS: ${WEBDRIVER_HEADLESS}"
echo "QA_SUPER_SIDEBAR_ENABLED: ${QA_SUPER_SIDEBAR_ENABLED}"
echo "GITLAB_USERNAME: ${GITLAB_USERNAME}"
echo "DEVFILE_PROJECT: ${AGENT_NAME}"
echo "AGENT_NAME: ${AGENT_NAME}"
echo "TEST_INSTANCE_URL: ${TEST_INSTANCE_URL}"

working_directory="$(git rev-parse --show-toplevel)/qa"

# TODO: https://gitlab.com/gitlab-org/gitlab/-/issues/397005
#       Remove the '--tag quarantine' from below once this test is removed from quarantine
(cd "$working_directory" && \
  bundle && \
  bundle exec bin/qa Test::Instance::All "$TEST_INSTANCE_URL" -- \
  --tag quarantine qa/specs/features/ee/browser_ui/3_create/remote_development)
