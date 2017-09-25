# $projectCollectionUri = "http://devtfs02/DefaultCollection"
# $projectName = "RnD"
# $repository = "RnD"
# $currentBranch = "develop"
# $env:TEAM_AUTHTYPE = "Basic"
# $env:TEAM_PAT = "OjVidjN6Mm1wM2ViYnB0ZnNuYmpxaWV2ajNidDJwcW9hM2xudTZmZnRkaXA2anNhem14NHE="
# $showIssuesOnBuildSummary = $false

# $rules = New-Object psobject -Property @{
#   MasterBranch = "master"
#   DevelopBranch = "develop"
#   HotfixPrefix = "hotfix/*"
#   ReleasePrefix = "release/*"
#   FeaturePrefix = "feature/*"

#   HotfixBranchLimit = 1
#   HotfixDaysLimit = 10
#   ReleaseBranchLimit = 1
#   ReleaseDaysLimit = 10
#   FeatureBranchLimit = 50
#   FeatureDaysLimit = 45

#   HotfixeBranchesMustNotBeBehindMaster = $false
#   ReleaseBranchesMustNotBeBehindMaster = $false
#   DevelopMustNotBeBehindMaster = $false
#   FeatureBranchesMustNotBeBehindMaster = $false
#   FeatureBranchesMustNotBeBehindDevelop = $false
#   CurrentFeatureMustNotBeBehindDevelop = $false
#   MustNotHaveHotfixAndReleaseBranches = $false
#   MasterMustNotHaveActivePullRequests = $false
#   HotfixBranchesMustNotHaveActivePullRequests = $false
#   ReleaseBranchesMustNotHaveActivePullRequests = $false
#   BranchNamesMustMatchConventions = $false
# }