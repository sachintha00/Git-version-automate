#!/bin/bash

MAIN_COLOR="#2c7da0"
SECONDARY_COLOR="#a9d6e5"

header_style() {
    text=$1
    color=$2
    gum style --foreground "$color" --bold "$text"
}

header_center_style() {
    text=$1
    color=$2
    gum style --align center --margin "0 13" --padding "2 0" \
    --foreground \
    "$color" --bold "$text"
}

normal_style() {
    text=$1
    color=$2
    gum style --height=2 --foreground "$color" "$text"
}

special_style() {
    text=$1
    gum style --foreground "#E36D5D" "$text"
}

branch_name_style() {
    text=$1
    gum style --foreground "#E36D5D" "$text"
}

main_menu() {
    text=$1
    gum style --foreground "$MAIN_COLOR" "$text"
}

gum style \
	--foreground "#733C46" --border-foreground "$MAIN_COLOR" --border double \
	--align center --width 50 --margin "1 2" --padding "2 4" \
	"$(header_style "GIT Manager" "$MAIN_COLOR")" \
    "$(main_menu "Sachintha Madhawa")" \
    "$(main_menu "v1.5.0")"

NOW="$(date +'%B %d, %Y')"

spinner()
{
    local pid=$1
    local text=$2
    local delay=0.2
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c] %s  " "$spinstr" "$text"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
}

# ********************************************************************************************************
# ********************************************************************************************************
get_branch_name() {
    local branch_name
    while [[ -z "$branch_name" ]]; do
        read -p "Please enter a branch name: " branch_name
    done
    echo "$branch_name"
}

