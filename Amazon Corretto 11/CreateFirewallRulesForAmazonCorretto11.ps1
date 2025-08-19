<#
.DESCRIPTION
    Post install script used to create and manage Windows Firewall rules for Amazon Corretto 11 installations. Written for use with Patch My PC.
#>

#Requires -Version 5.1
#Requires -RunAsAdministrator

# Get Amazon Corretto 11 paths from Program Files for 64-bit installations
$ProgramFilesAmazonCorretto = Get-ChildItem -Path "$env:ProgramFiles\Amazon Corretto","${env:ProgramFiles(x86)}\Amazon Corretto" -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -like "jdk11.*"}
# Check that at least one Amazon Corretto 11 installation exists
If (-not $ProgramFilesAmazonCorretto) {
    Write-Verbose -Message "No Amazon Corretto 11 installations found in Program Files so this script will exit."
    Exit
}
# Resolve any paths to the Java executable for Amazon Corretto 11
$ProgramFilesAmazonCorrettoResolvedPaths = $ProgramFilesAmazonCorretto | Foreach-Object {Get-ChildItem -Path $_.FullName -Recurse -Filter "java.exe" -ErrorAction SilentlyContinue | Where-Object {$_.FullName -like "*bin\java.exe"}}
# Check that at least one resolved path exists
If (-not $ProgramFilesAmazonCorrettoResolvedPaths) {
    Write-Verbose -Message "No resolved paths for Amazon Corretto 11 installations found so this script will exit."
    Exit
}
# Clean up any existing firewall rules for Amazon Corretto if the paths no longer exist
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "OpenJDK Platform Binary*"} | Foreach-Object {
    $Filter = Get-NetFirewallApplicationFilter -AssociatedNetFirewallRule $_ -ErrorAction SilentlyContinue
    If ($Filter -and $Filter.Program -and -not (Test-Path -Path $Filter.Program)) {
        Remove-NetFirewallRule -Name $_.Name -ErrorAction SilentlyContinue
    }
}
# Create new firewall rules for each current Amazon Corretto 11 installation
$ProgramFilesAmazonCorrettoResolvedPaths | Foreach-Object {
    # Dynamically set the rule name to use the version of java.exe
    $RuleName = "OpenJDK Platform Binary for Amazon Corretto $($_.VersionInfo.FileVersion)"
    # Check if the rule already exists
    If (-not (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue)) {
        # Create the firewall rule for the Amazon Corretto 11
        Try {
            New-NetFirewallRule -DisplayName $RuleName -Direction Inbound -Protocol TCP -Action Allow -Program $_.FullName -Profile Domain,Private,Public -ErrorAction Stop
        } Catch {
            Write-Verbose -Message "An error occurred while creating the firewall rule for $($_.FullName): $_"
            Exit
        }
    }
}