<?php

namespace App\SSH\OS;

use App\Exceptions\SSHError;
use App\Models\Server;
use App\Models\Site;

class Git
{
    /**
     * @throws SSHError
     */
    public function clone(Site $site, ?string $path = null): void
    {
        $this->cloneRepository(
            server: $site->server,
            user: (string) $site->user,
            repoUrl: (string) $site->getFullRepositoryUrl(),
            branch: (string) $site->branch,
            path: (string) ($path ?? $site->path),
            keyName: $site->getSshKeyName(),
            port: $site->sourceControl?->provider()?->getSshPort() ?? 22,
            usesToken: $site->sourceControl?->isGithubApp() ?? false,
            variables: $site->environmentVariables(),
            siteId: $site->id,
        );
    }

    /**
     * @param  array<string, string>  $variables
     *
     * @throws SSHError
     */
    public function cloneRepository(
        Server $server,
        string $user,
        string $repoUrl,
        string $branch,
        string $path,
        string $keyName,
        int $port,
        bool $usesToken,
        array $variables = [],
        ?int $siteId = null,
    ): void {
        $ssh = $server->ssh($user);

        if ($usesToken) {
            $ssh = $ssh->variables($variables);
        }

        $ssh->exec(
            view('ssh.git.clone', [
                'host' => $usesToken ? '' : str($repoUrl)->after('@')->before('-'),
                'repo' => escapeshellarg($repoUrl),
                'path' => escapeshellarg($path),
                'branch' => escapeshellarg($branch),
                'key' => $keyName,
                'port' => $port,
                'usesToken' => $usesToken,
            ]),
            'clone-repository',
            $siteId
        );
    }

    /**
     * @throws SSHError
     */
    public function checkout(Site $site, ?string $path = null): void
    {
        $site->server->ssh($site->user)->exec(
            view('ssh.git.checkout', [
                'path' => escapeshellarg((string) ($path ?? $site->path)),
                'branch' => escapeshellarg((string) $site->branch),
            ]),
            'checkout-branch',
            $site->id
        );
    }

    /**
     * @throws SSHError
     */
    public function fetchOrigin(Site $site, ?string $path = null): void
    {
        $ssh = $site->server->ssh($site->user);

        if ($site->sourceControl?->isGithubApp()) {
            $ssh = $ssh->variables($site->environmentVariables());
        }

        $ssh->exec(
            view('ssh.git.fetch-origin', [
                'path' => escapeshellarg((string) ($path ?? $site->path)),
            ]),
            'fetch-origin',
            $site->id
        );
    }

    /**
     * @throws SSHError
     */
    public function setRemote(Site $site, string $newRepoUrl): void
    {
        $usesToken = $site->sourceControl?->isGithubApp() ?? false;
        $ssh = $site->server->ssh($site->user);

        if ($usesToken) {
            $ssh = $ssh->variables($site->environmentVariables());
        }

        $ssh->exec(
            view('ssh.git.set-remote', [
                'path' => escapeshellarg((string) $site->path),
                'newRepoUrl' => escapeshellarg($newRepoUrl),
                'usesToken' => $usesToken,
            ]),
            'set-remote',
            $site->id
        );
    }
}
