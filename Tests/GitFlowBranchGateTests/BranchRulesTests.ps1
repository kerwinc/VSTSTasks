$sut = 'BranchRules'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$assetsPath = Join-Path $here 'assets'
$sourcePath = Join-Path (Get-Item -Path $here).Parent.Parent.FullName "Tasks\GitflowBranchGate"
$modulesPath = Join-Path $sourcePath "Task\ps_modules\Custom"

Import-Module "$modulesPath\$sut.psm1" -Force -DisableNameChecking

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

    $rules = New-Object psobject -Property @{
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

    $build = New-Object psobject -Property @{
      BuildId            = 0
      SourceBranch       = "develop"
      BuildReason        = "PullRequest"
      PullRequestId      = 7
      RepositoryProvider = "Git"
    }

    $branches = Get-Content "$assetsPath\Branches.defaults.json" | Out-String | ConvertFrom-Json
    $pullRequests = Get-Content "$assetsPath\PullRequests.empty.json" | Out-String | ConvertFrom-Json | ConvertTo-PullRequests

    It "Branches array should return 2 Branches" {
      $branches.Count | Should Be 2
    }

    It "Branches array should have a develop and master branch" {
      $branches.Value[0].name | Should Be "refs/heads/develop"
      $branches.Value[1].name | Should Be "refs/heads/master"
    }

    It "Pull Request array should have 0 items" {
      $pullRequests.Count | Should be 0
    }
  }

  Context "Pull Request to develop tests" { 
    $pullRequests = ConvertTo-PullRequests -PullRequests $(Get-Content "$assetsPath\PullRequests.DevelopToMaster.json" | Out-String | ConvertFrom-Json).Value

    It "PR develop to master must have items" {
      $pullRequests.Count | Should be 1
    }

    It "PR develop to master must correct data" {
      $pullRequests[0].ID | Should be 1
      $pullRequests[0].Title | Should be "developToMasterTest"
      $pullRequests[0].SourceBranch | Should be "develop"
      $pullRequests[0].TargetBranch | Should be "master"
      # $pullRequests[0].Created | Should be 1
      $pullRequests[0].CreatedBy | Should be "Kerwin Carpede"
      $pullRequests[0].Status | Should be "active"
      $pullRequests[0].SeverityThreshold | Should be "info"
      $pullRequests[0].Errors | Should be $null
    }

  }
}