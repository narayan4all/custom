<#
.SYNOPSIS
WebHook-ICM Connector Script facilitates creation of ICM incidents from WebHook data.
.DESCRIPTION
The script receives data from webhook.
Using the configuration available in the automation account, it forwards it to the appropriate ICM environment to create an equivalent ICM incident. 
This runbook is dependent on the WebHook-ICM-Connector automation Module which needs to be imported separately. 
.EXAMPLE
Create-WebHookToICMIncident.ps1 -Webhookdata = $object
.NOTES
AUTHOR: Batbaatar Burentogtokh - Modification from Arun Jolly's AI-ICM Connector script
LASTEDIT: Mar 31, 2017 baburent
Modified: Jun 24, 2016 baburent
#>
param(
	[object] $WebhookData
)
# Getting the configuration from the automation variables
$icmUrlProd = Get-AutomationVariable -Name "icmwebserviceUrlProd"
#$icmUrlPpe = Get-AutomationVariable -Name "ICMURLPpe"
$connectorIdProd = Get-AutomationVariable -Name "connectorID"
#$connectorIdPpe = Get-AutomationVariable -Name "ConnectorIDPpe"
$certificateThumbprint = Get-AutomationVariable -Name "certThumbprint"
$certPassword = Get-AutomationVariable -Name "certPassword"
$severity = Get-AutomationVariable -Name "severity"
$correlationId = Get-AutomationVariable -Name "correlationID"
$routingId = Get-AutomationVariable -Name "routingID"
$environment = Get-AutomationVariable -Name "environment"
$datacenter = $null
$role = $null
$instance = $null
$slice = $null
					
# Exporting the cert to local drive
$cert = Get-AutomationCertificate -Name 'icmprod'
$pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
$pfxContentType = [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx
[byte[]]$pfxBytes = $pfx.Export($pfxContentType, $certPassword)
[io.file]::WriteAllBytes('C:\Temp\icmprod.pfx', $pfxBytes)
cd C:\Temp
$list = dir
Write-Output "Exporting Certificate $certificateThumbprint complete"
	
# Importing the cert to 'My' certificate store under current user
[String]$certPath = "C:\Temp\icmprod.pfx"
[String]$certRootStore = “CurrentUser”
[String]$certStore = “My”
$pfxPass = $certPassword
$pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
$pfx.import($certPath, $pfxPass, “Exportable, PersistKeySet”)
$store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore, $certRootStore)
$store.open(“MaxAllowed”)
$store.add($pfx)
$store.close()
	
# Parsing the input data starts here
Write-Output "WebHook Data received : $WebhookData"
Import-Module Microsoft.IcM.WebHook.dll
	
# Calling the createICMIncident method on the custom module
$webHookBody = $WebhookData.RequestBody
$jsonData = $webHookBody | ConvertFrom-Json

$icmUrl = $icmUrlProd
$tenantId = $connectorIdProd
$name = "OMS alert"

if($jsonData.Name)
{
    $name = "$($jsonData.Name)"
}

if($jsonData.Severity)
{
    $severity = $jsonData.Severity
}

if($jsonData.RoutingId)
{
    $routingId = $jsonData.RoutingId
}

if($jsonData.CorrelationId)
{
    $correlationId = $jsonData.CorrelationId
}

if($jsonData.Environment)
{
    $environment = $jsonData.Environment

	if($environment -eq "test")
	{
		$icmUrl = $icmUrlPpe
		$tenantId = $connectorIdPpe
	}
}

if($jsonData.DataCenter)
{
    $datacenter = $jsonData.DataCenter
}

if($jsonData.Role)
{
    $role = $jsonData.Role
}

if($jsonData.Instance)
{
    $instance = $jsonData.Instance
}

if($jsonData.Slice)
{
    $slice = $jsonData.Slice
}

[string]$body = $jsonData
if($jsonData.Body)
{
    [string]$body = $jsonData.Body
    
    if($body.length -gt 30000)
    {
        $body = $body.SubString(0, 30000) + "... Message truncated for being too long. Please check the real data from the alert source."
    }
}

Write-Output "IcM Url: $icmUrl"
Write-Output "Tenant ID: $tenantId"
Write-Output "Certificate thumbprint: $certificateThumbprint"
Write-Output "Alert Name: $name"
Write-Output "JSON Data: $jsonData"
Write-Output "Severity: $severity"
Write-Output "Correlation ID: $correlationId"
Write-Output "Routing ID: $routingId"
Write-Output "Environment: $environment"
Write-Output "DataCenter: $datacenter"
Write-Output "Role: $role"
Write-Output "Instance: $instance"
Write-Output "Slice: $slice"

$icmIncident = [Microsoft.IcM.WebHook.IcMConnector]::CreateIcMIncident($icmUrl, $tenantId, $certificateThumbprint, $name, $body, $severity, $correlationId, $routingId, $environment, $datacenter, $role, $instance, $slice)
Write-Output "ICM Incident : $icmIncident"

if($icmIncident -notmatch "^[0-9]{1,}$")
{
    throw "Was not able to create IcM incident"
}