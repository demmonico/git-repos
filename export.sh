#!/usr/bin/env bash
#
# Script exports git repos
#
# @author demmonico <demmonico@gmail.com> <https://github.com/demmonico>
#
# @options
# -s|--source
# -d|--destination-repo
# -b|--destination-branch
#
# @usage ./export.sh [OPTIONS]
#
#######################################

RED='\033[0;31m'
NC='\033[0m' # No Color

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -s|--source)
            if [[ ! -z "$2" ]]; then
                FOLDER="$2"
            fi
            shift
            ;;
        -d|--destination-repo)
            if [[ ! -z "$2" ]]; then
                DESTINATION_REPO_URL="$2"
            fi
            shift
            ;;
        -b|--destination-branch)
            if [[ ! -z "$2" ]]; then
                DESTINATION_BRANCH="$2"
            fi
            shift
            ;;
        *)
            echo -e "${RED}Error:${NC} invalid option -$1"
            exit
            ;;
    esac
        shift
done

REQUIRED_PARAMS=("FOLDER" "DESTINATION_REPO_URL" "DESTINATION_BRANCH")
for param in "${!REQUIRED_PARAMS[@]}"; do
    if [[ -z "${!REQUIRED_PARAMS[param]}" ]]; then
        echo "${REQUIRED_PARAMS[param]} param is required"
        exit 1;
    fi
done

DESTINATION_REPO_NAME='storage'



if [ ! -d "${FOLDER}" ]; then
    echo -n "Skipped (no FOLDER)";
    exit
fi

cd ${FOLDER} && \
    git remote rm ${DESTINATION_REPO_NAME} > /dev/null 2>&1; \
    git remote add ${DESTINATION_REPO_NAME} ${DESTINATION_REPO_URL} && \
    FROM_BRANCH="$(git branch | grep \* | cut -d ' ' -f2)" && \
    if [ -n "${FROM_BRANCH}" ]; then \
        git push ${DESTINATION_REPO_NAME} ${FROM_BRANCH}:${DESTINATION_BRANCH} --quiet > /dev/null; \
        echo -n "Done";\
    else \
        echo -n "Skipped (empty FROM_BRANCH)";\
    fi && \
    cd - > /dev/null
