Function ConvertTo-Branches {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [System.Object]$Branches
  )
  Process {
    $result = @()
    foreach ($branch in $Branches) {
      $item = New-Object System.Object
      $item | Add-Member -Type NoteProperty -Name "BranchName" -Value $branch.name
      $item | Add-Member -Type NoteProperty -Name "Master" -Value $(New-Object psobject -Property @{Behind = $branch.behindCount; Ahead = $branch.aheadCount})
      
      # $item | Add-Member -Type NoteProperty -Name "Ahead" -Value $branch.aheadCount
      # $item | Add-Member -Type NoteProperty -Name "Behind" -Value $branch.behindCount
      $item | Add-Member -Type NoteProperty -Name "Develop" -Value @()
      $item | Add-Member -Type NoteProperty -Name "StaleDays" -Value (New-TimeSpan -Start $branch.commit.author.date -End (Get-Date)).Days
      $item | Add-Member -Type NoteProperty -Name "Modified" -Value $branch.commit.author.date
      $item | Add-Member -Type NoteProperty -Name "ModifiedBy" -Value $branch.commit.author.name
      $item | Add-Member -Type NoteProperty -Name "ModifiedByEmail" -Value $branch.commit.author.email
      $item | Add-Member -Type NoteProperty -Name "IsBaseVersion" -Value $branch.isBaseVersion

      $item | Add-Member -Type NoteProperty -Name "SourcePullRequests" -Value 0
      $item | Add-Member -Type NoteProperty -Name "TargetPullRequests" -Value 0

      $item | Add-Member -Type NoteProperty -Name "Status" -Value "Valid"
      $item | Add-Member -Type NoteProperty -Name "SeverityThreshold" -Value "Info"
      $item | Add-Member -Type NoteProperty -Name "Errors" -Value @()
      $result += $item
    }
    return $result
  }
}

