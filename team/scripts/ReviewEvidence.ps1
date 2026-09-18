function New-TeamAuthority([string]$Repo,[string]$Base,[string]$Directory) {
    $files=@((Invoke-TeamGit $Repo @('-c','core.quotePath=false','ls-tree','-r','--name-only',$Base)) -split "`n" |
        Where-Object { $_ -match '(^|/)AGENTS(\.override)?\.md$|^team/(manifest\.yaml$|policies/)' })
    $documents=@(foreach ($file in $files) {
        @{path=$file;blob=(Invoke-TeamGit $Repo @('rev-parse',"${Base}:$file"));text=(Invoke-TeamGit $Repo @('show',"${Base}:$file"))}
    })
    $path=Join-Path $Directory 'authority.json'
    Write-TeamData $path @{schema_version=1;base_sha=$Base;documents=$documents}
    return Get-TeamHash $path
}

function Read-TeamAuthority($State,[string]$Directory) {
    $path=Join-Path $Directory 'authority.json'
    if (-not $State['authority_hash'] -or -not (Test-Path -LiteralPath $path) -or
        (Get-TeamHash $path) -cne $State.authority_hash) { Stop-TeamError 80 'Frozen run authority is missing or changed; preserve the run and start an explicitly planned replacement' }
    $authority=Read-TeamData $path
    if ($authority.base_sha -cne $State.run_base_sha) { Stop-TeamError 80 'Frozen authority base differs from run base' }
    return $authority
}

function Test-TeamGovernanceChange([string]$Repo,[string]$Base,[string]$Tip) {
    $paths=Invoke-TeamGit $Repo @('-c','core.quotePath=false','diff','--name-only','--no-renames',$Base,$Tip)
    return @($paths -split "`n" | Where-Object {$_ -match '(^|/)AGENTS(\.override)?\.md$|^team/(manifest\.yaml$|policies/)'}).Count -gt 0
}

function New-TeamReviewHolding($State,[string]$Label) {
    $codexRoot=if ($env:CODEX_HOME) {$env:CODEX_HOME} else {Join-Path $env:USERPROFILE '.codex'}
    $repoKey=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($State.repo).ToLowerInvariant()))).Substring(0,24).ToLowerInvariant()
    $root=Get-TeamChild $codexRoot 'team-review-holding'
    $repo=[IO.Path]::GetFullPath($State.repo).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if (($root+[IO.Path]::DirectorySeparatorChar).StartsWith($repo,[StringComparison]::OrdinalIgnoreCase)) { Stop-TeamError 20 'Review holding must be outside the reviewed repository' }
    Assert-TeamId $State.run_id; Assert-TeamId $Label
    $holding=Get-TeamChild $root "$repoKey/$($State.run_id)/$Label-$([guid]::NewGuid().ToString('N'))"
    [IO.Directory]::CreateDirectory($holding) | Out-Null
    return $holding
}

function Save-TeamReviewEvidence($Record,[string]$Directory) {
    $relative="reviews/archives/$([IO.Path]::GetFileName($Record.holding))"
    $target=Get-TeamChild $Directory $relative
    [IO.Directory]::CreateDirectory($target) | Out-Null
    foreach ($file in @('verdict.json','prompt.txt')) {
        $source=Join-Path $Record.holding $file
        $expected=if ($file -eq 'verdict.json') {$Record.verdict_hash} else {$Record.input_hash}
        if ((Get-TeamHash $source) -cne $expected) { Stop-TeamError 80 'Review evidence changed before archival' }
        $temporary=Join-Path $target ('.archive-'+[guid]::NewGuid().ToString('N'))
        try {
            [IO.File]::Copy($source,$temporary)
            if ((Get-TeamHash $temporary) -cne $expected) {Stop-TeamError 80 'Review evidence changed while archiving'}
            [IO.File]::Move($temporary,(Join-Path $target $file),$true)
        } finally {if (Test-Path -LiteralPath $temporary) {[IO.File]::Delete($temporary)}}
        if ((Get-TeamHash (Join-Path $target $file)) -cne $expected) { Stop-TeamError 80 'Archived review evidence hash mismatch' }
    }
    $Record['evidence_directory']=$relative
}

function Assert-TeamReviewEvidence($Record,[string]$Directory) {
    if (-not $Record['authority_hash'] -or -not $Record['evidence_directory']) { Stop-TeamError 80 'Legacy review lacks frozen authority or durable evidence; preserve the run and start an explicitly planned replacement' }
    $statePath=Get-TeamChild $Directory 'state.json'
    if (-not (Test-Path -LiteralPath $statePath)) {Stop-TeamError 80 'Review run state is missing'}
    $state=Read-TeamData $statePath
    $null=Read-TeamAuthority $state $Directory
    if ($Record.authority_hash -cne $state.authority_hash) { Stop-TeamError 80 'Review authority differs from the run' }
    $evidence=Get-TeamChild $Directory $Record.evidence_directory
    foreach ($file in @('verdict.json','prompt.txt')) {
        if (-not (Test-Path -LiteralPath (Get-TeamChild $evidence $file) -PathType Leaf)) {Stop-TeamError 80 'Durable review evidence is missing'}
    }
    if ((Get-TeamHash (Join-Path $evidence 'verdict.json')) -cne $Record.verdict_hash -or
        (Get-TeamHash (Join-Path $evidence 'prompt.txt')) -cne $Record.input_hash) { Stop-TeamError 80 'Durable review evidence changed' }
}

function Get-TeamReviewOutput([string]$Directory,[string]$Prefix,[int]$MaxChars=4096) {
    $parts=@(); $left=$MaxChars
    foreach ($file in @(Get-ChildItem -LiteralPath $Directory -Filter "$Prefix-*.stdout" | Sort-Object Name)) {
        $reader=[IO.File]::OpenText($file.FullName)
        try { $buffer=[char[]]::new([Math]::Max(0,[Math]::Min(1024,$left))); $count=$reader.ReadBlock($buffer,0,$buffer.Length); $excerpt=[string]::new($buffer,0,$count); $truncated=-not $reader.EndOfStream }
        finally {$reader.Dispose()}
        $left-=$count
        $parts+=@{file=$file.Name;bytes=$file.Length;sha256=(Get-TeamHash $file.FullName);excerpt=$excerpt;truncated=$truncated}
    }
    return ConvertTo-Json -InputObject $parts -Depth 8
}

function Assert-TeamReviewInput([string]$Diff,[string]$Prompt,$Runtime) {
    $maxDiff=if ($Runtime['max_diff_bytes']) {[long]$Runtime.max_diff_bytes} else {2000000L}
    $maxInput=if ($Runtime['max_review_input_bytes']) {[long]$Runtime.max_review_input_bytes} else {4000000L}
    if ([Text.Encoding]::UTF8.GetByteCount($Diff) -gt $maxDiff -or [Text.Encoding]::UTF8.GetByteCount($Prompt) -gt $maxInput) {
        Stop-TeamInputCapacity 'Review input is too large; split/replan the task. The exact diff was not truncated and no reviewer was launched.'
    }
}
