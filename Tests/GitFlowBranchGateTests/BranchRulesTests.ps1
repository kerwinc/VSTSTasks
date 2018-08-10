$sut = 'BranchRules'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$assetsPath = Join-Path $here 'assets'
$sourcePath = Join-Path (Get-Item -Path $here).Parent.Parent.FullName "Tasks\GitflowBranchGate"
$modulesPath = Join-Path $sourcePath "Task\ps_modules\Custom"

Import-Module "$modulesPath\$sut.psm1" -Force -DisableNameChecking

function Get-DefaultRules {
  param (
  )
  return New-Object psobject -Property @{
    MasterBranch                                 = "master"
    DevelopBranch                                = "develop"
    HotfixPrefix                                 = "hotfix/*"
    ReleasePrefix                                = "release/*"
    FeaturePrefix                                = "feature/*"
    HotfixBranchLimit                            = 1
    HotfixDaysLimit                              = 10
    ReleaseBranchLimit                           = 1
    ReleaseDaysLimit                             = 10
    FeatureBranchLimit                           = 50
    FeatureDaysLimit                             = 45
    HotfixeBranchesMustNotBeBehindMaster         = $true
    ReleaseBranchesMustNotBeBehindMaster         = $true
    DevelopMustNotBeBehindMaster                 = $true
    FeatureBranchesMustNotBeBehindMaster         = $true
    FeatureBranchesMustNotBeBehindDevelop        = $true
    CurrentFeatureMustNotBeBehindDevelop         = $false
    CurrentFeatureMustNotBeBehindMaster          = $true
    MustNotHaveHotfixAndReleaseBranches          = $true
    MasterMustNotHaveActivePullRequests          = $true
    HotfixBranchesMustNotHaveActivePullRequests  = $true
    ReleaseBranchesMustNotHaveActivePullRequests = $true
    BranchNamesMustMatchConventions              = $true
  }
}

function Get-DefaultManualBuild { 
  return New-Object psobject -Property @{
    BuildId            = 1
    SourceBranch       = "master"
    BuildReason        = "Manual"
    PullRequestId      = 0
    RepositoryProvider = "Git"
  }
}

function Get-DefaultPullRequestBuild { 
  return New-Object psobject -Property @{
    BuildId            = 2
    SourceBranch       = "master"
    BuildReason        = "PullRequest"
    PullRequestId      = 1
    RepositoryProvider = "Git"
  }
}

