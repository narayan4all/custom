<#
    .DESCRIPTION
        An example runbook which gets all the ARM resources using the Run As Account (Service Principal)

    .NOTES
        AUTHOR: Azure Automation Team
        LASTEDIT: Mar 14, 2016
#>

param ( 
    [object]$WebhookData
)
if($WebhookData -ne $null)
{

    $connectionName = "AzureRunAsConnection"
    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
    }
    catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }    

    # Collect properties of WebhookData.
    $WebhookName    =   $WebhookData.WebhookName
    $WebhookBody    =   $WebhookData.RequestBody
    $WebhookHeaders =   $WebhookData.RequestHeader
       
    # Information on the webhook name that called This
    Write-Output "This runbook was started from webhook $WebhookName."
       
    # Obtain the WebhookBody containing the AlertContext
    $WebhookBody = (ConvertFrom-Json -InputObject $WebhookBody)
    Write-Output "`nWEBHOOK BODY"
    Write-Output "============="
    Write-Output $WebhookBody

    # Some selected AlertContext information
    Write-Output "`nALERT CONTEXT DATA"
    Write-Output "==================="
    Write-Output $WebhookBody.subscriptionId
    Write-Output $WebhookBody.resourceGroup
    Write-Output $WebhookBody.sqlServerName
    Write-Output $WebhookBody.sqlDatabaseName
    Write-Output $WebhookBody.PreferredSize
    Write-Output $WebhookBody.timestamp

    Set-AzureRmContext -SubscriptionId $WebhookBody.subscriptionId

    $serverName = $WebhookBody.sqlServerName;

    $databaseName = $WebhookBody.sqlDatabaseName

    $resourceGroup = $WebhookBody.resourceGroup;

    $RequestedSize = $WebhookBody.PreferredSize

    Write-output "Get the database: $databaseName in Server: $serverName in resourceGroup: $resourceGroupName"

    $database = Get-AzurermSqlDatabase -ServerName $serverName -ResourceGroupName $resourceGroup -DatabaseName $databaseName

    if($database -ne $null)
    {
        Write-Output "found the database to resize $($database.DatabaseName) and the current size is $($database.CurrentServiceObjectiveName)"
        
        if($database.CurrentServiceObjectiveName -ne $RequestedSize)
        {
            Write-Output "Attempt to resize the database from: $($database.CurrentServiceObjectiveName)  to $RequestedSize"

            Set-AzureRmSqlDatabase -ServerName $serverName -ResourceGroupName $resourceGroup -DatabaseName $databaseName -RequestedServiceObjectiveName $RequestedSize
        }
        else{
            Write-Output "Skip  resize the database from: $($database.CurrentServiceObjectiveName) to $RequestedSize as they are already in same size"
        }
        }

    }
