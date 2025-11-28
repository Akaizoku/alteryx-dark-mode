# Alteryx Dark Mode Easy Switch

This repository contains a simple script to toggle Alteryx Designer between light and dark mode by updating the UserSettings.xml file to synchronise both the actual interface theme and the canvas settings in a single operation.

## Usage

### Setting the theme

Download the repository and run the following PowerShell command to switch Alteryx Designer to dark mode:

```powershell
Set-AlteryxTheme.ps1 -Mode Dark
```

### Modifying the templates

To modify either the dark or light mode templates, edit the respective XML files located in the `Templates` folder. You can easily customise the interface from within Alteryx Designer and then copy the relevant XML nodes from `%AppData%\Alteryx\Engine\<Version>\UserSettings.xml` into the template files.