Describe "BrandRules Module Tests" { 

  Context "Generic Tests" { 
    It "has a $sut.psm1 file" {
      "$modulesPath\$sut.psm1" | Should Exist
    }

    It "$sut is valid PowerShell code" {
      $psFile = Get-Content -Path "$modulesPath\$sut.psm1" -ErrorAction Stop
      $errors = $null;
      $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
      $errors.Count | Should Be 0
    }
  }
 
  Context "Default branch rules tests" {

    $branches = Get-Content "$assetsPath\Branches.defaults.json" | Out-String | ConvertFrom-Json
    $pullRequests = Get-Content "$assetsPath\PullRequests.empty.json" | Out-String | ConvertFrom-Json | ConvertTo-PullRequests

    It "Branches array should return 2 Branches" {
      $branches.Count | Should Be 2
    }
    
    It "should return 'refs/heads/develop' when passed default valid default branches" {
      $branches.Value[0].name | Should Be "refs/heads/develop"
    }

    It "should return 'refs/heads/master' when passed default valid default branches" {
      $branches.Value[1].name | Should Be "refs/heads/master"
    }

    It "Pull Request array should have 0 items" {
      $pullRequests.Count | Should be 0
    }
  }

  Context "When ConvertTo-PullRequestsPull is passed a PR from develop to master" { 
    $pullRequests = Get-Content "$assetsPath\PullRequests.DevelopToMaster.json" | Out-String | ConvertFrom-Json | ConvertTo-PullRequests

    It "should have 1 item in the array" {
      $pullRequests.Count | Should be 1
    }

    It "should have the correct data" {
      $pullRequests[0].ID | Should be 1
      $pullRequests[0].Title | Should be "developToMasterTest"
      $pullRequests[0].SourceBranch | Should be "develop"
      $pullRequests[0].TargetBranch | Should be "master"
      $pullRequests[0].CreatedBy | Should be "Kerwin Carpede"
      $pullRequests[0].Status | Should be "active"
      $pullRequests[0].SeverityThreshold | Should be "info"
      $pullRequests[0].Errors | Should be $null
    }

    It "should have the correct data types" {
      $pullRequests[0].ID | Should BeOfType ([long])
      $pullRequests[0].Title | Should BeOfType ([string])
      $pullRequests[0].SourceBranch | Should BeOfType ([string])
      $pullRequests[0].TargetBranch | Should BeOfType ([string])
      $pullRequests[0].Created | Should beoftype ([DateTime])
      $pullRequests[0].CreatedBy | Should BeOfType ([string])
      $pullRequests[0].Status | Should BeOfType ([string])
      $pullRequests[0].SeverityThreshold | Should BeOfType ([string])
    }
  }

  Context "When ConvertTo-Branches is passed 2 branches" {

    $branchStats = Get-Content "$assetsPath\Branches.Stats.MasterAsBase.json" | Out-String | ConvertFrom-Json | ConvertTo-Branches

    It "should have 8 items in the array" { 
      $branchStats.Count | Should be 8
    }

    It "should have the correct data types" { 
      $branchStats[0].BranchName | Should BeOfType ([string])
      $branchStats[0].Master | Should BeOfType ([System.Management.Automation.PSCustomObject])
      $branchStats[0].Develop | Should Be $null
      $branchStats[0].StaleDays | Should BeOfType ([int])
      $branchStats[0].Modified | Should BeOfType ([DateTime])
      $branchStats[0].ModifiedBy | Should BeOfType ([string])
      $branchStats[0].ModifiedByEmail | Should BeOfType ([string])
      $branchStats[0].IsBaseVersion | Should BeOfType ([bool])
      $branchStats[0].SourcePullRequests | Should BeOfType ([int])
      $branchStats[0].TargetPullRequests | Should BeOfType ([int])
      $branchStats[0].PullRequests | Should BeNullOrEmpty
      $branchStats[0].Status | Should BeOfType ([string])
      $branchStats[0].SeverityThreshold | Should BeOfType ([string])
      $branchStats[0].Errors | Should BeNullOrEmpty
    }

    It "should not return null branch when given correct data for master" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch | Should Not BeNullOrEmpty
    }

    It "should return 'master' for BranchName when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.BranchName | Should be "master"
    }

    It "should return 'Kerwin Carpede' for ModifiedBy when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.ModifiedBy | Should be "Kerwin Carpede"
    }

    It "should return 'kerwinc@videojunky.co.za' for ModifiedByEmail when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.ModifiedBy | Should be "Kerwin Carpede"
    }

    It "should return 0 for Master.Behind when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.Master.Behind | Should be 0
    }

    It "should return 0 for Master.Ahead when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.Master.Ahead | Should be 0
    }

    It "should return null for PullRequests when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.PullRequests | Should BeNullOrEmpty
    }

    It "should return true for IsBaseVersion when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.IsBaseVersion | Should BeTrue
    }

    It "should return 0 for SourcePullRequests when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.SourcePullRequests | Should be 0
    }

    It "should return 0 for TargetPullRequests when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.TargetPullRequests | Should be 0
    }

    It "should return 0 for Status when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.Status | Should be "Valid"
    }

    It "should return info for SeverityThreshold when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.SeverityThreshold | Should be "info"
    }

    It "should return null for Errors when given valid master branch" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      $branch.Errors | Should BeNullOrEmpty
    }

    It "should return 0 stale days when given correct data for master" { 
      $branch = $branchStats | Where-Object {$_.BranchName -eq "master"}
      # $branch.StaleDays | Should be 0
    }
  }

  Context "When Add-DevelopCompare is passed valid develop compare" { 

    $rules = Get-DefaultRules
    $build = Get-DefaultManualBuild
    [System.Object[]]$branches = Get-Content "$assetsPath\Branches.Stats.MasterAsBase.json" | Out-String | ConvertFrom-Json | ConvertTo-Branches
    [System.Object[]]$developBranchStats = (Get-Content "$assetsPath\Branches.Stats.DevelopAsBase.json" | Out-String | ConvertFrom-Json).Value

    It "should return 5 aheadfor feature/feature1 (develop comapre)" { 
      $branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $developBranchStats
      $branch = $branches | Where-Object {$_.BranchName -eq "feature/Feature1"}
      $branch.Develop.Ahead | Should Be 5
    }

    It "should return 1 behind for feature/feature1 (develop comapre)" { 
      $branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $developBranchStats
      $branch = $branches | Where-Object {$_.BranchName -eq "feature/Feature1"}
      $branch.Develop.Behind | Should Be 1
    }

    It "should return 20 ahead for develop (develop comapre)" { 
      $branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $developBranchStats
      $branch = $branches | Where-Object {$_.BranchName -eq "develop"}
      $branch.Develop.Ahead | Should Be 20
    }

    It "should return 0 behind for develop (develop comapre)" { 
      $branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $developBranchStats
      $branch = $branches | Where-Object {$_.BranchName -eq "develop"}
      $branch.Develop.Behind | Should Be 0
    }

    It "should return 0 behind for release/release1 (develop comapre)" { 
      $branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $developBranchStats
      $branch = $branches | Where-Object {$_.BranchName -eq "release/release1"}
      $branch.Develop.Behind | Should Be 1
    }

    It "should return 0 ahead for release/release1 (develop comapre)" { 
      $branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $developBranchStats
      $branch = $branches | Where-Object {$_.BranchName -eq "release/release1"}
      $branch.Develop.Ahead | Should Be 5
    }

  }

  Context "When Add-PullRequests is passed valid list of active PRs" { 

    [System.Object[]]$branches = Get-Content "$assetsPath\Branches.Stats.MasterAsBase.json" | Out-String | ConvertFrom-Json | ConvertTo-Branches
    $pullRequests = Get-Content "$assetsPath\PullRequests.DevelopToMaster.json" | Out-String | ConvertFrom-Json | ConvertTo-PullRequests
    
    It "should return 1 TargetPullRequests for master" { 
      $branches = Add-PullRequests -Branches $branches -PullRequests $pullRequests
      $branch = $branches | Where-Object {$_.BranchName -eq "master"}
      $branch.TargetPullRequests | Should Be 1
    }

    It "should return 0 SourcePullRequests for master" { 
      $branches = Add-PullRequests -Branches $branches -PullRequests $pullRequests
      $branch = $branches | Where-Object {$_.BranchName -eq "master"}
      $branch.SourcePullRequests | Should Be 0
    }

  }

}

