
[CmdletBinding()]
param(       
)
Trace-VstsEnteringInvocation $MyInvocation
$ConnectedServiceName = Get-VstsInput -Name ConnectedServiceName -Require
$resourceGroup = Get-VstsInput -Name resourceGroup -Require
$slotName = Get-VstsInput -Name slotName -Require
$appSettings = Get-VstsInput -Name appSettings -Require
$functionAppName = Get-VstsInput -Name functionAppName -Require

try{

        # Get the parameters
        $ConnectedServiceName = Get-VstsInput -Name "ConnectedServiceName"
        # Get the end point from the name passed as a parameter
        $Endpoint = Get-VstsEndpoint -Name $ConnectedServiceName -Require
        # Get the authentication details
        $clientID = $Endpoint.Auth.parameters.serviceprincipalid
        $key = $Endpoint.Auth.parameters.serviceprincipalkey
        $tenantId = $Endpoint.Auth.parameters.tenantid
        $SecurePassword = $key | ConvertTo-SecureString -AsPlainText -Force
        $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $clientID, $SecurePassword
        # Authenticate
        Login-AzureRmAccount -Credential $cred -TenantId $tenantId -ServicePrincipal

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
        $getExistingAppSettings = Get-AzureRmWebAppSlot -ResourceGroupName $resourceGroup  -Name $functionAppName -Slot $slotName 
    
    #$get SiteConfig.AppSettings
    
    $existingAppSettings = $getExistingAppSettings.SiteConfig.AppSettings
    $existingAppSettings

     $getExistingAppSettings = Get-AzureRmWebAppSlot -ResourceGroupName $resourceGroup  -Name $functionAppName -Slot $slotName 
    
    #$get SiteConfig.AppSettings
    
    $existingAppSettings = $getExistingAppSettings.SiteConfig.AppSettings
    $existingAppSettings

    
 $appSettingHash = @{}
 $appSettings.Split('|') | ForEach-Object{
         $key, $value = $_.Split(':')
         $appSettingHash[$key] = $value
 }


     #converting existing appsetting into hastable
     $existingAppSettingsHash = @{}
     foreach($k in $existingAppSettings)
     {
             $existingAppSettingsHash[$k.name] = $k.value
     }
     Write-Host "Exiting Hash"
     $existingAppSettingsHash

     Write-host "calling merge function"
     $mergeHashtable = $existingAppSettingsHash,$appSettingHash | Merge-Hashtables {$_[0]}

      Write-Host "After Merge"
     $mergeHashtable


     Write-host "Updating the App setting values"
     Set-AzureRmWebAppSlot -AppSettings $mergeHashtable -name $functionAppName -ResourceGroupName $resourceGroup -slot $slotName
                    # getting updated appconfig setting
    $getupdatedAppSettings = Get-AzureRmWebAppSlot  -ResourceGroupName  $resourceGroup  -Name $functionAppName -Slot $slotName 
    Write-host "Updated App setting values"
    $getupdatedAppSettings.SiteConfig.AppSettings
    
    }
    finally{
    }
    


