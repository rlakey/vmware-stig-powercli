<#
.SYNOPSIS
	vSphere 5.x STIG ESXi Host Remediation Script
	Created by: Ryan Lakey, rlakey@vmware.com 
	Provided as is and is not supported by VMware
.DESCRIPTION
	This script will remediate the specified ESXi host in the target vCenter for some vSphere 5.x STIG items.
	All other ESXi Host STIG items are recommended to remediate on a case by case basis.
	Note - The vSphere Web Client service firewall policy must be configured manually as doing so via this script puts the host in a disconnected state as we have to turn off all allowed IPs first then add exceptions.  Turning off all allowed IPs first though does not allow us to perform the second operation.

	!!Please read and know what this script it doing before running!!
	
	!!You will need to fill out the site specific variables below in the "Script Configuration Variables" section.

	Requirements to run script
	-PowerCLI 6.0+ and Powershell 3+
	-Powershell allowed to run unsigned/remote scripts
	-Update $TransFolder variable below to fit your environment
	-Update site specific settings in the "Site specific variables" section
	-Remediations can be turned on and off individually by changing the defined remediation variables to true or false
.PARAMETER vcenter
   vCenter server to run script against
.PARAMETER esxi
   ESXi server to remediate
.PARAMETER ds
   Datastore to copy VIB to for installation.
.PARAMETER cred
   This will prompt user for credentials that will be used to connect to vCenter specified.
.EXAMPLE
   ./VMware_5.x_STIG_Remediate_ESXi_Single.ps1 -vcenter vcenter.test.lab -esxi myhost.test.lab -ds mydatastore
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$vcenter,
	[Parameter(Mandatory=$True,Position=2)]
    [string]$esxi,
	[Parameter(Mandatory=$True,Position=3)]
    [string]$ds,
	[Parameter(Mandatory=$True,Position=4)]
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

## !!Site Specific Variables!!

## Path to Custom STIG VIB
$localbundlepath = "C:\PowerCLI\DoD-STIG-RA-v1.r4-offline_bundle.zip"
## Custom STIG VIB Package Name
$bundlename = "DoD-STIG-RA-v1.r4-offline_bundle.zip"

## Plink Settings
$plink = "C:\PowerCLI\plink.exe"

## Turn specific remediations on or off
$remediatemob = $true
$remediateAdvSettings = $true
$remediateServices = $true
$remediateNtp = $false
$remediateVibLevel = $true
$remediateFirewallRules = $true
$remediateVswitchSec = $true
$remediateipv6 = $true
$remediateDoDVIB = $true
$remediateLockdown = $true

## ESXi Advanced host settings to remediate
$esxiSettings = @{"UserVars.ESXiShellInteractiveTimeOut" = "600"; ## SRG-OS-000126-ESXi5
"UserVars.ESXiShellTimeOut" = "600"; ## SRG-OS-000126-ESXi5
#"Net.DVFilterBindIpAddress" = ""; ## SRG-OS-99999-ESXI5-000151
"Config.HostAgent.plugins.hostsvc.esxAdminsGroup" = "vCenter Admins"; ## SRG-OS-99999-ESXI5-000155
#Edit syslog server setting to reflect correct value for your environment
"Syslog.global.logHost" = "tcp://yoursyslog.server.here:514"; ## SRG-OS-000197-ESXI5
#Edit this to match your environments settings...default is specified.
#"Syslog.global.logDir" = "[] /scratch/log" ## SRG-OS-99999-ESXI5-000132
}

## ESXi services to stop
$esxiServices = @{"SSH" = $false;
"ESXi Shell" = $false;
}

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

## Get username to connect to hosts
$hostuser = Read-Host "Please enter the username that has access to SSH to the ESXi hosts"

## Get password for root to connect to hosts
$rootpw = Read-Host "Please enter the current password for $hostuser" -AsSecureString

## Convert entered passwords from secure strings to strings
$rootpwdec = [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($rootpw))

## Plink options
$plinkoptions = '-l $hostuser -pw $rootpwdec'

## Connect to vCenter Server
Try{
	Write-ToConsole "...Connecting to vCenter Server $vcenter"
	Connect-VIServer -Server $vcenter -ErrorAction Stop -Credential $cred | Out-Null}
Catch{
	Write-ToConsole "...Could not connect to $vcenter with supplied credentials...exiting script"
	Exit
	}

## Collect ESXi Hosts in variable for processing
Write-ToConsole "...Getting ESXi host info for $esxi from $vcenter"
$vmhost = Get-VMHost -Name $esxi | Where {$_.version -match "^5.*"}
$vmhostv = $vmhost | Get-View
$esxcli = $vmhost | Get-Esxcli

## Remediate ESXi Host

