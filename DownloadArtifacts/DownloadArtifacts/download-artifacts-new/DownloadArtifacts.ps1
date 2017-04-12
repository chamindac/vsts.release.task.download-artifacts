#
# ExampleTask.ps1
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param(
	<#[Parameter()]
    [string]$buildDefinitionName = $Env:BUILD_DEFINITIONNAME,#>
    [Parameter()]
    [string]$artifactNames = "*",
    [Parameter()]
    [string]$artifactDestinationFolder  
)

$ErrorActionPreference = "Stop"
Write-Host "Version 2.0.0"

$buildDefinitionName = $Env:BUILD_DEFINITIONNAME
if ([string]::IsNullOrEmpty($artifactDestinationFolder))
{
	$artifactDestinationFolder = $Env:SYSTEM_DEFAULTWORKINGDIRECTORY
}

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

Write-Host ('buildDefinitionName: ' + $buildDefinitionName)
Write-Host ('artifactNames: ' + $artifactNames)
Write-Host ('artifactDestinationFolder: ' + $artifactDestinationFolder)

#$tfscollection = "https://tfs.chamindac.com/tfs/SandBox/"
#$tfsUrl = "https://tfs.chamindac.com/tfs/SandBox/ChamindacTest"

$tfscollection = $Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI	
$tfsUrl = $Env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI 
$relAPIUrl = $Env:SYSTEM_TEAMFOUNDATIONSERVERURI + $Env:SYSTEM_TEAMPROJECT
$releaseId = $Env:RELEASE_RELEASEID

Write-Host $tfsUrl
Write-Host $relAPIUrl

$releaseInfoURI = $relAPIUrl +'/_apis/release/releases/' + $releaseId + '?api-version=3.0-preview.2'

#get the release
$releaseInfo = Invoke-RestMethod -Uri $releaseInfoURI -Method GET -Headers $headers

# Clean Destination
CreateOrCleanDirectory -DirectoryPath $artifactDestinationFolder

