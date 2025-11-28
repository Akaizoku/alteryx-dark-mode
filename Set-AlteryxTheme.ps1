<#
    .SYNOPSIS
    Switch Alteryx Designer theme between light and dark modes.

    .DESCRIPTION
    Switch Alteryx Designer theme between light and dark modes by updating UserSettings.xml configuration file.

    The script:
    - Detects if AlteryxGui.exe (Alteryx Designer) is running
        - If running, asks the user whether to close it
        - If user declines, script aborts
        - If user confirms, Designer is closed and executable path captured
    - Idendify UserSettings.xml path
        - Finds all version subfolders under %APPDATA%\Alteryx\Engine
        - Sorts them in ascending order by name and selects the last one
        - Uses the UserSettings.xml in that folder as the target
    - Loads template XML fragment from light.xml or dark.xml
        - Wraps the fragment with a synthetic root element
    - Update UserSettings.xml
        - <CustomizationTheme> inner text
        - All attributes of specific nodes (except MergeId) from template to target
        - MergeId attributes in the target XML are preserved.
    - If Designer was closed by the script, proposes to restart it at the end

    .PARAMETER Mode
    Theme mode to apply. Valid values are 'Light' or 'Dark'.

    .EXAMPLE
    .\Set-AlteryxTheme.ps1 -Mode Dark

    .EXAMPLE
    .\Set-AlteryxTheme.ps1 -Mode Light
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('Dark', 'Light')]
    [string] $Mode
)

#region Helper Functions

function Set-XmlElementInnerTextFromTemplate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument] $TargetXml,

        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument] $TemplateXml,

        [Parameter(Mandatory = $true)]
        [string] $XPath
    )

    try {
        # Select nodes in both documents
        $TargetNode     = $TargetXml.SelectSingleNode($XPath)
        $TemplateNode   = $TemplateXml.SelectSingleNode($XPath)

        if ($null -eq $TargetNode) {
            throw "Target node not found for XPath '${XPath}'."
        }

        if ($null -eq $TemplateNode) {
            throw "Template node not found for XPath '${XPath}'."
        }

        # Copy inner text value from template to target
        $TargetNode.InnerText = $TemplateNode.InnerText
    }
    catch {
        throw "Failed to copy inner text for XPath '${XPath}': $(${PSItem}.Exception.Message)"
    }
}

function Set-XmlElementAttributesFromTemplate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument] $TargetXml,

        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument] $TemplateXml,

        [Parameter(Mandatory = $true)]
        [string] $XPath
    )

    try {
        # Select nodes in both documents using the same XPath
        $TargetNode = $TargetXml.SelectSingleNode($XPath)
        $TemplateNode = $TemplateXml.SelectSingleNode($XPath)

        if ($null -eq $TargetNode) {
            throw "Target node not found for XPath '${XPath}'."
        }

        if ($null -eq $TemplateNode) {
            throw "Template node not found for XPath '${XPath}'."
        }

        # --------------------------------------------------------------------
        # Remove all attributes (except MergeId)
        # --------------------------------------------------------------------
        if ($null -ne $TargetNode.Attributes -and $TargetNode.Attributes.Count -gt 0) {
            $AttributeNames = @()

            foreach ($Attribute in $TargetNode.Attributes) {
                $AttributeNames += $Attribute.Name
            }

            foreach ($AttributeName in $AttributeNames) {
                if ($AttributeName -ne 'MergeId') {
                    $null = $TargetNode.Attributes.RemoveNamedItem($AttributeName)
                }
            }
        }

        # --------------------------------------------------------------------
        # Add template attributes (except MergeId)
        # --------------------------------------------------------------------
        foreach ($TemplateAttribute in $TemplateNode.Attributes) {
            if ($TemplateAttribute.Name -eq 'MergeId') {
                continue
            }

            $null = $TargetNode.SetAttribute(
                $TemplateAttribute.Name,
                $TemplateAttribute.Value
            )
        }
    }
    catch {
        throw "Failed to copy attributes for XPath '${XPath}': $(${PSItem}.Exception.Message)"
    }
}

