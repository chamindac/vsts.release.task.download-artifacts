# Chamindac.vsts.release.task.download-artifacts

Release task that enable you to download build artifacts with filtering by artifact name, when you have more than one artifact, or download sub folders or files, without downloading the entire artifact folder.

Multiple artifact names/paths to download can be specified separated by ;. Example asterisk (default) as artifat names allow all artifacts download. Multiple artifacts can be specified with pattern Drop1;Drop2. Artifact name with subpath allows to download sub item of a given artifact. Multiple can be specified with pattern Drop1\\MyWebProj;Drop1\\ReleaseNote.html;Drop2;Drop3\\MyWebProj2 . Wild cards in paths are NOT SUPPORTED. Asterisk value as default supported to specify all artifacts.

# Documentation

[Update 1.1.15](http://chamindac.blogspot.com/2016/08/download-artifactsvststfs-extension.html)

Please check the [Get started](http://chamindac.blogspot.com/2016/07/vsts-release-task-download-artifacts.html) and [requirement of this extension](http://chamindac.blogspot.com/2016/07/multiple-build-artifactstfs-2015vsts.html)

**Note**
TFS 2015.2.1 onwards and VSTS supported.
XAML build output not supported. Only supports new web based build system.
Updating from version 1.0.18 to 1.1.15 requires to edit the release defintion and save to, fix parameter not found issues for removed input parameters.

![Download Artifacts](https://chamindac.gallery.vsassets.io/_apis/public/gallery/publisher/chamindac/extension/chamindac-vsts-release-task-download-artifacts/1.1.15/privateasset/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJwbiI6ImNoYW1pbmRhYyIsImVuIjoiY2hhbWluZGFjLXZzdHMtcmVsZWFzZS10YXNrLWRvd25sb2FkLWFydGlmYWN0cyIsImV4cCI6IjE0NjkzMTM4NzUifQ==.N0U4Q0k1RUxLRVBNcXJUYzB2WENtMUp4cXc2VUlCZWZBOExqM0FHcVNiaz0=/Microsoft.VisualStudio.Services.Screenshots.2)

![Download Artifacts](https://chamindac.gallery.vsassets.io/_apis/public/gallery/publisher/chamindac/extension/chamindac-vsts-release-task-download-artifacts/1.1.15/privateasset/eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJwbiI6ImNoYW1pbmRhYyIsImVuIjoiY2hhbWluZGFjLXZzdHMtcmVsZWFzZS10YXNrLWRvd25sb2FkLWFydGlmYWN0cyIsImV4cCI6IjE0NjkzMTM4NzUifQ==.N0U4Q0k1RUxLRVBNcXJUYzB2WENtMUp4cXc2VUlCZWZBOExqM0FHcVNiaz0=/Microsoft.VisualStudio.Services.Screenshots.3)