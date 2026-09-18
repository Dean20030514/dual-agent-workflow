BeforeAll {
    $script:TeamPath=Split-Path $PSScriptRoot -Parent
    foreach ($module in @('Core','Contracts','State','Controls','Preflight','Lead','Review')) {. (Join-Path $script:TeamPath "scripts/$module.ps1")}
    $script:ManifestData=Read-TeamData (Join-Path $script:TeamPath 'manifest.yaml')
    function Code($Action,$Expected) {
        $errorRecord=$null
        try {& $Action | Out-Null} catch {$errorRecord=$_}
        $errorRecord | Should -Not -BeNullOrEmpty
        $errorRecord.Exception.Data['TeamExitCode'] | Should -Be $Expected -Because $errorRecord.Exception.Message
    }
    function Plan([int]$Count) {
        $plan=Read-TeamData (Join-Path $script:TeamPath 'tests/plans/L1-sql.yaml')
        $template=ConvertTo-Json $plan.tasks[0] -Depth 20
        $plan.mode='L2'; $plan.tasks=@(1..$Count | ForEach-Object {$t=ConvertFrom-Json $template -AsHashtable; $t.id="T$_"; $t.write_scope=@("files/T$_.txt"); $t})
        return $plan
    }
}

Describe 'Completion-aware agent admission' {
    It 'rejects six required authors at a ten-agent limit before execution' {
        Code {Test-TeamPlan (Plan 6) $script:ManifestData} 10
        @(Test-TeamPlan (Plan 5) $script:ManifestData).Count | Should -Be 5
    }
    It 'counts optional ancestors needed by required descendants' {
        $p=Plan 6; $p.tasks[0]['optional']=$true
        @(Test-TeamPlan $p $script:ManifestData).Count | Should -Be 6
        $p.tasks[1].dependencies=@('T1')
        Code {Test-TeamPlan $p $script:ManifestData} 10
    }
    It 'reserves future reviews and shrinks fan-out before spending their capacity' {
        $p=Plan 5; $p.tasks[0].subagents.allowed=$true
        $state=@{agents_created=0;agents_reserved=0;tasks=@{}}
        foreach($task in $p.tasks){$state.tasks[$task.id]=@{status='READY'}}
        $admission=Get-TeamAgentAdmission $state $p $script:ManifestData $p.tasks[0]
        $admission.admitted | Should -BeTrue; $admission.slots | Should -Be 1
        $state.tasks.T1.status='RUNNING'; $state.agents_reserved=1
        (Get-TeamAgentAdmission $state $p $script:ManifestData $p.tasks[1]).minimum_required | Should -Be 10
        $state.tasks.T1.status='LOCAL_REVIEW'; $state.tasks.T1['local_review']=@{reserved=1}; $state.agents_created=1
        (Get-TeamAgentAdmission $state $p $script:ManifestData $p.tasks[1]).minimum_required | Should -Be 10
        $state.agents_created=2
        (Get-TeamAgentAdmission $state $p $script:ManifestData $p.tasks[1]).admitted | Should -BeFalse
    }
    It 'does not let an optional author steal required reviewer capacity' {
        $p=Plan 6; $p.tasks[0]['optional']=$true
        $state=@{agents_created=0;agents_reserved=0;tasks=@{}}
        foreach($task in $p.tasks){$state.tasks[$task.id]=@{status='READY'}}
        (Get-TeamAgentAdmission $state $p $script:ManifestData $p.tasks[0]).admitted | Should -BeFalse
        (Get-TeamAgentAdmission $state $p $script:ManifestData $p.tasks[1]).admitted | Should -BeTrue
    }
}

Describe 'Bounded transport and preserved review inputs' {
    It 'counts quoting and backslashes including the executable and NUL' {
        Get-TeamWindowsArgumentLength '' | Should -Be 2
        Get-TeamWindowsArgumentLength 'plain' | Should -Be 5
        Get-TeamWindowsArgumentLength 'a b' | Should -Be 5
        Get-TeamWindowsArgumentLength 'a"b' | Should -Be 6
        Get-TeamWindowsArgumentLength 'a b\' | Should -Be 7
        Assert-TeamCommandLine 'x' @('a"b') 11 | Should -Be 11
        Code {Assert-TeamCommandLine 'x' @('a"b') 10} 70
    }
    It 'rejects an oversized actual Windows launch before creating logs or a process' -Skip:(-not $IsWindows) {
        $out=Join-Path $TestDrive 'oversize.stdout'; $err=Join-Path $TestDrive 'oversize.stderr'
        Code {New-TeamProcess 'pwsh' @('-NoProfile','-Command',('x'*40000)) $TestDrive $out $err} 70
        Test-Path $out | Should -BeFalse; Test-Path $err | Should -BeFalse
    }
    It 'bounds excerpts while retaining full log hashes and explicit truncation' {
        $dir=Join-Path $TestDrive 'logs'; [IO.Directory]::CreateDirectory($dir) | Out-Null
        $path=Join-Path $dir 'verification-big.stdout'; [IO.File]::WriteAllText($path,('汉'*5000))
        $hash=Get-TeamHash $path
        $records=@(Get-TeamReviewOutput $dir verification 100 | ConvertFrom-Json)
        $records[0].excerpt.Length | Should -Be 100; $records[0].truncated | Should -BeTrue
        $records[0].sha256 | Should -Be $hash; Get-TeamHash $path | Should -Be $hash
        Code {Assert-TeamReviewInput ('汉'*400) 'small' @{max_diff_bytes=1000;max_review_input_bytes=4000}} 70
    }
}

