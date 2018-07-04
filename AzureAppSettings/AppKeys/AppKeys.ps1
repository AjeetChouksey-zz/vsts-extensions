
[CmdletBinding()]
param(       
)

Function Merge-Hashtables([ScriptBlock]$Operator) {
  $Output = @{}
  ForEach ($Hashtable in $Input) {
          If ($Hashtable -is [Hashtable]) {
                  ForEach ($Key in $Hashtable.Keys) {
                          $Output.$Key = If ($Output.ContainsKey($Key)) {@($Output.$Key) + $Hashtable.$Key} Else {$Hashtable.$Key}}
                  }
          }
          If ($Operator) {ForEach ($Key in @($Output.Keys)) {$_ = @($Output.$Key); $Output.$Key = Invoke-Command $Operator}}
          $Output
}
function GetHostKeys ($functionName) {
        # Get Host Keys
        $hostKeysEndpoint = "/host/keys"       
        $hostKeysUri = $functionAppBaseUri + $hostKeysEndpoint
        $adminTokenHeader = @{ "Authorization" = "Bearer " + $adminBearerToken }
        $hostKey = Invoke-RestMethod -Method Get -Uri $hostKeysUri -Headers $adminTokenHeader
        $updateAppSettings.Add($functionName,$hostKeys)
       $hostKey.value
        # Get Master Keys       
        $masterKeyEndpoint = "/host/systemkeys/_master"
        $masterKeyUri = $functionAppBaseUri + $masterKeyEndpoint
        $masterKey = Invoke-RestMethod -Method Get -Uri $masterKeyUri -Headers $adminTokenHeader
        $masterKey.value
      $updateAppSettings.Add($functionName,$masterKey)
}
function UpdateFunctionAppSettings ( $updateAppSettings) {
  write-host "Getting Existing Function App Settings: "$functionAppName
  
        $getExistingAppSettings = Get-AzureRmWebAppSlot -ResourceGroupName $resourceGroup  -Name $functionAppName -Slot $slotName 
         #$get SiteConfig.AppSettings
        $existingAppSettings = $getExistingAppSettings.SiteConfig.AppSettings
       
        $getExistingAppSettings = Get-AzureRmWebAppSlot -ResourceGroupName $resourceGroup  -Name $functionAppName -Slot $slotName 
        #$get SiteConfig.AppSettings
        $existingAppSettings = $getExistingAppSettings.SiteConfig.AppSettings
      
         #converting existing appsetting into hastable
        $existingAppSettingsHash = @{}
        foreach($k in $existingAppSettings)
        {
             $existingAppSettingsHash[$k.name] = $k.value
        }
        Write-host "calling merge function"
      $mergeHashtable = $existingAppSettingsHash,$updateAppSettings | Merge-Hashtables {$_[0]}
    
      Write-host "Updating the App setting values"
      Set-AzureRmWebAppSlot -AppSettings $mergeHashtable -name $functionAppName -ResourceGroupName $resourceGroup -slot $slotName
                      # getting updated appconfig setting
      $getupdatedAppSettings = Get-AzureRmWebAppSlot  -ResourceGroupName  $resourceGroup  -Name $functionAppName -Slot $slotName 
      Write-host "Updated App setting values"
      $getupdatedAppSettings.SiteConfig.AppSettings
      
}
function GetAzureFunctionKey ($functionName) {
  write-host "Getting Function Key for: "$functionName
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
        
          if(($getKey.name -eq "default") -and (($getKey.name -eq $selectFunctionKeyType) -or ($selectFunctionKeyType -eq "all")) )
          {
            write-host "Adding Function Key for: "$functionName
          $updateAppSettings.Add($functionName,$functionURL)
          }
          else {
            write-host "Adding Function Key for: "$functionName
          $functionName= $functionName+"_"+$getKey.name
          $updateAppSettings.Add($functionName,$functionURL)
          }         
      }        
}

