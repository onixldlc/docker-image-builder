#!/bin/bash


CRED_PATH=".docker/config.json"

if [ -f "/root/${CRED_PATH}" ]; then
    echo "docker for \`root\` found!"
    CRED_PATH="/root/${CRED_PATH}"
elif [ -f "${HOME}/${CRED_PATH}" ]; then
    echo "docker for \`${USER}\` found!"
    CRED_PATH="${HOME}/${CRED_PATH}"
else
    echo "no docker login found!"
    echo "re-run the script after logging in with \`docker login\`"
    echo "exiting..."
    exit 1
fi

CREDS_BASE64="$(cat "${CRED_PATH}" | jq -r '.[] | .[].auth')"
CREDS="$(echo "$CREDS_BASE64" | base64 -d)"
PAT="$(echo "${CREDS#*:}")"
USERNAME="$(echo "${CREDS%:*}")"

PROJECT_NAME="project123"
VERSION_TAG="1.15.2"
PROD_BUILD_PATH="./docker"

if [[ -z "${1}" || -z "${2}" ]]; then
    echo "no project_name or version_tag specified!"
    echo "example usage: "
    echo "${0} {project_name} {version_tag} [prod_build_path]"
    echo "${0} project123 1.15.2 ./docker"
    echo "${0} project123 250409 ./docker/prod"
    echo "${0} project123 20250409 ./build/prod"
    echo ""
    echo "exiting..."
    exit 1
else
    echo "project_name & version_tag specified!"
    echo "using: \`${1}\` as project_name"
    echo "using: \`${2}\` as version_tag"
fi

if [[ -z "${3}" ]]; then
    echo "warning! prod built path is empty!"
    echo "using \`${PROD_BUILD_PATH}\` as prod_build_path"
else
    echo "prod_build_path found!"
    echo "using \`${3}\` as prod_build_path"
fi

PROJECT_NAME="${1:-"${PROJECT_NAME}"}"
VERSION_TAG="${2:-"${ADDTION_TAG}"}"
PROD_BUILD_PATH="${3:-"${PROD_BUILD_PATH}"}"
BASE_TAG_NAME="${USERNAME}/${PROJECT_NAME}"
RELATIVE_PATH="../${PROJECT_NAME}/"
DOCKER_AUTH_URL="https://auth.docker.io/token?service=registry.docker.io&scope=repository:${USERNAME}/${PROJECT_NAME}:pull"

function build_base(){
    echo "building: ${BASE_TAG_NAME}:base-${VERSION_TAG}"
    docker build \
        -t "${BASE_TAG_NAME}:base-$VERSION_TAG" \
        -t "${BASE_TAG_NAME}:base" \
        .
}

function push_base(){
    docker push "${BASE_TAG_NAME}:base-$VERSION_TAG"
    docker push "${BASE_TAG_NAME}:base"
}

function build_prod(){
    docker build \
        -t "${BASE_TAG_NAME}:$VERSION_TAG" \
        -t "${BASE_TAG_NAME}:latest" \
        "${PROD_BUILD_PATH}"
}

function push_prod(){
    docker push "${BASE_TAG_NAME}:$VERSION_TAG"
    docker push "${BASE_TAG_NAME}:latest"
}

function prune_build(){
                docker builder prune -af
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"


if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

RES="$( curl -sH "Authorization: Basic ${CREDS_BASE64}" "${DOCKER_AUTH_URL}" | jq -r ".details" )"
if [ -z "$RES" ]; then
    echo "error whilst sending request to auth.docker.io"
    exit 1
elif [ "$RES" != "null" ]; then
    echo "${RES}"
    exit 1
elif [ "$RES" == "null" ]; then
    echo "PAT still active!"
fi


if [ -d "${RELATIVE_PATH}" ]; then
    echo "${RELATIVE_PATH} exist!"
else
    echo "${RELATIVE_PATH} doesn't exist! existing..."
fi


if [ "basename $(pwd)" != "${PROJECT_NAME}" ]; then
    cd ../${PROJECT_NAME}/
fi

echo "building and pushing base image for ${BASE_TAG_NAME}"
build_base && push_base && prune_build

echo "building and pushing prod image for ${BASE_TAG_NAME}"
build_prod && push_prod && prune_build


