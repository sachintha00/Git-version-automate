#!/bin/bash

NOW="$(date +'%B %d, %Y')"
RED="\033[1;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
PURPLE="\033[1;35m"
CYAN="\033[1;36m"
WHITE="\033[1;37m"
RESET="\033[0m"
QUESTION_FLAG="${GREEN}?"
WARNING_FLAG="${YELLOW}!"
NOTICE_FLAG="${CYAN}❯"

get_branch_name() {
    local branch_name
    while [[ -z "$branch_name" ]]; do
        read -p "Please enter a branch name: " branch_name
    done
    echo "$branch_name"
}

get_latest_tag() {
    # git fetch --tags > /dev/null 2>&1
    # git describe --tags --abbrev=0 2> /dev/null
    # git describe --tags $(git rev-list --tags --max-count=1)
    git log --grep='^v.*' -1 --pretty=format:"%s"
}

get_version_info() {
    local latest_tag=$(get_latest_tag)
    if [[ -z "$latest_tag" ]]; then
        latest_tag="v0.0.0"
    fi

    local v_with_major=$(echo "$latest_tag" | cut -d'.' -f1)
    local v_minor=$(echo "$latest_tag" | cut -d'.' -f2)
    local v_patch=$(echo "$latest_tag" | cut -d'.' -f3)

    local v=$(echo "$v_with_major" | tr -dc '[:alpha:]')
    local v_major=$(echo "$v_with_major" | tr -dc '[:digit:]')

    echo "$v_with_major $v_minor $v_patch $v $v_major $latest_tag"
}

branch_name=$(get_branch_name "$1")
version_info=$(get_version_info)

v_with_major=$(echo "$version_info" | awk '{print $1}')
v_minor=$(echo "$version_info" | awk '{print $2}')
v_patch=$(echo "$version_info" | awk '{print $3}')
v=$(echo "$version_info" | awk '{print $4}')
v_major=$(echo "$version_info" | awk '{print $5}')

if [[ "$branch_name" == "dev"* ]]; then
    v_minor=$((v_minor + 1))
    v_patch=$((0))
elif [[ "$branch_name" == "fix"* ]]; then
    v_patch=$((v_patch + 1))
else
    echo "Invalid branch name"
    exit 1
fi

old_version=$(echo "$version_info" | awk '{print $6}')
new_version="$v_with_major.$v_minor.$v_patch"

echo "Old version: $old_version"
echo "New version: $new_version"

echo -ne "${QUESTION_FLAG} ${CYAN}Are you sure about this version? [${WHITE}y${CYAN}]: "
read RESPONSE
if [ "$RESPONSE" = "" ]; then RESPONSE="y"; fi
if [ "$RESPONSE" = "Y" ]; then RESPONSE="y"; fi
if [ "$RESPONSE" = "Yes" ]; then RESPONSE="y"; fi
if [ "$RESPONSE" = "yes" ]; then RESPONSE="y"; fi
if [ "$RESPONSE" = "YES" ]; then RESPONSE="y"; fi
if [ "$RESPONSE" = "y" ]; then
    git merge "$branch_name" --no-ff -m "$new_version"
    git push
    echo -ne "${QUESTION_FLAG} ${CYAN}Do you want to release a version tag? [${WHITE}y${CYAN}]: "
    read RESPONSE
    if [ "$RESPONSE" = "" ]; then RESPONSE="y"; fi
    if [ "$RESPONSE" = "Y" ]; then RESPONSE="y"; fi
    if [ "$RESPONSE" = "Yes" ]; then RESPONSE="y"; fi
    if [ "$RESPONSE" = "yes" ]; then RESPONSE="y"; fi
    if [ "$RESPONSE" = "YES" ]; then RESPONSE="y"; fi
    if [ "$RESPONSE" = "y" ]; then
        git tag $new_version
        git push origin $new_version
    fi
fi
