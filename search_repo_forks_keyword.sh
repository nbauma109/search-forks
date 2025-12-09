#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# This script retrieves all forks of a specified GitHub repository,
# shallow-clones each repository, and searches commit messages
# for a user-specified keyword.
#
# Usage:
#   ./search_repo_forks_keyword.sh <keyword> <owner> <repository>
# ---------------------------------------------------------------------------

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <keyword> <owner> <repository>"
    exit 1
fi

SEARCH_TERM="$1"
OWNER="$2"
REPO="$3"

GITHUB_API="https://api.github.com"
FORKS_ENDPOINT="${GITHUB_API}/repos/${OWNER}/${REPO}/forks"

CLONE_ROOT="forks_${OWNER}_${REPO}"

mkdir -p "${CLONE_ROOT}"

list_all_forks() {
    page=1
    while true; do
        url="${FORKS_ENDPOINT}?per_page=100&page=${page}"
        echo "Retrieving page ${page} of forks..."

        response=$(curl -s "${url}")
        count=$(echo "${response}" | grep -c '"full_name"' || true)

        if [ "${count}" -eq 0 ]; then
            break
        fi

        echo "${response}" | \
            grep '"full_name"' | \
            sed 's/.*"full_name": "\(.*\)".*/\1/'

        page=$((page + 1))
        sleep 1
    done
}

clone_repository() {
    full_name="$1"
    clone_url="https://github.com/${full_name}.git"
    target="${CLONE_ROOT}/${full_name//\//_}"

    if [ -d "${target}" ]; then
        echo "${target}"
        return
    fi

    echo "Cloning ${full_name}..."
    if git clone --depth 50 "${clone_url}" "${target}" >/dev/null 2>&1; then
        echo "${target}"
    else
        echo ""
    fi
}

contains_keyword_commit() {
    repo_path="$1"
    if git -C "${repo_path}" log --all --grep="${SEARCH_TERM}" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

echo "Gathering list of forks for ${OWNER}/${REPO}..."
forks=$(list_all_forks)

echo "Total forks discovered: $(echo "${forks}" | wc -l)"

echo
echo "Searching commit messages for keyword: ${SEARCH_TERM}"
echo

while IFS= read -r fork; do
    [ -z "${fork}" ] && continue
    echo "Processing fork: ${fork}"

    repo_path=$(clone_repository "${fork}")
    if [ -z "${repo_path}" ]; then
        echo "Repository clone failed: ${fork}"
        continue
    fi

    if contains_keyword_commit "${repo_path}"; then
        echo ">>> Keyword found in commit messages: ${fork}"
    fi
done <<< "${forks}"

echo
echo "Search completed."
