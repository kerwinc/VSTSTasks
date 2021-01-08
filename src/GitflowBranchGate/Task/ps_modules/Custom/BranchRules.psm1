Function ConvertTo-Branches {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [System.Object]$Branches
  )
  Process {
    $result = @()
    if ($null -ne $Branches -and $Branches.Count -gt 0) {
      foreach ($branch in $Branches.Value) {
        $item = New-Object System.Object
        $item | Add-Member -Type NoteProperty -Name "BranchName" -Value $branch.name
        $item | Add-Member -Type NoteProperty -Name "Master" -Value $(New-Object psobject -Property @{Behind = $branch.behindCount; Ahead = $branch.aheadCount})
        
        $item | Add-Member -Type NoteProperty -Name "Develop" -Value @()
        $item | Add-Member -Type NoteProperty -Name "StaleDays" -Value (New-TimeSpan -Start $branch.commit.author.date -End (Get-Date)).Days
        $item | Add-Member -Type NoteProperty -Name "Modified" -Value (Get-Date $branch.commit.author.date)
        $item | Add-Member -Type NoteProperty -Name "ModifiedBy" -Value $branch.commit.author.name
        $item | Add-Member -Type NoteProperty -Name "ModifiedByEmail" -Value $branch.commit.author.email
        $item | Add-Member -Type NoteProperty -Name "IsBaseVersion" -Value $branch.isBaseVersion
  
        $item | Add-Member -Type NoteProperty -Name "SourcePullRequests" -Value 0
        $item | Add-Member -Type NoteProperty -Name "TargetPullRequests" -Value 0
        $item | Add-Member -Type NoteProperty -Name "PullRequests" -Value @()
  
        $item | Add-Member -Type NoteProperty -Name "Status" -Value "Valid"
        $item | Add-Member -Type NoteProperty -Name "SeverityThreshold" -Value "Info"
        $item | Add-Member -Type NoteProperty -Name "Errors" -Value @()
        $result += $item
      }
    }
    return $result
  }
}

Function ConvertTo-PullRequests {
  [CmdletBinding()]
  param(
    [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [System.Object]$PullRequests
  )
  Process {
    $result = @()
    if ($null -ne $PullRequests -and $PullRequests.Count -gt 0) {
      foreach ($pullRequest in $PullRequests.Value) {
        $item = New-Object System.Object
        $item | Add-Member -Type NoteProperty -Name "ID" -Value ([convert]::ToInt64($pullRequest.pullRequestId))
        $item | Add-Member -Type NoteProperty -Name "Title" -Value $pullRequest.title
        $item | Add-Member -Type NoteProperty -Name "SourceBranch" -Value $($pullRequest.sourceRefName.Replace("refs/heads/", ""))
        $item | Add-Member -Type NoteProperty -Name "TargetBranch" -Value $($pullRequest.targetRefName.Replace("refs/heads/", ""))
        $item | Add-Member -Type NoteProperty -Name "Created" -Value (Get-Date $pullRequest.creationDate)
        $item | Add-Member -Type NoteProperty -Name "CreatedBy" -Value $pullRequest.createdBy.displayName
        $item | Add-Member -Type NoteProperty -Name "Status" -Value $pullRequest.status
        $item | Add-Member -Type NoteProperty -Name "SeverityThreshold" -Value "Info"
        $item | Add-Member -Type NoteProperty -Name "Errors" -Value $null
        $result += $item
      }
    }
    return $result
  }
}

Function Add-Error {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [System.Object]$Branch,
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Info', 'Warning', 'Error')]
    [Parameter(ParameterSetName = 'List', Mandatory = $true)][string]$Type,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Message
  )
  Process {
    $branch.Errors += New-Object psobject -Property @{
      Type    = $Type
      Message = $Message
    }
  }
}

Function Add-DevelopCompare {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.Object]$Branches,
    [System.Object]$BranchesComparedToDevelop
  )
  Process {
    foreach ($branch in $Branches) {
      $branchToDevelop = @($BranchesComparedToDevelop | Where-Object {$_.name -eq $branch.BranchName })
      $branch.Develop = New-Object psobject -Property @{
        Behind = $branchToDevelop.behindCount
        Ahead  = $branchToDevelop.aheadCount
      }
    }
    return $Branches
  }
}

Function Add-PullRequests {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.Object]$Branches,
    [System.Object]$PullRequests
  )
  Process {
    if ($PullRequests -and $PullRequests.Count -gt 0 ) {
      foreach ($branch in $Branches) {

        [object[]]$branchPullRequests = $PullRequests | Where-Object {$_.SourceBranch -eq $branch.BranchName -or $_.TargetBranch -eq $branch.BranchName}
        foreach ($pullRequest in $branchPullRequests) {
          $branch.PullRequests += $pullRequest
        }

        $branch.SourcePullRequests = @($PullRequests | Where-Object {$_.SourceBranch -eq $branch.BranchName }).Count
        $branch.TargetPullRequests = @($PullRequests | Where-Object {$_.TargetBranch -eq $branch.BranchName }).Count
      }
    }
    return $Branches
  }
}

