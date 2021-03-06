Function Test-AcMetadata {
    <#
        .SYNOPSIS
            Returns True|False if all specified properties does or doesn't have metadata

        .DESCRIPTION
            Returns True|False if all specified properties does or doesn't have metadata
            Return $True is the item has metadata we can act on; Return $False if the item does not have metadata
            Enabling filtering an array returned from Get-AcFileMetadata for files with or without metadata

        .NOTES
            Author: Aaron Parker
            Twitter: @stealthpuppy
  
        .LINK
            https://github.com/Insentra/ApplicationControl
  
        .OUTPUTS
            Boolean
  
        .PARAMETER FileList
            An array of files with metadata returned from Get-AcFileMetadata
  
        .EXAMPLE
            $NoMetadata = $Files | Where-Object { (Test-AcMetadata $_) -eq $False }
    
            Description:
            Filters the items in $Files that do not have any metadata.

        .EXAMPLE
            $Metadata = $Files | Where-Object { Test-AcMetadata $_ }

            Description:
            Filters the items in $Files that do have metadata that we can use for white listing.
    #>
    [CmdletBinding(SupportsShouldProcess = $False)]
    [OutputType([Bool])]
    Param (
        [Parameter(Mandatory = $True, Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $False)]
        [object]$obj
    )
    ForEach ($Property in 'Vendor', 'Company', 'Product', 'Description') {
        Write-Verbose "Testing $($obj.Path)"
        If ($obj.$Property -ge 2) { Return $True }
    }
    Return $False
}