foreach ($linkedArtifact in $releaseInfo.artifacts)
    {
    <#$BuildDefUri = ($tfsURL + '/_apis/build/definitions?api-version=2.0&name=' + $buildDefinitionName)

    #Get Build Defintion ID
    Write-Host "REST Call [$BuildDefUri]"
    $buildDefinition = Invoke-RestMethod -Uri $BuildDefUri -Method GET -Headers $headers #-UseDefaultCredentials
    $buildDefinitionId = ($buildDefinition.value).id;#>
    $buildDefinitionId = $linkedArtifact.definitionReference.definition.id
    $buildDefinitionName = $linkedArtifact.alias
    $buildDefinitionProject = $linkedArtifact.definitionReference.project.name
    Write-Host "Build Def.Id: [$buildDefinitionId]"
    Write-Host "Build Def.Name: [$buildDefinitionName]"
    Write-Host "Build Def.Project Name: [$buildDefinitionProject]"
    
    <##Get latest succeeded build ID
    $tfsGetLatestSucceededBuildUrl = $tfsUrl + '/_apis/build/builds?definitions=' + $buildDefinitionId + '&statusFilter=completed&resultFilter=succeeded&$top=1&api-version=2.0'
    Write-Host "REST Call [$BuildDefUri]"
    $builds = Invoke-RestMethod -Uri $tfsGetLatestSucceededBuildUrl -Method GET -Headers $headers #-UseDefaultCredentials
    $buildId = ($builds.value).id;#>
    $buildId = $linkedArtifact.definitionReference.version.id
    Write-Host "Build Id: [$buildId]"

    #get artifacts
    $buildArtifactsURI = $tfsURL + $buildDefinitionProject + '/_apis/build/builds/' + $buildId + '/artifacts?api-version=2.0'
    Write-Host "REST Call [$buildArtifactsURI]"
    $buildArtifacts = Invoke-RestMethod -Uri $buildArtifactsURI -Method GET -Headers $headers #-UseDefaultCredentials

    $dropDestination = join-path $artifactDestinationFolder $buildDefinitionName

    # Clean Destination
    CreateOrCleanDirectory -DirectoryPath $dropDestination

    foreach($buildArtifact in $buildArtifacts.value)
    {
        $buildartifactFullName = join-path $buildDefinitionName $buildArtifact.name # Createing full artifact naem similar to ArtfactSourceAlias\Drop1

        foreach($artifactPathName in $artifactNamesArray) # Try for each Artifact Path
        {
            $artifactPathPartsArray = [regex]::split($artifactPathName, "\\")

            if(($artifactPathName -eq "*") -or ($artifactPathName -eq $buildartifactFullName) -or (($artifactPathPartsArray[0] -eq $buildDefinitionName ) -and ($artifactPathPartsArray[1] -eq $buildArtifact.name)))
            {
                <# 
                    Only * (default) as artifat path allow all artifacts download. 
                    Artifact name allows to download given artifact. Multiple artifacts can be specified with pattern Drop1;Drop2
                    Artifact name with subpath allows to download sub item of a given artifact. Multiple can be specified with pattern ArtifactsourceAlias\Drop1\MyWebProj;ArtifactsourceAlias\Drop1\ReleaseNote.html;ArtifactsourceAlias\Drop2;ArtifactsourceAlias\Drop3\MyWebProj2

                    Wild cards in paths are NOT Supported. * value as default supported to specify all artifacts.
                #>
                Write-Host ('Downloading artifact: ' + $artifactPathName)
            
                if($buildArtifact.resource.type -eq "FilePath")
                {
                    # UNC Path
                    $droppath = $buildArtifact.resource.downloadUrl -replace "file://","\\"
                    $droppath = $droppath -replace "%20"," "
                    $droppath = $droppath -replace "/","\"                    

                    
                    if (($artifactPathName -ne "*") -and ($artifactPathName -ne $buildartifactFullName))
                    {
                        for($i=1;$i -lt ($artifactPathPartsArray.Length);$i++)
                        {
                            $dropDestination = Join-Path $dropDestination $artifactPathPartsArray[$i]
                             $droppath = Join-Path $droppath $artifactPathPartsArray[$i]
                        }

                        #Subpath used - Create the destination path by drop folder
                        if (-not([IO.Directory]::Exists($dropDestination))) 
                        {
                            Write-Host ('Creating destination path: ' + $dropDestination)
                            [IO.Directory]::CreateDirectory($dropDestination) | Out-Null
                        }
                    
                    }
                    else
                    {
                        $droppath = Join-Path $droppath $buildArtifact.name # Creating drop path with specified artifact path
                    }
                
                     Write-Host ('Downloading from: ' + $droppath)
                    Copy-Item -Path $droppath -Destination $dropDestination -Recurse -Verbose
                }
                else
                {   # Drop available as server
                    
                    if (($artifactPathName -eq "*") -or ($artifactPathName -eq $buildartifactFullName))
                    {
                        $dropArchiveDestination = Join-path $dropDestination ("{0}.zip" -f $buildArtifact.name)
                        $droppath = $buildArtifact.resource.downloadUrl # If only artifact name default download url can be used
                    }
                    else
                    {
                        $tempArtifactPath= $buildArtifact.name
                        for($i=2;$i -lt ($artifactPathPartsArray.Length);$i++)
                        {
                            $tempArtifactPath = Join-Path $tempArtifactPath $artifactPathPartsArray[$i]
                             Write-Host ('temp artifact path: ' + $tempArtifactPath)
                        }

                        $dropArchiveDestination = Join-path $dropDestination ("{0}.zip" -f ($tempArtifactPath -replace "\\", "."))
                        # for sub path generate download url. Using the data ID.
                        $droppath =  $tfscollection + "_apis/resources/Containers/" + $buildArtifact.resource.data.Split("/")[1] + "?itemPath=" + ($tempArtifactPath -replace "\\", "%2F") + "&`$format=zip"
                    }

                    Write-Host ('Downloading from: ' + $droppath)
                    Invoke-WebRequest -uri $droppath -OutFile $dropArchiveDestination -Headers $headers #-UseDefaultCredentials
                
                    Write-Host ('Extracting artifact: ' + $buildArtifact.name)
                    Write-Host ('Extracting to: ' + $dropDestination)
                    [io.compression.zipfile]::ExtractToDirectory($dropArchiveDestination, $dropDestination)
                    Write-Host ("Extracting completed for: {0} to: {1}" -f $buildArtifact.name, $dropDestination)
                }
            }
        }
    }
}
Write-Host "##vso[task.complete result=Succeeded;]DONE"