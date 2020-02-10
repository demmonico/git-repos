#!/usr/bin/env php
<?php
/**
 * Script helps to fetch repos list from Git over all namespaces.
 * Best fit to create repos mirror
 *
 * !!! Warning !!! Works only with GitLab !!!!
 *
 * @usage
 * // fetch all available repos ssh_url_to_repo
 * touch repo_list.txt
 * ./fetch_repo_list.php "https://<GIT_BASE_URL>/api/v4/projects?access_token=<TOKEN>&archived=false" > repo_list.txt
 *
 * // fetch all available repos name and http_url
 * touch repo_list.txt
 * ./fetch_repo_list.php "https://<GIT_BASE_URL>/api/v4/projects?access_token=<TOKEN>&archived=false" "path,http_url_to_repo" > repo_list.txt
 *
 * // fetch single page repos ssh_url_to_repo info, e.g. 3
 * touch repo_list.txt
 * ./fetch_repo_list.php "https://<GIT_BASE_URL>/api/v4/projects?access_token=<TOKEN>&archived=false" "ssh_url_to_repo" 3 > repo_list.txt
 *
 * // parse list and make git clone
 * cat repo_list.txt | xargs -n5 sh -c $'FOLDER=$(echo $@ | awk \'{print $1 "/" $2}\'); URL=$(echo $@ | awk \'{print $4}\'); echo ">>> Repo $URL fetching into > $FOLDER"; git clone --quiet $URL $FOLDER;' sh
 * // or if define fetch fields
 * cat repo_list.txt | xargs -n2 sh -c $'FOLDER=$(echo $@ | awk \'{print $1}\'); URL=$(echo $@ | awk \'{print $2}\'); echo ">>> Repo $URL fetching into > $FOLDER"; git clone --quiet $URL $FOLDER;' sh
 */

/**
 * Class GitLabRepoFetcher
 *
 * @author dep demmonico@gmail.com
 */
class GitLabRepoFetcher
{
    const PARAM_PER_PAGE_NAME = 'per_page';
    const PARAM_PER_PAGE_VALUE = 100;
    const PARAM_PAGE_NAME = 'page';

    const HEADER_TOTAL_NUMBER = 'X-Total:';

    private $url;
    private $repoDataMapper;

    public function __construct(RepoDataMapper $repoDataMapper, string $url)
    {
        $this->repoDataMapper = $repoDataMapper;

        if (false == $this->url = filter_var($url, FILTER_SANITIZE_URL)) {
            throw new LogicException('Bad format of URL');
        }
    }

    public function fetchReposByPage(int $page): array
    {
        $reposData = file_get_contents($this->buildUrlByPage($page));
        if ($reposData === false) {
            throw new LogicException('Fetch error');
        }

        $reposData = json_decode($reposData, true);
        $repos = [];

        foreach ($reposData as $repoData) {
            $repos[] = ($this->repoDataMapper)($repoData);
        }

        return $repos;
    }

    public function fetchReposTotalCount(): int
    {
        $headers = get_headers($this->url);
        $headersTotal = preg_grep('/' . self::HEADER_TOTAL_NUMBER . '/', $headers);
        if (empty($headersTotal)) {
            throw new LogicException('Unable to find total count header: ' . implode(',' . PHP_EOL, $headers));
        }

        $totalRepoNumber = trim(str_replace(self::HEADER_TOTAL_NUMBER, '', current($headersTotal)));
        if (!ctype_digit($totalRepoNumber) || empty($totalRepoNumber)) {
            throw new LogicException('Unable to define total count');
        }

        return (int) $totalRepoNumber;
    }

    private function buildUrlByPage(int $page)
    {
        return sprintf(
            '%s&%s=%d&%s=%d',
            $this->url,
            self::PARAM_PER_PAGE_NAME,
            self::PARAM_PER_PAGE_VALUE,
            self::PARAM_PAGE_NAME,
            $page
        );
    }
}

class RepoDataMapper
{
    private $rulesMap;

    /**
     * RepoDataMapper constructor.
     * @param array $rules repo data map in format:
     * "original_name_or_path"
     * OR "target_name => original_name" for change field naming
     * OR "target_name => [original_name_1, original_name_2]" for fetch inner field $repoData[original_name_1][original_name_2]
     */
    public function __construct(array $rules)
    {
        foreach ($rules as $targetKey => $originKey) {
            list($targetKey, $originKey) = self::normalizeRule($targetKey, $originKey);
            $this->rulesMap[$targetKey] = $originKey;
        }
    }

    public function __invoke(array $repoData): array
    {
        $mappedData = [];

        foreach ($this->rulesMap as $targetKey => $originKey) {
            if (is_array($originKey)) {
                $mappedData[$targetKey] = self::fetchInnerArrayValue($repoData, $originKey);
            } elseif (isset($repoData[$originKey])) {
                $mappedData[$targetKey] = $repoData[$originKey];
            }
        }

        return $mappedData;
    }

    private static function normalizeRule($targetKey, $rule): array
    {
        // use simple rule definitions
        if (is_int($targetKey)) {
            $targetKey = $rule;
        }

        return [$targetKey, $rule];
    }

    private static function fetchInnerArrayValue(array $array, array $path)
    {
        $key = array_shift($path);
        $value = $array[$key] ?? null;

        // return value if path ends or NULL if no value or loop forward
        return is_null($value) || empty($path) ? $value : self::fetchInnerArrayValue($value, $path);
    }
}



/////////////////////////////

// access url
if (isset($argv[1])) {
    $url = $argv[1];
} else {
    throw new LogicException('Access url param is required. It looks like "https://<GIT_BASE_URL>/api/v4/projects?access_token=<TOKEN>&archived=false"');
}

// output fields
// from $argv[2] in comma separated format path,ssh_url_to_repo
// all available fields see https://docs.gitlab.com/ee/api/projects.html
$fields = isset($argv[2]) ? explode(',', $argv[2]) : [
    // alias => api_field_name OR alias => [api_field_name => api_inner_field_name]
    'namespace' => ['namespace', 'path'],
    'name' => 'path',
    'ssh_url' => 'http_url_to_repo',
    'http_url' => 'ssh_url_to_repo',
    'default_branch',
];
$repoDataMapper = new RepoDataMapper($fields);

// pre-defined page to scan
$page = isset($argv[3]) ? intval($argv[3]) : null;

// format output
$outputCallback = function (array $repos) {
    foreach ($repos as $repo) {
        echo implode(' ', $repo) .PHP_EOL;
    }
};

/////////////////////////////

$processor = new GitLabRepoFetcher($repoDataMapper, $url);

// fetch single page if was defined
if (isset($page)) {
    $outputCallback($processor->fetchReposByPage($page));
}
// fetch all available repos
else {
    $totalRepos = $processor->fetchReposTotalCount();
    $totalPages = (int) ceil($totalRepos / GitLabRepoFetcher::PARAM_PER_PAGE_VALUE);

    for ($page = 1; $page <= $totalPages; $page++) {
        $outputCallback($processor->fetchReposByPage($page));
    }
}
