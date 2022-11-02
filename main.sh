#!/bin/bash

# User needs to supply a github personal access token here
gh_token=""
if [[ $gh_token == "" ]]; then
    echo "[ERROR]: Missing Github Personal Access Token. Exiting."
    exit 1
fi
gh_repo="packbackbooks/code-challenge-devops"
gh_api_prefix="https://api.github.com/repos"

tag1=$1
tag2=$2

gh_api () {
    url=$1
    curl -s --request GET \
    --url $url \
    --header "Accept: application/vnd.github+json" \
    --header "Authorization: Bearer $gh_token"
}

# get repo as a test
repo_homepage=$(gh_api "https://github.com/$gh_repo")

# get commits
repo_commits=$(gh_api "$gh_api_prefix/$gh_repo/commits")

# get git tags
repo_tags=$(gh_api "$gh_api_prefix/$gh_repo/tags")

# output vars to files for sanity check
# SANITY_CHECK echo "$repo_homepage" > ./repo_homepage
# SANITY_CHECK echo "$repo_commits" > ./repo_commits
# SANITY_CHECK echo "$repo_tags" > ./repo_tags

# get sha for input tags
tag1_sha=$(jq -r ' .[] | select( .name == "'v$tag1'" ) | .commit.sha ' <<< $repo_tags)
tag2_sha=$(jq -r ' .[] | select( .name == "'v$tag2'" ) | .commit.sha ' <<< $repo_tags)

# SANITY_CHECK echo "$tag1 sha: $tag1_sha"
# SANITY_CHECK echo "$tag2 sha: $tag2_sha"

# compare the two commits
tags_compare=$(gh_api "$gh_api_prefix/$gh_repo/compare/$tag1_sha...$tag2_sha")
echo "$tags_compare" >  ./tags_compare
commits=$(jq -c ' .commits ' <<< $tags_compare)
# SANITY_CHECK commits=$(jq -c ' .commits ' <<< $(cat ./commits))

# loop through the commits
while read -r i; do
    
    # check the commit message
    commit_message=$(jq -r ' .commit.message ' <<< $i)

    # skip if this is a merge or revert commit
    commit_message_pattern='^(Revert|Merge)'
    if [[ $commit_message =~ $commit_message_pattern ]]; then
        continue
    fi

    # check for pattern, e.g. PODC-123
    commit_message_pattern='^(POD[A-C]|MGMT)-[0-9]+ .+'
    if [[ $commit_message =~ $commit_message_pattern ]]; then
        commit_message_check="TRUE"
    else
        commit_message_check="FALSE"
    fi
    # SANITY_CHECK echo $commit_message_check

    # get the sha
    commit_sha=$(jq -r ' .sha ' <<< $i)
    # SANITY_CHECK echo ${commit_sha: -12}

    # get the username
    commit_username=$(jq -r ' .author.login ' <<< $i)
    # SANITY_CHECK echo $commit_username
    
    # output each result
    printf "${commit_sha: -12} $commit_message_check $commit_username\n"
done < <(jq -c -r ' .[] ' <<< $commits)
