#!/usr/bin/env bash
#
# Script syncs git repos, optionally including fetching repos list, import and export all repos to single storage repo (as a branches)
#
# @author demmonico <demmonico@gmail.com> <https://github.com/demmonico>
#
# @flags
# -f|--fetch-repos
# -i|--import-repos
# -e|--export-repos
#
# @options
# -c|--config-file
# --repos-file
# --export-repo-url
#
# @usage ./export.sh [FLAGS|OPTIONS]
#
# @example Fetch all available repos to list provided at .env file
# ./sync.sh -c sync_config.env -f
#
# @example Import all available repos to folder having .env file
# ./sync.sh -c sync_config.env -i
#
# @example Export all available repos to storage repo provided at .env file or passing by arg
# ./sync.sh -c sync_config.env -e
#
# @example Fetch, import and export all available repos to folder and then to storage repo provided at .env file
# ./sync.sh -c sync_config.env -f -i -e
#
#######################################

# set colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

### get arguments
while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -f|--fetch-repos) isNeedFetchRepos='true';;
        -i|--import-repos) isNeedImportRepos='true';;
        -e|--export-repos) isNeedExportRepos='true';;
        -c|--config-file)
            if [ ! -z "$2" ]; then
                FILE_CONFIG="$( name="$( basename "$2" )"; dir="$( cd "$( dirname "$2" )" && pwd )"; echo "${dir}/${name}" )"
            fi
            shift
            ;;
        --repos-file)
            if [ ! -z "$2" ]; then
                CONFIG_REPOS_FILE="$2"
            fi
            shift
            ;;
        --export-repo-url)
            if [ ! -z "$2" ]; then
                CONFIG_EXPORT_REPO_URL="$2"
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
if [ -z "${FILE_CONFIG}" ]; then
    echo -e "${RED}Error:${NC} option '-c|--config-file' is required"
    exit
fi

_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# config
echo -e "Reading file config '${YELLOW}${FILE_CONFIG}${NC}' ... "
# configs from .env file overrides CLI one
export $( cat ${FILE_CONFIG} | xargs )

# repo list file
if [ -z "${CONFIG_REPOS_FILE}" ]; then
    echo -e "${RED}Error:${NC} CONFIG_REPOS_FILE variable or '--repos-file' option is required"
    exit
fi
REPOS_FOLDER="$( dirname "${FILE_CONFIG}" )"
REPOS_FILE="${REPOS_FOLDER}/${CONFIG_REPOS_FILE}"


#####

# fetch repos list
echo -n "Fetching repos list ... "
if [ ! -z "${isNeedFetchRepos}" ]; then
    REQUIRED_PARAMS=("CONFIG_REPO_URL" "CONFIG_REPO_FIELDS")
    for param in "${!REQUIRED_PARAMS[@]}"; do
        if [[ -z "${!REQUIRED_PARAMS[param]}" ]]; then
            echo "${REQUIRED_PARAMS[param]} param is required"
            exit 1;
        fi
    done
    echo ""
    echo -e " >>> Repo URL: '${YELLOW}${CONFIG_REPO_URL}${NC}'"
    echo -e " >>> Repo fields: '${YELLOW}${CONFIG_REPO_FIELDS}${NC}'"
    echo -e " >>> Repo list file: '${YELLOW}${REPOS_FILE}${NC}'"
    php ${_DIR}/fetch_repo_list.php ${CONFIG_REPO_URL} ${CONFIG_REPO_FIELDS} > ${REPOS_FILE}
    echo "Done. $(cat ${REPOS_FILE} | wc -l ) lines"
else
    echo "Skipping"
fi

# import repos
echo -e "Importing repos from list '${YELLOW}${REPOS_FILE}${NC}' to folder '${YELLOW}${REPOS_FOLDER}${NC}' ... "
if [ -n "${isNeedImportRepos}" ]; then
    # re-read SSH keys for term session
    echo "Re-reading OpenSSH keys for TERM session ... "
    # TODO add some automation here
    ssh-add -K ~/.ssh/id_rsa
    # import
    cat ${REPOS_FILE} | \
        sed "s,^,${REPOS_FOLDER} ,g" | \
        xargs -n3 bash -c $' \
            SUBFOLDER="$(echo $@ | awk \'{print $2}\')"; \
            FOLDER="$(echo $@ | awk \'{print $1 "/" $2}\')"; \
            URL=$(echo $@ | awk \'{print $3}\'); \
            echo " > Repo ${URL} >>> ${SUBFOLDER}"; \
            if [ -d "$FOLDER" ]; then \
                echo -n " >>> Updating ... "; \
                cd $FOLDER; \
                git pull --quiet; \
                cd - > /dev/null; \
            else \
                echo -n " >>> Importing ... "; \
                git clone --quiet $URL $FOLDER; \
            fi; \
            echo "Done"; \
        ' bash
    echo "Importing Done"
else
    echo "Skipping"
fi

# export repos
echo -e "Exporting repos from folder '${YELLOW}${REPOS_FOLDER}${NC}' ... "
if [ -n "${isNeedExportRepos}" ]; then
    if [ -z "${CONFIG_EXPORT_REPO_URL}" ]; then
        echo -e "${RED}Error:${NC} CONFIG_EXPORT_REPO_URL variable or '--export-repo-url' option is required"
        exit
    fi
    # check access to export repo whether ask for creds
    git ls-remote ${CONFIG_EXPORT_REPO_URL} > /dev/null
    # export
    export _DIR
    tail -n3 ${REPOS_FILE} | \
        sed "s,^,${REPOS_FOLDER} ,g" | \
        xargs -n3 bash -c $' \
            REPO="$(echo $@ | awk \'{print $2}\')"; \
            REPO_NAME="$(echo "${REPO}" | sed \'s/\//_/\')"; \
            FOLDER="$(echo $@ | awk \'{print $1 "/" $2}\')"; \
            echo -n " > Repo ${REPO_NAME} from ${REPO} ... "; \
            source ${_DIR}/export.sh --source ${FOLDER} --destination-repo ${CONFIG_EXPORT_REPO_URL} --destination-branch ${REPO_NAME}; \
            echo ""; \
        ' bash
    echo "Exporting Done"
else
    echo "Skipping"
fi
