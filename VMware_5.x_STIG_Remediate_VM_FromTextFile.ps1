<#
.SYNOPSIS
	vSphere 5.x STIG Virtual Machine Remediation Script
	Updated for STIG: vSphere 5 Virtual Machine - Version 1, Release 5
	Created by: Ryan Lakey, rlakey@vmware.com 
	Provided as is and is not supported by VMware
.DESCRIPTION
	This script will remediate all Virtual Machines in the target vCenter for the vSphere 5.x STIG items defined in the VM advanced settings section below
	
	All other Virtual Machine STIG items are recommended to remediate on a case by case basis such as removing unneeded devices
	like floppy drives, serial ports, parallel ports, non-persistent drives, etc

	!!Please read and know what this script it doing before running!!

	Requirements to run script
	-PowerCLI 6.0+ and Powershell 3+
	-Powershell allowed to run unsigned/remote scripts
	-Update $TransFolder variable below to fit your environment
	-Comment/Uncomment specific settings appropriate for your environment in the advanced settings section
.PARAMETER vcenter
   vCenter server to run script against and remediate ALL Virtual Machines in that vCenter
.PARAMETER file
   Path to text file and name with list of servers to remediate.  Name must be name of VM in vCenter with 1 per line and no extra spaces.
.PARAMETER cred
   This will prompt user for credentials that will be used to connect to vCenter specified.
.EXAMPLE
   ./VMware_5.x_STIG_Remediate_VM_FromTextFile.ps1 -vcenter vcenter.test.lab -file C:\PowerCLI\ServerstoRemediate.txt
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$vcenter,
	[Parameter(Mandatory=$True,Position=2)]
    [string]$file,
	[Parameter(Mandatory=$True,Position=2)]
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

## File Name with VMs
$vmlist = Get-Content $file

## Virtual Machine Advanced Settings to remediate
	$VMAdvSettings = @{#"isolation.tools.autoInstall.disable" = $true;  ## ESXI5-VM-000002  Uncomment if tools autoinstall not used
	"isolation.tools.copy.disable" = $true; ## ESXI5-VM-000003
	"isolation.tools.dnd.disable" = $true; ## ESXI5-VM-000004
	"isolation.tools.setGUIOptions.enable" = $false; ## ESXI5-VM-000005
	"isolation.tools.paste.disable" = $true; ## ESXI5-VM-000006
	"isolation.tools.diskShrink.disable" = $true; ## ESXI5-VM-000007
	"isolation.tools.diskWiper.disable" = $true;  ## ESXI5-VM-000008
	"isolation.tools.hgfsServerSet.disable" = $true;  ## ESXI5-VM-000009
	"vmci0.unrestricted" = $false;  ## ESXI5-VM-000011
	"logging" = $false;  ## ESXI5-VM-000012
#	"isolation.monitor.control.disable" = $true;  ## ESXI5-VM-000013   !!Not Recommended!!
	"isolation.tools.ghi.autologon.disable" = $true;  ## ESXI5-VM-000014
	"isolation.bios.bbs.disable" = $true;   ## ESXI5-VM-000015
	"isolation.tools.getCreds.disable" = $true;  ## ESXI5-VM-000016
	"isolation.tools.ghi.launchmenu.change" = $true;  ## ESXI5-VM-000017
	"isolation.tools.memSchedFakeSampleStats.disable" = $true;  ## ESXI5-VM-000018
	"isolation.tools.ghi.protocolhandler.info.disable" = $true;  ## ESXI5-VM-000019
	"isolation.ghi.host.shellAction.disable" = $true;  ## ESXI5-VM-000020
	"isolation.tools.dispTopoRequest.disable" = $true;  ## ESXI5-VM-000021
	"isolation.tools.trashFolderState.disable" = $true;  ## ESXI5-VM-000022
	"isolation.tools.ghi.trayicon.disable" = $true;  ## ESXI5-VM-000023
	"isolation.tools.unity.disable" = $true;  ## ESXI5-VM-000024
	"isolation.tools.unityInterlockOperation.disable" = $true;  ## ESXI5-VM-000025
	"isolation.tools.unity.push.update.disable" = $true;  ## ESXI5-VM-000026
	"isolation.tools.unity.taskbar.disable" = $true;  ## ESXI5-VM-000027
	"isolation.tools.unityActive.disable" = $true;  ## ESXI5-VM-000028
	"isolation.tools.unity.windowContents.disable" = $true;  ## ESXI5-VM-000029
	"isolation.tools.vmxDnDVersionGet.disable" = $true;  ## ESXI5-VM-000030
	"isolation.tools.guestDnDVersionSet.disable" = $true;  ## ESXI5-VM-000031
	"isolation.tools.vixMessage.disable" = $true;  ## ESXI5-VM-000033
	"RemoteDisplay.maxConnections" = "1";  ## ESXI5-VM-000039
	"log.keepOld" = "10";  ## ESXI5-VM-000041
	"log.rotateSize" = "100000";  ## ESXI5-VM-000042
	"tools.setinfo.sizeLimit" = "1048576";  ## ESXI5-VM-000043
	"isolation.device.connectable.disable" = $true;  ## ESXI5-VM-000045
	"isolation.device.edit.disable" = $true;  ## ESXI5-VM-000046
	"tools.guestlib.enableHostInfo" = $false;  ## ESXI5-VM-000047
	"vmsafe.enable" = $false;  ## ESXI5-VM-000054  If vmsafe used this can be enabled.
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

ForEach($server in $vmlist){
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
}

## Disconnect from vCenter
Write-ToConsole "...Disconnecting from vCenter Server $vcenter"
Disconnect-VIServer -Server $vcenter -Force -Confirm:$false

## Stop Transcript
Stop-Transcript