Function ConvertTo-PullRequests {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [System.Object]$PullRequests
  )
  Process {
    $result = @()
    foreach ($pullRequest in $PullRequests) {
      $item = New-Object System.Object
      $item | Add-Member -Type NoteProperty -Name "ID" -Value $pullRequest.pullRequestId
      $item | Add-Member -Type NoteProperty -Name "SourceBranch" -Value $($pullRequest.sourceRefName.Replace("refs/heads/", ""))
      $item | Add-Member -Type NoteProperty -Name "TargetBranch" -Value $($pullRequest.targetRefName.Replace("refs/heads/", ""))
      $item | Add-Member -Type NoteProperty -Name "Created" -Value $pullRequest.creationDate
      # $item | Add-Member -Type NoteProperty -Name "CreatedBy" -Value $pullRequest.

      $item | Add-Member -Type NoteProperty -Name "Status" -Value $pullRequest.status
      $item | Add-Member -Type NoteProperty -Name "SeverityThreshold" -Value "Info"
      $item | Add-Member -Type NoteProperty -Name "Errors" -Value $null
      $result += $item
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
    [System.Object]$Rules,
    [string]$CurrentBranchName
  )
  Process {
    $baseBranch = $Branches | Where-Object { $_.IsBaseVersion -eq "True" }

    foreach ($branch in $Branches) {

      if ($branch.BranchName -eq $Rules.MasterBranch) {
        if ($Rules.MasterMustNotHaveActivePullRequests -eq $true -and $branch.TargetPullRequests -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request. Master must not have any pending Pull Requests"
        }
        if ($Rules.MasterMustNotHaveActivePullRequests -eq $true -and $branch.SourcePullRequests -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request targeting another branch. Master must not have any pending Pull Requests"
        }
      }

      if ($branch.BranchName -eq $Rules.DevelopBranch) {
        if ($Rules.DevelopMustNotBeBehindMaster -eq $true -and $branch.Master.Behind -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is missing $($branch.Behind) commit(s) from $($baseBranch.BranchName)"
        }
      }

      if ($branch.BranchName -like $Rules.HotfixPrefix) {
        if ($Rules.HotfixBranchLimit -lt $($Branches | Where-Object {$_.BranchName -like $Rules.HotfixPrefix}).Count) {
          $branch | Add-Error -Type Error -Message  "Hotfix branch limit reached"
        }
        if ($branch.StaleDays -gt $Rules.HotfixDaysLimit) {
          $branch | Add-Error -Type Error -Message "Hotfix branch days limit reached (stale branch)"
        }
        if ($Rules.HotfixeBranchesMustNotBeBehindMaster -eq $true -and $branch.Master.Behind -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is missing $($branch.Behind) commit(s) from $($baseBranch.BranchName)"
        }
        if ($Rules.HotfixBranchesMustNotHaveActivePullRequests -eq $true -and $branch.TargetPullRequests -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request. Hotfix branches must not have any pending Pull Requests"
        }
        if ($Rules.HotfixBranchesMustNotHaveActivePullRequests -eq $true -and $branch.SourcePullRequests -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request targeting another branch. Hotfix branches must not have any pending Pull Requests"
        }
      }

      if ($branch.BranchName -like $Rules.ReleasePrefix) {
        if ($Rules.ReleaseBranchLimit -lt $($Branches | Where-Object {$_.BranchName -like $Rules.ReleasePrefix}).Count) {
          $branch | Add-Error -Type Error -Message "Release branch limit reached"
        }
        if ($branch.StaleDays -gt $Rules.ReleaseDaysLimit) {
          $branch | Add-Error -Type Error -Message "Release branch days limit reached (stale branch)"
        }
        if ($Rules.ReleaseBranchesMustNotBeBehindMaster -eq $true -and $branch.Master.Behind -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is missing $($branch.Master.Behind) commit(s) from $($baseBranch.BranchName)"
        }
        if ($Rules.ReleaseBranchesMustNotHaveActivePullRequests -eq $true -and $branch.TargetPullRequests -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request. Release branches must not have any pending Pull Requests"
        }
        if ($Rules.ReleaseBranchesMustNotHaveActivePullRequests -eq $true -and $branch.SourcePullRequests -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) has an active Pull Request targeting another branch. Release branches must not have any pending Pull Requests"
        }
      }

      if ($branch.BranchName -like $Rules.FeaturePrefix) {
        if ($Rules.FeatureBranchLimit -lt $($Branches | Where-Object {$_.BranchName -like $Rules.FeaturePrefix}).Count) {
          $branch | Add-Error -Type Error -Message "Feature branch limit reached"
        }
        if ($branch.StaleDays -gt $Rules.FeatureDaysLimit) {
          $branch | Add-Error -Type Error -Message "Feature branch days limit reached (stale branch)"
        }
        if ($Rules.FeatureBranchesMustNotBeBehindMaster -eq $true -and $branch.Master.Behind -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is missing $($branch.Master.Behind) commit(s) from $($baseBranch.BranchName)"
        }
        if ($branch.Develop.Behind -gt 0) {
          $type = "Warning"
          if ($Rules.FeatureBranchesMustNotBeBehindDevelop -eq $true) {
            $type = "Error"
          }
          if ($Rules.CurrentFeatureMustNotBeBehindDevelop -eq $true -and $branch.BranchName -eq $CurrentBranchName) {
            $type = "Error"
          }
          $branch | Add-Error -Type $type -Message "$($branch.BranchName) is missing $($branch.Develop.Behind) commit(s) from develop"  
        }
      }

      if ($Rules.BranchNamesMustMatchConventions -eq $true) {
        if (($branch.BranchName -notlike $Rules.MasterBranch) -and ($branch.BranchName -notlike $Rules.DevelopBranch) -and ($branch.BranchName -notlike $Rules.HotfixPrefix) -and ($branch.BranchName -notlike $Rules.ReleasePrefix) -and ($branch.BranchName -notlike $Rules.FeaturePrefix)) {
          $branch | Add-Error -Type $type -Message "$($branch.BranchName) does not follow naming convention i.e $($Rule.MasterBranch), $($Rule.DevelopBranch), $($Rule.HotfixPrefix), $($Rule.ReleasePrefix), $($Rule.FeaturePrefix)"
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
    $item = @()
    if ($branch.Errors.Count -gt 0) {
      foreach($branchError in $($branch.Errors))
      {
        if ($branchError.Type -eq $Type) {
          $item += New-Object psobject -Property @{
            Type = $branchError.Type
            Message = $branchError.Message
            BranchName = $branch.BranchName
          }  
        }
      }
    }
    return $item
  }
}