#$updateAppSettings

#Inputs from VSTS
Trace-VstsEnteringInvocation $MyInvocation
$ConnectedServiceName = Get-VstsInput -Name ConnectedServiceName -Require
$resourceGroup = Get-VstsInput -Name resourceGroup -Require
$functionAppName = Get-VstsInput -Name functionAppName -Require
$selectFunctionName = Get-VstsInput -Name selectFunctionName -Require
$slotName = Get-VstsInput -Name slotName -Require
$selectFunctionKeyType = Get-VstsInput -Name selectFunctionKeyType -Require
$hostKey = Get-VstsInput -Name hostKey -Require


try {
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

          #Claiming JWT Token for Azure Functions
          $accessTokenHeader = @{ "Authorization" = "Bearer " + $auth.access_token }
          $azureRmBaseUri = "https://management.azure.com"
          $azureRmApiVersion = "2016-08-01"
          $azureRmResourceType = "Microsoft.Web/sites"
          $azureRmResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/$azureRmResourceType/$functionAppName"
          $azureRmAdminBearerTokenEndpoint = "/functions/admin/token"
          $adminBearerTokenUri = $azureRmBaseUri + $azureRmResourceId + $azureRmAdminBearerTokenEndpoint + "?api-version=" + $azureRmApiVersion
          $adminBearerToken = Invoke-RestMethod -Method Get -Uri $adminBearerTokenUri -Headers $accessTokenHeader  
          $adminTokenHeader = @{ "Authorization" = "Bearer " + $adminBearerToken }

          #intialazing Hashtable to store new values
          $updateAppSettings =@{}
            #List of Azure Functions
          #functionAppBaseUri
          if($slotName -ne "production") 
          {
              $functionAppBaseUri = "https://$functionAppName-$slotName.azurewebsites.net/admin"
          }
          else {
              $functionAppBaseUri = "https://$functionAppName.azurewebsites.net/admin"
            }

            #List of Azure Functions
            if($slotName -ne "production")
            {
              $azureRmListFunctionsEndpoint = "/slots/$slotName/functions"
            }
            else {
              $azureRmListFunctionsEndpoint = "/functions"
            }
          if($selectFunctionName -eq "all")
          {
                $listFunctionsUri = $azureRmBaseUri + $azureRmResourceId+$azureRmListFunctionsEndpoint + "?api-version=" + $azureRmApiVersion
                $listFunctions = Invoke-RestMethod -Method Get -Uri $listFunctionsUri -Headers $accessTokenHeader   
                $listFunctionsSplit = ($listFunctions.value.name).split("`n")
                $listFunctionsSplit
                  foreach($fn in   $listFunctionsSplit)
                    {
                      write-host "Getting function Name: "$fn
                      if($slotName   -ne "production")
                      {
                        $functionName = $fn  -replace $functionAppName+ "/" -replace $slotName+ "/"
                        #$functionURLAPI ="https://$functionAppName-$slotName.azurewebsites.net/api/"
                      }
                    else
                    {
                      $functionName = $fn  -replace $functionAppName+ "/"
                    }
                    
                     GetAzureFunctionKey -functionName $functionName 
                    if($hostKey -eq $true)
                    {
                       #GetHostKeys -functionName $functionName
                    }                
                }
              }
              else{            
              
                  GetAzureFunctionKey -functionName $selectFunctionName       
                  if($hostKey -eq $true)
                  {
                     #GetHostKeys -functionName$ selectFunctionName                               
                }   
              }       
                write-host "Following Values will be added into App Settings for : "$functionAppName
                $updateAppSettings | Format-Table
                
                Write-host "Update Function...."
               UpdateFunctionAppSettings -updateAppSettings $updateAppSettings
             
} 
catch {
      $ErrorMessage = $_.Exception.Message
      $FailedItem = $_.Exception.ItemName
      $ErrorMessage
      $FailedItem
}
   


