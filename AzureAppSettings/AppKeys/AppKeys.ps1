
[CmdletBinding()]
param(       
)
Trace-VstsEnteringInvocation $MyInvocation
$ConnectedServiceName = Get-VstsInput -Name ConnectedServiceName -Require
$resourceGroup = Get-VstsInput -Name resourceGroup -Require
$functionAppName = Get-VstsInput -Name functionAppName -Require
$slotName = Get-VstsInput -Name slotName -Require
$action = Get-VstsInput -Name action -Require


        # Get the parameters
        $ConnectedServiceName = Get-VstsInput -Name "ConnectedServiceName"
        # Get the end point from the name passed as a parameter
        $Endpoint = Get-VstsEndpoint -Name $ConnectedServiceName -Require
        # Get the authentication details
        $subscriptionId=$Endpoint.Data.SubscriptionId
        $clientID = $Endpoint.Auth.parameters.serviceprincipalid
        $clientSecret = $Endpoint.Auth.parameters.serviceprincipalkey
        $tenantId = $Endpoint.Auth.parameters.tenantid
        $SecurePassword = $clientSecret | ConvertTo-SecureString -AsPlainText -Force
        $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $clientID, $SecurePassword
        # Authenticate
        Login-AzureRmAccount -Credential $cred -TenantId $tenantId -ServicePrincipal
      
        $authUri = "https://login.microsoftonline.com/"+$tenantId+"/oauth2/token?api-version=1.0"
        $resourceUri = "https://management.core.windows.net/"

        $authRequestBody = @{}
        $authRequestBody.grant_type = "client_credentials"
        $authRequestBody.resource = $resourceUri
        $authRequestBody.client_id = $clientId
        $authRequestBody.client_secret = $clientSecret

        $auth = Invoke-RestMethod -Uri $authUri -Method Post -Body $authRequestBody
        #$auth
      #Claiming JWT Token for Azure Functions
        $accessTokenHeader = @{ "Authorization" = "Bearer " + $auth.access_token }

        $azureRmBaseUri = "https://management.azure.com"
        $azureRmApiVersion = "2016-08-01"
        $azureRmResourceType = "Microsoft.Web/sites"
    
        $azureRmResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/$azureRmResourceType/$functionAppName"
        $azureRmAdminBearerTokenEndpoint = "/functions/admin/token"
        $adminBearerTokenUri = $azureRmBaseUri + $azureRmResourceId + $azureRmAdminBearerTokenEndpoint + "?api-version=" + $azureRmApiVersion
        
        $adminBearerToken = Invoke-RestMethod -Method Get -Uri $adminBearerTokenUri -Headers $accessTokenHeader  
      
      $updateAppSettings =@{}
        if($slotName -ne "production") 
        {
          $functionAppBaseUri = "https://$functionAppName-$slotName.azurewebsites.net/admin"
        }
        else {
          $functionAppBaseUri = "https://$functionAppName.azurewebsites.net/admin"
        }

        $hostKeysEndpoint = "/host/keys"       
        $hostKeysUri = $functionAppBaseUri + $hostKeysEndpoint
        $adminTokenHeader = @{ "Authorization" = "Bearer " + $adminBearerToken }

        $hostKeys = Invoke-RestMethod -Method Get -Uri $hostKeysUri -Headers $adminTokenHeader
        #Write-Host hostKeys
      #  $hostKeys
        #$hostKeys.name
        #$hostKeys.value
        #$hostKeys.link.hrf

       
        $masterKeyEndpoint = "/host/systemkeys/_master"
        $masterKeyUri = $functionAppBaseUri + $masterKeyEndpoint

        $masterKey = Invoke-RestMethod -Method Get -Uri $masterKeyUri -Headers $adminTokenHeader
    #    Write-Host _master
        #$masterKey
        #$masterKey.value
        #$masterKey.link.hrf


      #List of Azure Functions
     if($slotName -ne "production")
      {
        $azureRmListFunctionsEndpoint = "/slots/$slotName/functions"
      }
      else {
        $azureRmListFunctionsEndpoint = "/functions"
      }
      
        $listFunctionsUri = $azureRmBaseUri + $azureRmResourceId+$azureRmListFunctionsEndpoint + "?api-version=" + $azureRmApiVersion
        $listFunctions = Invoke-RestMethod -Method Get -Uri $listFunctionsUri -Headers $accessTokenHeader
       
        $functionName=""
        #Accessing to Individual Function Keys
        #$functionAppBaseUri = "https://$functionAppName.azurewebsites.net/admin"
        #testfnapps-slot/HttpTriggerCSharp1
      $listFunctionsSplit = ($listFunctions.value.name).split("`n")

      foreach($fn in   $listFunctionsSplit)
       {
         if($slotName   -ne "production")
         {
           $functionName = $fn  -replace $functionAppName+ "/" -replace $slotName+ "/"
         }
        else
        {
          $functionName = $fn  -replace $functionAppName+ "/"
        }
        $functionName
          $functionKeysEndpoint = "/functions/$functionName/keys"
          $functionKeysUri = $functionAppBaseUri + $functionKeysEndpoint
            
           # $adminTokenHeader = @{ "Authorization" = "Bearer " + $adminBearerToken }
            
            $functionKeys = Invoke-RestMethod -Method Get -Uri $functionKeysUri -Headers $adminTokenHeader
         
           
        foreach($getKey in  $functionKeys.keys)
        {
           
             if($slotName   -ne "production")
            {
              $functionURL= "https://$functionAppName-$slotName.azurewebsites.net/api/"+$functionName+"?code="+$getKey.value
              
            }
            else{
              $functionURL= "https://$functionAppName.azurewebsites.net/api/"+$functionName+"?code="+ $getKey.value
            }
           if($getKey.name -eq "default")
           {
            $updateAppSettings.Add($functionName,$functionURL)
           }
           else {
            $functionName= $functionName+"_"+$getKey.name
            $updateAppSettings.Add($functionName,$functionURL)
           }           
        
          }
        }
        $updateAppSettings | Format-Table
        &  .\MergeHash.ps1
   #merge hashtable

