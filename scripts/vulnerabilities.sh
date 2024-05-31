#!/bin/zsh
#
# A script for checking possible vulnerabilities in a given org on GitHub. Outputs only critical vulnerabilities to avoid verbosity
# usage: ./vulnerabilities.sh <name_of_org>
#
# requirements: 
# - zsh (or possibly bash minimum version 4)
# - GitHub CLI (https://cli.github.com/)
# - OpenSSF Scorecard standalone (https://github.com/ossf/scorecard)
# - jq (https://jqlang.github.io/jq/)
#
if [ -z "$1" ]; then
    echo "Need to provide the name of an organization"
    exit -1
fi
repos=($(gh repo list $1 --limit 500 --json name --jq '.[].name'))
typeset -A dictionary 
echo "Found ${#repos[@]} $1 repos"
critical_count_tot=0
for repo in $repos; do
    echo "\nChecking $repo"
    vulnerabilities=($(scorecard --checks=Vulnerabilities --show-details --format=json --repo=github.com/$1/$repo | jq 'select(.checks.[].details != null).checks.[].details.[]' | grep -oE -e "GHSA-[^ \"]*"))
    critical_count=0
    for vulnerability in $vulnerabilities; do
        json=($(gh api --method GET -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" /advisories -F ghsa_id="$vulnerability" --jq ".[].severity,if .[].cvss.score != null then .[].cvss.score else 0 end,.[].html_url"))
        severity=$json[1]
        if [[ $severity == "critical" ]]; then
            critical_count=$((critical_count+1))            
            critical_count_tot=$((critical_count_tot+1))
            score=$json[2]
            url=$json[3]
            echo "$url $severity $score"
            if [[ -v dictionary[$url] ]]; then
                num=${dictionary[$url]}
                dictionary[$url]=$((num+1))
            else
                dictionary[$url]=1
            fi
        fi
    done
    echo "Number of critical vulnerabilities in $repo: $critical_count"
done
echo "\n---SUMMARY---"
if [[ $critical_count_tot>0 ]]; then
    echo "Number of total critical vulnerabilities found in $1: $critical_count_tot" 
    for key val in "${(@kv)dictionary}"; do
        foo="occurrences"
        if [[ $val == 1 ]]; then
            foo="occurrence"
        fi
        echo "$key : $val $foo"
    done
else
    echo "No critical vulnerabilities found"
fi
