<#
.SYNOPSIS
	vSphere 6.0 STIG ESXi Host Remediation Script
	Created by: Ryan Lakey, rlakey@vmware.com 
	Provided as is and is not supported by VMware
.DESCRIPTION
	This script will remediate specified ESXi Hosts from a text file in the target vCenter for the following vSphere 6.0 STIG items:
	ESXI-06-000001-45
	All other ESXi Host STIG items are recommended to remediate on a case by case basis and via the DoD STIG VIB fling on vmware.com
	Note - The vSphere Web Client service firewall policy must be configured manually as doing so via this script puts the host in a disconnected state as we have to turn off all allowed IPs first then add exceptions.  Turning off all allowed IPs first though does not allow us to perform the second operation.

	!!Please read and know what this script it doing before running!!

	Requirements to run script
	-PowerCLI 6.0+ and Powershell 3+
	-Powershell allowed to run unsigned/remote scripts
	-Update $TransFolder variable below to fit your environment
	-Update site specific settings in the "Site specific variables" section
	-Remediation can be turned on or off individually by changing the defined remediation variables to true or false
.PARAMETER vcenter
   vCenter server to run script against and remediate ALL ESXi Hosts in that vCenter
.PARAMETER cred
   This will prompt user for credentials that will be used to connect to vCenter specified.
.EXAMPLE
   ./VMware_6.0_STIG_Remediate_ESXi_FromTextFile.ps1 -vcenter vcenter.test.lab -file C:\PowerCLI\hostlist.txt
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$vcenter,
    [Parameter(Mandatory=$True,Position=2)]
    [string]$file,
	[Parameter(Mandatory=$True,Position=3)]
	[Management.Automation.PSCredential]$cred
)

## Script Configuration Variables
## Capture Date variable
$Date = Get-Date
## Path to store transcript
$TransFolder = "C:\PowerCLI\Output"
## Start Transcript
$TranscriptName = $TransFolder + "\VMware_ESXi_STIG_Remediation_Transcript" + "_" + $Date.Month + "-" + $Date.Day + "-" + $Date.Year + "_" + $Date.Hour + "-" + $Date.Minute + "-" + $Date.Second + ".txt"
Start-Transcript -Path $TranscriptName
## File Name with hosts
$hostlist = Get-Content $file

## !!Site Specific Variables!!
## Set Lockdown mode level.  lockdownNormal or lockdownStrict are valid
$lockdownlevel = "lockdownNormal"

## Turn specific remediations on or off
$remediateAdvSettings = $true
$remediateServices = $true
$remediateDump = $true
$remediateNtp = $true
$remediateVibLevel = $true
$remediateDefaultFw = $true
$remediateFirewallRules = $true
$remediateVswitchSec = $true
$remediateipv6 = $true
$remediateLockdown = $true

## ESXi Advanced host settings to remediate
$esxiSettings = @{"Security.AccountLockFailures" = "3"; ## ESXI-06-000005
"Security.AccountUnlockTime" = "900"; ## ESXI-06-000006
"Config.HostAgent.log.level" = "info" ## ESXI-06-000030
"Security.PasswordQualityControl" = "similar=deny retry=3 min=disabled,disabled,disabled,disabled,15"; ## ESXI-06-000031
"Config.HostAgent.plugins.solo.enableMob" = $false; ## ESXI-06-000034
"UserVars.ESXiShellInteractiveTimeOut" = "600"; ## ESXI-06-000041
"UserVars.ESXiShellTimeOut" = "600"; ## ESXI-06-000042
"UserVars.DcuiTimeOut" = "600"; ## ESXI-06-000043
"Mem.ShareForceSalting" = "2"; ## ESXI-06-000055
"Net.BlockGuestBPDU" = "1"; ## ESXI-06-000058
"Net.DVFilterBindIpAddress" = ""; ## ESXI-06-000062
"DCUI.Access" = "root"; ## ESXI-06-000002
#Edit to reflect site specific AD group for vCenter admins...recommended to change this even if not joined to AD
"Config.HostAgent.plugins.hostsvc.esxAdminsGroup" = "vCenter Admins"; ## ESXI-06-000039
#Edit syslog server setting to reflect correct value for your environment
"Syslog.global.logHost" = "tcp://yoursyslog.server.here:514"; ## ESXI-06-000004
#Edit this to match your environments settings...default is specified.
"Syslog.global.logDir" = "[] /scratch/log" ## ESXI-06-000045
}

## ESXi services to stop
$esxiServices = @{"SSH" = $false;
"ESXi Shell" = $false;
}

