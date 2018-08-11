[xml]$xml = Get-Content -LiteralPath "C:\temp\DeployReport.xml"
if ($xml -ne $null -and $xml.DeploymentReport -ne $null -and $xml.DeploymentReport.Alerts -ne $null) {
  foreach($alert in $xml.DeploymentReport.Alerts.Alert){
    Write-Warning "SSDT Alert: $($alert.Name) detected on $($alert.Issue.Value)"
  }
}