Function Invoke-BranchRules {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [System.Object]$Branches,
    [System.Object]$Build,
    [System.Object]$Rules
  )
  Process {

    [bool]$isPullRequestBuild = $Build.BuildReason -eq "PullRequest"
    
    foreach ($branch in $Branches) {
      
      if($branch.BranchName -like $Rules.BypassBranchesWithNameMatchingPattern) {
        Write-Verbose "$($branch.BranchName) bypassed from branch rules. Skipping rule checks"
        continue
      }

      [bool]$isCurrentPullRequest = ($branch.PullRequests | Where-Object { $_.Id -eq $Build.PullRequestId }).Count -gt 0
      
      if ($branch.BranchName -eq $Rules.MasterBranch) {
        if ($Rules.MasterMustNotHaveActivePullRequests -eq $true -and $branch.TargetPullRequests -gt 0 -and $isPullRequestBuild -eq $false) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request."
        }
        if ($Rules.MasterMustNotHaveActivePullRequests -eq $true -and $branch.SourcePullRequests -gt 0 -and $isPullRequestBuild -eq $false) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request targeting another branch."
        }
      }

      if ($branch.BranchName -eq $Rules.DevelopBranch) {
        if ($Rules.DevelopMustNotBeBehindMaster -eq $true -and $branch.Master.Behind -gt 0) {
          if ($isPullRequestBuild -ne $true -or $isCurrentPullRequest -ne $true) {
            $branch | Add-Error -Type Error -Message "$($branch.BranchName) is missing $($branch.Master.Behind) commit(s) from $($Rules.MasterBranch)"  
          }
          else {
            Write-Verbose "Rule Skipped: [DevelopMustNotBeBehindMaster]. Current build is was initiated from PR [$($Build.PullRequestId)]"
          }
        }
      }

      if ($branch.BranchName -like $Rules.HotfixPrefix) {
        if ($Rules.HotfixBranchLimit -lt $($Branches | Where-Object {$_.BranchName -like $Rules.HotfixPrefix}).Count) {
          $branch | Add-Error -Type Error -Message  "Hotfix branch limit reached"
        }
        if ($branch.StaleDays -gt $Rules.HotfixDaysLimit) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is stale and has reached hotfix days limit"
        }

        if ($Rules.MustNotHaveHotfixAndReleaseBranches -eq $true -and $($Branches | Where-Object {$_.BranchName -like $Rules.ReleasePrefix}).Count -gt 0) {
          $branch | Add-Error -Type Error -Message "Must not have hotfix and release branches at the same time"
        }

        if ($Rules.HotfixeBranchesMustNotBeBehindMaster -eq $true -and $branch.Master.Behind -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is missing $($branch.Master.Behind) commit(s) from $($Rules.MasterBranch)"
        }
        if ($Rules.HotfixBranchesMustNotHaveActivePullRequests -eq $true -and $branch.TargetPullRequests -gt 0 -and ($isPullRequestBuild -eq $false -or $isCurrentPullRequest -eq $false)) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request."
        }
        if ($Rules.HotfixBranchesMustNotHaveActivePullRequests -eq $true -and $branch.SourcePullRequests -gt 0 -and ($isPullRequestBuild -eq $false -or $isCurrentPullRequest -eq $false)) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request targeting another branch."
        }
      }

      if ($branch.BranchName -like $Rules.ReleasePrefix) {
        if ($Rules.ReleaseBranchLimit -lt $($Branches | Where-Object {$_.BranchName -like $Rules.ReleasePrefix}).Count) {
          $branch | Add-Error -Type Error -Message "Release branch limit reached"
        }
        if ($branch.StaleDays -gt $Rules.ReleaseDaysLimit) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is stale and has reached release days limit"
        }

        if ($Rules.MustNotHaveHotfixAndReleaseBranches -eq $true -and $($Branches | Where-Object {$_.BranchName -like $Rules.HotfixPrefix}).Count -gt 0) {
          $branch | Add-Error -Type Error -Message "Must not have hotfix and release branches at the same time"
        }

        if ($Rules.ReleaseBranchesMustNotBeBehindMaster -eq $true -and $branch.Master.Behind -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is missing $($branch.Master.Behind) commit(s) from $($Rules.MasterBranch)"
        }
        if ($Rules.ReleaseBranchesMustNotHaveActivePullRequests -eq $true -and $branch.TargetPullRequests -gt 0 -and ($isPullRequestBuild -eq $false -or $isCurrentPullRequest -eq $false)) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request."
        }
        if ($Rules.ReleaseBranchesMustNotHaveActivePullRequests -eq $true -and $branch.SourcePullRequests -gt 0 -and ($isPullRequestBuild -eq $false -or $isCurrentPullRequest -eq $false)) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request targeting another branch."
        }
      }

      if ($branch.BranchName -like $Rules.FeaturePrefix) {
        if ($Rules.FeatureBranchLimit -lt $($Branches | Where-Object {$_.BranchName -like $Rules.FeaturePrefix}).Count) {
          $branch | Add-Error -Type Error -Message "Feature branch limit reached"
        }
        if ($branch.StaleDays -gt $Rules.FeatureDaysLimit) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is stale and has reached feature days limit"
        }
        if ($branch.Develop.Behind -gt 0) {
          $type = "Warning"
          if ($Rules.FeatureBranchesMustNotBeBehindDevelop -eq $true) {
            $type = "Error"
          }
          if ($Rules.CurrentFeatureMustNotBeBehindDevelop -eq $true -and $branch.BranchName -eq $Build.SourceBranch) {
            $type = "Error"
          }
          if ($Rules.CurrentFeatureMustNotBeBehindDevelop -eq $true -and $isPullRequestBuild -eq $true -and $isCurrentPullRequest -eq $true -and $branch.SourcePullRequests -gt 0){
            $type = "Error"
          }
          $branch | Add-Error -Type $type -Message "$($branch.BranchName) is missing $($branch.Develop.Behind) commit(s) from $($Rules.DevelopBranch)"
        }

        if ($branch.Master.Behind -gt 0) {
          $type = "Warning"
          if ($Rules.FeatureBranchesMustNotBeBehindMaster -eq $true) {
            $type = "Error"
          }
          if ($Rules.CurrentFeatureMustNotBeBehindMaster -eq $true -and $branch.BranchName -eq $Build.SourceBranch) {
            $type = "Error"
          }
          if ($Rules.CurrentFeatureMustNotBeBehindMaster -eq $true -and $isPullRequestBuild -eq $true -and $isCurrentPullRequest -eq $true -and $branch.SourcePullRequests -gt 0){
            $type = "Error"
          }
          $branch | Add-Error -Type $type -Message "$($branch.BranchName) is missing $($branch.Master.Behind) commit(s) from $($Rules.MasterBranch)"
        }
      }

      if ($Rules.BranchNamesMustMatchConventions -eq $true) {
        if (($branch.BranchName -notlike $Rules.MasterBranch) -and ($branch.BranchName -notlike $Rules.DevelopBranch) -and ($branch.BranchName -notlike $Rules.HotfixPrefix) -and ($branch.BranchName -notlike $Rules.ReleasePrefix) -and ($branch.BranchName -notlike $Rules.FeaturePrefix)) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) branch does not follow naming convention i.e $($Rule.MasterBranch), $($Rules.DevelopBranch), $($Rules.HotfixPrefix), $($Rules.ReleasePrefix), $($Rules.FeaturePrefix)"
        }
      }

    }
    return $Branches
  }
}

