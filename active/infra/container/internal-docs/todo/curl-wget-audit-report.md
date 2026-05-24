# curl/wget Security Audit Report

Generated on: Wed Feb  4 05:33:15 PM PST 2026

## Summary

This report audits all Dockerfiles in the project for unsafe curl/wget usage and identifies containers that need the levonk.common.vet_script_installer package for safe remote script execution.

## Findings

[0;34m=== Starting curl/wget security audit ===[0m
[0;34mℹ Found 76 Dockerfiles to audit[0m

Auditing: ./configs/ntp.bak/Dockerfile.bak ... no curl/wget
Auditing: ./configs/ntp.bak/Dockerfile.chronyd.bak ... no curl/wget
Auditing: ./configs/transparent-gateway/Dockerfile.transparent-gateway ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./Dockerfile.dnscrypt-proxy.bak ... uses wget
[0;32m✓ usage appears safe[0m
Auditing: ./Dockerfile.dnsdist.bak ... no curl/wget
Auditing: ./services/ai-codeassist/autoclaude-runner/Dockerfile ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/ai-codeassist/claude-code/claude-code/docker/Dockerfile.auth ... no curl/wget
Auditing: ./services/ai-codeassist/claude-code/claude-code/docker/Dockerfile.claude-code ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/ai-codeassist/claude-code-intercept/Dockerfile.claude-code-intercept ... uses wget
[0;31m✗   wget pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/ai-codeassist/hapi-client/Dockerfile.hapi-client ... uses curl
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/ai-codeassist/hapi-server/Dockerfile.hapi-server ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/ai-codeassist/opencode-runner/Dockerfile ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/ai-codeassist/vibe-kanban/Dockerfile ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/airflow/airflow-base-common/alpine/docker/Dockerfile.airflow-base-common-alpine ... no curl/wget
Auditing: ./services/airflow/airflow-base-common/alpine/Dockerfile ... no curl/wget
Auditing: ./services/airflow/airflow-base-common/debian/docker/Dockerfile.airflow-base-common-debian ... no curl/wget
Auditing: ./services/airflow/airflow-base-common/debian/Dockerfile ... no curl/wget
Auditing: ./services/airflow/airflow-core/Dockerfile ... no curl/wget
Auditing: ./services/airflow/airflow-platform/Dockerfile ... no curl/wget
Auditing: ./services/airflow/airflow-py/Dockerfile ... no curl/wget
Auditing: ./services/airflow/base-python-alpine/docker/Dockerfile.base-python-alpine ... no curl/wget
Auditing: ./services/airflow/base-python-alpine/Dockerfile ... no curl/wget
Auditing: ./services/airflow/base-python-debian/docker/Dockerfile.base-python-debian ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/airflow/base-python-debian/Dockerfile ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/apps/stfu/Dockerfile.stfu ... uses wget
[0;31m✗   wget pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/artifact/asdf-sidecar/Dockerfile.asdf-sidecar ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/artifact/bazel-sidecar/Dockerfile.bazel-sidecar ... uses curl
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/artifact/conda-sidecar/Dockerfile.conda-sidecar ... uses curl
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/artifact/dart-sidecar/Dockerfile.dart-sidecar ... uses curl
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/artifact/dotnet-sidecar/Dockerfile.dotnet-sidecar ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/artifact/elixir-sidecar/Dockerfile.elixir-sidecar ... no curl/wget
Auditing: ./services/artifact/go-sidecar/Dockerfile.go-sidecar ... no curl/wget
Auditing: ./services/artifact/gradle-sidecar/Dockerfile.gradle-sidecar ... uses curl
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/artifact/haskell-sidecar/Dockerfile.haskell-sidecar ... no curl/wget
Auditing: ./services/artifact/java-sidecar/Dockerfile.java-sidecar ... no curl/wget
Auditing: ./services/artifact/mise-sidecar/Dockerfile.mise-sidecar ... uses curl
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/artifact/nexus/Dockerfile.nexus ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/artifact/nvm-sidecar/Dockerfile.nvm-sidecar ... no curl/wget
Auditing: ./services/artifact/php-sidecar/Dockerfile.php-sidecar ... no curl/wget
Auditing: ./services/artifact/pnpm-sidecar/Dockerfile.pnpm-sidecar ... no curl/wget
Auditing: ./services/artifact/poetry-sidecar/Dockerfile.poetry-sidecar ... no curl/wget
Auditing: ./services/artifact/pyenv-sidecar/Dockerfile.pyenv-sidecar ... no curl/wget
Auditing: ./services/artifact/python-sidecar/Dockerfile.python-sidecar ... no curl/wget
Auditing: ./services/artifact/ruby-sidecar/Dockerfile.ruby-sidecar ... no curl/wget
Auditing: ./services/artifact/rust-sidecar/Dockerfile.rust-sidecar ... no curl/wget
Auditing: ./services/artifact/sdkman-sidecar/Dockerfile.sdkman-sidecar ... no curl/wget
Auditing: ./services/artifact/turborepo-sidecar/Dockerfile.turborepo-sidecar ... no curl/wget
Auditing: ./services/artifact/unity-sidecar/Dockerfile.unity-sidecar ... uses curl
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/artifact/verdaccio/docker/Dockerfile.verdaccio ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/artifact/vscode-sidecar/Dockerfile.vscode-sidecar ... uses curl
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/base/base-alpine/Dockerfile.base-alpine ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/base/base.bak/docker/Dockerfile.base ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/base/base-debian/Dockerfile.base-debian ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/base/base-debnix/Dockerfile.base-debnix ... no curl/wget
Auditing: ./services/base/base-dev/Dockerfile.base-dev ... no curl/wget
Auditing: ./services/base/base-nix/Dockerfile.base-nix ... no curl/wget
Auditing: ./services/base/base-sidecar/Dockerfile.base-sidecar ... no curl/wget
Auditing: ./services/base/nix-sidecar/Dockerfile.nix-sidecar ... no curl/wget
Auditing: ./services/dns/adguard/Dockerfile.adguard ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/dns/coredns/docker/Dockerfile.coredns ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/dns/dns-blocklists/Dockerfile.bak ... uses curl
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/dns/dns-blocklists/Dockerfile.blocklist-compiler ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/dns/dnscrypt/docker/Dockerfile.dnscrypt-proxy ... no curl/wget
Auditing: ./services/dns/dnsdist/docker/Dockerfile.dnsdist ... uses curl
[0;32m✓ usage appears safe[0m
Auditing: ./services/ntp/chronyd/Dockerfile.chronyd ... no curl/wget
Auditing: ./services/proxy/gost/docker/Dockerfile.gost ... uses curl
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./services/proxy/tor/docker/Dockerfile.tor ... no curl/wget
Auditing: ./services/proxy/traefik/docker/Dockerfile.traefik ... no curl/wget
Auditing: ./services/security/arpwatch/docker/Dockerfile ... no curl/wget
Auditing: ./services/vpn/cloudflare-warp/docker/Dockerfile.cloudflare-warp ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./warp-gateway/gost/Dockerfile ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./warp-gateway/gost/Dockerfile.bak ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./warp-gateway/gost/Dockerfile.warp-gateway-gost ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   insecure HTTP URLs detected[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./warp-gateway/warp/Dockerfile ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./warp-gateway/warp/Dockerfile.bak ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m
Auditing: ./warp-gateway/warp/Dockerfile.warp-gateway-warp ... uses curl
[0;31m✗   curl pipe to shell - potential command injection[0m
[0;31m✗   missing verification for remote downloads[0m
[0;31m✗   vet NOT available - consider installing levonk.common.vet_script_installer[0m

[0;34m=== Audit Summary ===[0m
Total Dockerfiles audited: 76
Using curl/wget: 39
Unsafe usage detected: 26
Need vet installed: 26

[0;31m✗ Security issues found! Review the Dockerfiles above.[0m

## Recommendations

1. **Install levonk.common.vet_script_installer**: Add this package to any base image that downloads files via curl/wget
2. **Use HTTPS**: Ensure all downloads use HTTPS URLs
3. **Verify downloads**: Use vet-run or vet to verify script integrity before execution
4. **Avoid pipes**: Never pipe curl/wget output directly to shell
5. **Enable SSL verification**: Never disable SSL certificate checks

## Actions Required

- [ ] Add levonk.common.vet_script_installer to base images that need it
- [ ] Update Dockerfiles to use HTTPS URLs
- [ ] Replace unsafe curl/wget usage with vet-verified alternatives
