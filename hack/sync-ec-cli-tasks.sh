#!/usr/bin/env bash
# Copyright 2023 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

# Use this script to sync the task definitions with the task definitions
# found in the enterprise-contract/ec-cli repository.
# Usage:
#   sync-ec-cli-tasks.sh <PATH_TO_EC_CLI_REPO>

set -o errexit
set -o pipefail
set -o nounset

EC_CLI_REPO_PATH="${1}"
RELEASE_PREFIX="release-v"

# helper function to add tasks to a git branch
add_tasks() {
  local remote_branch=${1}
  local branch=$(echo "$remote_branch" | cut -d'/' -f2)
  pushd "${EC_CLI_REPO_PATH}" > /dev/null
  git checkout "${branch}"
  popd > /dev/null
  git checkout -B "${branch}" --track "${remote_branch}"
  cp -r "${EC_CLI_REPO_PATH}/tasks" .
  diff="$(git diff)"
  if [[ -z "${diff}" ]]; then
      echo "No changes to sync"
      exit
  fi

  git add tasks
  git commit -m "sync ec-cli task definitions"
  git push origin "${branch}"
}

# collect remote branches in a repo returning just the branch name
collect_remotes() {
  echo "$(git branch -r | grep "origin/${RELEASE_PREFIX}" | sed "s|origin/||" | tr -d ' ')"
}

tekton_catalog_branches=$(collect_remotes)
pushd "${EC_CLI_REPO_PATH}" > /dev/null
ec_cli_branches=$(collect_remotes)
popd > /dev/null

# now sync the release branches from ec-cli
if [ -n "$ec_cli_branches" ]; then
  while IFS= read -r branch; do
    if ! echo "$tekton_catalog_branches" | grep -Fxq "$branch"; then
      add_tasks "origin/main"
    else
      add_tasks "origin/${branch}"
    fi
  done <<< "$ec_cli_branches"
else
  echo "No release branch to process."
fi

# sync the main branch
add_tasks "origin/main"
