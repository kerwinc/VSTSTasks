
$baseUrl = "http://devtfs02/DefaultCollection/Scheduler POC/"
# $pat = "dwzoumhg42spsm7vtqjm4mgc7dzidydei6wrw7wakyl5kv6mc6cq"

Function Get-VSTSBuilds {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Branch,
    [Parameter(ParameterSetName = 'List')]
    [ValidateSet('inProgress', 'completed', 'cancelling', 'postponed', 'notStarted', 'all')]
    [string] $StatusFilter,
    [Parameter(ParameterSetName = 'List')]
    [ValidateSet('succeeded', 'partiallySucceeded', 'failed', 'canceled')]
    [string] $ResultFilter,
    [Parameter(ParameterSetName = 'List')]
    [int] $Top = 5
  )
  Process {

    $resultString = (Invoke-RestMethod -Uri "$baseUrl/_apis/build/builds?statusFilter=$StatusFilter&resultFilter=$ResultFilter" -Headers @{Authorization = "Basic $env:TEAM_PAT"}).value
    $jsonResult = $resultString | Where-Object -Property sourceBranch -Value "refs/heads/$Branch" -EQ | Select-Object -Property Id, status, buildNumber, sourceBranch, result -First $Top
    $jsonResult
  }
}

Function Get-VSTSBuild {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][int] $BuildId
  )
  Process {

    $resultString = (Invoke-RestMethod -Uri "$baseUrl/_apis/build/builds/$BuildId/" -Headers @{Authorization = "Basic $env:TEAM_PAT"})
    $jsonResult = $resultString #| Select-Object -Property Id, status, buildNumber, sourceBranch, result -First $Top
    $jsonResult
  }
}

Function Get-VSTSBuildArtifacts {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][int] $BuildId
  )
  Process {

    $resultString = (Invoke-RestMethod -Uri "$baseUrl/_apis/build/builds/$BuildId/artifacts" -Headers @{Authorization = "Basic $env:TEAM_PAT"}).value
    $jsonResult = $resultString #| Select-Object -Property Id, status, buildNumber, sourceBranch, result -First $Top
    $jsonResult
  }
}

Add-TeamAccount -Account $baseUrl -PersonalAccessToken "m36nxou47z7myfq3hj3zk2m5pjfx5kqino2kjhmwjywlz3wqs7kq"

$builds = Get-VSTSBuilds -Branch master -StatusFilter completed -ResultFilter succeeded -top 1
#$builds
#$lastBuild = Get-VSTSBuild -BuildId $builds.id

#Get the build's artifacts url
$artifactUrl = (Get-VSTSBuildArtifacts -BuildId $builds.id).resource.downloadUrl

#Download the drop artifacts
Invoke-WebRequest -Uri $artifactUrl -OutFile "C:\temp\drop.zip" -Headers @{Authorization = "Basic $env:TEAM_PAT"}
