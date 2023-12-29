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

changed_files_style() {
    files=$1
    color=$2
    status=$3

    readarray -t files_array <<<"$files"
    file_count=${#files_array[@]}

    for file in "${files_array[@]}"; do
        gum style --align left --width 50 --margin "0 2" --foreground "$color" \
            "$([[ -n "$status" ]] && echo $status: $file || echo $file)"
    done
    echo " "
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

spinner() {
    local pid=$1
    local text=$2
    local delay=0.2
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local beta=${spinstr#?}
        printf " [%c] %s  " "$spinstr" "$text"
        local spinstr=$beta${spinstr%"$beta"}
        sleep $delay
        printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b"
}

# ********************************************************************************************************
# ********************************************************************************************************

get_latest_tag() {
    # git ls-remote --tags origin | awk -F/ '{print $3}' | grep '^v' | sort -V | tail -n1
    # git describe --tags --abbrev=0 --match "v*" origin
    # git log origin/master -n 1 --pretty=format:%s
    git ls-remote --tags origin | awk '{print $2}' | grep -E '^(refs/tags/v)' | sed 's#refs/tags/##' | sort -V | tail -n 1
}

get_version_info() {
    local latest_tag=$(get_latest_tag)
    if [[ -z "$latest_tag" ]]; then
        latest_tag="v1.0.0"
    fi

    local v_with_major=$(echo "$latest_tag" | cut -d'.' -f1)
    local v_minor=$(echo "$latest_tag" | cut -d'.' -f2)
    local v_patch=$(echo "$latest_tag" | cut -d'.' -f3)

    local v=$(echo "$v_with_major" | tr -dc '[:alpha:]')
    local v_major=$(echo "$v_with_major" | tr -dc '[:digit:]')

    echo "$v_with_major $v_minor $v_patch $v $v_major $latest_tag"
}

merge_and_release_tag() {
    local branch_name
    if git branch --no-merged | grep -q -E '^( |\*) (dev|fix)'; then
        echo "Choose $(header_style 'branches' "#E36D5D") to operate on:"
        branch_name=$(gum choose --selected.foreground="$GIT_COLOR" --limit=1 $(git branch --no-merged | grep -E '^( |\*) (dev|fix)'))
    fi
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
        "$(header_style "New version: $(normal_style "$new_version" "#ffd23f")" "#cccccc")"

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

        if [[ "$branch" == "fix"* ]]; then
            git merge --no-ff "$branch" -m "Merge branch '$branch' into dev"
            git push
        else
            git merge $branch
            git push
        fi
        git branch --delete "$branch" && git push origin --delete "$branch"
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
    local git_status=$(git status --porcelain)
    local untracked_files="$(git ls-files --others --exclude-standard)"
    local modified_file="$(git ls-files -m)"
    local staged_changes="$(git diff --cached --name-only)"

    local untracked_count=$(echo "$untracked_files" | wc -l)
    local modified_count=$(echo "$modified_file" | wc -l)
    local staged_count=$(echo "$staged_changes" | wc -l)

    gum style \
        --foreground "#733C46" --border-foreground "$MAIN_COLOR" --border normal \
        --align left --margin "1 2" --padding "2 4" --width 50 \
        "$(header_center_style "On branch $brnach_name" "$MAIN_COLOR")" \
        "$([[ -z "$staged_changes" ]] || header_style "Changes to be committed ($staged_count):" "#cccccc")" \
        "$([[ -z "$staged_changes" ]] || changed_files_style "$staged_changes" "#1F8A70" "modified:")" \
        "$([[ -z "$modified_file" ]] || header_style "Changes not staged for commit ($modified_count):" "#cccccc")" \
        "$([[ -z "$modified_file" ]] || changed_files_style "$modified_file" "#C21010" "modified")" \
        "$([[ -z "$untracked_files" ]] || header_style "Untracked files ($untracked_count):" "#cccccc")" \
        "$([[ -z "$untracked_files" ]] || changed_files_style "$untracked_files" "#C21010")"

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

get_latest_beta_tag() {
    git ls-remote --tags origin | awk '{print $2}' | grep -E '^(refs/tags/beta-v)' | sed 's#refs/tags/##' | sort -V | tail -n 1
}

get_beta_version_info() {
    local latest_beta_tag=$(get_latest_beta_tag)
    if [[ -z "$latest_beta_tag" ]]; then
        latest_beta_tag="beta-v1.0.0"
    fi

    local v_with_major=$(echo "$latest_beta_tag" | cut -d'.' -f1)
    local v_minor=$(echo "$latest_beta_tag" | cut -d'.' -f2)
    local v_patch=$(echo "$latest_beta_tag" | cut -d'.' -f3)

    local v=$(echo "$v_with_major" | tr -dc '[:alpha:]')
    local v_major=$(echo "$v_with_major" | tr -dc '[:digit:]')

    echo "$v_with_major $v_minor $v_patch $v $v_major $latest_beta_tag"
}

release_beta_tag() {
    local BRANCH_NAME=$brnach_name
    local beta_version_info=$(get_beta_version_info)

    local beta_v_with_major=$(echo "$beta_version_info" | awk '{print $1}')
    local beta_v_minor=$(echo "$beta_version_info" | awk '{print $2}')
    local beta_v_patch=$(echo "$beta_version_info" | awk '{print $3}')
    local beta_v=$(echo "$beta_version_info" | awk '{print $4}')
    local beta_v_major=$(echo "$beta_version_info" | awk '{print $5}')

    if [[ "$BRANCH_NAME" == "do"* || "$BRANCH_NAME" == "dev" ]]; then
        beta_v_minor=$((beta_v_minor + 1))
        beta_v_patch=$((0))
    elif [[ "$BRANCH_NAME" == "fix"* ]]; then
        beta_v_patch=$((beta_v_patch + 1))
    else
        echo "Invalid branch name"
        exit 1
    fi

    old_beta_version=$(echo "$beta_version_info" | awk '{print $6}')
    new_beta_version="$beta_v_with_major.$beta_v_minor.$beta_v_patch"

    gum style \
        --foreground "#733C46" --border-foreground "$MAIN_COLOR" --border normal \
        --align left --margin "1 2" --padding "2 4" --width 50 \
        "$(header_center_style "Final Preview" "$MAIN_COLOR")" \
        "$(header_style "Old version: $(normal_style "$old_beta_version" "#6c757d")" "#cccccc")" \
        "$(header_style "New version: $(normal_style "$new_beta_version" "#ffd23f")" "#cccccc")"

    local var=$(gum confirm \
        --prompt.foreground="#adb5bd" --selected.foreground="#000814" --unselected.foreground="#ffffff" \
        "Are you agree with that ?" && echo true || false)
    if [[ $var ]]; then
        git tag $new_beta_version
        git push origin $new_beta_version
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
    items=("1.Merge" "2.Release beta Tag" "3.Fetch Updates" "4.Exit")

    choose=$(gum choose --cursor.foreground="$SECONDARY_COLOR" --item.foreground="$MAIN_COLOR" "${items[@]}")

    if [ "${choose%%.*}" = "1" ]; then
        merge_to_dev
    elif [ "${choose%%.*}" = "2" ]; then
        release_beta_tag
    elif [ "${choose%%.*}" = "3" ]; then
        echo "Fetch Updates"
    else
        exit 0
    fi
}

do_fix_branch() {
    items=("1.Changes Add" "2.Squash" "3.Release beta Tag" "4.Exit")

    choose=$(gum choose --cursor.foreground="$SECONDARY_COLOR" --item.foreground="$MAIN_COLOR" "${items[@]}")

    if [ "${choose%%.*}" = "1" ]; then
        add_changes
    elif [ "${choose%%.*}" = "2" ]; then
        squash
    elif [ "${choose%%.*}" = "3" ]; then
        release_beta_tag
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
