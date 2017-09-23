function Invoke-GetCommand {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Url
  )
  Process {
    # if (_useWindowsAuthenticationOnPremise ) {
    # $responseFromGet = Invoke-RestMethod -Uri $Url -UseDefaultCredentials
    # return $responseFromGet
    # }
    # else {
    Write-Host $env:TEAM_PAT
    $responseFromGet = Invoke-RestMethod -Uri $Url -Method Get -ContentType "application/json" -Headers @{Authorization = "Basic $env:TEAM_PAT"}
    return $responseFromGet
    # }
  }
}

Function Get-BranchStats {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$ProjectCollectionUri,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$ProjectName,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Repository,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$BaseBranch
  )
  Process {
    $url = "$ProjectCollectionUri/$ProjectName/_apis/git/repositories/$Repository/stats/branches?baseVersion=$BaseBranch&api-version=1.0"
    $result = Invoke-GetCommand -Url $Url
    return $result.Value
  }
}

Function Get-BranchCompareStats {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$ProjectCollectionUri,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$ProjectName,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Repository,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Branch,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$CompareBranch
  )
  Process {
    $Branch = $Branch.Replace("/", "%2F")
    $url = "$ProjectCollectionUri/$ProjectName/_apis/git/repositories/$Repository/stats/branches/$CompareBranch?baseVersion=$Branch&_a=commits"
    $result = Invoke-GetCommand -Url $Url
    return $result.Value
  }
}

Function Get-PullRequests {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$ProjectCollectionUri,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$ProjectName,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Repository,
    [ValidateNotNullOrEmpty()]
    [ValidateSet('Active', 'Abandoned', 'Completed', 'All')]
    [Parameter(ParameterSetName = 'List', Mandatory = $true)][string]$StatusFilter = "All"
  )
  Process {
    $url = "$ProjectCollectionUri/$ProjectName/_apis/git/repositories/$Repository/pullRequests?api-version=3.0"
    if ($StatusFilter -eq "All") {
      $url = $url + "&status=$StatusFilter"
    }
    $result = Invoke-GetCommand -Url $Url
    return $result.Value
  }
}