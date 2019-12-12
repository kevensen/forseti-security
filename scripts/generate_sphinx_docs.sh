#!/bin/bash
# Copyright 2018 The Forseti Security Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Build our Python documentation from source files with Sphinx and then insert
# the generated documentation files into the appropriate path for use by Jekyll
# when building our website

BUILD_FROM_PYTHON_SOURCE_BRANCH="${1:-master}"
readonly BUILD_FROM_PYTHON_SOURCE_BRANCH


#######################################
# Generate the API reference doc from
# Python docstrings with Sphinx; the
# generated docs are baked into the
# Docker image once the build is
# finished.
#######################################
function generate_sphinx_docs_in_docker() {
    docker build \
      --build-arg BUILD_FROM_PYTHON_SOURCE_BRANCH=$BUILD_FROM_PYTHON_SOURCE_BRANCH \
      -t forseti/generate_sphinx_docs \
      -f scripts/docker/generate_sphinx_docs.Dockerfile ./scripts/docker
}

function copy_sphinx_docs_into_jekyll_docs() {
    # The docs have been baked into the image with docker-build; now we just
    # to copy the generated docs over from a live container
    local container_id
    container_id="$(docker create forseti/generate_sphinx_docs)"

    # Remove the old generated Sphinx docs
    rm -rf _docs/_latest/develop/reference

    # Copy generated docs from container into Jekyll
    docker cp \
      "${container_id}":/opt/forseti-security/build/sphinx/html/. \
      _docs/_latest/develop/reference

    docker rm "${container_id}"
}

function main() {
    generate_sphinx_docs_in_docker
    copy_sphinx_docs_into_jekyll_docs
}

main "$@"