function Get-LatestUserSettingsPath {
    [CmdletBinding()]
    param ()

    # Build base Engine path under %APPDATA%\Alteryx\Engine
    $AppDataPath    = [System.Environment]::GetFolderPath('ApplicationData')
    $EngineRootPath = Join-Path -Path $AppDataPath -ChildPath 'Alteryx\Engine'

    if (-not (Test-Path -Path $EngineRootPath -PathType "Container")) {
        throw "Engine root path '${EngineRootPath}' does not exist."
    }

    # Get all version-like subdirectories (e.g., 2025.1, 2025.2)
    $VersionDirectories = Get-ChildItem -Path $EngineRootPath -Directory

    if ($null -eq $VersionDirectories -or $VersionDirectories.Count -eq 0) {
        throw "No Engine version subfolder was found under '${EngineRootPath}'."
    }

    # Sort by name ascending and select the last one (highest)
    $LatestVersionDirectory = $VersionDirectories |
        Sort-Object -Property "Name" |
        Select-Object -Last 1

    if ($null -eq $LatestVersionDirectory) {
        throw "Failed to determine the latest engine version subfolder under '${EngineRootPath}'."
    }

    # Build the path to UserSettings.xml in that version folder
    $UserSettingsPath = Join-Path -Path $LatestVersionDirectory.FullName -ChildPath 'UserSettings.xml'

    if (-not (Test-Path -Path $UserSettingsPath -PathType Leaf)) {
        throw "UserSettings.xml was not found at '${UserSettingsPath}'."
    }

    return $UserSettingsPath
}

function Get-ScriptRoot {
    [CmdletBinding()]
    param ()

    # When running as a script, $PSScriptRoot is populated; otherwise, use current location.
    if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        return (Get-Location).Path
    }
    else {
        return $PSScriptRoot
    }
}

function Get-TemplateXmlFromFragmentFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $TemplatePath
    )

    # Create XmlDocument for the template
    $TemplateXmlDocument = New-Object -TypeName "System.Xml.XmlDocument"

    try {
        # Read the XML fragment from file as a single string
        $TemplateContent = Get-Content -Path $TemplatePath -Raw

        if ([string]::IsNullOrWhiteSpace($TemplateContent)) {
            throw "Template file '${TemplatePath}' is empty."
        }

        # Wrap the fragment in a proper XML document with a synthetic root element
        $WrappedContent = @"
<?xml version="1.0" encoding="utf-8"?>
<Root>
${TemplateContent}
</Root>
"@

        # Load the wrapped content as XML
        $TemplateXmlDocument.LoadXml($WrappedContent)
    }
    catch {
        throw "Failed to load template XML from '${TemplatePath}': $(${PSItem}.Exception.Message)"
    }

    return $TemplateXmlDocument
}

#endregion Helper Functions

#region Variables

# Track whether Alteryx Designer was running and closed by this script
[bool]      $DesignerWasRunning     = $false
[string]    $DesignerExecutablePath = $null

#endregion Variables

#region Pre-requisites checks

try {
    # Try to get the AlteryxGui process without throwing if it does not exist
    $AlteryxProcess = Get-Process -Name 'AlteryxGui' -ErrorAction "SilentlyContinue"

    if ($null -ne $AlteryxProcess) {
        # Designer is running; ask user whether to close it
        Write-Warning   -Message "Alteryx Designer (AlteryxGui.exe) is currently running." -WarningAction "Continue"
        Write-Host      -Object "Designer must be closed to change the theme" -ForegroundColor "Cyan"
        Write-Warning   -Message "Make sure to save your work before closing Designer" -WarningAction "Continue"
        $UserChoice = Read-Host -Prompt "Do you want to close Alteryx Designer? (Y/N)"

        if ($UserChoice -notin @('Y', 'y')) {
            Write-Warning -Message "Theme cannot be updated while Alteryx Designer is running." -WarningAction "Continue"
            throw "Aborting theme change."
        }

        # Capture executable path if available (for restart)
        try {
            $DesignerExecutablePath = $AlteryxProcess.Path
        }
        catch {
            # Path may not be available; will fall back to 'AlteryxGui.exe'
            $DesignerExecutablePath = $null
        }

        try {
            # Stop the process
            Stop-Process -Id $AlteryxProcess.Id -Force -ErrorAction "Stop"
            $DesignerWasRunning = $true
            Write-Host -Object "Alteryx Designer has been closed." -ForegroundColor "Green"
        }
        catch {
            throw "Failed to close Alteryx Designer: $(${PSItem}.Exception.Message)"
        }
    }
}
catch {
    throw "Unable to perform Alteryx process check/close: $(${PSItem}.Exception.Message)"
}