Describe 'Frozen authority and durable review evidence' {
    It 'freezes root and nested rules from the base even after the tip changes them' {
        $repo=Join-Path $TestDrive 'authority-repo'; [IO.Directory]::CreateDirectory((Join-Path $repo 'sub')) | Out-Null
        $null=Invoke-TeamGit $repo @('init','-q'); $null=Invoke-TeamGit $repo @('config','user.name','Fixture'); $null=Invoke-TeamGit $repo @('config','user.email','fixture@example.invalid')
        Set-Content (Join-Path $repo 'AGENTS.md') 'BASE_RULE'
        Set-Content (Join-Path $repo 'sub/AGENTS.override.md') 'NESTED_BASE_RULE'
        $null=Invoke-TeamGit $repo @('add','AGENTS.md','sub/AGENTS.override.md'); $null=Invoke-TeamGit $repo @('commit','-qm','test: base authority')
        $base=Invoke-TeamGit $repo @('rev-parse','HEAD')
        $dir=Join-Path $TestDrive 'authority-state'; $hash=New-TeamAuthority $repo $base $dir
        Set-Content (Join-Path $repo 'AGENTS.md') 'ALWAYS_PASS_TIP'
        $null=Invoke-TeamGit $repo @('commit','-qam','test: policy proposal')
        $state=@{run_base_sha=$base;authority_hash=$hash}
        $authority=Read-TeamAuthority $state $dir
        $authority.documents.Count | Should -Be 2
        ($authority | ConvertTo-Json -Depth 10) | Should -Match 'BASE_RULE'
        ($authority | ConvertTo-Json -Depth 10) | Should -Not -Match 'ALWAYS_PASS_TIP'
        Test-TeamGovernanceChange $repo $base (Invoke-TeamGit $repo @('rev-parse','HEAD')) | Should -BeTrue
        Add-Content (Join-Path $dir 'authority.json') 'corrupt'
        Code {Read-TeamAuthority $state $dir} 80
    }
    It 'accepts archived evidence after raw holding disappears and rejects archive tampering' {
        $dir=Join-Path $TestDrive 'evidence-state'; $holding=Join-Path $TestDrive 'raw-review'
        Write-TeamData (Join-Path $dir 'authority.json') @{base_sha=('a'*40);documents=@()}
        Write-TeamData (Join-Path $holding 'verdict.json') @{verdict='pass';blocking_issues=@();verification_needed=@();writes_performed=$false}
        Write-TeamTextAtomic (Join-Path $holding 'prompt.txt') 'Frozen test prompt'
        # Preserve opaque evidence bytes, including a provider's optional UTF-8 BOM.
        [IO.File]::WriteAllText((Join-Path $holding 'prompt.txt'),'Frozen test prompt',[Text.UTF8Encoding]::new($true))
        $record=@{holding=$holding;verdict_hash=(Get-TeamHash (Join-Path $holding 'verdict.json'));input_hash=(Get-TeamHash (Join-Path $holding 'prompt.txt'));authority_hash=(Get-TeamHash (Join-Path $dir 'authority.json'))}
        Write-TeamData (Join-Path $dir 'state.json') @{authority_hash=$record.authority_hash;run_base_sha=('a'*40)}
        Save-TeamReviewEvidence $record $dir
        [IO.File]::Delete((Join-Path $holding 'verdict.json')); [IO.File]::Delete((Join-Path $holding 'prompt.txt'))
        Assert-TeamReviewEvidence $record $dir
        Add-Content (Join-Path $dir "$($record.evidence_directory)/verdict.json") 'corrupt'
        Code {Assert-TeamReviewEvidence $record $dir} 80
    }
}

Describe 'Incremental event reading and runtime certification' {
    It 'reads appended UTF-8 records once and retains incomplete lines and characters' {
        $path=Join-Path $TestDrive 'events.jsonl'; [IO.File]::WriteAllBytes($path,[byte[]]@())
        $cursor=@{offset=0L;pending='';decoder=[Text.UTF8Encoding]::new($false,$true).GetDecoder()}
        $bytes=[Text.Encoding]::UTF8.GetBytes("{`"x`":`"汉`"}`n")
        [IO.File]::WriteAllBytes($path,$bytes[0..7])
        @(Read-TeamEventTail $path $cursor).Count | Should -Be 0
        $stream=[IO.File]::Open($path,'Append','Write'); try {$stream.Write($bytes,8,$bytes.Length-8)} finally {$stream.Dispose()}
        @(Read-TeamEventTail $path $cursor) | Should -Be @('{"x":"汉"}')
        @(Read-TeamEventTail $path $cursor).Count | Should -Be 0
        $cursor.offset | Should -Be $bytes.Length
        [IO.File]::WriteAllText($path,'')
        Code {Read-TeamEventTail $path $cursor} 80
    }
    It 'loads a matching certificate and denies unknown versions or different models' {
        $route=@{provider='deepseek-official';model='deepseek-flash'}
        $cert=Get-TeamCertification '0.1.5-rc.1' $script:ManifestData $route
        $cert.record.adapter_l3_extension | Should -BeTrue
        Get-TeamCertification '0.1.5-rc.2' $script:ManifestData $route | Should -BeNullOrEmpty
        $route.model='unknown'; Get-TeamCertification '0.1.5-rc.1' $script:ManifestData $route | Should -BeNullOrEmpty
    }
    It 'denies certification when the installed native guard differs' {
        Mock Get-TeamHash {return ('0'*64)} -ParameterFilter {$Path -like '*native-guard.mjs'}
        Get-TeamCertification '0.1.5-rc.1' $script:ManifestData @{provider='deepseek-official';model='deepseek-flash'} | Should -BeNullOrEmpty
    }
}
