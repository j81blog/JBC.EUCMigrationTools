function Get-IvantiWCApplication {
    <#
    .SYNOPSIS
        Extracts Ivanti Workspace Control application configurations from XML file(s).

    .DESCRIPTION
        Processes Ivanti Workspace Control XML building block file(s) and extracts application
        settings, assignments, and metadata. Supports both single large XML files and
        directories containing multiple separate XML files (one per application).

    .PARAMETER XmlFilePath
        (Legacy parameter) Path to a single Ivanti Workspace Control XML building block file.
        This parameter is maintained for backward compatibility. Use -XmlPath instead.

    .PARAMETER XmlPath
        Path to either:
        - A single XML file containing all application configurations
        - A directory containing multiple XML files (one per application)

    .PARAMETER DomainFqdn
        Optional domain FQDN to append to non-FQDN SMB paths.

    .PARAMETER AsJson
        Switch to output the results as JSON format instead of PowerShell objects.

    .EXAMPLE
        Get-IvantiWCApplication -XmlFilePath "C:\Config\IvantiApps.xml"

        Processes a single XML file (legacy parameter usage).

    .EXAMPLE
        Get-IvantiWCApplication -XmlPath "C:\Config\IvantiApps.xml"

        Processes a single XML file containing all applications.

    .EXAMPLE
        Get-IvantiWCApplication -XmlPath "C:\Config\Applications\" -AsJson

        Processes all XML files in the specified directory and outputs as JSON.

    .NOTES
        Function  : Get-IvantiWCApplication
        Author    : John Billekens
        Copyright : Copyright (c) John Billekens Consultancy
        Version   : 2025.1106.1445
    #>
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'ByFilePath',
            HelpMessage = "Path to the Ivanti Workspace Control XML building block file."
        )]
        [ValidateScript({
                if (-not (Test-Path $_ -PathType Leaf)) {
                    throw "File '$_' does not exist."
                }
                return $true
            })]
        [string]$XmlFilePath,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'ByPath',
            HelpMessage = "Path to the Ivanti Workspace Control XML building block file or directory containing XML files."
        )]
        [ValidateScript({
                if (-not (Test-Path $_)) {
                    throw "Path '$_' does not exist."
                }
                return $true
            })]
        [string]$XmlPath,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Domain FQDN to append to non-FQDN SMB paths."
        )]
        [string]$DomainFqdn,

        [Parameter(
            Mandatory = $false,
            HelpMessage = "Output the results as JSON."
        )]
        [switch]$AsJson
    )

    $JsonOutput = @()
    $ApplicationsToProcess = @()

    # Handle backward compatibility - map XmlFilePath to XmlPath
    if ($PSCmdlet.ParameterSetName -eq 'ByFilePath') {
        $XmlPath = $XmlFilePath
    }

    # Determine if XmlPath is a file or directory
    if (Test-Path -Path $XmlPath -PathType Leaf) {
        # Single XML file mode
        Write-Verbose "Processing single XML file: $XmlPath"
        try {
            [xml]$IvantiXmlData = Get-Content -Path $XmlPath -Raw -ErrorAction Stop
            $ApplicationsToProcess = @($IvantiXmlData.SelectNodes("//application"))
        } catch {
            Write-Error "Failed to load XML file '$XmlPath': $_"
            return
        }
    } elseif (Test-Path -Path $XmlPath -PathType Container) {
        # Directory with multiple XML files mode
        Write-Verbose "Processing directory containing multiple XML files: $XmlPath"
        $XmlFiles = Get-ChildItem -Path $XmlPath -Filter "*.xml" -File

        if ($XmlFiles.Count -eq 0) {
            Write-Warning "No XML files found in directory: $XmlPath"
            return
        }

        Write-Verbose "Found $($XmlFiles.Count) XML file(s) in directory."

        foreach ($XmlFile in $XmlFiles) {
            try {
                [xml]$XmlData = Get-Content -Path $XmlFile.FullName -Raw -ErrorAction Stop
                $Apps = @($XmlData.SelectNodes("//application"))

                if ($Apps.Count -gt 0) {
                    $ApplicationsToProcess += $Apps
                    Write-Verbose "Loaded $($Apps.Count) application(s) from '$($XmlFile.Name)'"
                } else {
                    Write-Warning "No application nodes found in file: $($XmlFile.Name)"
                }
            } catch {
                Write-Warning "Failed to load XML file '$($XmlFile.Name)': $_"
                continue
            }
        }
    } else {
        Write-Error "XmlPath must be either a file or a directory."
        return
    }

    if ($ApplicationsToProcess.Count -eq 0) {
        Write-Warning "No applications found to process."
        return
    }

    $ItemsWithErrors = @()
    $TotalNumberOfItems = $ApplicationsToProcess.Count
    $Counter = 0
    Write-Verbose "Found $TotalNumberOfItems applications to process in the Ivanti Workspace Control XML."
    for ($i = 0; $i -lt $ApplicationsToProcess.Count; $i++) {
        $Counter++
        $Application = $ApplicationsToProcess[$i]
        Write-Progress -Activity "Processing Applications" -Status "Processing item $($Counter) of $($TotalNumberOfItems)" -CurrentOperation "Application: `"$($Application.configuration.title)`"" -PercentComplete (($Counter / $TotalNumberOfItems) * 100)
        $Enabled = $false
        $State = "Disabled"
        if ($Application.settings.enabled -eq "yes") {
            $Enabled = $true
            $State = "Enabled"
        }
        if ($Application.settings.enabled -eq "no" -or [string]::IsNullOrEmpty($Application.settings.enabled)) {
            $Enabled = $false
            $State = "Disabled"
        }
        $URL = ""
        $Parameters = "$($Application.configuration.parameters)"
        $CommandLine = "$($Application.configuration.commandline)"
        $WorkingDir = "$($Application.configuration.workingdir)"
        $DisplayName = "$($Application.configuration.title)"
        $Description = "$($Application.configuration.description)"

        $BinaryIconData = $null
        if (-not [string]::IsNullOrEmpty($($Application.configuration.icon32x256))) {
            $BinaryIconData = $($Application.configuration.icon32x256)
        } elseif (-not [string]::IsNullOrEmpty($($Application.configuration.icon32x16))) {
            $BinaryIconData = $($Application.configuration.icon32x16)
        } elseif (-not [string]::IsNullOrEmpty($($Application.configuration.icon16x16))) {
            $BinaryIconData = $($Application.configuration.icon16x16)
        }
        if (-not [string]::IsNullOrEmpty($BinaryIconData)) {
            $IconStream = Convert-BinaryIconToBase64 -IconData $BinaryIconData -Size 32
        } else {
            $IconStream = "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"
        }

        $StartMenuPath = "$($Application.configuration.menu)"
        if ($StartMenuPath -eq "") {
            $StartMenuPath = "Start Menu\Programs"
        } elseif ($StartMenuPath -like "Start\*") {
            $StartMenuPath = "Start Menu\Programs$($StartMenuPath.Substring(5))"
        }

        $Assignments = @()
        $AccessControl = $Application.accesscontrol
        $AccessItems = @($AccessControl.grouplist.group)
        if ($AccessControl.accesstype -eq "all") {
            $Assignments += [PSCustomObject]@{
                Sid  = "S-1-1-0"
                Name = "Everyone"
                Type = "group"
            }
        } elseif (($AccessControl.access_mode -ieq 'or' -and $AccessItems.Count -ge 1) -or
            ($AccessControl.access_mode -ieq 'and' -and $AccessItems.Count -eq 1)) {
            foreach ($AccessItem in $AccessItems) {
                if ($AccessControl.notgrouplist.group -contains $AccessItem) {
                    Write-Warning "Exclusion rules (notgrouplist) are currently not supported for application '$($Application.configuration.title)' (App is $($State))."
                    $ItemsWithErrors += $Application
                } elseif ($AccessItem.type -ne "group" -and $AccessItem.type -ne "user") {
                    Write-Warning "Unsupported object type '$($AccessItem.type)' for application '$($Application.configuration.title)'. Only 'group' or 'user' are supported."
                    $ItemsWithErrors += $Application
                } else {
                    $ObjectName = $AccessItem.'#text'
                    if ($ObjectName -like "*\*") {
                        $ObjectName = $ObjectName.Split("\")[1]
                    }
                    $Assignments += [PSCustomObject]@{
                        Sid  = $AccessItem.sid
                        Name = $ObjectName
                        Type = $AccessItem.type
                    }
                }
            }
            if ($Assignments.Count -eq 0) {
                $Assignments += [PSCustomObject]@{
                    Sid  = "S-1-1-0"
                    Name = "Everyone"
                    Type = "group"
                }
            }
        } else {
            Write-Warning "Unsupported access control mode '$($AccessControl.access_mode)' with $($AccessItems.Count) item(s) for application '$($Application.configuration.title)'."
            $ItemsWithErrors += $Application
        }
        $IsDesktop = $false
        if ($Application.configuration.desktop -ine "none" -and -not [string]::IsNullOrEmpty($($Application.configuration.desktop))) {
            $IsDesktop = $true
        }
        $isQuickLaunch = $false
        if ($Application.configuration.quicklaunch -ine "none" -and -not [string]::IsNullOrEmpty($($Application.configuration.quicklaunch))) {
            $isQuickLaunch = $true
        }

        $isStartMenu = $false
        if ($Application.configuration.createmenushortcut -ieq "yes") {
            $isStartMenu = $true
        }

        $isAutoStart = $false
        if ($Application.settings.autoall -ine "no" -and -not [string]::IsNullOrEmpty($($Application.settings.autoall))) {
            $isAutoStart = $true
        }
        $WindowStyle = $Application.settings.startstyle
        if ([string]::IsNullOrEmpty($WindowStyle) -or $WindowStyle -like "nor*") {
            $WindowStyle = "Normal"
        } elseif ($WindowStyle -like "max*") {
            $WindowStyle = "Maximized"
        } elseif ($WindowStyle -like "min*") {
            $WindowStyle = "Minimized"
        } else {
            $WindowStyle = "Normal"
        }

        $Output = [PSCustomObject]@{
            Name                 = $DisplayName
            Enabled              = $Enabled
            WEMAssignments       = @($Assignments)
            WEMAssignmentParams  = [PSCustomObject]@{
                isAutoStart   = $IsAutoStart
                isDesktop     = $IsDesktop
                isQuickLaunch = $IsQuickLaunch
                isStartMenu   = $IsStartMenu
            }
            WEMApplicationParams = [PSCustomObject]@{
                startMenuPath = $StartMenuPath
                appType       = "InstallerApplication"
                state         = $State
                iconStream    = $IconStream
                parameter     = $Parameters
                description   = $Description
                name          = $DisplayName
                commandLine   = $CommandLine
                workingDir    = $WorkingDir
                url           = $URL
                displayName   = $DisplayName
                WindowStyle   = $WindowStyle
                ActionType    = "CreateAppShortcut"
            }
        }
        if ($AsJson) {
            $JsonOutput += $Output
        } else {
            Write-Output $Output
        }
    }
    Write-Progress -Activity "Processing Applications" -Completed
    Write-Verbose "Processing completed. Processed $TotalNumberOfItems applications."
    if ($AsJson) {
        Write-Verbose "Converting output to JSON format."
        return ($JsonOutput | ConvertTo-Json -Depth 5)
    }
}
