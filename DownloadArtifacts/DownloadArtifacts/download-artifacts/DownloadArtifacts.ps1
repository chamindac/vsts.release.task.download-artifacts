#
# ExampleTask.ps1
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param(
	[Parameter(Mandatory=$True)]
    [string]$buildDefinitionName,
    [Parameter()]
    [string]$artifactNames = "*",
    [Parameter()]
    [string]$artifactDestinationFolder = $Env:SYSTEM_DEFAULTWORKINGDIRECTORY
)

$ErrorActionPreference = "Stop"
Write-Verbose -Verbose "Version 1.0.18"

Add-Type -assembly 'system.io.compression.filesystem'
#--------------------------CreateCleanDirectory----------------------

function CreateOrCleanDirectory($DirectoryPath)
{
    if ([IO.Directory]::Exists($DirectoryPath)) 
    { 
	    $DeletePath = $DirectoryPath + "\*"
	    Remove-Item $DeletePath -recurse -Force
		[IO.Directory]::CreateDirectory($DirectoryPath) | Out-Null
    } 
    else
    { 
	    [IO.Directory]::CreateDirectory($DirectoryPath) | Out-Null
	    
    } 
}

#--------------------------Invoke-FileDownload----------------------

function Invoke-FileDownload
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [uri] $Uri,

        [Parameter(Mandatory)]
        [string] $OutputFile,

        [Parameter(Mandatory)]
        [System.Net.WebClient]$webClient
    )

    #$webClient = New-Object System.Net.WebClient

    $changed = Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
        #Write-Progress -Activity "Downloading to $OutputFile" -PercentComplete $eventArgs.ProgressPercentage
        Write-Verbose -Verbose ("Downloading to {0} completed {1}" -f $OutputFile,$eventArgs.ProgressPercentage)
    }

    $handle = $webClient.DownloadFileAsync($Uri, $PSCmdlet.GetUnresolvedProviderPathFromPSPath($OutputFile))

    Write-Verbose -Verbose "Downloading started"
    sleep -Seconds 2

    while ($webClient.IsBusy)
    {
        Start-Sleep -Milliseconds 10
    }

    #Write-Progress -Activity "Downloading to $OutputFile" -Completed
    Write-Verbose -Verbose ("Downloading to {0} completed." -f $OutputFile)
    Remove-Job $changed -Force
    Get-EventSubscriber | Where SourceObject -eq $webClient | Unregister-Event -Force
}

#------------------------------------------------------------------------------

$artifactNamesArray = [regex]::split($artifactNames, ";")

$vssEndPoint = Get-ServiceEndPoint -Name "SystemVssConnection" -Context $distributedTaskContext
$personalAccessToken = $vssEndpoint.Authorization.Parameters.AccessToken
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization" ,"Bearer $personalAccessToken")
$webclient = new-object System.Net.WebClient
$webclient.Headers.Add("Authorization" ,"Bearer $personalAccessToken")
#$webclient.Encoding = [System.Text.Encoding]::UTF8
#Write-Host "Get service endpoint done"

Write-Verbose -Verbose ('buildDefinitionName: ' + $buildDefinitionName)
Write-Verbose -Verbose ('artifactNames: ' + $artifactNames)
Write-Verbose -Verbose ('artifactDestinationFolder: ' + $artifactDestinationFolder)
	
$tfsUrl = $Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + $Env:SYSTEM_TEAMPROJECT

Write-verbose -Verbose $tfsUrl
$BuildDefUri = ($tfsURL + '/_apis/build/definitions?api-version=2.0&name=' + $buildDefinitionName)

#Get Build Defintion ID
write-verbose -Verbose "REST Call [$BuildDefUri]"
$buildDefinition = Invoke-RestMethod -Uri $BuildDefUri -Method GET -Headers $headers
$buildDefinitionId = ($buildDefinition.value).id;
Write-Verbose -Verbose "Build Def.Id: [$buildDefinitionId]"
    
#Get latest succeeded build ID
$tfsGetLatestSucceededBuildUrl = $tfsUrl + '/_apis/build/builds?definitions=' + $buildDefinitionId + '&statusFilter=completed&resultFilter=succeeded&$top=1&api-version=2.0'
write-verbose -Verbose "REST Call [$BuildDefUri]"
$builds = Invoke-RestMethod -Uri $tfsGetLatestSucceededBuildUrl -Method GET -Headers $headers
$buildId = ($builds.value).id;
Write-Verbose -Verbose "Build Id: [$buildId]"

#get artifacts
$buildArtifactsURI = $tfsURL + '/_apis/build/builds/' + $buildId + '/artifacts?api-version=2.0'
write-verbose -Verbose "REST Call [$buildArtifactsURI]"
$buildArtifacts = Invoke-RestMethod -Uri $buildArtifactsURI -Method GET -Headers $headers

CreateOrCleanDirectory -DirectoryPath $artifactDestinationFolder

foreach($buildArtifact in $buildArtifacts.value)
{
    if($artifactNamesArray.Contains("*") -or $artifactNamesArray.Contains($buildArtifact.name))
    {
        Write-Verbose -Verbose ('Downloading artifact: ' + $buildArtifact.name)
        Write-Verbose -Verbose ('Downloading from: ' + $buildArtifact.resource.downloadUrl)
        if($buildArtifact.resource.type -eq "FilePath")
        {
            $droppath = $buildArtifact.resource.downloadUrl -replace "file://","\\"
            Copy-Item -Path "$droppath\*" -Destination $artifactDestinationFolder -Recurse -Verbose
        }
        else
        {   
            $dropArchiveDestination = Join-path $artifactDestinationFolder ("{0}.zip" -f $buildArtifact.name)
            Invoke-WebRequest -uri $buildArtifact.resource.downloadUrl -OutFile $dropArchiveDestination -Headers $headers
            #Invoke-FileDownload -Uri $buildArtifact.resource.downloadUrl -OutputFile $dropArchiveDestination -webClient $webclient
            
            Write-Verbose -Verbose ('Extracting artifact: ' + $buildArtifact.name)
            Write-Verbose -Verbose ('Extracting to: ' + $artifactDestinationFolder)
            [io.compression.zipfile]::ExtractToDirectory($dropArchiveDestination, $artifactDestinationFolder)
            #Remove-Item $dropArchiveDestination -Force
            Write-Verbose -Verbose ("Extracting completed for: {0} to: {1}" -f $buildArtifact.name, $artifactDestinationFolder)
        }
    }
}