Describe "Default Rules with Invalid Branche Stats Tests" { 
  
  function _getConextBranches {
  
    [System.Object[]]$branches = Get-Content "$assetsPath\Branches.Stats.MasterAsBase.json" | Out-String | ConvertFrom-Json | ConvertTo-Branches
    [System.Object[]]$developBranchStats = (Get-Content "$assetsPath\Branches.Stats.DevelopAsBase.json" | Out-String | ConvertFrom-Json).Value
    $pullRequests = Get-Content "$assetsPath\PullRequests.DevelopToMaster.json" | Out-String | ConvertFrom-Json | ConvertTo-PullRequests
    $branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $developBranchStats
    $branches = Add-PullRequests -Branches $branches -PullRequests $pullRequests

    return $branches
  }

  Context "When default rules set and validing master" { 

    It "should return 'has an active Pull Request' Error when master has an active PR" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "master"} | Foreach {
        $_.TargetPullRequests = 1
        $_.SourcePullRequests = 0
      }
      $build = Get-DefaultPullRequestBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "master"}

      #Assert
      $branch.TargetPullRequests | Should Be 1
      $branch.SourcePullRequests | Should Be 0
      $branch.Errors.Count | Should be 0
    }

    It "should return 'has an active Pull Request targeting another branch' error when SourcePullRequests=1 and NOT PR build" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "master"} | Foreach {
        $_.TargetPullRequests = 0
        $_.SourcePullRequests = 1
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "master"}

      #Assert
      $branch.TargetPullRequests | Should Be 0
      $branch.SourcePullRequests | Should Be 1
      $branch.Errors.Count | Should Be 1
      $branch.Errors[0].Message | Should BeLike "*has an active Pull Request targeting another branch*"
    }

    It "should return 0 errors when master has an active PR and build trigger is manual" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $build = Get-DefaultManualBuild
      
      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "master"}

      #Assert
      $rules.MasterBranch | Should Be "master"
      $branch.Errors | Should Not BeNullOrEmpty
      $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request."} | Should Not BeNullOrEmpty
    }
    
  }
  
  Context "When custom rules set and validing master" { 

    It "should have 0 errors if master has an active PR and MasterMustNotHaveActivePullRequests is false" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.MasterMustNotHaveActivePullRequests = $false
      $branches = _getConextBranches
      $build = Get-DefaultPullRequestBuild
      
      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "master"}

      #Assert
      $rules.MasterMustNotHaveActivePullRequests | Should Be $false
      $rules.MasterBranch | Should Be "master"
      $branch.Errors | Should BeNullOrEmpty
    }
    
  }

}