Function Out-Errors {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [System.Object]$Branch,
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Info', 'Warning', 'Error')]
    [Parameter(ParameterSetName = 'List', Mandatory = $true)][string]$Type = "Error"
  )
  Process {
    [System.Object]$item = @()
    if ($branch.Errors.Count -gt 0) {
      foreach ($branchError in $($branch.Errors)) {
        if ($branchError.Type -eq $Type) {
          $item += New-Object psobject -Property @{
            Type       = $branchError.Type
            Message    = $branchError.Message
            BranchName = $branch.BranchName
          }  
        }
      }
    }
    return $item
  }
}

Function Write-OutputCurrentBranches {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][System.Object[]]$Branches
  )
  Process {
    Write-Output "------------------------------------------------------------------------------"
    Write-Output "Current Branches:"
    Write-Output "------------------------------------------------------------------------------"
    $Branches | Select-Object BranchName, @{Name = 'Master'; Expression = { "$($_.Master.Behind) | $($_.Master.Ahead)" }}, @{Name = 'Develop'; Expression = { "$($_.Develop.Behind) | $($_.Develop.Ahead)" }}, @{Name = 'Modified'; Expression = {Get-Date $_.Modified -Format 'dd-MMM-yyyy'}}, ModifiedBy, StaleDays, @{Name = 'Issues'; Expression = {$_.Errors.Count}} | Format-Table
  }
}

