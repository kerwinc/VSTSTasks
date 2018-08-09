$sut = 'BranchRules'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourcePath = Join-Path (Get-Item -Path $here).Parent.Parent.FullName "Tasks\GitflowBranchGate"
$modulesPath = Join-Path $sourcePath "Task\ps_modules\Custom"

Import-Module "$modulesPath\$sut.psm1" -Force -DisableNameChecking

Describe "BrandRules Module Tests" { 

  It "has a $sut.psm1 file" {
    "$modulesPath\$sut.psm1" | Should Exist
  }

  It "$sut is valid PowerShell code" {
    $psFile = Get-Content -Path "$modulesPath\$sut.psm1" -ErrorAction Stop
    $errors = $null;
    $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
    $errors.Count | Should Be 0
  }

  Context "ConvertoTo-Branches tests" {
    # $branches =  
    

  }

  # It "ConvertTo-Branches should return list of Branches" { 

  # }
}