Function Get-DigitalSignatures {
    <#
        .SYNOPSIS
            Get digital signatures from files in a target folder.
        
        .DESCRIPTION
            Gets digital signatures from .exe and .dll files from a specified path and sub-folders.
            Retreives the certificate thumbprint, certificate name, certificate expiry, certificate validity and file path and outputs the results.
            Output includes files that are not signed.

        .NOTES
            Name: Get-DigitalSignatures.ps1
            Author: Aaron Parker
            Twitter: @stealthpuppy
        
        .LINK
            http://stealthpuppy.com

        .OUTPUTS
            [System.Array]

        .PARAMETER Path
            A target path in which to scan files for digital signatures.

        .PARAMETER Include
            Gets only the specified items.

        .PARAMETER OutPath
            A target path to export certificates in P7B file format to. Each file will be named for the certificte thumbprint.

        .PARAMETER Unique
            By default the script will return all files and their certificate details. Use -Unique to return the first listing for each unique certificate.

        .PARAMETER Gridivew
            The script will return an object that can be used on the pipeline; however, use -Gridview output directly to an interactive table in a separate window.

        .EXAMPLE
            .\Get-DigitalSignatures.ps1 -Path "C:\Users\aaron\AppData\Local\GitHubDesktop"

            Description:
            Scans the folder specified in the Path variable and returns the digital signatures for each file.

        .EXAMPLE
            .\Get-DigitalSignatures.ps1 -Path "C:\Users\aaron\AppData\Local\GitHubDesktop" -OutPath C:\Temp

            Description:
            Scans the folder specified in the Path variable and returns the digital signatures for each file.
            A .P7B certificate file will be exported for each unique certificate and stored in the C:\Temp folder

        .EXAMPLE
            .\Get-DigitalSignatures.ps1 -Path "C:\Users\aaron\AppData\Local\GitHubDesktop" -Unique

            Description:
            Scans the folder specified in the Path variable and returns the digital signatures for only the first file with a unique certificate.
    #>
    [CmdletBinding(SupportsShouldProcess = $False, DefaultParameterSetName = 'Base')]
    Param (
        [Parameter(ParameterSetName = 'Base', Mandatory = $False, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, `
                HelpMessage = 'Specify a target path in which to scan files for digital signatures.')]
        [Alias('FullName', 'PSPath')]
        [string[]]$Path,

        [Parameter(Mandatory = $False, Position = 1, ValueFromPipeline = $False, `
                HelpMessage = 'Gets only the specified items.')]
        [Alias('Filter')]
        [string[]]$Include = @('*.exe', '*.dll'),

        [Parameter(ParameterSetName = 'Base', Mandatory = $False, HelpMessage = 'Output certificates to files in a specific folder.')]
        [ValidateScript( { If (Test-Path $_ -PathType 'Container') { $True } Else { Throw "Cannot find output path $_" } })]
        [string]$OutPath,

        [Parameter(ParameterSetName = 'Base', Mandatory = $False)]
        [switch]$Unique,

        [Parameter(ParameterSetName = 'Base', Mandatory = $False)]
        [switch]$Gridview
    )

    Begin {
        # Measure time taken to gather data
        $StopWatch = [system.diagnostics.stopwatch]::StartNew()

        Function Export-P7bFile {
            Param (
                [string]$File,
                [string]$OutPath
            )
            $cert = (Get-AuthenticodeSignature $File).SignerCertificate
            Write-Verbose "Exporting certificate: $OutPath\$($cert.Thumbprint).p7b"
            Export-Certificate -Cert $cert -FilePath "$OutPath\$($cert.Thumbprint).p7b" -Type P7B
        }
        
        # Initialise $Signatures as an array
        $Signatures = @()
    }
    Process {
        # For each path in $Path, check that the path exists
        If (Test-Path -Path $Path -IsValid) {

            # Get the item to determine whether it's a file or folder
            If ((Get-Item -Path $Path -Force).PSIsContainer) {

                # Target is a folder, so trawl the folder for .exe and .dll files in the target and sub-folders
                Write-Verbose "Scanning files in folder: $Path"
                $items = Get-ChildItem -Path $Path -Recurse -File -Include $Include
            }
            Else {

                # Target is a file, so just get metadata for the file
                Write-Verbose "Scanning file: $Path"
                $items = Get-ChildItem -Path $Path
            }

            # Get Exe and Dll files from the target path (inc. subfolders), find signatures and return certain properties in a grid view
            Write-Verbose "Getting digital signatures for: $Path"
            $Signatures += $items | Get-AuthenticodeSignature | `
                Select-Object @{Name = "Thumbprint"; Expression = {$_.SignerCertificate.Thumbprint}}, `
            @{Name = "Subject"; Expression = {$_.SignerCertificate.Subject}}, `
            @{Name = "Expiry"; Expression = {$_.SignerCertificate.NotAfter}}, `
                Status, `
                Path

        }
        Else {
            Write-Error "Path does not exist: $Path"
        }
    }
    End {
        # If -Unique is specified, filter the signatures list and return the first item of each unique certificate
        If ($Outpath -or $Unique) { 
            Write-Verbose "Filtering for unique signatures."
            $Signatures = $Signatures | Where-Object {$_.Status -eq "Valid" -or $_.Status -eq "UnknownError" } | `
                Group-Object -Property Thumbprint | `
                ForEach-Object { $_.Group | Select-Object -First 1 }
            Write-Verbose "$($Signatures.Count) unique signature/s found in $Path"
        }

        # Output the a P7b certificate file for each unique certificate found from files in the folder
        If ($OutPath) {
            Write-Verbose "Exporting certificate P7B files to $Outpath."
            ForEach ( $file in $Signatures.Path ) {
                Export-P7bFile -File $file -OutPath $OutPath | Out-Null
            } 
        }

        # If Gridview switch specified, output to a Grid View
        If ($Gridview) { $Signatures | Out-GridView -Title "Digital Signatures: $Path" }

        # Return output
        $StopWatch.Stop()
        Write-Verbose "Digital signature trawling complete. Script took $($StopWatch.Elapsed.TotalMilliseconds) ms to complete."
        Return $Signatures | Sort-Object -Property Thumbprint
    }
}