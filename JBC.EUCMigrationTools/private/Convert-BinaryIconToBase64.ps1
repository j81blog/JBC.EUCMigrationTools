function Convert-BinaryIconToBase64 {
    <#
    .SYNOPSIS
        Converts binary icon data (hex string) to Base64 format with optional resizing.

    .DESCRIPTION
        Takes a hex-encoded icon string, converts it to binary, optionally resizes the image,
        and returns the Base64-encoded result.

    .PARAMETER IconData
        Hex-encoded string representing the binary icon data.

    .PARAMETER Size
        Target size for the icon (width and height in pixels). Default is 32.
        Must be between 16 and 256.

    .EXAMPLE
        Convert-BinaryIconToBase64 -IconData "89504E470D0A1A0A..." -Size 64
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$IconData,

        [Parameter(Mandatory = $false)]
        [ValidateRange(16, 256)]
        [int]$Size = 32
    )

    try {
        # Validate hex string format
        if ($IconData -notmatch '^[0-9A-Fa-f]+$') {
            throw "IconData must be a valid hexadecimal string"
        }

        if ($IconData.Length % 2 -ne 0) {
            throw "IconData must have an even number of characters"
        }

        # Convert hex string to byte array
        $binaryData = [byte[]]::new($IconData.Length / 2)
        for ($i = 0; $i -lt $binaryData.Length; $i++) {
            $binaryData[$i] = [Convert]::ToByte($IconData.Substring($i * 2, 2), 16)
        }

        # Load System.Drawing assembly
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop

        # Load image from byte array
        $memoryStream = New-Object System.IO.MemoryStream(, $binaryData)
        $originalImage = [System.Drawing.Image]::FromStream($memoryStream)

        # Check if resizing is needed
        if ($originalImage.Width -eq $Size -and $originalImage.Height -eq $Size) {
            # No resizing needed - use original binary data
            $resultData = $binaryData
        } else {
            # Resize image
            $resizedImage = New-Object System.Drawing.Bitmap $Size, $Size
            $graphics = [System.Drawing.Graphics]::FromImage($resizedImage)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($originalImage, 0, 0, $Size, $Size)
            $graphics.Dispose()

            # Convert resized image to byte array
            $outputStream = New-Object System.IO.MemoryStream
            $resizedImage.Save($outputStream, [System.Drawing.Imaging.ImageFormat]::Png)
            $resultData = $outputStream.ToArray()
            $outputStream.Dispose()
            $resizedImage.Dispose()
        }

        # Clean up resources
        $originalImage.Dispose()
        $memoryStream.Dispose()

        # Convert byte array to Base64
        $base64String = [Convert]::ToBase64String($resultData)

        return $base64String
    } catch {
        Write-Error "Failed to convert icon data to Base64: $_"
        throw
    }
}