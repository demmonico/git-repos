# Git repositories synchronizer

Util to backing up synchronize repositories locally or remotely.


### Details

Util can:
- fetch repositories list from API by `access_token` e.g. `https://GITLAB_BASE_URL/api/v4/projects?access_token=ACCESS_TOKEN&archived=false`
  (work only on `GitLab` !!! @TODO make it for other platforms)
- import locally repositories by list
- export remotely repositories by list (tested on `Bitbucket` and `GitHub`)

Locally imported repositories could be used:
- as a basis of export process
- as a backups (with further `tar`, `gzip` etc)
- as a basis for looking through overall repositories code
  (e.g. you wanna search for usage `http://api.backend.dev` URL overall project to be sure that refactoring will not broke something. 
  You run `find YOUR_FOLDER_LOCATION -type f -exec grep -il "api.backend.dev" {} \; 2>&1` or even way better using [ack](https://beyondgrep.com/) `ack api.backend.dev` ;) . 
  Yes, I know - integration tests are best, for sure :). And yes, I know that search would act only on stable branch - mostly `master` )
- counting LoC etc 


### Preparing

- download util script files
- create file with env variables for you project/group, e.g. `/<FOLDER>/project.env`
- fill out env var file:
  
  **Fetching**
  ```env
  CONFIG_REPO_URL="https://GITLAB_BASE_URL/api/v4/projects?access_token=ACCESS_TOKEN&archived=false"
  CONFIG_REPO_FIELDS="path_with_namespace,ssh_url_to_repo"
  CONFIG_REPOS_FILE="repos.txt"
  ```
  
  **Importing**
    ```env
    CONFIG_REPOS_FILE="repos.txt"
    ```
    
  **Exporting**
    ```env
    CONFIG_REPOS_FILE="repos.txt"
    CONFIG_EXPORT_REPO_URL="git@bitbucket.org:SOME_REPO.git"
    ```

***Note:*** To avoid multi-asking ssh password run in terminal. Be sure that you have access to all fetching repositories:
- `ssh-add ~/.ssh/xx_rsa` (where `xx_rsa` - identity file for source repo)
- `ssh-add ~/.ssh/yy_rsa` (where `yy_rsa` - identity file for destination repo)


### Run

Fetch all available repos to list provided at .env file

```shell script
./sync.sh --config-file FULL_PATH/sync_config.env --fetch-repos
```

Import all available repos to folder having .env file

```shell script
./sync.sh --config-file FULL_PATH/sync_config.env --import-repos
```

Export all available repos to storage repo provided at .env file or passing by arg

```shell script
./sync.sh --config-file FULL_PATH/sync_config.env --export-repos
```

Fetch, import and export all available repos to folder and then to storage repo provided at .env file

```shell script
./sync.sh --config-file FULL_PATH/sync_config.env --fetch-repos --import-repos --export-repos
```