Function Write-OutputPullRequests {
  [CmdletBinding()]
  param(
    [Parameter()][System.Object[]]$PullRequests
  )
  Process {
    Write-Output "------------------------------------------------------------------------------"
    Write-Output "Active Pull Requests:"
    Write-Output "------------------------------------------------------------------------------"
    if ($PullRequests -ne $null -and $PullRequests.Count -gt 0) {
      $PullRequests | Select-Object ID, CreatedBy, SourceBranch, TargetBranch, @{Name = 'Created'; Expression = {Get-Date $_.Created -Format 'dd-MMM-yyyy'}} | Format-Table
    }
    else {
      Write-Output "There are no active Pull Requests at the moment..."
    }
  }
}

Function Write-OutputWarnings {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][System.Object[]]$Branches
  )
  Process {
    [System.Object[]]$warnings = $Branches | Out-Errors -Type Warning
    if ($warnings.Count -gt 0) {
      Write-Output "------------------------------------------------------------------------------"
      Write-Output "Warnings:"
      Write-Output "------------------------------------------------------------------------------"  
      foreach ($warning in $warnings) {
        Write-Warning "Gitflow Branch Gate: $($warning.Message)"
      }
    }
  }
}

Function Write-OutputSummary {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][System.Object[]]$Branches
  )
  Process {
    [System.Object[]]$errors = $Branches | Out-Errors -Type Error
    [System.Object[]]$warnings = $Branches | Out-Errors -Type Warning
   
    Write-Output "------------------------------------------------------------------------------"
    Write-Output "Branch Gate Summary:"
    Write-Output "Total Branches: $($branches.Count)"
    Write-Output "Warnings: $($warnings.Count)"
    Write-Output "Errors: $($errors.Count)"
    Write-Output "------------------------------------------------------------------------------"
  }
}

Function Write-OutputErrors {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][System.Object[]]$Branches
  )
  Process {
    [System.Object[]]$errors = $Branches | Out-Errors -Type Error 
    if ($errors.Count -gt 0) {
      Write-Output "------------------------------------------------------------------------------"
      Write-Output "Branches with Errors:"
      Write-Output "------------------------------------------------------------------------------"
      $Branches | Select-Object * -ExpandProperty Errors | Where-Object {$_.Type -eq "Error" } | Select-Object BranchName, Message | Sort-Object BranchName | Format-Table -Wrap
      Write-Error "Current branches did not pass the Gitflow Branch Gate rules."
    }
    else {
      Write-Output "Branches passed the Gitflow Branch Gate rules."
    }
  }
}

Function Invoke-ReportSummary {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][System.Object[]]$Branches,
    [Parameter(Mandatory = $true)][string]$TemplatePath,
    [Parameter(Mandatory = $true)][string]$ReportDestination,
    [Parameter(Mandatory = $true)][bool]$DisplayIssues
  )
  Process {
    [System.Object[]]$errors = $Branches | Out-Errors -Type Error
    [System.Object[]]$warnings = $Branches | Out-Errors -Type Warning

    $summaryContent = Get-Content -Path $TemplatePath

    $staleDaysMeasure = $Branches | Measure-Object -Property StaleDays -Minimum -Maximum -Average
    
    $summaryContent = $summaryContent.Replace("@@TotalBranches@@", $branches.Count)
    $summaryContent = $summaryContent.Replace("@@TotalWarnings@@", $warnings.Count)
    $summaryContent = $summaryContent.Replace("@@TotalErrors@@", $errors.Count)
    $summaryContent = $summaryContent.Replace("@@ActivePullRequests@@", $pullRequests.Count)
    $summaryContent = $summaryContent.Replace("@@MaxStaleDays@@", $staleDaysMeasure.Maximum)
    $summaryContent = $summaryContent.Replace("@@MinStaleDays@@", $staleDaysMeasure.Minimum)
    $summaryContent = $summaryContent.Replace("@@AvgStaleDays@@", $staleDaysMeasure.Average)
    
    $issues = "Not issues found"
    $gateResult = "<span style='color:#fff;Background-Color:#00c700;padding:5px 5px;'>Passed</span>"
    if ($errors.Count -gt 0) {
      $gateResult = "<span style='color:#fff;Background-Color:#e80303;padding:5px 8px;'>Failed</span>"

      if ($DisplayIssues -eq $true) {
        $issues = "### Issues:`n"
        foreach ($branchError in $errors) {
          $issues += "- $($branchError.Message)`n"
        }  
      }
      else {
        $issues = ""
      }
    }

    $summaryContent = $summaryContent.Replace("@@GateResult@@", $gateResult)
    $summaryContent = $summaryContent.Replace("@@Issues@@", $issues)

    Set-Content -Path $ReportDestination -Value $summaryContent
  }
}