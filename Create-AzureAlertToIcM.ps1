<#
.SYNOPSIS
	AzureToIcmConnector runbook script facilitates creation of IcM incidents from Azure alerts.
.DESCRIPTION
	The script receives the incoming alert context data from Azure. 
	Using the configuration available in the automation account, it forwards it to the appropriate IcM environment to create an equivalent IcM incident. 
	This runbook is dependent on the AzureToIcmConnector automation module which needs to be imported separately
.EXAMPLE
	Create-AzureAlertToIcM.ps1 -Webhookdata =$object. 
.NOTES
    AUTHOR: Azad Naik
    LASTEDIT: May 08, 2017
#>
param(
		[object] $WebhookData
	)
if ($WebhookData -ne $null) { 
	# Getting the configuration from the automation variables
	$connectorId = Get-AutomationVariable -Name "connectorID"
	$certThumbprint = Get-AutomationVariable -Name "certThumbprint"
	$certPassword = Get-AutomationVariable -Name "certPassword"
	$severity = Get-AutomationVariable -Name "severity"	
	$correlationID = Get-AutomationVariable -Name "correlationID"
	$routingID = Get-AutomationVariable -Name "routingID"
	$environment = Get-AutomationVariable -Name "environment"
					
	# Exporting the certificate to local drive of the machine where runbook script is executed
	$cert = Get-AutomationCertificate -Name 'AzureAlert'
	$pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2($cert)
	$pfxContentType = [System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx
	[byte[]]$pfxBytes = $pfx.Export($pfxContentType,$certPassword)
	[io.file]::WriteAllBytes('C:\Temp\AzureAlert.pfx',$pfxBytes)
	Write-Output "Exporting Certificate $certThumbprint complete"
	
	# Importing the certificate to 'My' certificate store under current user
	[String]$certPath = "C:\Temp\AzureAlert.pfx"
	[String]$certRootStore = “CurrentUser”
	[String]$certStore = “My”
	$pfxPass = $certPassword
	$pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
	$pfx.import($certPath,$pfxPass,“Exportable,PersistKeySet”)
	$store = new-object System.Security.Cryptography.X509Certificates.X509Store($certStore,$certRootStore)
	$store.open(“MaxAllowed”)
	$store.add($pfx)
	$store.close()

	# Parsing the input data starts here
	Write-Output "WebHook Data received from Azure Alert : $WebhookData"
	Import-Module AzureToIcmConnector.dll
	
	# Calling the createICMIncident method on the custom module
	$webHookBody = ""
    $webHookBody = $WebhookData.RequestBody
	$webHookBody = $webHookBody | Out-String
	Write-Output "Body: $webHookBody"	
    Write-Output "Azure alert send to IcM"	
  	$createdIcMIncidentID = [AzureToIcmConnector.ICMConnector]::createICMIncidentFromAzureAlert($connectorId,$certThumbprint,$webHookBody,$severity,$correlationID,$routingID,$environment)	
    Write-Output "IcM Incident: $createdIcMIncidentID"
}
else  
{ 
    Write-Error "Webhook data for Azure alert can't be null"  
} 
