
$currentDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$taskDirectory = Join-Path (Get-Item -Path $currentDirectory).Parent.Parent.FullName "Tasks\GitflowBranchGate\Task"

Write-Host "Importing Required Modules"
Import-Module -Name Pester

Write-Host "Running Pester Tests"
Invoke-Pester -Script "$currentDirectory\BranchRulesTests.ps1"
