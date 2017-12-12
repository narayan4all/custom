
    $SqlServer = "msexpensevnext.database.windows.net"
    $SqlServerPort = 1433
    $Database = "MSExpense"
    $SiteURL = "https://microsoft.sharepoint.com/teams/ExpenseAtMicrosoftPOC"
    $Message = "Welcome to Microsoft Expense Training Site!"
    $Permission = "View"

    #Get-ChildItem c:\Modules\User\SPClient\


    Add-Type -Path "C:\Modules\User\SharepointOnline\Microsoft.Sharepoint.Client.dll"
    Add-Type -Path "C:\Modules\User\SharepointOnline\Microsoft.Sharepoint.Client.Runtime.dll"
 #   Use-SPClientType
    $SqlCredential = Get-AutomationPSCredential -Name 'SqlCredentialAsset'
    $SPCredentials = Get-AutomationPSCredential -Name 'SPCredentialAsset'
 
    if ($SqlCredential -eq $null) 
    { 
        throw "Could not retrieve '$SqlCredentialAsset' credential asset. Check that you created this first in the Automation service." 
    }   
    # Get the username and password from the SQL Credential 
    $SqlUsername = $SqlCredential.UserName 
    $SqlPass = $SqlCredential.GetNetworkCredential().Password 

    
  
  # Define the connection to the SQL Database 
    $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$SqlServer,$SqlServerPort;Database=$Database;User ID=$SqlUsername;Password=$SqlPass;Trusted_Connection=False;Encrypt=True;Connection Timeout=30;") 
#     $Conn = New-Object System.Data.SqlClient.SqlConnection("Server=tcp:$SqlServer,$SqlServerPort;Database=$Database;Trusted_Connection=True;Encrypt=True;Connection Timeout=30;") 
         
    # Open the SQL connection 
    $Conn.Open() 
 
    # Define the SQL command to run. In this case we are getting the number of rows in the table 
    $Cmd=new-object system.Data.SqlClient.SqlCommand
    $Cmd.CommandText = "Select loginid from stg.EmployeeOneProfile where OrganizationalUnit3 = 1075 and createddate >= (Select dateadd(d,-1,getdate()))"
    $Cmd.Connection = $Conn
    $Cmd.CommandTimeout=120 
  
   
    # Execute the SQL command 
    $Ds=New-Object system.Data.DataSet 
    $Da=New-Object system.Data.SqlClient.SqlDataAdapter($Cmd)
    
   [void]$Da.fill($Ds) 
   
    # Output the loginid for Subcon
    # Output the loginid for Subcon
    foreach( $loginid in $Ds.Tables[0].Rows)
    {
         $SPUser = [string]$loginid[0]
      #   $SPUser = "xyz@hotmail.com"

         [net.mail.mailaddress[]]$User = $SPUser

         $StatusOK = $True
         Write-Verbose "Initializing SharePoint Client Libraries"

        try{

            $loadInfo1 = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client")

            $loadInfo2 = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client.Runtime")

        }

        catch{

            Write-Error "Failed to load SharePoint Client Libraries."

            $StatusOK = $False

            break

        }

        Write-Verbose "Initializing SharePoint context object."

        try{

            Write-Output $SPCredentials.UserName
        #    $SPCredentialsSecure = ConvertTo-SecureString $SPCredentials.Password

            $ctx = New-Object Microsoft.SharePoint.Client.ClientContext($SiteURL)

            $SharePointCreds = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($SPCredentials.UserName, $SPCredentials.Password)
 
            $ctx.Credentials = $SharePointCreds

            $SharingManager = [Microsoft.SharePoint.Client.Sharing.WebSharingManager]

        }

        catch{
            Write-Error  $_.Exception.Message
            Write-Error  $_.Exception.StackTrace
            Write-Error "Failed to initialize SharePoint context object. Ensure you have the correct permissions on the sharepoint site."

            $StatusOK = $False

            break

        }

        switch ($Permission){

                "View" {$SetPermission = [Microsoft.SharePoint.Client.Sharing.Role]::View}

                "Edit" {$SetPermission = [Microsoft.SharePoint.Client.Sharing.Role]::Edit}

                "Owner"{$SetPermission = [Microsoft.SharePoint.Client.Sharing.Role]::Owner}

        } 

       if(!$StatusOK){return}

       $User | ForEach-Object {

            $CurUser = $_.Address.ToString()

            Write-Verbose "Granting '$CurUser' '$Permission' access to '$SiteURL'."

            $userList = New-Object "System.Collections.Generic.List``1[Microsoft.SharePoint.Client.Sharing.UserRoleAssignment]"

            $userRoleAssignment = New-Object Microsoft.SharePoint.Client.Sharing.UserRoleAssignment

            $userRoleAssignment.UserId = $CurUser

            $userRoleAssignment.Role = $SetPermission

            $userList.Add($userRoleAssignment)

            try{

                $res = $SharingManager::UpdateWebSharingInformation($ctx, $ctx.Web, $userList, $SendNotificationEmail, $message, $true, $true)

                $ctx.ExecuteQuery()

                $Success = $res.Status

                $StatusMessage = $res.message

            }

            catch{

                write-error "Error granting '$CurUser' '$Permission' access to '$SiteURL'."

                $Success = $False

                $StatusMessage = "Error granting '$CurUser' '$Permission' access to '$SiteURL'."

            }

            $ObjProperties = @{

                SiteURL = $SiteURL

                Permission = $Permission

                User = $CurUser

                Success = $Success

                StatusMessage = $StatusMessage

            }

            $OutObj = new-object psobject -Property $ObjProperties

            Write-Output $OutObj

    
    # Close the SQL connection 
    $Conn.Close()
  }
}