#endregion Pre-requisites checks

try {
    #region Check UserSettings.xml

    $TargetPath = Get-LatestUserSettingsPath

    #endregion Check UserSettings.xml

    #region Check template

    $ScriptRootPath = Get-ScriptRoot

    switch ($Mode) {
        'Light' {
            $TemplateFileName = 'light.xml'
        }
        'Dark' {
            $TemplateFileName = 'dark.xml'
        }
        default {
            throw "Unsupported mode '${Mode}'. Valid values are 'Light' or 'Dark'."
        }
    }

    $TemplatePath = Join-Path -Path $ScriptRootPath -ChildPath "Templates\$TemplateFileName"

    if (-not (Test-Path -Path $TemplatePath -PathType Leaf)) {
        throw "The template file '${TemplatePath}' does not exist. Ensure ${TemplateFileName} is in the same folder as this script."
    }

    #endregion Check template

    #region Load XML Documents

    # Target full XML
    $TargetXml = New-Object System.Xml.XmlDocument
    try {
        $TargetXml.Load($TargetPath)
    }
    catch {
        throw "Failed to load target XML from '${TargetPath}': $(${PSItem}.Exception.Message)"
    }

    # Template XML from fragment
    $TemplateXml = Get-TemplateXmlFromFragmentFile -TemplatePath $TemplatePath

    #endregion Load XML Documents

    #region Update Nodes From Template

    # Copy inner text and attributes from template fragment into real UserSettings.xml
    Set-XmlElementInnerTextFromTemplate  -TargetXml $TargetXml -TemplateXml $TemplateXml -XPath '//CustomizationTheme'
    Set-XmlElementAttributesFromTemplate -TargetXml $TargetXml -TemplateXml $TemplateXml -XPath '//DocumentBGColor'
    Set-XmlElementAttributesFromTemplate -TargetXml $TargetXml -TemplateXml $TemplateXml -XPath '//DocumentLineColor'
    Set-XmlElementAttributesFromTemplate -TargetXml $TargetXml -TemplateXml $TemplateXml -XPath '//DocumentLineTextColor'
    Set-XmlElementAttributesFromTemplate -TargetXml $TargetXml -TemplateXml $TemplateXml -XPath '//DocumentGridColor'
    Set-XmlElementAttributesFromTemplate -TargetXml $TargetXml -TemplateXml $TemplateXml -XPath '//DefaultContainerColor'
    Set-XmlElementAttributesFromTemplate -TargetXml $TargetXml -TemplateXml $TemplateXml -XPath '//AnnBGColor'
    Set-XmlElementAttributesFromTemplate -TargetXml $TargetXml -TemplateXml $TemplateXml -XPath '//AnnTextColor'

    #endregion Update Nodes From Template

    #region Save Updated UserSettings.xml

    try {
        $TargetXml.Save($TargetPath)
    }
    catch {
        throw "Failed to save updated XML to '${TargetPath}': $(${PSItem}.Exception.Message)"
    }

    #endregion Save Updated UserSettings.xml

    Write-Debug -Message "UserSettings.xml at '${TargetPath}' was successfully updated using template '${TemplatePath}' for mode '${Mode}'."
    Write-Host  -Object "Alteryx Designer theme has been set to $(${Mode}.ToLower()) mode." -ForegroundColor "Green"

    #region Restart Alteryx Designer

    if ($DesignerWasRunning -eq $true) {
        $RestartChoice = Read-Host -Prompt "Do you want to restart Alteryx Designer now? (Y/N)"
        if ($RestartChoice -in @('Y', 'y')) {
            try {
                if ([string]::IsNullOrWhiteSpace($DesignerExecutablePath)) {
                    # Fall back to executable name only; assumes it is on PATH or registered
                    Start-Process -FilePath 'AlteryxGui.exe' -ErrorAction "Stop"
                }
                else {
                    Start-Process -FilePath $DesignerExecutablePath -ErrorAction "Stop"
                }
                Write-Host -Object "Alteryx Designer has been restarted." -ForegroundColor "Green"
            }
            catch {
                Write-Error -Message "Failed to restart Alteryx Designer: $(${PSItem}.Exception.Message)"
            }
        }
    }

    #endregion Restart Alteryx Designer
}
catch {
    Write-Error -Message "An error occurred: $(${PSItem}.Exception.Message)"
}