#Requires -Version 5.1

# Define paths to public and private functions in a more robust way
$PublicPath = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$PrivatePath = Join-Path -Path $PSScriptRoot -ChildPath 'Private'

$PublicFunctions = @( Get-ChildItem -Path $PublicPath -Filter '*.ps1' -Recurse -ErrorAction Ignore )
$PrivateFunctions = @( Get-ChildItem -Path $PrivatePath -Filter '*.ps1' -Recurse -ErrorAction Ignore )

# Dot source all functions (both public and private) to make them available inside the module
foreach ($FunctionFile in @($PublicFunctions + $PrivateFunctions)) {
    try {
        # Unblock files downloaded from the internet
        $FunctionFile | Unblock-File -ErrorAction SilentlyContinue
        . $FunctionFile.FullName
    } catch {
        Write-Error -Message "Failed to import function '$($FunctionFile.FullName)': $_"
    }
}

#$ModuleName = $($MyInvocation.MyCommand.Name) -replace '\.psm1$', ''
#$AppDataPath = [System.IO.Path]::Combine($env:APPDATA, $ModuleName)

# Explicitly export ONLY the public functions to the user.
# The private functions remain available inside the module, but are hidden from the user.
$ExportableFunctions = $PublicFunctions.BaseName
Export-ModuleMember -Function $ExportableFunctions

