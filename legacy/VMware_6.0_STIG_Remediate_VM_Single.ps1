<#
.SYNOPSIS
	vSphere 6.0 STIG Virtual Machine Remediation Script for single VM
	Created by: Ryan Lakey, rlakey@vmware.com 
	Provided as is and is not supported by VMware
.DESCRIPTION
	This script will remediate a single Virtual Machines in the target vCenter for the following vSphere 6.0 STIG items:
	VM-06-000001-6,8-27,33-39
	All other Virtual Machine STIG items are recommended to remediate on a case by case basis.

	!!Please read and know what this script it doing before running!!

	Requirements to run script
	-PowerCLI 6.0+ and Powershell 3+
	-Powershell allowed to run unsigned/remote scripts
	-Update $TransFolder variable below to fit your environment
	-Comment/Uncomment specific settings appropriate for your environment in the advanced settings section
.PARAMETER vcenter
   vCenter server to run script against and remediate ALL Virtual Machines in that vCenter
.PARAMETER server
   Name of virtual machine as displayed in vCenter to remediate.
.PARAMETER cred
   This will prompt user for credentials that will be used to connect to vCenter specified.
.EXAMPLE
   ./VMware_6.0_STIG_Remediate_VM_Single.ps1 -vcenter vcenter.test.lab -server mytestserver
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$vcenter,
	[Parameter(Mandatory=$True,Position=2)]
    [string]$server,
	[Parameter(Mandatory=$True,Position=3)]
	[Management.Automation.PSCredential]$cred
)

## Script Configuration Variables
## Capture Date variable
$Date = Get-Date
## Path to store transcript
$TransFolder = "C:\PowerCLI\Output"
## Start Transcript
$TranscriptName = $TransFolder + "\VMware_VM_STIG_Remediation_Transcript" + "_" + $Date.Month + "-" + $Date.Day + "-" + $Date.Year + "_" + $Date.Hour + "-" + $Date.Minute + "-" + $Date.Second + ".txt"
Start-Transcript -Path $TranscriptName

## Virtual Machine Advanced Settings to remediate
	$VMAdvSettings = @{"isolation.tools.copy.disable" = $true; ## VM-06-000001
	"isolation.tools.dnd.disable" = $true; ## VM-06-000002
	"isolation.tools.setGUIOptions.enable" = $false; ## VM-06-000003
	"isolation.tools.paste.disable" = $true; ## VM-06-000004
	"isolation.tools.diskShrink.disable" = $true; ## VM-06-000005
	"isolation.tools.diskWiper.disable" = $true;  ## VM-06-000006
	"isolation.tools.hgfsServerSet.disable" = $true;  ## VM-06-000008
	"isolation.tools.ghi.autologon.disable" = $true;  ## VM-06-000009
	"isolation.bios.bbs.disable" = $true;   ## VM-06-000010
	"isolation.tools.getCreds.disable" = $true;  ## VM-06-000011
	"isolation.tools.ghi.launchmenu.change" = $true;  ## VM-06-000012
	"isolation.tools.memSchedFakeSampleStats.disable" = $true;  ## VM-06-000013
	"isolation.tools.ghi.protocolhandler.info.disable" = $true;  ## VM-06-000014
	"isolation.ghi.host.shellAction.disable" = $true;  ## VM-06-000015
	"isolation.tools.dispTopoRequest.disable" = $true;  ## VM-06-000016
	"isolation.tools.trashFolderState.disable" = $true;  ## VM-06-000017
	"isolation.tools.ghi.trayicon.disable" = $true;  ## VM-06-000018
	"isolation.tools.unity.disable" = $true;  ## VM-06-000019
	"isolation.tools.unityInterlockOperation.disable" = $true;  ## VM-06-000020
	"isolation.tools.unity.push.update.disable" = $true;  ## VM-06-000021
	"isolation.tools.unity.taskbar.disable" = $true;  ## VM-06-000022
	"isolation.tools.unityActive.disable" = $true;  ## VM-06-000023
	"isolation.tools.unity.windowContents.disable" = $true;  ## VM-06-000024
	"isolation.tools.vmxDnDVersionGet.disable" = $true;  ## VM-06-000025
	"isolation.tools.guestDnDVersionSet.disable" = $true;  ## VM-06-000026
	"isolation.tools.vixMessage.disable" = $true;  ## VM-06-000027
	"RemoteDisplay.maxConnections" = "1";  ## VM-06-000033
	"RemoteDisplay.vnc.enabled" = $false;  ## VM-06-000034
#	"isolation.tools.autoInstall.disable" = $true;  ## VM-06-000035  Uncomment if tools auto install is not used
	"tools.setinfo.sizeLimit" = "1048576";  ## VM-06-000036
	"isolation.device.connectable.disable" = $true;  ## VM-06-000037
	"isolation.device.edit.disable" = $true;  ## VM-06-000038
	"tools.guestlib.enableHostInfo" = $false;  ## VM-06-000039
	}

## Function to write messages to console with time stamp
Function Write-ToConsole ($Details){
	$LogDate = Get-Date -Format T
	Write-Host "$($LogDate) $Details"
}

## Check for PowerCLI modules loaded and if not load them and if we can't exit
Try{
	if (!(Get-Module -Name VMware.VimAutomation.Core -ErrorAction Stop) ) {
	Write-ToConsole "...PowerCLI modules not detected...loading PowerCLI"
	."C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"}}
Catch{
	Write-ToConsole "...Issue loading PowerCLI modules or PowerCLI modules not present...please correct and rerun...exiting script"
	Exit
}

## Connect to vCenter Server
Try{
	Write-ToConsole "...Connecting to vCenter Server $vcenter"
	Connect-VIServer -Server $vcenter -ErrorAction Stop -Credential $cred | Out-Null}
Catch{
	Write-ToConsole "...Could not connect to $vcenter with supplied credentials...exiting script"
	Exit
	}

## Collect Virtual Machines in variable for processing
Write-ToConsole "...Getting virtual machine list from $vcenter"
$vm = Get-VM $server | Sort Name

## Remediate Virtual Machines
Write-ToConsole "...Remediating $vm on $vcenter"
	ForEach($setting in ($VMAdvSettings.GetEnumerator() | Sort Name)){
	## Pulling values for each setting specified in $VMAdvSettings
	$name = $setting.name
	$value = $setting.value
		## Checking to see if current setting exists
    	If($asetting = $vm | Get-AdvancedSetting -Name $name){
			If($asetting.value -eq $value){
			Write-ToConsole "...Setting $name is already configured correctly to $value on $vm"
			}else{
				Write-ToConsole "...Setting $name was incorrectly set to $($asetting.value) on $vm ...setting to $value"
				$asetting | Set-AdvancedSetting -Value $value -Confirm:$false
			}
		}else{
			Write-ToConsole "...Setting $name does not exist on $vm ...creating setting..."
			$vm | New-AdvancedSetting -Name $name -Value $value -Confirm:$false
		}
	}

## Disconnect from vCenter
Write-ToConsole "...Disconnecting from vCenter Server $vcenter"
Disconnect-VIServer -Server $vcenter -Force -Confirm:$false

## Stop Transcript
Stop-Transcript
