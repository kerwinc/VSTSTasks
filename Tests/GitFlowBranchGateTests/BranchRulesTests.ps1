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

Describe "Invoke-BranchRules Tests" { 
  
  function _getConextBranches {
  
    [System.Object[]]$branches = Get-Content "$assetsPath\Branches.Stats.MasterAsBase.json" | Out-String | ConvertFrom-Json | ConvertTo-Branches
    [System.Object[]]$developBranchStats = (Get-Content "$assetsPath\Branches.Stats.DevelopAsBase.json" | Out-String | ConvertFrom-Json).Value
    $pullRequests = Get-Content "$assetsPath\PullRequests.DevelopToMaster.json" | Out-String | ConvertFrom-Json | ConvertTo-PullRequests
    $branches = Add-DevelopCompare -Branches $branches -BranchesComparedToDevelop $developBranchStats
    $branches = Add-PullRequests -Branches $branches -PullRequests $pullRequests

    return $branches
  }

  Context "When Invoke-BranchRules is executed and validating master" {

    It "should return 'has an active Pull Request' error when master has an active PR" { 
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

    It "should return 'has an active Pull Request' error when master has an active PR and renamed master" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.MasterBranch = "AlternateMaster"
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "master"} | Foreach {
        $_.BranchName = "AlternateMaster"
      }
      $build = Get-DefaultPullRequestBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "AlternateMaster"}

      #Assert
      $branch.BranchName | Should Be "AlternateMaster"
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

  Context "When Invoke-BranchRules is executed and validating develop" { 

    It "should return 'develop is missing 3 commit(s) from master' Error when develop is behind master with default rules" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "develop"}

      #Assert
      $branch.Errors.Count | Should be 1
      $branch.Errors[0].Message | Should BeLike "*develop is missing 3 commit(s) from master"
    }

    It "should return 'AlternateDevelop is missing 3 commit(s) from master' Error when develop is behind master and renamed develop branch" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.DevelopBranch = "AlternateDevelop"
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "develop"} | Foreach {
        $_.BranchName = "AlternateDevelop"
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "AlternateDevelop"}

      #Assert
      $branch.BranchName | Should Be "AlternateDevelop"
      $branch.Errors.Count | Should be 1
      $branch.Errors[0].Message | Should BeLike "*develop is missing 3 commit(s) from master"
    }

    It "should return no errors when develop is NOT behind master and Rules.DevelopMustNotBeBehindMaster is true" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "develop"} | Foreach {
        $_.Master.Behind = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "develop"}

      #Assert
      $branch.Errors.Count | Should be 0
    }

    It "should return no errors when develop is behind master and PR Build" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $build = Get-DefaultPullRequestBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "develop"}

      #Assert
      $branch.Errors.Count | Should be 0
    }

    It "should return no errors when develop is behind master and Rules.DevelopMustNotBeBehindMaster is false" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.DevelopMustNotBeBehindMaster = $false
      $branches = _getConextBranches
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "develop"}

      #Assert
      $branch.Errors.Count | Should be 0
    }
    
  }
  
  Context "When Invoke-BranchRules is executed and validating hotfix branches" { 

    It "should return 'Hotfix branch limit reached' error when multiple hotfix branches and HotfixBranchLimit is 1" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "hotfix/*"} | Foreach {
        $_.Master.Behind = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $hotfixBranches = $branches | Where-Object {$_.BranchName -like "hotfix/*"}

      #Assert
      $hotfixBranches.Count | Should Be 2
      foreach ($branch in $hotfixBranches) {
        $branch.Errors | Where-Object {$_.Message -eq "Hotfix branch limit reached"} | Should Not BeNullOrEmpty
        $branch.Errors[0].Message | Should BeLike "Hotfix branch limit reached"
      }
    }

    It "should return 'is stale and has reached hotfix days limit' error when hotfix branche is stale" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "hotfix/hotfix1"} | Foreach {
        $_.StaleDays = 11
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "hotfix/hotfix1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*is stale and has reached hotfix days limit"} | Should Not BeNullOrEmpty
    }

    It "should return 'Must not have hotfix and release branches at the same time' error when there are hotfix & release branches" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.MustNotHaveHotfixAndReleaseBranches = $true
      $branches = _getConextBranches
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $hotfixBranches = $branches | Where-Object {$_.BranchName -like "hotfix/*"}

      #Assert
      $hotfixBranches.Count | Should Be 2
      foreach ($branch in $hotfixBranches) {
        $branch.Errors | Where-Object {$_.Message -eq "Must not have hotfix and release branches at the same time"} | Should Not BeNullOrEmpty
      }
    }

    It "should NOT return 'Must not have hotfix and release branches at the same time' error when there are hotfix & release branches and MustNotHaveHotfixAndReleaseBranches is false" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.MustNotHaveHotfixAndReleaseBranches = $false
      $branches = _getConextBranches
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $hotfixBranches = $branches | Where-Object {$_.BranchName -like "hotfix/*"}

      #Assert
      $hotfixBranches.Count | Should Be 2
      foreach ($branch in $hotfixBranches) {
        $branch.Errors | Where-Object {$_.Message -eq "Must not have hotfix and release branches at the same time"} | Should BeNullOrEmpty
      }
    }
    
    It "should return 'hotfix is missing 100 commit(s) from master' error when hotfix1 is behind master" {
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "hotfix/hotfix1"} | Foreach {
        $_.Master.Behind = 100
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "hotfix/hotfix1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*hotfix1 is missing 100 commit(s) from master"} | Should Not BeNullOrEmpty
    }

    It "should NOT return 'hotfix is missing 100 commit(s) from master' error when hotfix1 is behind master and HotfixeBranchesMustNotBeBehindMaster is false" {
      # Arrange
      $rules = Get-DefaultRules
      $rules.HotfixeBranchesMustNotBeBehindMaster = $false
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "hotfix/hotfix1"} | Foreach {
        $_.Master.Behind = 100
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "hotfix/hotfix1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*hotfix1 is missing 100 commit(s) from master"} | Should BeNullOrEmpty
    }

    It "should return 'hotfix has an active Pull Request.' error when hotfix1 has an active PR" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "hotfix/*"} | Foreach {
        $_.TargetPullRequests = 1
        $_.SourcePullRequests = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $hotfixBranches = $branches | Where-Object {$_.BranchName -like "hotfix/*"}

      #Assert
      $hotfixBranches.Count | Should Be 2
      foreach ($branch in $hotfixBranches) {
        $branch.TargetPullRequests | Should Be 1
        $branch.SourcePullRequests | Should Be 0  
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request."} | Should Not BeNullOrEmpty
      }
    }

    It "should return NOT 'hotfix has an active Pull Request.' error when hotfix has an active PR and HotfixBranchesMustNotHaveActivePullRequests is false" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.HotfixBranchesMustNotHaveActivePullRequests = $false
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "hotfix/*"} | Foreach {
        $_.TargetPullRequests = 1
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $hotfixBranches = $branches | Where-Object {$_.BranchName -like "hotfix/*"}

      #Assert
      $hotfixBranches.Count | Should Be 2
      foreach ($branch in $hotfixBranches) {
        $branch.TargetPullRequests | Should Be 1
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request."} | Should BeNullOrEmpty
      }
    }

    It "should NOT return 'hotfix has an active Pull Request.' error when hotfix has an no active PRs" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "hotfix/*"} | Foreach {
        $_.TargetPullRequests = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $hotfixBranches = $branches | Where-Object {$_.BranchName -like "hotfix/*"}

      #Assert
      $hotfixBranches.Count | Should Be 2
      foreach ($branch in $hotfixBranches) {
        $branch.TargetPullRequests | Should Be 0  
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request."} | Should BeNullOrEmpty
      }
    }

    It "should return 'hotfix has an active Pull Request targeting another branch.' error when hotfix has an active PR" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "hotfix/*"} | Foreach {
        $_.SourcePullRequests = 1
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $hotfixBranches = $branches | Where-Object {$_.BranchName -like "hotfix/*"}

      #Assert
      $hotfixBranches.Count | Should Be 2
      foreach ($branch in $hotfixBranches) {
        $branch.SourcePullRequests | Should Be 1 
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request targeting another branch."} | Should Not BeNullOrEmpty
      }
    }

    It "should NOT return 'hotfix has an active Pull Request targeting another branch.' error when hotfix has an active PR and HotfixBranchesMustNotHaveActivePullRequests is false" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.HotfixBranchesMustNotHaveActivePullRequests = $false
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "hotfix/*"} | Foreach {
        $_.SourcePullRequests = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $hotfixBranches = $branches | Where-Object {$_.BranchName -like "hotfix/*"}

      #Assert
      $hotfixBranches.Count | Should Be 2
      foreach ($branch in $hotfixBranches) {
        $branch.SourcePullRequests | Should Be 0
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request targeting another branch."} | Should BeNullOrEmpty
      }
    }

    It "should NOT return 'hotfix has an active Pull Request targeting another branch.' error when hotfix has NO active PRs" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "hotfix/*"} | Foreach {
        $_.SourcePullRequests = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $hotfixBranches = $branches | Where-Object {$_.BranchName -like "hotfix/*"}

      #Assert
      $hotfixBranches.Count | Should Be 2
      foreach ($branch in $hotfixBranches) {
        $branch.SourcePullRequests | Should Be 0
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request targeting another branch."} | Should BeNullOrEmpty
      }
    }

  }

  Context "When Invoke-BranchRules is executed and validating release branches" { 

    It "should return 'Release branch limit reached' error when multiple release branches and ReleaseBranchLimit is 1" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "release/*"} | Foreach {
        $_.Master.Behind = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $releaseBranches = $branches | Where-Object {$_.BranchName -like "release/*"}

      #Assert
      $releaseBranches.Count | Should Be 2
      foreach ($branch in $releaseBranches) {
        $branch.Errors | Where-Object {$_.Message -eq "Release branch limit reached"} | Should Not BeNullOrEmpty
      }
    }

    It "should return 'Release1 is stale and has reached hotfix days limit' error when release branch is stale" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "release/release1"} | Foreach {
        $_.StaleDays = 11
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "release/release1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*is stale and has reached release days limit"} | Should Not BeNullOrEmpty
    }

    It "should return 'Must not have hotfix and release branches at the same time' error when there are hotfix & release branches" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.MustNotHaveHotfixAndReleaseBranches = $true
      $branches = _getConextBranches
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $releaseBranches = $branches | Where-Object {$_.BranchName -like "release/*"}

      #Assert
      $releaseBranches.Count | Should Be 2
      foreach ($branch in $releaseBranches) {
        $branch.Errors | Where-Object {$_.Message -eq "Must not have hotfix and release branches at the same time"} | Should Not BeNullOrEmpty
      }
    }

    It "should NOT return 'Must not have hotfix and release branches at the same time' error when there are hotfix & release branches and MustNotHaveHotfixAndReleaseBranches is false" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.MustNotHaveHotfixAndReleaseBranches = $false
      $branches = _getConextBranches
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $releaseBranches = $branches | Where-Object {$_.BranchName -like "release/*"}

      #Assert
      $releaseBranches.Count | Should Be 2
      foreach ($branch in $releaseBranches) {
        $branch.Errors | Where-Object {$_.Message -eq "Must not have hotfix and release branches at the same time"} | Should BeNullOrEmpty
      }
    }
    
    It "should return 'release is missing 50 commit(s) from master' error when release1 is behind master" {
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "release/release1"} | Foreach {
        $_.Master.Behind = 50
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "release/release1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*release1 is missing 50 commit(s) from master"} | Should Not BeNullOrEmpty
    }

    It "should NOT return 'release1 is missing 50 commit(s) from master' error when release1 is behind master and HotfixeBranchesMustNotBeBehindMaster is false" {
      # Arrange
      $rules = Get-DefaultRules
      $rules.ReleaseBranchesMustNotBeBehindMaster = $false
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "release/release1"} | Foreach {
        $_.Master.Behind = 50
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "release/release1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*release1 is missing 50 commit(s) from master"} | Should BeNullOrEmpty
    }

    It "should return 'release has an active Pull Request.' error when release has an active PR" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "release/*"} | Foreach {
        $_.TargetPullRequests = 1
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $releaseBranches = $branches | Where-Object {$_.BranchName -like "release/*"}

      #Assert
      $releaseBranches.Count | Should Be 2
      foreach ($branch in $releaseBranches) {
        $branch.TargetPullRequests | Should Be 1
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request."} | Should Not BeNullOrEmpty
      }
    }

    It "should return NOT 'release has an active Pull Request.' error when release has an active PR and ReleaseBranchesMustNotHaveActivePullRequests is false" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.ReleaseBranchesMustNotHaveActivePullRequests = $false
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "release/*"} | Foreach {
        $_.TargetPullRequests = 1
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $releaseBranches = $branches | Where-Object {$_.BranchName -like "release/*"}

      #Assert
      $releaseBranches.Count | Should Be 2
      foreach ($branch in $releaseBranches) {
        $branch.TargetPullRequests | Should Be 1
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request."} | Should BeNullOrEmpty
      }
    }

    It "should NOT return 'hotfix has an active Pull Request.' error when hotfix has an no active PRs" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "release/*"} | Foreach {
        $_.TargetPullRequests = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $releaseBranches = $branches | Where-Object {$_.BranchName -like "release/*"}

      #Assert
      $releaseBranches.Count | Should Be 2
      foreach ($branch in $releaseBranches) {
        $branch.TargetPullRequests | Should Be 0
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request."} | Should BeNullOrEmpty
      }
    }

    It "should return 'release has an active Pull Request targeting another branch.' error when release has an active PR" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "release/*"} | Foreach {
        $_.SourcePullRequests = 1
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $releaseBranches = $branches | Where-Object {$_.BranchName -like "release/*"}

      #Assert
      $releaseBranches.Count | Should Be 2
      foreach ($branch in $releaseBranches) {
        $branch.SourcePullRequests | Should Be 1 
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request targeting another branch."} | Should Not BeNullOrEmpty
      }
    }

    It "should NOT return 'release has an active Pull Request targeting another branch.' error when hotfix has an active PR and HotfixBranchesMustNotHaveActivePullRequests is false" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.ReleaseBranchesMustNotHaveActivePullRequests = $false
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "release/*"} | Foreach {
        $_.SourcePullRequests = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $releaseBranches = $branches | Where-Object {$_.BranchName -like "release/*"}

      #Assert
      $releaseBranches.Count | Should Be 2
      foreach ($branch in $releaseBranches) {
        $branch.SourcePullRequests | Should Be 0
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request targeting another branch."} | Should BeNullOrEmpty
      }
    }

    It "should NOT return 'release has an active Pull Request targeting another branch.' error when hotfix has NO active PRs" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "release/*"} | Foreach {
        $_.SourcePullRequests = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $releaseBranches = $branches | Where-Object {$_.BranchName -like "release/*"}

      #Assert
      $releaseBranches.Count | Should Be 2
      foreach ($branch in $releaseBranches) {
        $branch.SourcePullRequests | Should Be 0
        $branch.Errors | Where-Object {$_.Message -like "*has an active Pull Request targeting another branch."} | Should BeNullOrEmpty
      }
    }

  }

  Context "When Invoke-BranchRules is executed and validating feature branches" { 

    It "should return 'Feature branch limit reached' error when multiple feature branches and ReleaseBranchLimit is 50" { 
      # Arrange
      $rules = Get-DefaultRules
      $rules.FeatureBranchLimit = 1
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -like "feature/*"} | Foreach {
        $_.Master.Behind = 0
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $featureBranches = $branches | Where-Object {$_.BranchName -like "feature/*"}

      #Assert
      $featureBranches.Count | Should Be 2
      foreach ($branch in $featureBranches) {
        $branch.Errors | Where-Object {$_.Message -eq "Feature branch limit reached"} | Should Not BeNullOrEmpty
      }
    }

    It "should return 'Feature1 is stale and has reached feature days limit' error when feature branch is stale" { 
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "feature/feature1"} | Foreach {
        $_.StaleDays = 200
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "feature/feature1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*is stale and has reached feature days limit"} | Should Not BeNullOrEmpty
    }

    It "should return 'Feature1 is missing 500 commit(s) from master' error when feature1 is behind master" {
      # Arrange
      $rules = Get-DefaultRules
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "feature/feature1"} | Foreach {
        $_.Master.Behind = 500
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "feature/feature1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*feature1 is missing 500 commit(s) from master"} | Should Not BeNullOrEmpty
    }

    It "should NOT return 'Feature1 is missing 500 commit(s) from master' error when release1 is behind master and FeatureBranchesMustNotBeBehindMaster is false" {
      # Arrange
      $rules = Get-DefaultRules
      $rules.FeatureBranchesMustNotBeBehindMaster = $false
      $rules.CurrentFeatureMustNotBeBehindMaster = $false
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "feature/feature1"} | Foreach-Object {
        $_.Master.Behind = 500
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "feature/feature1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*feature1 is missing 500 commit(s) from master" -and $_.Type -eq "Error"} | Should BeNullOrEmpty
    }

    It "should return 'Feature1 is missing 99 commit(s) from develop' error when feature1 is behind develop" {
      # Arrange
      $rules = Get-DefaultRules
      $rules.FeatureBranchesMustNotBeBehindMaster = $true
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "feature/feature1"} | Foreach {
        $_.Develop.Behind = 99
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "feature/feature1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*feature1 is missing 99 commit(s) from develop" -and $_.Type -eq "Error"} | Should Not BeNullOrEmpty
    }

    It "should return 'Feature1 is missing 89 commit(s) from develop' error when feature1 is behind develop and CurrentFeatureMustNotBeBehindDevelop is true" {
      # Arrange
      $rules = Get-DefaultRules
      $rules.FeatureBranchesMustNotBeBehindDevelop = $false
      $rules.CurrentFeatureMustNotBeBehindDevelop = $true
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "feature/feature1"} | Foreach {
        $_.Develop.Behind = 89
      }
      $build = Get-DefaultManualBuild
      $build.SourceBranch = "feature/feature1"
      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "feature/feature1"}

      #Assert
      $branch.Errors.Count | Should BeGreaterThan 0
      $branch.Errors | Where-Object {$_.Message -like "*feature1 is missing 89 commit(s) from develop" -and $_.Type -eq "Error"} | Should Not BeNullOrEmpty
    }

    It "should NOT return 'Feature1 is missing 89 commit(s) from develop' error when feature1 is behind develop and CurrentFeatureMustNotBeBehindDevelop is false" {
      # Arrange
      $rules = Get-DefaultRules
      $rules.FeatureBranchesMustNotBeBehindDevelop = $false
      $rules.CurrentFeatureMustNotBeBehindDevelop = $false
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "feature/feature1"} | Foreach {
        $_.Master.Behind = 89
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "feature/feature1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*feature1 is missing 89 commit(s) from develop" -and $_.Type -eq "Error"} | Should BeNullOrEmpty
    }

    It "should return 'Feature1 is missing 79 commit(s) from master' error when feature1 is behind develop and CurrentFeatureMustNotBeBehindMaster is true" {
      # Arrange
      $rules = Get-DefaultRules
      $rules.FeatureBranchesMustNotBeBehindMaster = $false
      $rules.CurrentFeatureMustNotBeBehindMaster = $true
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "feature/feature1"} | Foreach-Object {
        $_.Master.Behind = 79
      }
      $build = Get-DefaultManualBuild
      $build.SourceBranch = "feature/feature1"
      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "feature/feature1"}

      #Assert
      $branch.Errors.Count | Should BeGreaterThan 0
      $branch.Errors | Where-Object {$_.Message -like "*feature1 is missing 79 commit(s) from master" -and $_.Type -eq "Error"} | Should Not BeNullOrEmpty
    }

    It "should NOT return 'Feature1 is missing 79 commit(s) from master' error when feature1 is behind master and CurrentFeatureMustNotBeBehindMaster is false" {
      # Arrange
      $rules = Get-DefaultRules
      $rules.FeatureBranchesMustNotBeBehindMaster = $false
      $rules.CurrentFeatureMustNotBeBehindMaster = $false
      $branches = _getConextBranches
      $branches | Where-Object {$_.BranchName -eq "feature/feature1"} | Foreach {
        $_.Master.Behind = 79
      }
      $build = Get-DefaultManualBuild

      #Act
      $branches = Invoke-BranchRules -Branches $branches -Build $build -Rules $rules
      $branch = $branches | Where-Object {$_.BranchName -eq "feature/feature1"}

      #Assert
      $branch.Errors | Where-Object {$_.Message -like "*feature1 is missing 79 commit(s) from master" -and $_.Type -eq "Error"} | Should BeNullOrEmpty
    }
  }

}