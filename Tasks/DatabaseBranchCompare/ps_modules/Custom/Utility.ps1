# function Get-SqlPackageCommandArguments
# {
#     param([String] $dacpacFile,
#           [String] $targetMethod,
#           [String] $serverName,
#           [String] $databaseName,
#           [String] $sqlUsername,
#           [String] $sqlPassword,
#           [String] $connectionString,
#           [String] $publishProfile,
#           [String] $additionalArguments,
#           [switch] $isOutputSecure)

#     $ErrorActionPreference = 'Stop'
#     $dacpacFileExtension = ".dacpac"
#     $SqlPackageOptions =
#     @{
#         SourceFile = "/SourceFile:"; 
#         Action = "/Action:"; 
#         TargetServerName = "/TargetServerName:";
#         TargetDatabaseName = "/TargetDatabaseName:";
#         TargetUser = "/TargetUser:";
#         TargetPassword = "/TargetPassword:";
#         TargetConnectionString = "/TargetConnectionString:";
#         Profile = "/Profile:";
#     }

#     # validate dacpac file
#     if([System.IO.Path]::GetExtension($dacpacFile) -ne $dacpacFileExtension)
#     {
#         Write-Error (Get-VstsLocString -Key "SAD_InvalidDacpacFile" -ArgumentList $dacpacFile)
#     }

#     $sqlPackageArguments = @($SqlPackageOptions.SourceFile + "`"$dacpacFile`"")
#     $sqlPackageArguments += @($SqlPackageOptions.Action + "Publish")

#     if($targetMethod -eq "server")
#     {
#         $sqlPackageArguments += @($SqlPackageOptions.TargetServerName + "`"$serverName`"")
#         if($databaseName)
#         {
#             $sqlPackageArguments += @($SqlPackageOptions.TargetDatabaseName + "`"$databaseName`"")
#         }

#         if($sqlUsername)
#         {
#             $sqlUsername = Get-FormattedSqlUsername -sqlUserName $sqlUsername -serverName $serverName

#             $sqlPackageArguments += @($SqlPackageOptions.TargetUser + "`"$sqlUsername`"")
#             if(-not($sqlPassword))
#             {
#                 Write-Error (Get-VstsLocString -Key "SAD_NoPassword" -ArgumentList $sqlUserName)
#             }

#             if( $isOutputSecure ){
#                 $sqlPassword = "********"
#             } 
#             else
#             {
#                 $sqlPassword = ConvertParamToSqlSupported $sqlPassword
#             }
            
#             $sqlPackageArguments += @($SqlPackageOptions.TargetPassword + "`"$sqlPassword`"")
#         }
#     }
#     elseif($targetMethod -eq "connectionString")
#     {
#         $sqlPackageArguments += @($SqlPackageOptions.TargetConnectionString + "`"$connectionString`"")
#     }

#     if($publishProfile)
#     {
#         # validate publish profile
#         if([System.IO.Path]::GetExtension($publishProfile) -ne ".xml")
#         {
#             Write-Error (Get-VstsLocString -Key "SAD_InvalidPublishProfile" -ArgumentList $publishProfile)
#         }
#         $sqlPackageArguments += @($SqlPackageOptions.Profile + "`"$publishProfile`"")
#     }

#     $sqlPackageArguments += @("$additionalArguments")
#     $scriptArgument = ($sqlPackageArguments -join " ") 

#     return $scriptArgument
# }
  
# function Execute-Command {
#   param(
#     [String][Parameter(Mandatory = $true)] $FileName,
#     [String][Parameter(Mandatory = $true)] $Arguments
#   )

#   $ErrorActionPreference = 'Continue' 
#   Invoke-Expression "& '$FileName' --% $Arguments" 2>&1 -ErrorVariable errors | ForEach-Object {
#     if ($_ -is [System.Management.Automation.ErrorRecord]) {
#       Write-Error $_
#     }
#     else {
#       Write-Host $_
#     }
#   }
    
#   foreach ($errorMsg in $errors) {
#     Write-Error $errorMsg
#   }
#   $ErrorActionPreference = 'Stop'
#   if ($LASTEXITCODE -ne 0) {
#     throw  (Get-VstsLocString -Key "SQLDacpacTaskFailed")
#   }
# }