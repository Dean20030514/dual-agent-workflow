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

function Read-TeamLogExcerpt([string]$Path, [int]$HeadChars, [int]$TailChars) {
    $length = (Get-Item -LiteralPath $Path).Length
    if ($length -le ([int64]($HeadChars + $TailChars) * 4 + 8)) {
        # Small log: decode once and split exactly by characters. The reported byte counts
        # describe the excerpt that is actually returned, never the whole file.
        $text = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        $head = if ($text.Length -gt $HeadChars) { $text.Substring(0, $HeadChars) } else { $text }
        $tail = if ($TailChars -gt 0 -and $text.Length -gt $HeadChars) {
            if ($text.Length - $HeadChars -gt $TailChars) { $text.Substring($text.Length - $TailChars) } else { $text.Substring($HeadChars) }
        } else { '' }
        return (Get-TeamExcerptRecord $head $tail $length)
    }
    $head = ''; $tail = ''; $headBytes = 0L; $tailBytes = 0L
    $stream = [IO.File]::Open($Path, 'Open', 'Read', ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try {
        if ($HeadChars -gt 0) {
            $buffer = [byte[]]::new([Math]::Min([int64]($HeadChars * 4 + 4), $length))
            $headBytes = $stream.Read($buffer, 0, $buffer.Length)
            $head = [Text.Encoding]::UTF8.GetString($buffer, 0, [int]$headBytes)
            if ($head.Length -gt $HeadChars) { $head = $head.Substring(0, $HeadChars) }
        }
        if ($TailChars -gt 0 -and $length -gt $headBytes) {
            $bytes = [Math]::Min([int64]($TailChars * 4 + 4), $length - $headBytes)
            $null = $stream.Seek(-$bytes, [IO.SeekOrigin]::End)
            $buffer = [byte[]]::new($bytes)
            $read = $stream.Read($buffer, 0, [int]$bytes)
            $tailBytes = [int64]$read
            $tail = [Text.Encoding]::UTF8.GetString($buffer, 0, $read)
            if ($tail.Length -gt $TailChars) { $tail = $tail.Substring($tail.Length - $TailChars) }
        }
    } finally { $stream.Dispose() }
    return (Get-TeamExcerptRecord $head $tail $length)
}

function Get-TeamExcerptRecord([string]$Head, [string]$Tail, [long]$Length) {
    # The metadata must agree with the returned excerpt: head/tail bytes are the UTF-8 size
    # of the reported strings and the omitted bytes are what no excerpt covers.
    $headBytes = Get-TeamTextByteCount $Head
    $tailBytes = Get-TeamTextByteCount $Tail
    $covered = $headBytes + $tailBytes
    return @{ head = $Head; tail = $Tail; head_bytes = $headBytes; tail_bytes = $tailBytes
        excerpt_chars = $Head.Length + $Tail.Length
        omitted_bytes = [Math]::Max(0L, $Length - $covered); truncated = ($covered -lt $Length) }
}

function Get-TeamReviewOutput([string]$Directory,[string]$Prefix,[int]$MaxChars=4096) {
    $files=@(Get-ChildItem -LiteralPath $Directory -Filter "$Prefix-*.stdout" -File -ErrorAction SilentlyContinue | Sort-Object Name)
    $files+=@(Get-ChildItem -LiteralPath $Directory -Filter "$Prefix-*.stderr" -File -ErrorAction SilentlyContinue | Sort-Object Name)
    if (-not $files.Count) { return '[]' }
    # Fair allocation per file: one huge command log can no longer starve every command
    # that follows it. The total excerpt budget stays bounded by MaxChars.
    $perFile=[int][Math]::Floor($MaxChars/$files.Count)
    $headChars=if ($perFile -ge 40) {[int][Math]::Floor($perFile/2)} else {$perFile}
    $tailChars=if ($perFile -ge 40) {$perFile-$headChars} else {0}
    $parts=@()
    foreach ($file in $files) {
        $window=Read-TeamLogExcerpt $file.FullName $headChars $tailChars
        $parts+=@{ file=$file.Name; stream=$(if ($file.Extension -eq '.stderr') {'stderr'} else {'stdout'})
            bytes=$file.Length; sha256=(Get-TeamHash $file.FullName)
            head=$window.head; tail=$window.tail; excerpt=($window.head+$window.tail)
            head_bytes=$window.head_bytes; tail_bytes=$window.tail_bytes
            omitted_bytes=$window.omitted_bytes; truncated=$window.truncated
            excerpt_chars=$window.excerpt_chars; excerpt_chars_budget=$perFile }
    }
    return ConvertTo-Json -InputObject $parts -Depth 8
}

function Get-TeamChangeSummary([string]$Worktree,[string]$Base,[string]$Tip) {
    $numstat=@((Invoke-TeamGit $Worktree @('-c','core.quotePath=false','diff','--numstat','--no-renames',$Base,$Tip)) -split "`n" | Where-Object { $_ })
    $files=@(); $additions=0; $deletions=0; $binary=0
    foreach ($line in $numstat) {
        $columns=$line -split "`t"
        if ($columns.Count -lt 3) { continue }
        $isBinary=($columns[0] -eq '-' -or $columns[1] -eq '-')
        if ($isBinary) { $binary++ } else { $additions+=[int]$columns[0]; $deletions+=[int]$columns[1] }
        $files+=@{ path=$columns[2]
            additions=$(if ($isBinary) {$null} else {[int]$columns[0]})
            deletions=$(if ($isBinary) {$null} else {[int]$columns[1]}); binary=$isBinary }
    }
    return @{ base=$Base; tip=$Tip; file_count=$files.Count; additions=$additions; deletions=$deletions
        binary_files=$binary; files=$files; source='git diff --numstat --no-renames (machine-derived)' }
}

function Get-TeamIssueAcceptanceMap($Task) {
    $objectives=@(Get-TeamOptionalList $Task['objective']); $acceptance=@(Get-TeamOptionalList $Task['acceptance'])
    # An absent optional mapping must stay empty: @($null) would otherwise report one
    # declared row and then fail while reading a property off $null.
    $declared=@(Get-TeamOptionalList $Task['issue_acceptance_map']); $rows=@(); $mapped=@{}
    foreach ($entry in $declared) {
        $objectiveIndex=[int]$entry.objective_index
        $items=@(foreach ($index in @(Get-TeamOptionalList $entry['acceptance_indexes'])) {
            $mapped[[int]$index]=$true
            @{ index=[int]$index; acceptance=$acceptance[[int]$index] }
        })
        $rows+=@{ objective_index=$objectiveIndex; issue=$objectives[$objectiveIndex]; acceptance=$items; declared=$true }
    }
    $unmapped=@(for ($index=0; $index -lt $acceptance.Count; $index++) {
        if (-not $mapped.ContainsKey($index)) { @{ index=$index; acceptance=$acceptance[$index] } }
    })
    return @{ issues=@(for ($index=0; $index -lt $objectives.Count; $index++) { @{ index=$index; issue=$objectives[$index] } })
        acceptance=@(for ($index=0; $index -lt $acceptance.Count; $index++) { @{ index=$index; acceptance=$acceptance[$index] } })
        mapping=$rows; unmapped_acceptance=$unmapped; declared_count=$declared.Count
        note='Mapping is author-declared. Original issue text stays in objective/acceptance; the runner never invents it.' }
}

function Get-TeamCommandSummary($Evidence) {
    # Index access only: evidence written before a field existed must still be summarisable.
    return @(foreach ($entry in @($Evidence)) {
        @{ id=$entry['id']; executable=$entry['executable']
            args_sha256=(Get-TeamTextHash ((@($entry['args'])) -join "`n")); exit_code=$entry['exit_code']
            process_started=$entry['process_started']; timeout_kind=$entry['timeout_kind']
            reused=[bool]$entry['reused']; duration_seconds=$entry['duration_seconds']
            stdout_bytes=$entry['stdout_bytes']; stdout_sha256=$entry['stdout_sha256']
            stderr_bytes=$entry['stderr_bytes']; stderr_sha256=$entry['stderr_sha256'] }
    })
}

function Assert-TeamReviewInput([string]$Diff,[string]$Prompt,$Runtime) {
    $maxDiff=if ($Runtime['max_diff_bytes']) {[long]$Runtime.max_diff_bytes} else {2000000L}
    $maxInput=if ($Runtime['max_review_input_bytes']) {[long]$Runtime.max_review_input_bytes} else {4000000L}
    if ([Text.Encoding]::UTF8.GetByteCount($Diff) -gt $maxDiff -or [Text.Encoding]::UTF8.GetByteCount($Prompt) -gt $maxInput) {
        Stop-TeamInputCapacity 'Review input is too large; split/replan the task. The exact diff was not truncated and no reviewer was launched.'
    }
}
