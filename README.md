# Alteryx Dark Mode Easy Switch

This repository contains a simple script to toggle [Alteryx Designer Desktop](https://www.alteryx.com/products/alteryx-designer) between light and dark mode by updating the [UserSettings.xml](https://help.alteryx.com/current/en/designer/get-started/user-settings.html) configuration file to synchronise both the actual interface theme and the canvas settings in a single and repeatable operation.

> **Remarks:**
>
> 1. Alteryx Designer must be restarted after running the script to apply the changes.
> 2. If the setting "[Save Layout & Settings on Exit](https://help.alteryx.com/current/en/designer/get-started/designer-user-interface/main-menus.html#id523866)" is enabled, Designer must be closed prior to changing the theme to prevent it from overwriting the changes on exit.
>

## Process

The script performs the following operations in sequence:

1. **Check if Alteryx Designer is running**
   1. Detects whether `AlteryxGui.exe` is active.
   2. If Designer is running, the user is prompted to close it.
      - If the user declines, the script stops.
      - If the user agrees, Designer is closed and its executable path is recorded for possible restart.
2. **Locate the target `UserSettings.xml` file**
   - Scans `%APPDATA%\Alteryx\Engine` for versioned subfolders (e.g., `2025.1`, `2025.2`, etc.).
   - Sorts folders in ascending version order and selects the most recent one.
   - Uses the `UserSettings.xml` file inside that folder as the update target.
3. **Load the selected theme template**
   1. Reads either `light.xml` or `dark.xml` from the script template directory.
   2. Wraps the XML fragment in a synthetic root element to ensure proper parsing.
4. **Apply theme updates to `UserSettings.xml`**
   1. Updates the `<CustomizationTheme>` value from the template.
   2. Replaces all attributes in theme-related nodes except `MergeId`, which is always preserved.
      1. `DocumentBGColor`: Canvas background colour.
      2. `DocumentLineColor`: Data connections line colour.
      3. `DocumentLineTextColor`: Data connections name text colour.
      4. `DocumentGridColor`: Canvas grid colour.
      5. `DefaultContainerColor`: Default tool container colour.
      6. `AnnBGColor`: Tool annotation background colour.
      7. `AnnTextColor`: Tool annotation text colour.
   3. Ensures template values overwrite all previous color and style settings reliably.
5. **Optional restart of Alteryx Designer**
   1. If the script closed Designer earlier, the user is prompted to restart it.
   2. If the user agrees, Designer is launched again.

## Usage

### Setting the theme

Download the repository and run the following PowerShell command to switch Alteryx Designer to dark mode:

```powershell
Set-AlteryxTheme.ps1 -Mode Dark
```

### Modifying the templates

To modify either the dark or light mode templates, edit the respective XML files located in the `Templates` folder. You can easily customise the interface from within Alteryx Designer and then copy the relevant XML nodes from `%AppData%\Alteryx\Engine\<Version>\UserSettings.xml` into the template files.

## Dependencies

### Alteryx

Alteryx Designer Desktop version [2023.1](https://help.alteryx.com/release-notes/en/release-notes/designer-release-notes/designer-2023-1-release-notes.html#id187018) or later is required to support dark mode. Attempting to use the script with earlier versions will only affect the canvas settings.

### PowerShell

The script requires [PowerShell](https://learn.microsoft.com/en-us/powershell/scripting/what-is-windows-powershell?view=powershell-5.1) 5.1 or later. Therefore, PowerShell must be installed on the machine, but this requirement should be satisfied by default on modern Windows operating systems.

> [Windows PowerShell 5.1 is installed by default on Windows Server version 2016 and higher and Windows client version 10 and higher.](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_windows_powershell_5.1)