get_latest_tag() {
    # git ls-remote --tags origin | awk -F/ '{print $3}' | grep '^v' | sort -V | tail -n1
    git describe --tags --abbrev=0 --match "v*" origin
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

merge_and_release_tag() {
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

    local old_version=$(echo "$version_info" | awk '{print $6}')
    local new_version="$v_with_major.$v_minor.$v_patch"

    gum style \
	--foreground "#733C46" --border-foreground "$MAIN_COLOR" --border normal \
	--align left --margin "1 2" --padding "2 4" --width 50 \
    "$(header_center_style "Final Preview" "$MAIN_COLOR")" \
	"$(header_style "Old version: $(normal_style "$old_version" "#6c757d")" "#cccccc")" \
    "$(header_style "New version: $(normal_style "$new_version" "#ffd23f")" "#cccccc")" \

    local var=$(gum confirm \
    --prompt.foreground="#adb5bd" --selected.foreground="#000814" --unselected.foreground="#ffffff" \
    "Are you sure about this version?" && echo true || false)
    if [[ $var ]]; then
        git merge "$branch_name" --no-ff -m "$new_version"
        git push

        local var=$(gum confirm \
        --prompt.foreground="#adb5bd" --selected.foreground="#000814" --unselected.foreground="#ffffff" \
        "Do you want to release a version tag?" && echo true || false)
        if [[ $var ]]; then
            git tag $new_version
            git push origin $new_version
        fi
    fi
}

# ********************************************************************************************************
# ********************************************************************************************************

merge_to_dev() {
    if git branch --no-merged | grep -q -E '^( |\*) (do|fix)'; then
        echo "Choose $(header_style 'branches' "#E36D5D") to operate on:"
        local branch=$(gum choose --selected.foreground="$GIT_COLOR" --limit=1 $(git branch --no-merged | grep -E '^( |\*) (do|fix)'))

        # echo "Merge branch '$branch' into dev"
        
        if [[ "$branch" == "fix"* ]]; then
            git merge --no-ff -m "Merge branch '$branch' into dev"
            git push
        else
            git merge $branch
            git push
        fi
    fi
}

# ********************************************************************************************************
# ********************************************************************************************************

final_squash() {
    local ISSUE_COLOR=$5
    gum style \
	--foreground "#733C46" --border-foreground "$MAIN_COLOR" --border normal \
	--align left --margin "1 2" --padding "2 4" --width 50 \
    "$(header_center_style "Final Preview" "$MAIN_COLOR")" \
	"$(header_style "First commit hash:" "#cccccc")" "$(normal_style "$1" "#f1c0e8")" \
    "$(header_style "First commit:" "#cccccc")" "$(normal_style "$2" "#6c757d")" \
    "$(header_style "New commit:" "#cccccc")" "$(normal_style "$3" "#4361ee")" \
    "$(header_style "Issue type:" "#cccccc")" "$(normal_style "$4" "$ISSUE_COLOR")"

    local var=$(gum confirm \
    --prompt.foreground="#adb5bd" --selected.foreground="#000814" --unselected.foreground="#ffffff" \
    "Are you agree with that ?" && echo true || false)
    if [[ $var ]]; then
        git reset --soft $SHA
        git commit --amend -m "$ISSUE_MESSAGE_FORMAT"
        git push -f
    fi
}

squash() {
    local BRANCH_NAME=$brnach_name
    local issue_number=${BRANCH_NAME//[!0-9]/}
    local issue_branch=${BRANCH_NAME//[^a-zA-Z]/}

    if [[ "$BRANCH_NAME" == "do"* ]]; then
        SHA=$(git rev-list ^dev "$BRANCH_NAME" | tail -n 1) 
        MESSAGE=$(git log --format=%B -n 1 $SHA)
        ISSUE_MESSAGE_FORMAT=$(gum input --cursor.foreground="#b23a48" --width 70 --header.foreground="$MAIN_COLOR" --header="User your issue title" --value "#$issue_number Feat: " --placeholder="Type commit message...")
        final_squash "$SHA" "$MESSAGE" "$ISSUE_MESSAGE_FORMAT" "Enhancement" "#A3EEEF"
    elif [[ "$BRANCH_NAME" == "fix"* ]]; then
        SHA=$(git rev-list ^master "$BRANCH_NAME" | tail -n 1) 
        MESSAGE=$(git log --format=%B -n 1 $SHA)
        ISSUE_MESSAGE_FORMAT=$(gum input --cursor.foreground="#b23a48" --width 70 --header.foreground="$MAIN_COLOR" --header="User your issue title" --value "#$issue_number Fix: " --placeholder="Type commit message...")
        final_squash "$SHA" "$MESSAGE" "$ISSUE_MESSAGE_FORMAT" "Bug" "#D73B4A"
    else
        echo "Invalid branch name"
        exit 1
    fi 
}

add_changes() {
    # changes to be commited
    local BRANCH_NAME=$brnach_name
    local SUGGESTED_COMMIT="."
    local ISSUE_MESSAGE=$(gum input --cursor.foreground="#b23a48" --header.foreground="$MAIN_COLOR" \
    --header="Enter commit message [.]:" --placeholder="Type commit message...")

    if [ -z "$ISSUE_MESSAGE" ]; then
        ISSUE_MESSAGE=$SUGGESTED_COMMIT
    fi

    git add .
    git commit -am "$ISSUE_MESSAGE"
    if git show-ref --verify --quiet "refs/remotes/origin/$BRANCH_NAME"; then
        git push
    else
        git push --set-upstream origin $BRANCH_NAME
    fi
}

get_latest_temp_tag() {
    git ls-remote --tags origin | awk '{print $2}' | grep -E '^(refs/tags/temp-v)' | sed 's#refs/tags/##' | sort -V | tail -n 1
}

get_temp_version_info() {
    local latest_temp_tag=$(get_latest_temp_tag)
    if [[ -z "$latest_temp_tag" ]]; then
        latest_temp_tag="temp-v0.0.0"
    fi

    local v_with_major=$(echo "$latest_temp_tag" | cut -d'.' -f1)
    local v_minor=$(echo "$latest_temp_tag" | cut -d'.' -f2)
    local v_patch=$(echo "$latest_temp_tag" | cut -d'.' -f3)

    local v=$(echo "$v_with_major" | tr -dc '[:alpha:]')
    local v_major=$(echo "$v_with_major" | tr -dc '[:digit:]')

    echo "$v_with_major $v_minor $v_patch $v $v_major $latest_temp_tag"
}

release_temp_tag() {
    local BRANCH_NAME=$brnach_name
    local temp_version_info=$(get_temp_version_info)

    local temp_v_with_major=$(echo "$temp_version_info" | awk '{print $1}')
    local temp_v_minor=$(echo "$temp_version_info" | awk '{print $2}')
    local temp_v_patch=$(echo "$temp_version_info" | awk '{print $3}')
    local temp_v=$(echo "$temp_version_info" | awk '{print $4}')
    local temp_v_major=$(echo "$temp_version_info" | awk '{print $5}')

    if [[ "$BRANCH_NAME" == "do"* || "$BRANCH_NAME" == "dev" ]]; then
        temp_v_minor=$((temp_v_minor + 1))
        temp_v_patch=$((0))
    elif [[ "$BRANCH_NAME" == "fix"* ]]; then
        temp_v_patch=$((temp_v_patch + 1))
    else
        echo "Invalid branch name"
        exit 1
    fi

    old_temp_version=$(echo "$temp_version_info" | awk '{print $6}')
    new_temp_version="$temp_v_with_major.$temp_v_minor.$temp_v_patch"

    gum style \
	--foreground "#733C46" --border-foreground "$MAIN_COLOR" --border normal \
	--align left --margin "1 2" --padding "2 4" --width 50 \
    "$(header_center_style "Final Preview" "$MAIN_COLOR")" \
	"$(header_style "Old version: $(normal_style "$old_temp_version" "#6c757d")" "#cccccc")" \
    "$(header_style "New version: $(normal_style "$new_temp_version" "#ffd23f")" "#cccccc")" \

    local var=$(gum confirm \
    --prompt.foreground="#adb5bd" --selected.foreground="#000814" --unselected.foreground="#ffffff" \
    "Are you agree with that ?" && echo true || false)
    if [[ $var ]]; then
        git tag $new_temp_version
        git push origin $new_temp_version
    fi
}

# ********************************************************************************************************
# ********************************************************************************************************

master_branch() {
    items=("1.Merge & Release Tag" "2.Only Tag Push" "3.Exit")

    choose=$(gum choose --cursor.foreground="$SECONDARY_COLOR" --item.foreground="$MAIN_COLOR" "${items[@]}")

    if [ "${choose%%.*}" = "1" ]; then
        merge_and_release_tag
    elif [ "${choose%%.*}" = "2" ]; then
        echo "Only Tag Push"
    else
        exit 0
    fi
}

dev_branch() {
    items=("1.Merge" "2.Release Temp Tag" "3.Fetch Updates" "4.Exit")

    choose=$(gum choose --cursor.foreground="$SECONDARY_COLOR" --item.foreground="$MAIN_COLOR" "${items[@]}")

    if [ "${choose%%.*}" = "1" ]; then
        merge_to_dev
    elif [ "${choose%%.*}" = "2" ]; then
        release_temp_tag
    elif [ "${choose%%.*}" = "3" ]; then
        echo "Fetch Updates"
    else
        exit 0
    fi
}

do_fix_branch() {
    items=("1.Changes Add" "2.Squash" "3.Release Temp Tag" "4.Exit")

    choose=$(gum choose --cursor.foreground="$SECONDARY_COLOR" --item.foreground="$MAIN_COLOR" "${items[@]}")

    if [ "${choose%%.*}" = "1" ]; then
        add_changes
    elif [ "${choose%%.*}" = "2" ]; then
        squash
    elif [ "${choose%%.*}" = "3" ]; then
        release_temp_tag
    else
        exit 0
    fi
}

get_selected_branch() {
   git rev-parse --abbrev-ref HEAD
}

brnach_name=$(get_selected_branch)

if [[ "$brnach_name" == "master" ]]; then
    master_branch
elif [[ "$brnach_name" == "dev" ]]; then
    dev_branch
elif [[ "$brnach_name" == "do"* || "$brnach_name" == "fix"* ]]; then
    do_fix_branch
else
    echo "Invalid branch name"
    exit 1
fi

# ********************************************************************************************************
# ********************************************************************************************************