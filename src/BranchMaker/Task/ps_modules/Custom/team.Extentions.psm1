function Invoke-GetCommand {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Url
  )
  Process {
    if ($env:TEAM_AUTHTYPE -eq "WindowsAuthentication" ) {
      $responseFromGet = Invoke-RestMethod -Uri $Url -UseDefaultCredentials
      return $responseFromGet
    }
    elseif ($env:TEAM_AUTHTYPE -eq "Basic" ) {
      $responseFromGet = Invoke-RestMethod -Uri $Url -Method Get -ContentType "application/json" -Headers @{Authorization = "Basic $env:TEAM_PAT"}
      return $responseFromGet
    }
    else {
      $responseFromGet = Invoke-RestMethod -Uri $Url -Method Get -ContentType "application/json" -Headers @{Authorization = "Bearer $env:TEAM_PAT"}
      return $responseFromGet
    }
  }
}

function Invoke-PostCommand {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Url,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Body
  )
  Process {
    Write-Verbose "Executing Request [$Url] using Auth Type: [$env:TEAM_AUTHTYPE]"
    if ($env:TEAM_AUTHTYPE -eq "WindowsAuthentication" ) {
      $response = Invoke-RestMethod -Uri $Url -Method Post -ContentType "application/json" -Body $body -UseDefaultCredentials
      $response | ConvertTo-Json | Write-Verbose
      return $response
    }
    elseif ($env:TEAM_AUTHTYPE -eq "Basic" ) {
      $response = Invoke-RestMethod -Uri $Url -Method Post -ContentType "application/json" -Body $body -Headers @{Authorization = "Basic $env:TEAM_PAT"}
      $response | ConvertTo-Json | Write-Verbose
      return $response
    }
    else {
      $response = Invoke-RestMethod -Uri $Url -Method Post -ContentType "application/json" -Body $body -Headers @{Authorization = "Bearer $env:TEAM_PAT"}
      $response | ConvertTo-Json | Write-Verbose
      return $response
    }
  }
}

Function Get-Repository {
  [CmdletBinding()]
  param(
    [Parameter()][string]$ProjectCollectionUri  = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI,
    [Parameter()][string]$ProjectName = $env:SYSTEM_TEAMPROJECT,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Repository
  )
  Process {
    $url = "$ProjectCollectionUri/$ProjectName/_apis/git/repositories/$Repository/?api-version=5.0"
    $result = Invoke-GetCommand -Url $Url
    return $result
  }
}

Function Get-Branches {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$ProjectCollectionUri,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$ProjectName,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Repository
  )
  Process {
    $url = "$ProjectCollectionUri/$ProjectName/_apis/git/repositories/$Repository/refs/heads?api-version=5.0"
    $result = Invoke-GetCommand -Url $Url
    return $result
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
    return $result
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
    return $result
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
    return $result
  }
}

Function New-Branch {
  [CmdletBinding()]
  param(
    [Parameter()][string]$ProjectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI,
    [Parameter()][string]$ProjectName = $env:SYSTEM_TEAMPROJECT,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Repository,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$BranchName,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$NewObjectId
  )
  Process {
    $url = "$ProjectCollectionUri/$ProjectName/_apis/git/repositories/$Repository/refs?api-version=5.0"
    $branchFullName = "refs/heads/$BranchName"
    $body = ConvertTo-Json @(@{name="$branchFullName";newObjectId="$NewObjectId";oldObjectId="0000000000000000000000000000000000000000"})
    Write-Verbose "Creating Branch: [$branchFullName]"
    $response = Invoke-PostCommand -Url $url -Body $body -Verbose
    return $response.Value
  }
}