## ESXi Network Dump Collector Settings
$dumpvmk = "vmk0" ## VMkernel port to use for network dumps
$dumpip = "192.168.10.150" ## IP address of network dump collector
$dumpport = "6500" ## Port for network dump collector

## ESXi NTP Servers
$ntpservers = "192.168.23.10","192.168.23.11"

## ESXi VIB Acceptance Level.  Must be one of the following:  VMwareCertified, VMwareAccepted, or PartnerSupported
$esxiacceptlevel = "PartnerSupported"

## ESXi Service Firewall Rulesets Allowed IP Range.   In "" with commas separating ranges...for example "192.168.0.0/24","10.10.0.0/16"
$allowedips = "192.168.0.0/16","10.0.0.0/8"

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

## Collect ESXi Hosts in variable for processing
#Write-ToConsole "...Getting ESXi 6.0 hosts list from $vcenter"
#$vmhosts = Get-VMHost | Where {$_.version -match "^6.0*"} | Sort Name
#$vmhostsv = Get-View -ViewType "HostSystem" | Where {$_.config.product.version -match "^6.0*"} | Sort Name

ForEach($server in $hostlist){
## Collect ESXi Hosts in variable for processing
Write-ToConsole "...Getting ESXi host info for $server from $vcenter"
$vmhost = Get-VMHost -Name $server | Where {$_.version -match "^6.0*"}
$vmhostv = $vmhost | Get-View
$esxcli = $vmhost | Get-Esxcli

## Remediate ESXi Hosts

## Remediate ESXi Advanced Settings
If($remediateAdvSettings){
		ForEach($setting in ($esxiSettings.GetEnumerator() | Sort Name)){
		## Pulling values for each setting specified in $esxiSettings
		$name = $setting.name
		$value = $setting.value
			## Checking to see if current setting exists
    		If($asetting = $vmhost | Get-AdvancedSetting -Name $name){
				If($asetting.value -eq $value){
				Write-ToConsole "...Setting $name is already configured correctly to $value on $vmhost"
				}Else{
					Write-ToConsole "...Setting $name was incorrectly set to $($asetting.value) on $vmhost...setting to $value"
					$asetting | Set-AdvancedSetting -Value $value -Confirm:$false
				}
			}Else{
				Write-ToConsole "...Setting $name does not exist on $vmhost...creating setting..."
				$vmhost | New-AdvancedSetting -Name $name -Value $value -Confirm:$false
			}
		}
}

## Remediate ESXi services that should not be running
If($remediateServices){
	ForEach($service in ($esxiServices.GetEnumerator() | Sort Name)){
		$name = $service.name
		$value = $service.value
        	If($vmhostservice = $vmhost | Get-VMHostService | Where {$_.Label -eq $name -and $_.Running -eq $True}){
				Write-ToConsole "...Stopping service $name on $vmhost"
				$vmhostservice | Set-VMHostService -Policy Off -Confirm:$false
				$vmhostservice | Stop-VMHostService -Confirm:$false
			}Else{
				Write-ToConsole "...Service $name on $vmhost already stopped"
			}
	}
}

## Remediate ESXi hosts to configure a network dump location
If($remediatedump){
	$esxcli = $vmhost | Get-Esxcli
	$dumpnet = $esxcli.system.coredump.network.get()
	If($dumpnet.Enabled -eq $false){
		Write-ToConsole "...Configuring network core dumps using $dumpvmk to $dumpip using port $dumpport on $vmhost"
		$esxcli.system.coredump.network.set($null,$dumpvmk,$null,$dumpip,$dumpport)
		$esxcli.system.coredump.network.set($true)
	}Else{
		Write-ToConsole "...Network core dumps already configured on $vmhost"
	}
}

## Remediate NTP servers on ESXi
If($remediateNtp){    
	Write-ToConsole "...Setting NTP servers $ntpservers and starting services on $vmhost"
    $vmhost | Add-VMHostNTPServer $ntpservers
	$vmhost | Get-VMHostService | Where {$_.Label -eq "NTP Daemon"} | Set-VMHostService -Policy On
	$vmhost | Get-VMHostService | Where {$_.Label -eq "NTP Daemon"} | Start-VMHostService
}

## Remediate ESXi host VIB acceptance level
If($remediateVibLevel){	
	$esxcli = $vmhost | Get-Esxcli
	$acceptlevel = $esxcli.software.acceptance.get()
	If($acceptlevel -ne $esxiacceptlevel){
		Write-ToConsole "...Configuring ESXi VIB Acceptance level to $esxiacceptlevel on $vmhost"
		$esxcli.software.acceptance.set($esxiacceptlevel)
	}Else{
		Write-ToConsole "...ESXi VIB Acceptance level already configured to $esxiacceptlevel on $vmhost"
	}
}

## Remediate ESXi host default firewall policy
If($remediateDefaultFw){
	If(Get-VMHostFirewallDefaultPolicy -VMHost $vmhost | Where {$_.IncomingEnabled -eq $true -or $_.OutgoingEnabled -eq $true}){
		Write-ToConsole "...Configuring ESXi Default Firewall Policy to disabled on $vmhost"
		Get-VMHostFirewallDefaultPolicy -VMHost $vmhost | Set-VMHostFirewallDefaultPolicy -AllowIncoming $false -AllowOutgoing $false
	}else{
		Write-ToConsole "...ESXi Default Firewall Policy already configured correctly on $vmhost"
	}
}

## Remediate ESXi host service firewall rules
If($remediateFirewallRules){
	$esxcli = $vmhost | Get-Esxcli
	$fwservices = $vmhost | Get-VMHostFirewallException | Where {$_.Enabled -eq $True -and $_.extensiondata.allowedhosts.allip -eq "enabled" -and $_.Name -ne "vSphere Web Client"}
	ForEach($fwservice in $fwservices){
		$fwsvcname = $fwservice.extensiondata.key
		Write-ToConsole "...Configuring ESXi Firewall Policy on service $($fwservice.name) to $allowedips on $vmhost"
		## Disables All IPs allowed policy
		$esxcli.network.firewall.ruleset.set($false,$true,$fwsvcname)
		ForEach($allowedip in $allowedips){
		$esxcli.network.firewall.ruleset.allowedip.add($allowedip,$fwsvcname)
		}
	}
}

## Remediate vswitch and port group security policies
If($remediateVswitchSec){
	If($vswitches = Get-VirtualSwitch -VMHost $vmhost | Get-SecurityPolicy | Where {$_.AllowPromiscuous -eq $true -or $_.ForgedTransmits -eq $true -or $_.MacChanges -eq $true}){
		Write-ToConsole "...Configuring Virtual Switch security settings $vmhost"
		$vswitches | Set-SecurityPolicy -AllowPromiscuous $false -ForgedTransmits $false -MacChanges $false -Confirm:$false
	}else{
		Write-ToConsole "...Virtual Switch security settings already configured correctly on $vmhost"
	}
	If($portgroups = Get-VirtualPortGroup -VMHost $vmhost | Get-SecurityPolicy | Where {$_.AllowPromiscuous -eq $true -or $_.ForgedTransmits -eq $true -or $_.MacChanges -eq $true -or $_.AllowPromiscuousInherited -eq $false -or $_.ForgedTransmitsInherited -eq $false -or $_.MacChangesInherited -eq $false }){
		Write-ToConsole "...Configuring Port Group security settings $vmhost"
		$portgroups | Set-SecurityPolicy -AllowPromiscuousInherited $true -ForgedTransmitsInherited $true -MacChangesInherited $true -Confirm:$false
	}else{
		Write-ToConsole "...Port Group security settings already configured correctly on $vmhost"
	}
}

## Remediate IPV6 enabled
If($remediateipv6){
	If($hostnet = $vmhost | Get-VMHostNetwork | Where {$_.IPv6Enabled -eq $True}){
		Write-ToConsole "...Disabling IPv6 on $vmhost...!!Host will need to be rebooted for this to take effect!!"
		$hostnet | Set-VMHostNetwork -IPv6Enabled $false -Confirm:$false
	}else{
		Write-ToConsole "...IPv6 already disabled on $vmhost"
	}
}

## Enable lockdown mode
If($remediateLockdown){
	If($vmhostv.config.LockdownMode -eq "lockdownDisabled"){
		Write-ToConsole "...Enabling Lockdown mode with level $lockdownlevel on $($vmhostv.name) on $vcenter"
		$lockdown = Get-View $vmhostv.ConfigManager.HostAccessManager
		$lockdown.ChangeLockdownMode($lockdownlevel)
	}Else{
	Write-ToConsole "...Lockdown mode already enabled on $($vmhostv.name)"
	}
}

}

## Disconnect from vCenter
Write-ToConsole "...Disconnecting from vCenter Server $vcenter"
Disconnect-VIServer -Server $vcenter -Force -Confirm:$false

## Stop Transcript
Stop-Transcript