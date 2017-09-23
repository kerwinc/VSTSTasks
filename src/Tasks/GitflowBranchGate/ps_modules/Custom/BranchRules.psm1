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
      $item | Add-Member -Type NoteProperty -Name "Ahead" -Value $branch.aheadCount
      $item | Add-Member -Type NoteProperty -Name "Behind" -Value $branch.behindCount
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
    # foreach ($branch in $Branches) {
    #   $item = New-Object psobject -Property @{
    #     BranchName = $branch.name
    #     Ahead = $branch.aheadCount
    #     Behind = $branch.behindCount
    #     Modified = $branch.commit.author.date
    #     ModifiedBy = $branch.commit.author.name
    #     ModifiedByEmail = $branch.commit.author.email
    #     IsBaseVersion = $branch.isBaseVersion
    #     SourcePullRequests = 0
    #     TargetPullRequests = 0
    #     Status = $null
    #     SeverityThreshold = "Info"
    #     Error = @()
    #   }
    #   $result += $item
    # }
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

Function Invoke-BranchCommitRules {
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

      if ($branch.BranchName -like $Rules.HotfixPrefix) {
        if ($Rules.HotfixBranchLimit -lt $($Branches | Where-Object {$_.BranchName -like $Rules.HotfixPrefix}).Count) {
          $branch | Add-Error -Type Error -Message  "Hotfix branch limit reached"
        }
        if ($branch.StaleDays -gt $Rules.HotfixDaysLimit) {
          $branch | Add-Error -Type Error -Message "Hotfix branch days limit reached (stale branch)"
        }
        if ($Rules.HotfixeBranchesMustNotBeBehindMaster -eq $true -and $branch.Behind -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is missing $($branch.Behind) commits from $($baseBranch.BranchName)"
        }
      }

      if ($branch.BranchName -like $Rules.ReleasePrefix) {
        if ($Rules.ReleaseBranchLimit -lt $($Branches | Where-Object {$_.BranchName -like $Rules.ReleasePrefix}).Count) {
          $branch | Add-Error -Type Error -Message "Release branch limit reached"
        }
        if ($branch.StaleDays -gt $Rules.ReleaseDaysLimit) {
          $branch | Add-Error -Type Error -Message "Release branch days limit reached (stale branch)"
        }
        if ($Rules.ReleaseBranchesMustNotBeBehindMaster -eq $true -and $branch.Behind -gt 0) {
          $branch | Add-Error -Type Error -Message "$($branch.BranchName) is missing $($branch.Behind) commits from $($baseBranch.BranchName)"
        }
      }

      if ($branch.BranchName -like $Rules.FeaturePrefix) {
        if ($Rules.FeatureBranchLimit -lt $($Branches | Where-Object {$_.BranchName -like $Rules.FeaturePrefix}).Count) {
          $branch | Add-Error -Type Error -Message "Feature branch limit reached"
        }
        if ($branch.StaleDays -gt $Rules.FeatureDaysLimit) {
          $branch | Add-Error -Type Error -Message "Feature branch days limit reached (stale branch)"
        }
      }

      Write-Verbose "Checking if any branches are behind master"
      # if ($branch.Behind -gt 0) {
      #   $branch.status = "Invalid"
      #   if ($branch.BranchName -like $CurrentBranchName) {
      #     $branch.SeverityThreshold = "Error"
      #   }
      #   else {
      #     $branch.SeverityThreshold = "Warning"
      #   }
      #   $branch.Errors += "$($branch.BranchName) is missing $($branch.Behind) commits from $($baseBranch.BranchName)"
      # }
      # else {
      #   $branch.Status = "Valid"
      # }
    }
    return $Branches
  }
}

Function Invoke-LimitRules {
  [CmdletBinding()]
  param(
    # [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Parameter(Mandatory = $true)]
    [System.Object]$Branches,
    [string]$CurrentBranchName
  )
  Process {
    $baseBranch = $Branches | Where-Object { $_.IsBaseVersion -eq "True" }

    foreach ($branch in $Branches) {
      if ($branch.Behind -gt 0) {
        $branch.status = "Invalid"
        if ($branch.BranchName -like $CurrentBranchName) {
          $branch.SeverityThreshold = "Error"
        }
        else {
          $branch.SeverityThreshold = "Warning"
        }
        $branch.Errors += "$($branch.BranchName) is missing $($branch.Behind) commits from $($baseBranch.BranchName)"
      }
    }
    return $Branches
  }
}