Function Set-RequireApprovalPolicy {
  [CmdletBinding()]
  param(
    [Parameter()][string]$ProjectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI,
    [Parameter()][string]$ProjectName = $env:SYSTEM_TEAMPROJECT,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$RepositoryId,
    [ValidateNotNullOrEmpty()]
    [Parameter()][string]$BranchName,
    [ValidateNotNullOrEmpty()]
    [Parameter()][string]$NewObjectId,
    [Parameter()][string]$MinimumApproverCount = 2,
    [Parameter()][bool]$CreatorVoteCounts = $false,
    [Parameter()][bool]$AllowDownvotes = $false,
    [Parameter()][bool]$ResetOnSourcePush = $false
  )
  Process {
    $url = "$ProjectCollectionUri/$ProjectName/_apis/policy/configurations?api-version=5.0"
    $branchFullName = "refs/heads/$BranchName"
    $body = ConvertTo-Json -Depth 10 @{
                              isEnabled=$true;
                              isBlocking=$true;
                              type=@{id="fa4e907d-c16b-4a4c-9dfa-4906e5d171dd"};
                              settings=@{
                                minimumApproverCount=$MinimumApproverCount;
                                creatorVoteCounts=$CreatorVoteCounts;
                                allowDownvotes=$AllowDownvotes;
                                resetOnSourcePush=$ResetOnSourcePush;
                                scope=@(@{
                                  repositoryId="$RepositoryId";
                                  refName="$branchFullName";
                                  matchKind="Exact";
                                });
                              }
                            };
    Write-Verbose "Setting Require Approval Policy: [$branchFullName]"
    $response = Invoke-PostCommand -Url $url -Body $body -Verbose
    return $response
  }
}

Function Set-RequireWorkItemPolicy {
  [CmdletBinding()]
  param(
    [Parameter()][string]$ProjectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI,
    [Parameter()][string]$ProjectName = $env:SYSTEM_TEAMPROJECT,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$RepositoryId,
    [ValidateNotNullOrEmpty()]
    [Parameter()][string]$BranchName,
    [Parameter()][bool]$IsBlocking = $true
  )
  Process {
    $url = "$ProjectCollectionUri/$ProjectName/_apis/policy/configurations?api-version=5.0"
    $branchFullName = "refs/heads/$BranchName"
    $body = ConvertTo-Json -Depth 10 @{
                              isEnabled=$true;
                              isBlocking=$IsBlocking;
                              type=@{id="40e92b44-2fe1-4dd6-b3d8-74a9c21d0c6e"};
                              settings=@{
                                scope=@(@{
                                  repositoryId="$RepositoryId";
                                  refName="$branchFullName";
                                  matchKind="Exact";
                                });
                              }
                            };
    Write-Verbose "Setting Require WorkItem Policy: [$branchFullName]"
    $result = Invoke-PostCommand -Url $url -Body $body -Verbose
    return $result
  }
}

Function Set-RequireCommentResolutionPolicy {
  [CmdletBinding()]
  param(
    [Parameter()][string]$ProjectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI,
    [Parameter()][string]$ProjectName = $env:SYSTEM_TEAMPROJECT,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$RepositoryId,
    [ValidateNotNullOrEmpty()]
    [Parameter()][string]$BranchName,
    [Parameter()][bool]$IsBlocking = $true
  )
  Process {
    $url = "$ProjectCollectionUri/$ProjectName/_apis/policy/configurations?api-version=5.0"
    $branchFullName = "refs/heads/$BranchName"
    $body = ConvertTo-Json -Depth 10 @{
                              isEnabled=$true;
                              isBlocking=$IsBlocking;
                              type=@{id="c6a1889d-b943-4856-b76f-9e46bb6b0df2"};
                              settings=@{
                                scope=@(@{
                                  repositoryId="$RepositoryId";
                                  refName="$branchFullName";
                                  matchKind="Exact";
                                });
                              }
                            };
    Write-Verbose "Setting Require Comment Resolution Policy: [$branchFullName]"
    $result = Invoke-PostCommand -Url $url -Body $body -Verbose
    return $result
  }
}

Function Set-RequireMergeStrategyPolicy {
  [CmdletBinding()]
  param(
    [Parameter()][string]$ProjectCollectionUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI,
    [Parameter()][string]$ProjectName = $env:SYSTEM_TEAMPROJECT,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$RepositoryId,
    [ValidateNotNullOrEmpty()]
    [Parameter()][string]$BranchName,
    [Parameter()][bool]$UseSquashMerge = $false
  )
  Process {
    $url = "$ProjectCollectionUri/$ProjectName/_apis/policy/configurations?api-version=5.0"
    $branchFullName = "refs/heads/$BranchName"
    $body = ConvertTo-Json -Depth 10 @{
                              isEnabled=$true;
                              isBlocking=$true;
                              type=@{id="fa4e907d-c16b-4a4c-9dfa-4916e5d171ab"};
                              settings=@{
                                useSquashMerge=$UseSquashMerge;
                                scope=@(@{
                                  repositoryId="$RepositoryId";
                                  refName="$branchFullName";
                                  matchKind="Exact";
                                });
                              }
                            };
    Write-Verbose "Setting Policy: [$branchFullName]"
    $result = Invoke-PostCommand -Url $url -Body $body -Verbose
    return $result
  }
}

