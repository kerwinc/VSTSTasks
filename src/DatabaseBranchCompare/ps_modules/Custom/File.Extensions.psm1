$ErrorActionPreference = "Stop"

function Copy-DirectoryContents {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {(Test-Path -Path $_ -PathType Container)})]
    [Parameter(Mandatory = $true)][string]$Source,
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {(Test-Path -Path $_ -PathType Container)})]
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter()][switch]$Force
  )
  Process {
    Write-Verbose "Starting copy items from $Source to $Destination"
    Get-ChildItem -LiteralPath $Source | Copy-Item -Destination $Destination -Recurse -Force:$Force
  }
}

function Copy-Directory {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {(Test-Path -Path $_ -PathType Container)})]
    [Parameter(Mandatory = $true)][string]$Directory,
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {(Test-Path -Path $_ -PathType Container)})]
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter()][switch]$Force
  )
  Process {
    Write-Verbose "Starting copy of $Directory to $Destination"
    if ($Force) {
      Write-Warning "-Force was specified. The directory will be overwritten if it exists in $Destination"
    }
    Copy-Item -LiteralPath $Directory -Destination $Destination -Recurse -Force:$Force
  }
}

function Test-DirectoryPath {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Path
  )
  Process {
    if ($Path -eq $null) {
      return $false
    }
    if ([System.String]::IsNullOrEmpty($Path) -or [System.String]::IsNullOrWhiteSpace($Path)) {
      return $false
    }
    if (-not(Test-Path -Path $Path -PathType Container)) {
      return $false
    }
    if ($Path.StartsWith("\") -or $path.StartsWith("*")) {
      return $false
    }
    return $true
  }
}

function Test-FilePath {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Path
  )
  Process {
    if ($Path -eq $null) {
      return $false
    }
    if ([System.String]::IsNullOrEmpty($Path) -or [System.String]::IsNullOrWhiteSpace($Path)) {
      return $false
    }
    if (-not(Test-Path -LiteralPath $Path -PathType Leaf)) {
      return $false
    }
    if ($Path.StartsWith("\") -or $path.StartsWith("*")) {
      return $false
    }
    return $true
  }
}

function ZipFiles {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {(Test-Path -Path $_ -PathType Container)})]
    [Parameter(Mandatory = $true)][string]$SourceDirectory,
    [ValidateNotNullOrEmpty()]
    [Parameter(Mandatory = $true)][string]$Zipfilename,
    [Parameter()][switch]$OutputContents
  )
  Process {
    Add-Type -Assembly System.IO.Compression.FileSystem
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal

    Write-Verbose "Creating archive from $SourceDirectory to $Zipfilename"
    [System.IO.Compression.ZipFile]::CreateFromDirectory($SourceDirectory, $Zipfilename, $compressionLevel, $false)

    if ($OutputContents) {
      Write-Verbose "Zipfile Contents:"
      $items = [System.IO.Compression.ZipFile]::OpenRead($Zipfilename).Entries
      foreach ($item in $items) {
        $displayValue = $item.FullName + " | Size: " + $item.Length + " | Last Updated: " + $item.LastWriteTime
        Write-Verbose "File: $displayValue"
      }
    }
  }
}

function ExtractZipFile {
  [CmdletBinding()]
  param(
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {(Test-Path -Path $_ -PathType Leaf)})]
    [Parameter(Mandatory = $true)][string]$Zipfilename,
    [ValidateNotNullOrEmpty()]
    # [ValidateScript( {(Test-Path -Path $_ -PathType Container)})]
    [Parameter(Mandatory = $true)][string]$Destination
  )
  Process {
    Write-Verbose "Adding Assembly Type"
    Add-Type -Assembly System.IO.Compression.FileSystem
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal

    Write-Verbose "Extracting $Zipfilename to $Destination"
    [System.IO.Compression.ZipFile]::ExtractToDirectory($Zipfilename, $Destination)
  }
}

function New-Directory {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {-not(Test-Path -Path $_ -PathType Container)})]
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter()][switch]$Force = $false
  )
  Process {
    if ((Test-DirectoryPath -Path $Path)) {
      throw "Directory ($path) already exists"
    }
    Write-Verbose "Creating new directory at $Path"
    New-Item -ItemType Directory -Path $Path -Force:$Force
  }
}

function Remove-Directory {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {Test-Path -Path $_ -PathType Container})]
    [Parameter(Mandatory = $true)][string]$Path
  )
  Process {
    if ((Test-DirectoryPath -Path $Path)) {
      Write-Verbose "Removing Directory: $path"
      Remove-Item -LiteralPath $Path -Recurse -Force
    }
    else {
      throw "Directry Path is invalid: $path"
    }
  }
}

function Remove-DirectoryContents {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [ValidateNotNullOrEmpty()]
    [ValidateScript( {Test-Path -Path $_ -PathType Container})]
    [Parameter(Mandatory = $true)][string]$Path
  )
  Process {
    if ((Test-DirectoryPath -Path $Path)) {
      Write-Verbose "Removing all items from $Path"
      Get-ChildItem -LiteralPath $Path | Remove-Item -Recurse -Force
    }
    else {
      throw "Directry Path is invalid: $path"
    }
  }
}

Export-ModuleMember -Function * -Alias *