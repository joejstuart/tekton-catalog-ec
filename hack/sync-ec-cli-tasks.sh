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

cp -r "${EC_CLI_REPO_PATH}/tasks" .

pushd tasks > /dev/null

images="$(grep -r -h -o -w 'quay.io/enterprise-contract/ec-cli:.*' | grep -v '@' | sort -u)"

for image in $images; do
    echo "Resolving image $image"
    digest="$(skopeo manifest-digest <(skopeo inspect --raw "docker://${image}"))"
    pinned_image="${image}@${digest}"
    echo "↳ ${pinned_image}"
    find . -type f -exec sed -i "s!${image}!${pinned_image}!g" {} +
done

popd > /dev/null

diff="$(git diff)"
if [[ -z "${diff}" ]]; then
    echo "No changes to sync"
    exit
fi
echo "${diff}"

if [ -n "${GITHUB_ACTIONS:-}" ]; then
  git config --global user.email "${GITHUB_ACTOR}@users.noreply.github.com"
  git config --global user.name "${GITHUB_ACTOR}"
  mkdir -p "${HOME}/.ssh"
  echo "${DEPLOY_KEY}" > "${HOME}/.ssh/id_ed25519"
  chmod 600 "${HOME}/.ssh/id_ed25519"
  trap 'rm -rf "${HOME}/.ssh/id_rsa"' EXIT
fi

git add tasks
git commit -m "sync ec-cli task definitions"
git push