## Remediate managed object browser
If($remediatemob){
	Write-ToConsole "...Disabling Managed Object Browser(MOB) on $vmhost"
    ## Plink Options
    $plinkcommand1 = 'vim-cmd proxysvc/remove_service "/mob" "httpsWithRedirect"'
    $remoteCommand1 = '"' + $plinkcommand1 + '"'

    ## Start the SSH service
    Write-ToConsole "...Starting SSH on $vmhost"
    $sshService = Get-VmHostService -VMHost $vmhost | Where { $_.Key -eq “TSM-SSH”}
    Start-VMHostService -HostService $sshService -Confirm:$false | Out-Null
        
    Write-ToConsole "...Disabling MOB on $vmhost"
    $command1 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand1
    $resultsssh1 = Invoke-Expression -command $command1
    $resultsssh1
            
    ## Stop SSH service
    Write-ToConsole "...Stopping SSH on $vmhost"
    Stop-VMHostService -HostService $sshService -Confirm:$false | Out-Null
}

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

## Remediate NTP servers on ESXi
If($remediateNtp){
	Write-ToConsole "...Setting NTP servers $ntpservers and starting services on $vmhost"
    $vmhost | Add-VMHostNTPServer $ntpservers -ErrorAction SilentlyContinue
	$vmhost | Get-VMHostService | Where {$_.Label -eq "NTP Daemon"} | Set-VMHostService -Policy On | Out-Null
	$vmhost | Get-VMHostService | Where {$_.Label -eq "NTP Daemon"} | Start-VMHostService | Out-Null
}

## Remediate ESXi host VIB acceptance level
If($remediateVibLevel){
	$acceptlevel = $esxcli.software.acceptance.get()
	If($acceptlevel -ne $esxiacceptlevel){
		Write-ToConsole "...Configuring ESXi VIB Acceptance level to $esxiacceptlevel on $vmhost"
		$esxcli.software.acceptance.set($esxiacceptlevel)
	}Else{
		Write-ToConsole "...ESXi VIB Acceptance level already configured to $esxiacceptlevel on $vmhost"
	}
}

## Remediate ESXi host service firewall rules
If($remediateFirewallRules){
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
	If($vswitches = Get-VirtualSwitch -VMHost $vmhost -Standard | Get-SecurityPolicy | Where {$_.AllowPromiscuous -eq $true -or $_.ForgedTransmits -eq $true -or $_.MacChanges -eq $true}){
		Write-ToConsole "...Configuring Virtual Switch security settings $vmhost"
		$vswitches | Set-SecurityPolicy -AllowPromiscuous $false -ForgedTransmits $false -MacChanges $false -Confirm:$false
	}else{
		Write-ToConsole "...Virtual Switch security settings already configured correctly on $vmhost"
	}
	If($portgroups = Get-VirtualPortGroup -VMHost $vmhost -Standard | Get-SecurityPolicy | Where {$_.AllowPromiscuous -eq $true -or $_.ForgedTransmits -eq $true -or $_.MacChanges -eq $true -or $_.AllowPromiscuousInherited -eq $false -or $_.ForgedTransmitsInherited -eq $false -or $_.MacChangesInherited -eq $false }){
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

## Install Custom STIG VIB
If($remediateDoDVIB){
    Write-ToConsole "...Applying Custom VIB $bundlename on $vmhost"
	$localds = $vmhost | Get-Datastore -Name $ds 
        
	## Create new PSDrive pointing to local datastore
	New-PSDrive -Location $localds -Name ds -PSProvider VimDatastore -Root "\"
        
    ## Copy config files to local datastore
    Try{
        Write-ToConsole "...Copying files to $localds on $vmhost"
        Copy-DatastoreItem -Item $localbundlepath -Destination ds:\ -Force -ErrorAction Stop
	}
    Catch{
        Write-ToConsole "...Error Copying files to $localds on $vmhost trying again"
        Copy-DatastoreItem -Item $localbundlepath -Destination ds:\ -Force
    }
        
    Write-ToConsole "...Installing package on $vmhost"
    $installpath = "/vmfs/volumes/$localds/$bundlename"
    $esxcli.software.vib.install($installpath,$false,$true,$false,$false,$true,$null,$null)

    ## Remove PS Drive and files copied over
    Write-ToConsole "...Removing files and PSDrive from $localds on $vmhost"
    del ds:\$bundlename
    Remove-PSDrive ds -Force
}


## Enable lockdown mode
If($remediateLockdown){
    Write-ToConsole "...Enabling Lockdown Mode on $vmhostv"
   	$vmhostv.EnterLockdownMode()
}

## Disconnect from vCenter
Write-ToConsole "...Disconnecting from vCenter Server $vcenter"
Disconnect-VIServer -Server $vcenter -Force -Confirm:$false

## Stop Transcript
Stop-Transcript
