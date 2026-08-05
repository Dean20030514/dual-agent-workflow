@{
    # Pinned PowerShell module versions for tools/validate - single source for
    # local use and CI (.github/workflows/offline-ci.yml installs from this file).
    # The validator NEVER auto-installs: a missing module is ENVIRONMENT_ERROR
    # (exit 2) with install guidance. One-time local install:
    #   Install-Module -Name <Name> -RequiredVersion <Version> -Scope CurrentUser -Force
    Modules = @(
        @{ Name = 'powershell-yaml';  RequiredVersion = '0.4.12' }
        @{ Name = 'PSScriptAnalyzer'; RequiredVersion = '1.25.0' }
        @{ Name = 'Pester';           RequiredVersion = '6.0.1' }
    )
    # gitleaks is a local prerequisite binary, not a PowerShell module; its pinned
    # release and artifact SHA-256 are recorded in .github/workflows/offline-ci.yml.
}
