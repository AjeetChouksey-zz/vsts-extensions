param(    
    [string]$projectFile,
    [string]$silent,
	[string]$arguments
)

foreach($key in $PSBoundParameters.Keys)
{
    Write-Host ($key + ' = ' + $PSBoundParameters[$key])
}

$path = split-path $MyInvocation.MyCommand.Path

if(!(Test-Path ($path + "\soapui"))){
	
	
	$urlZip = "https://azure365fileshare.blob.core.windows.net/soapui/SoapUI-5.4.0-windows.zip"
	$output = $path + "\soapui.zip"
	Write-Host "Is: "
	Write-Host (Test-Path $path)
	Write-Host ("Download SoapUI..." + $urlZip + " to " + $output)

	(New-Object System.Net.WebClient).DownloadFile($urlZip, $output)

	Add-Type -AssemblyName System.IO.Compression.FileSystem
	
	function Unzip
	{
		param([string]$zipfile, [string]$outpath)

		[System.IO.Compression.ZipFile]::ExtractToDirectory($zipfile, $outpath)
	}

	Write-Host "Unzip SoapUI..."

	Unzip $output ($path + "\soapui")
	$target = "soapui\SoapUI-5.4.0"
	Copy-Item soapui-settings.xml $target
	
}

Write-Host "SoapUI is ready."

$soapUiExe = $path + "\soapui\SoapUI-5.4.0\bin\testrunner.bat"
$env:SOAPUI_EXE = $soapUiExe

Write-Host("##vso[task.setvariable variable=SOAPUI_EXE;]$soapUiExe")

$args = ""
if($arguments)
{
	$args = $args + $arguments
}
$args = $args + " " + $projectFile
Write-Host("Executing Soap UI $soapUiExe with args: $args")

Invoke-Tool -Path $soapUiExe -Arguments $args
