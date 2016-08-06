#
# ExampleTask.ps1
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param(
	<#[Parameter(Mandatory=$True)]
    [string]$buildDefinitionName,#>
    [Parameter()]
    [string]$artifactNames = "*"<#,
    [Parameter()]
    [string]$artifactDestinationFolder = $Env:SYSTEM_DEFAULTWORKINGDIRECTORY#>
)

$ErrorActionPreference = "Stop"
Write-Verbose -Verbose "Version 1.1.11"

$buildDefinitionName = $Env:BUILD_DEFINITIONNAME
$artifactDestinationFolder = Join-Path $Env:SYSTEM_DEFAULTWORKINGDIRECTORY $buildDefinitionName

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


$artifactNamesArray = [regex]::split($artifactNames, ";")

$vssEndPoint = Get-ServiceEndPoint -Name "SystemVssConnection" -Context $distributedTaskContext
$personalAccessToken = $vssEndpoint.Authorization.Parameters.AccessToken
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization" ,"Bearer $personalAccessToken")

Write-Verbose -Verbose ('buildDefinitionName: ' + $buildDefinitionName)
Write-Verbose -Verbose ('artifactNames: ' + $artifactNames)
Write-Verbose -Verbose ('artifactDestinationFolder: ' + $artifactDestinationFolder)

#$tfscollection = "https://tfs.chamindac.com/tfs/SandBox/"
#$tfsUrl = "https://tfs.chamindac.com/tfs/SandBox/ChamindacTest"

$tfscollection = $Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI	
$tfsUrl = $Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI + $Env:SYSTEM_TEAMPROJECT

Write-verbose -Verbose $tfsUrl
<#$BuildDefUri = ($tfsURL + '/_apis/build/definitions?api-version=2.0&name=' + $buildDefinitionName)

#Get Build Defintion ID
write-verbose -Verbose "REST Call [$BuildDefUri]"
$buildDefinition = Invoke-RestMethod -Uri $BuildDefUri -Method GET -Headers $headers #-UseDefaultCredentials
$buildDefinitionId = ($buildDefinition.value).id;#>
$buildDefinitionId = $Env:BUILD_DEFINITIONID
Write-Verbose -Verbose "Build Def.Id: [$buildDefinitionId]"
    
<##Get latest succeeded build ID
$tfsGetLatestSucceededBuildUrl = $tfsUrl + '/_apis/build/builds?definitions=' + $buildDefinitionId + '&statusFilter=completed&resultFilter=succeeded&$top=1&api-version=2.0'
write-verbose -Verbose "REST Call [$BuildDefUri]"
$builds = Invoke-RestMethod -Uri $tfsGetLatestSucceededBuildUrl -Method GET -Headers $headers #-UseDefaultCredentials
$buildId = ($builds.value).id;#>
$buildId = $Env:BUILD_BUILDID
Write-Verbose -Verbose "Build Id: [$buildId]"

#get artifacts
$buildArtifactsURI = $tfsURL + '/_apis/build/builds/' + $buildId + '/artifacts?api-version=2.0'
write-verbose -Verbose "REST Call [$buildArtifactsURI]"
$buildArtifacts = Invoke-RestMethod -Uri $buildArtifactsURI -Method GET -Headers $headers #-UseDefaultCredentials

# Clean Destination
CreateOrCleanDirectory -DirectoryPath $artifactDestinationFolder

foreach($buildArtifact in $buildArtifacts.value)
{
    foreach($artifactPathName in $artifactNamesArray) # Try for each Artifact Path
    {
        $artifactPathPartsArray = [regex]::split($artifactPathName, "\\")

        if(($artifactPathName -eq "*") -or ($artifactPathName -eq $buildArtifact.name) -or ($artifactPathPartsArray[0] -eq $buildArtifact.name))
        {
            <# 
                Only * (default) as artifat path allow all artifacts download. 
                Artifact name allows to download given artifact. Multiple artifacts can be specified with pattern Drop1;Drop2
                Artifact name with subpath allows to download sub item of a given artifact. Multiple can be specified with pattern Drop1\MyWebProj;Drop1\ReleaseNote.html;Drop2;Drop3\MyWebProj2

                Wild cards in paths are NOT Supported. * value as default supported to specify all artifacts.
            #>
            Write-Verbose -Verbose ('Downloading artifact: ' + $artifactPathName)
            
            if($buildArtifact.resource.type -eq "FilePath")
            {
                # UNC Path
                $droppath = $buildArtifact.resource.downloadUrl -replace "file://","\\"
                $droppath = $droppath -replace "%20"," "
                $droppath = $droppath -replace "/","\"
                $droppath = Join-Path $droppath $artifactPathName # Creating drop path with specified artifact path
                Write-Verbose -Verbose ('Downloading from: ' + $droppath)

                $dropDestination = $artifactDestinationFolder

                if (($artifactPathName -ne "*") -and ($artifactPathName -ne $buildArtifact.name))
                {
                    for($i=0;$i -lt ($artifactPathPartsArray.Length-1);$i++)
                    {
                        $dropDestination = Join-Path $dropDestination $artifactPathPartsArray[$i]
                    }

                    #Subpath used - Create the destination path by drop folder
                    if (-not([IO.Directory]::Exists($dropDestination))) 
                    {
                        Write-Verbose -Verbose ('Creating destination path: ' + $dropDestination)
                        [IO.Directory]::CreateDirectory($dropDestination) | Out-Null
                    }
                    
                }
                
                Copy-Item -Path $droppath -Destination $dropDestination -Recurse -Verbose
            }
            else
            {   # Drop available as server
                

                if (($artifactPathName -eq "*") -or ($artifactPathName -eq $buildArtifact.name))
                {
                    $dropArchiveDestination = Join-path $artifactDestinationFolder ("{0}.zip" -f $buildArtifact.name)
                    $droppath = $buildArtifact.resource.downloadUrl # If only artifact name default download url can be used
                }
                else
                {
                    $dropArchiveDestination = Join-path $artifactDestinationFolder ("{0}.zip" -f ($artifactPathName -replace "\\", "."))
                    # for sub path generate download url. Using the data ID.
                    $droppath =  $tfscollection + "_apis/resources/Containers/" + $buildArtifact.resource.data.Split("/")[1] + "?itemPath=" + ($artifactPathName -replace "\\", "%2F") + "&`$format=zip"
                }

                Write-Verbose -Verbose ('Downloading from: ' + $droppath)
                Invoke-WebRequest -uri $droppath -OutFile $dropArchiveDestination -Headers $headers #-UseDefaultCredentials
                
                Write-Verbose -Verbose ('Extracting artifact: ' + $buildArtifact.name)
                Write-Verbose -Verbose ('Extracting to: ' + $artifactDestinationFolder)
                [io.compression.zipfile]::ExtractToDirectory($dropArchiveDestination, $artifactDestinationFolder)
                Write-Verbose -Verbose ("Extracting completed for: {0} to: {1}" -f $buildArtifact.name, $artifactDestinationFolder)
            }
        }
    }
}
