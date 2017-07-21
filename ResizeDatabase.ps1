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

    Set-AzureRmContext -SubscriptionId "4f4058b5-71da-4fa1-96b3-5f5c59002c14"

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

    # Obtain the AlertContext
    $AlertContext = [object]$WebhookBody.context

    # Some selected AlertContext information
    Write-Output "`nALERT CONTEXT DATA"
    Write-Output "==================="
    Write-Output $AlertContext.name
    Write-Output $AlertContext.subscriptionId
    Write-Output $AlertContext.resourceGroupName
    Write-Output $AlertContext.resourceName
    Write-Output $AlertContext.resourceType
    Write-Output $AlertContext.resourceId
    Write-Output $AlertContext.timestamp

    $resourceArray = $AlertContext.resourceName.split("/");

    $serverName = $resourceArray[0];

    $databaseName = "MSExpense"

    $resourceGroupName = $AlertContext.resourceGroupName;

    Write-output "Get the database: $databaseName in Server: $serverName in resourceGroup: $resourceGroupName"

    $database = Get-AzurermSqlDatabase -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName

    if($database -ne $null)
    {
        Write-Output "found the database to resize $($database.DatabaseName) and the current size is $($database.CurrentServiceObjectiveName)"
    }

    $PreferredSizes = "S1","S2","S3" #,"P1","P2","P4","P6","P11"

    $index = [array]::IndexOf($PreferredSizes, $database.CurrentServiceObjectiveName)

    $rampType = $WebhookName

    if($rampType -eq "ExpenseDatabaseRampUp")
    {
        Write-Output "Incrementing index to rampup $index"
        $index +=1
    }
    elseif($rampType -eq "ExpenseDatabaseRampDown")
    {
        Write-Output "decreasing index to rampdown $index"
        $index -=1
    }
    else
    {
        throw "Invalid ramp type"
    }

    if($index -ge 0 -and $index -lt $PreferredSizes.Length)
    {
        Write-Output "Attempt to resize the database from: $($database.CurrentServiceObjectiveName)  to $($PreferredSizes[$index])"
        $RequestedSize = $PreferredSizes[$index]
        #Set-AzureRmSqlDatabase -ServerName $serverName -ResourceGroupName $resourceGroupName -DatabaseName $databaseName -RequestedServiceObjectiveName $RequestedSize
    }
    else
    {
        Write-Output "Index $index out of range, so exit without resizing"
    }

    #$database


    #Get all ARM resources from all resource groups
    <#$ResourceGroups = Get-AzureRmResourceGroup 

    foreach ($ResourceGroup in $ResourceGroups)
    {    
        Write-Output ("Showing resources in resource group " + $ResourceGroup.ResourceGroupName)
        $Resources = Find-AzureRmResource -ResourceGroupNameContains $ResourceGroup.ResourceGroupName | Select ResourceName, ResourceType
        ForEach ($Resource in $Resources)
        {
            Write-Output ($Resource.ResourceName + " of type " +  $Resource.ResourceType)
        }
        Write-Output ("")
    }
    #>
}