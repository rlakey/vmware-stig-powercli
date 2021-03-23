<#
.SYNOPSIS
	vSphere 6.0 STIG ESXi Host Compliance Check HTML Report Script
	Created by: Ryan Lakey, rlakey@vmware.com
	Updated for STIG: vSphere 6 ESXi - Version 1, Release 1
	Provided as is and is not supported by VMware
.DESCRIPTION
	This script will check compliance of all ESXi Hosts in the target vCenter.  You will be prompted for a username and password to SSH into each host.  You will also be prompted for vCenter credentials.
	
	This script will turn off lock down mode and SSH into each host to check for compliance settings like SSH Daemon configuration, password complexity, and login banners.  Lockdown mode will be turned back on if it was turned off.
	
	!!Please read and know what this script it doing before running!!
	
	!!You will need to fill out the site specific variables below in the "Script Configuration Variables" section.
	
	Requirements to run script
	-PowerCLI 6.0+ and Powershell 3+
	-Powershell allowed to run unsigned/remote scripts
	-An account with the ability to SSH to all targeted hosts
	-ESXi hosts must be reachable over the network.  If DNS names are used for hosts in vCenter then names must be resolvable also.
	-Plink.exe in the path defined by the $plink variable below.  This is used to run commands through SSH on the hosts.
.PARAMETER vcenter
   vCenter server to run script against and check ESXi hosts for compliance.
.EXAMPLE
   ./VMware_6.0_STIG_Check_ESXi_All.ps1 -vcenter vcenter.test.lab
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$vcenter
)

## Script Configuration Variables
## Capture Date variable
$Date = Get-Date
## Path to store the generated report
$ReportFolder = "C:\PowerCLI\Output"
$ReportName = $ReportFolder + "\VMware_ESXi_STIG_Compliance_Report" + "_" + $Date.Month + "-" + $Date.Day + "-" + $Date.Year + "_" + $Date.Hour + "-" + $Date.Minute + "-" + $Date.Second + ".html"
## Start Transcript
$TranscriptName = $ReportFolder + "\VMware_ESXi_STIG_Compliance_Report_Transcript" + "_" + $Date.Month + "-" + $Date.Day + "-" + $Date.Year + "_" + $Date.Hour + "-" + $Date.Minute + "-" + $Date.Second + ".txt"
Start-Transcript -Path $TranscriptName
## Display report after completion
$DisplayToScreen = $true
## Report Colors
$bgcolor = "494A4D"
$headertextcolor = "FFFFFF"
$header0bgcolor = "387C2C" #VMware Dark Green
#$header0bgcolor = "006990" #Vmware Dark Blue
$header0textcolor = "FFFFFF"
$header1bgcolor = "6DB33F" #VMware Light Green
#$header1bgcolor = "C2CD23" #VMware Yellow
#$header1bgcolor = "0095D3" #VMware Medium Blue
#$header1bgcolor = "89CBDF" #VMware Light Blue
$header1textcolor = "FFFFFF"
$TitleTxtColor = "FFFFFF"

## !!Some Settings in the following section need to be configured for your environment!!!
## Latest ESXi Build Number
$esxibuildnum = "2715541"
## ESXi Advanced host settings to check
$esxiSettings = @{"Security.AccountLockFailures" = "3";
"Security.AccountUnlockTime" = "900";
"Config.HostAgent.log.level" = "info"
"Security.PasswordQualityControl" = "similar=deny retry=3 min=disabled,disabled,disabled,disabled,15";
"Config.HostAgent.plugins.solo.enableMob" = $false;
"UserVars.ESXiShellInteractiveTimeOut" = "600";
"UserVars.ESXiShellTimeOut" = "600";
"UserVars.DcuiTimeOut" = "600";
"Mem.ShareForceSalting" = "2";
"Net.BlockGuestBPDU" = "1";
"Net.DVFilterBindIpAddress" = "";
"DCUI.Access" = "root";
#Only applies if hosts are joined to Active Directory
"Config.HostAgent.plugins.hostsvc.esxAdminsGroup" = "vCenter Admins";
#Edit syslog server setting to reflect correct value for your environment
"Syslog.global.logHost" = "tcp://yoursyslog.server.here:514";
}
## ESXi services to check status
$esxiServices = @{"SSH" = $false;
"ESXi Shell" = $false;
"NTP Daemon" = $true;
}
## One or more NTP servers to check configurations for on ESXi hosts.
$vcntp = "192.168.23.10","192.168.23.11"
## SSH Daemon settings to check
$sshsettings = @("AcceptEnv","Banner /etc/issue","ClientAliveCountMax 3","ClientAliveInterval 200","Ciphers aes128-ctr,aes192-ctr,aes256-ctr","Compression no","GatewayPorts no","GSSAPIAuthentication no","HostbasedAuthentication no","IgnoreRhosts yes","KerberosAuthentication no","MACs hmac-sha1,hmac-sha2-256,hmac-sha2-512", "MaxSessions 1","PermitEmptyPasswords no","PermitRootLogin no","PermitTunnel no","PermitUserEnvironment no","Protocol 2","StrictModes yes","X11Forwarding no");
## Path to plink executable
$plink = "C:\PowerCLI\plink.exe"

Function Write-ToConsole ($Details){
	$LogDate = Get-Date -Format T
	Write-Host "$($LogDate) $Details"
}

## HTML Reporting Functions Begin
$DspHeader0 = "
	BORDER-RIGHT: #bbbbbb 1px solid;
	PADDING-RIGHT: 0px;
	BORDER-TOP: #bbbbbb 1px solid;
	DISPLAY: block;
	PADDING-LEFT: 0px;
	FONT-WEIGHT: bold;
	FONT-SIZE: 8pt;
	MARGIN-BOTTOM: -1px;
	MARGIN-LEFT: AUTO;
	BORDER-LEFT: #bbbbbb 1px solid;
	COLOR: #$($header0textcolor);
	MARGIN-RIGHT: AUTO;
	PADDING-TOP: 4px;
	BORDER-BOTTOM: #bbbbbb 1px solid;
	FONT-FAMILY: Tahoma;
	POSITION: relative;
	HEIGHT: 2.25em;
	WIDTH: 95%;
	TEXT-INDENT: 10px;
	BACKGROUND-COLOR: #$($header0bgcolor);
"

$DspHeader1 = "
    BORDER-RIGHT: #bbbbbb 1px solid;
	PADDING-RIGHT: 0px;
	BORDER-TOP: #bbbbbb 1px solid;
	DISPLAY: block;
	PADDING-LEFT: 0px;
	FONT-WEIGHT: bold;
	FONT-SIZE: 8pt;
	MARGIN-BOTTOM: -1px;
	MARGIN-LEFT: AUTO;
	BORDER-LEFT: #bbbbbb 1px solid;
	COLOR: #$($header1textcolor);
	MARGIN-RIGHT: AUTO;
	PADDING-TOP: 4px;
	BORDER-BOTTOM: #bbbbbb 1px solid;
	FONT-FAMILY: Tahoma;
	POSITION: relative;
	HEIGHT: 2.25em;
	WIDTH: 95%;
	TEXT-INDENT: 10px;
	BACKGROUND-COLOR: #$($header1bgcolor);
"

$dspcomments = "
	BORDER-RIGHT: #bbbbbb 1px solid;
	PADDING-RIGHT: 0px;
	BORDER-TOP: #bbbbbb 1px solid;
	DISPLAY: block;
	PADDING-LEFT: 0px;
	FONT-WEIGHT: bold;
	FONT-SIZE: 8pt;
	MARGIN-BOTTOM: -1px;
	MARGIN-LEFT: AUTO;
	BORDER-LEFT: #bbbbbb 1px solid;
	COLOR: #$($TitleTxtColour);
	MARGIN-RIGHT: AUTO;
	PADDING-TOP: 4px;
	BORDER-BOTTOM: #bbbbbb 1px solid;
	FONT-FAMILY: Tahoma;
	POSITION: relative;
	HEIGHT: 2.25em;
	WIDTH: 95%;
	TEXT-INDENT: 10px;
	BACKGROUND-COLOR:#FFFFE1;
	COLOR: #000000;
	FONT-STYLE: ITALIC;
	FONT-WEIGHT: normal;
	FONT-SIZE: 8pt;
"

$filler = "
	BORDER-RIGHT: medium none; 
	BORDER-TOP: medium none; 
	DISPLAY: block; 
	BACKGROUND: none transparent scroll repeat 0% 0%; 
	MARGIN-BOTTOM: -1px; 
	FONT: 100%/8px Tahoma; 
	MARGIN-LEFT: 43px; 
	BORDER-LEFT: medium none; 
	COLOR: #ffffff; 
	MARGIN-RIGHT: 0px; 
	PADDING-TOP: 4px; 
	BORDER-BOTTOM: medium none; 
	POSITION: relative
"

$dspcont ="
	BORDER-RIGHT: #bbbbbb 1px solid;
	BORDER-TOP: #bbbbbb 1px solid;
	PADDING-LEFT: 0px;
	FONT-SIZE: 8pt;
	MARGIN-BOTTOM: -1px;
	PADDING-BOTTOM: 5px;
	MARGIN-LEFT: AUTO;
	BORDER-LEFT: #bbbbbb 1px solid;
	WIDTH: 95%;
	COLOR: #000000;
	MARGIN-RIGHT: AUTO;
	PADDING-TOP: 4px;
	BORDER-BOTTOM: #bbbbbb 1px solid;
	FONT-FAMILY: Tahoma;
	POSITION: relative;
	BACKGROUND-COLOR: #f9f9f9
"

Function Get-CustomHTML ($Header){
$Report = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>$($Header)</title>
		<META http-equiv=Content-Type content='text/html; charset=windows-1252'>

		<style type="text/css">

		TABLE 		{
						TABLE-LAYOUT: fixed;
                       	FONT-SIZE: 100%; 
						WIDTH: 100%;                
					}
		*
					{
						margin:0
					}

		.pageholder	{
						margin: 0px auto;
					}
					
		td 				{
						VERTICAL-ALIGN: TOP; 
						FONT-FAMILY: Tahoma;
					}
					
		th 			{
						VERTICAL-ALIGN: TOP; 
						COLOR: #018AC0; 
						TEXT-ALIGN: left;
					}
					
		</style>
	</head>
	<body margin-left: 4pt; margin-right: 4pt; margin-top: 6pt; bgcolor="$bgcolor">
<div style="font-family:Arial, Helvetica, sans-serif; font-size:20px; font-weight:bolder; background-color:#$($bgcolor); color:#$($headertextcolor);"><center>
<p class="accent">
<div class="MainTitle">$($Header)</div>
<div class="SubTitle">Report created on $Date</div>
<div class="SubTitle">Connected vCenter: $vcenter </div>
<br/>
</p>
</center></div>
	       
"@
Return $Report
}

Function Get-CustomHeader0 ($Title){
$Report = @"
		<div style="margin: 0px auto;">		

		<h1 style="$($DspHeader0)">$($Title)</h1>
	
    	<div style="$($filler)"></div>
"@
Return $Report
}

Function Get-CustomHeader ($Title, $cmnt){
$Report = @"
	    <h2 style="$($dspheader1)">$($Title)</h2>
"@
If ($Comments) {
	$Report += @"
			<div style="$($dspcomments)">$($cmnt)</div>
"@
}
$Report += @"
        <div style="$($dspcont)">
"@
Return $Report
}

Function Get-CustomHeaderClose{

	$Report = @"
		</DIV>
		<div style="$($filler)"></div>
"@
Return $Report
}

Function Get-CustomHeader0Close{
	$Report = @"
</DIV>
"@
Return $Report
}

Function Get-CustomHTMLClose{
	$Report = @"
</div>

</body>
</html>
"@
Return $Report
}

Function Get-HTMLTable {
	param([array]$Content)
	$HTMLTable = $Content | ConvertTo-Html -Fragment
	$HTMLTable = $HTMLTable -Replace '<TABLE>', '<TABLE><style>tr:nth-child(even) { background-color: #e5e5e5; TABLE-LAYOUT: Fixed; FONT-SIZE: 100%; WIDTH: 100%;}</style>' 
	$HTMLTable = $HTMLTable -Replace '<td>', '<td style= "FONT-FAMILY: Tahoma; FONT-SIZE: 8pt; TEXT-ALIGN: center;">'
	$HTMLTable = $HTMLTable -Replace '<th>', '<th style= "FONT-FAMILY: Tahoma; FONT-SIZE: 8pt; COLOR: #000000; TEXT-ALIGN: center;">'
	$HTMLTable = $HTMLTable -replace '&lt;', "<"
	$HTMLTable = $HTMLTable -replace '&gt;', ">"
	Return $HTMLTable
}

Function Get-HTMLDetail ($Heading, $Detail){
$Report = @"
<TABLE TABLE-LAYOUT: Fixed; FONT-SIZE: 100%; WIDTH: 100%>
	<tr>
	<th width='50%';VERTICAL-ALIGN: TOP; FONT-FAMILY: Tahoma; FONT-SIZE: 8pt; COLOR: #$($Color1);><b>$Heading</b></th>
	<td width='50%';VERTICAL-ALIGN: TOP; FONT-FAMILY: Tahoma; FONT-SIZE: 8pt;>$($Detail)</td>
	</tr>
</TABLE>
"@
Return $Report
}
## HTML Reporting Functions End

## Check for PowerCLI modules loaded and if not load them..
Try{
	if (!(Get-Module -Name VMware.VimAutomation.Core -ErrorAction Stop) ) {
	Write-ToConsole "...PowerCLI modules not detected...loading PowerCLI"
	."C:\Program Files (x86)\VMware\Infrastructure\vSphere PowerCLI\Scripts\Initialize-PowerCLIEnvironment.ps1"}}
Catch{
	Write-ToConsole "...Issue loading PowerCLI modules or PowerCLI modules not present...please correct and rerun...exiting script"
	Exit
}
## Initiate Empty Report Variable
$MyReport = @()
## Report Header
$MyReport = Get-CustomHTML "VMware vSphere 6.0 ESXi STIG Compliance Report"

#Get username to connect to hosts
$hostuser = Read-Host "Please enter the username that has access to SSH to the ESXi hosts"

#Get password for root to connect to hosts
$rootpw = Read-Host "Please enter the current password for $hostuser" -AsSecureString

#Convert entered passwords from secure strings to strings
$rootpwdec = [System.Runtime.InteropServices.marshal]::PtrToStringAuto([System.Runtime.InteropServices.marshal]::SecureStringToBSTR($rootpw))

#Get vCenter credentials to use
Write-ToConsole "...Enter credentials to connect to vCenter"
$pscred = Get-Credential

## Connect to vCenter Server
Try{
	Write-ToConsole "...Connecting to vCenter Server $vcenter"
	Connect-VIServer -Server $vcenter -Credential $pscred -Protocol https -ErrorAction Stop | Out-Null}
Catch{
	Write-ToConsole "...Could not connect to $vcenter with supplied credentials...exiting script"
	Exit
}
	
#Initiate Variables for Report
$syslogpersistfound = @()
$dumpfound = @()
$acceptlvlfound = @()
$acceptlvlinstallfound = @()
$snmpenfound =@()
$sshdaemonfound = @()
$authkeysfound = @()
$rememberfound = @()
$passhashfound = @()
$lockdownusersfound = @()
$stacksfound = @()
$fwrulesfound = @()
$fwpolicyfound = @()
$ntpfound = @()
$chapconffound = @()
$lockdownfound = @()
$welcomefound = @()
$issuefound = @()
$noADfound = @()
$noCACfound = @()
$oldbuildfound = @()
$ipv6found = @()
$vsssecfound = @()
$vsspgsecfound = @()
$vsspgvlanfound = @()
	
Write-ToConsole "...Gathering ESXi 6.0.x host information for $vcenter"
$vmhosts = Get-VMHost | Where {$_.version -match "^6.0*"} | Sort Name
$vmhostsv = Get-View -ViewType "HostSystem" | Where {$_.config.product.version -match "^6.0*"} | Sort Name

#Plink Settings
$plinkoptions = '-l $hostuser -pw $rootpwdec'

#Plink Commands
$plinkcommand1 = 'cat /etc/ssh/sshd_config'
$plinkcommand2 = 'cat /etc/ssh/keys-root/authorized_keys'
$plinkcommand3 = 'grep -i "^password" /etc/pam.d/passwd | grep sufficient'
$remoteCommand1 = '"' + $plinkcommand1 + '"'
$remoteCommand2 = '"' + $plinkcommand2 + '"'
$remoteCommand3 = '"' + $plinkcommand3 + '"'

$MyReport += Get-CustomHeader0 "ESXi Host STIG checks for vCenter server: $vcenter"	
	
#ESXCLI/SSH based checks
foreach($vmhost in $vmhosts){
		
	#Get lockdown mode view
	$ldconfig = Get-View $vmhost.extensiondata.ConfigManager.HostAccessManager
		
	#Disable Lockdown Mode if enabled	
    If($vmhost.extensiondata.config.LockdownMode -ne "lockdownDisabled"){
		Write-ToConsole "...Disabling Lockdown Mode on $vmhost"
		$ldmode = $vmhost.extensiondata.config.LockdownMode
		$ldconfig.ChangeLockdownMode("lockdownDisabled")
		$lockdownon = $true
    }
	else{$lockdownon = $false}
		
	#Query lockdown mode users
	$ldexceptusers = $ldconfig.QueryLockdownExceptions()
		
    #Get esxcli for current host
    Write-ToConsole "...Getting ESXCLI on $vmhost"
    $esxcli = Get-EsxCli -VMHost $VMHost
                
    #Start the SSH service
    Write-ToConsole "...Starting SSH on $vmhost"
    $sshService = Get-VmHostService -VMHost $vmhost | Where { $_.Key -eq “TSM-SSH”}
    Start-VMHostService -HostService $sshService -Confirm:$false | Out-Null

    $command1 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand1
    $resultsssh1 = Invoke-Expression -command $command1
		
	$command2 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand2
    $resultsssh2 = Invoke-Expression -command $command2
		
	$command3 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand3
    $resultsssh3 = Invoke-Expression -command $command3
		
	#Stop SSH service
    Write-ToConsole "...Stopping SSH on $vmhost"
    Stop-VMHostService -HostService $sshService -Confirm:$false | Out-Null

    #Re-Enable Lockdown Mode
	If($lockdownon){
        Write-ToConsole "...Enabling Lockdown Mode on $vmhost"
        $ldconfig.ChangeLockdownMode($ldmode)
	}
		
	#Check for persistent local log location
	$syslogloc = $esxcli.system.syslog.config.get()
	If($syslogloc.LocalLogOutputIsPersistent -eq $false){
		$syslogpersistfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Log Location" = $syslogloc.LocalLogOutput
            "LocalLogOutputIsPersistent" = $syslogloc.LocalLogOutputIsPersistent
			"Expected Value" = "True"
        })
	}
			
	#Check for kernel core dumps enabled
	$dumploc = $esxcli.system.coredump.partition.get()
	$dumpnet = $esxcli.system.coredump.network.get()
	If($dumpnet.Enabled -eq $false -and $dumploc.Active -eq ""){
		$dumpfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Active Partition" = $dumploc.Active
            "Network Dump Enabled" = $dumpnet.Enabled
			"Expected Value" = "Network Dumps Enabled or Active local partition configured."
        })
	}
			
	#Check for acceptance level
	$acceptlvl = $esxcli.software.acceptance.get()
	If($acceptlvl -eq "CommunitySupported"){
		$acceptlvlfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Acceptance Level" = $acceptlvl
			"Expected Value" = "VMware Accepted,VMware Certified,Partner Supported"
        })
	}
			
	#Check for vibs installed with community supported acceptance level
	$acceptinstalllvl = $esxcli.software.vib.list() | Where {$_.AcceptanceLevel -eq "CommunitySupported"}	
    foreach($vib in $acceptinstalllvl){
		$acceptlvlinstallfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "VIB Name" = $vib.Name
			"VIB Install Date" = $vib.InstallDate
			"VIB Acceptance Level" = $vib.AcceptanceLevel
			"Expected Value" = "VMware Accepted,VMware Certified,Partner Supported"
        })
	}
		
	#Check for snmp enabled without v3 targets
	$snmpconf = $esxcli.system.snmp.get()
	If($snmpconf.enable -eq $true -and $snmpconf.v3targets -eq $null){
		$snmpenfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "SNMP Enabled" = $snmpconf.enable
			"SNMP v3 Targets" = $snmpconf.v3targets
			"SNMP Targets" = $snmpconf.targets
			"SNMP Communities" = $snmpconf.communities
			"Expected Value" = "If SNMP is enabled only v3 targets can be configured."
        })
	}
			
	#Check SSH Daemon settings
	foreach($sshsetting in $sshsettings){
		$separator = " "
		$splitsetting = $sshsetting.split($separator)
		$sshsettingleft = $splitsetting[0]
			
       	$regex1 = [regex]"^$sshsetting$"
       	$regex2 = [regex]"^$sshsettingleft*"

       	foreach($result in $resultsssh1){
       		if($result -match $regex2 -and $result -notmatch $regex1){
           		$sshdaemonfound += New-Object PSObject -Property ([ordered]@{
               	"Host Name" = $vmhost.name
               	"SSH Setting" = $result
				"Expected Value" = $sshsetting
               	})			
        	}
        }
        $resultsssh1count = (($resultsssh1 -match $regex2).count)
        if($resultsssh1count -eq 0){
           	$sshdaemonfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "SSH Setting" = "Setting $sshsetting not found in /etc/ssh/sshd_config!"
			"Expected Value" = $sshsetting
            })
        }
	}
		
    #Check for ssh authorized_keys file not empty in /etc/ssh/keys-root/authorized_keys       
    $resultsssh2count = (($resultsssh2).count)
    if($resultsssh2count -ne 0){
        $authkeysfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "Authorized Keys" = $resultsssh2 | Out-String
		"Expected Value" = "/etc/ssh/keys-root/authorized_keys should be empty!"
        })
    }
		
	#Check for password remember setting and password hash algorithm       
    if($resultsssh3 -notmatch "remember=5"){
        $rememberfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "Remember Setting" = $resultsssh3 | Out-String
		"Expected Value" = "remember=5 should be present!"
        })
    }
	if($resultsssh3 -notmatch "sha512"){
        $passhashfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "Remember Setting" = $resultsssh3 | Out-String
		"Expected Value" = "sha512 should be present!"
        })
    }
		
	#Check for lockdown mode exception users
	$ldusercount = (($ldexceptusers).count)
    If($ldusercount -ne 0){
        $lockdownusersfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "Lockdown Exception Users" = &{If($ldexceptusers){([String]::Join(',',$ldexceptusers))}else{"No users found."}}
		"Expected Value" = "Verify all users on list are valid."
        })
    }          	
}
	
#Check vSwitch Security Settings
Write-ToConsole "...Checking ESXi Hosts for incorrect network security settings on $vcenter"
foreach($vmhost in $vmhostsv){
	$vmhostnet = $vmhost.configmanager.networksystem
	$vmhostnetv = Get-View $vmhostnet
	foreach($vswitch in $vmhostnetv.networkconfig.vswitch){
        If($vswitch.spec.policy.security.AllowPromiscuous -ne $false){
	        $vsssecfound += New-Object PSObject -Property ([ordered]@{
                HostName = $vmhost.Name
                vSwitch = $vswitch.name
                "Policy Name" = "AllowPromiscuous"
                "Policy Value" = $vswitch.spec.policy.security.AllowPromiscuous
				"Expected Value" = "False"
            })}
        If($vswitch.spec.policy.security.MacChanges -ne $false){
    	    $vsssecfound += New-Object PSObject -Property ([ordered]@{
            	HostName = $vmhost.Name
            	vSwitch = $vswitch.name
            	"Policy Name" = "MacChanges"
            	"Policy Value" = $vswitch.spec.policy.security.MacChanges
				"Expected Value" = "False"
            })}
        If($vswitch.spec.policy.security.ForgedTransmits -ne $false){
        	$vsssecfound += New-Object PSObject -Property ([ordered]@{
                HostName = $vmhost.Name
                vSwitch = $vswitch.name
                "Policy Name" = "Forged Transmits"
                "Policy Value" = $vswitch.spec.policy.security.ForgedTransmits
				"Expected Value" = "False"
            })}
    }
    foreach($portgroup in $vmhostnetv.networkconfig.portgroup){
        If($portgroup.spec.policy.security.AllowPromiscuous -ne $false -and $portgroup.spec.policy.security.AllowPromiscuous -ne $NULL){
            $vsspgsecfound += New-Object PSObject -Property ([ordered]@{
                HostName = $vmhost.Name
                PortGroup = $portgroup.spec.name
                "Policy Name" = "AllowPromiscuous"
                "Policy Value" = $portgroup.spec.policy.security.AllowPromiscuous
				"Expected Value" = "False"
            })}
        If($portgroup.spec.policy.security.MacChanges -ne $false -and $portgroup.spec.policy.security.MacChanges -ne $NULL){
    	    $vsspgsecfound += New-Object PSObject -Property ([ordered]@{
                HostName = $vmhost.Name
                PortGroup = $portgroup.spec.name
                "Policy Name" = "MacChanges"
                "Policy Value" = $portgroup.spec.policy.security.MacChanges
				"Expected Value" = "False"
            })}
        If($portgroup.spec.policy.security.ForgedTransmits -ne $false -and $portgroup.spec.policy.security.ForgedTransmits -ne $NULL){
            $vsspgsecfound += New-Object PSObject -Property ([ordered]@{
                HostName = $vmhost.Name
                PortGroup = $portgroup.spec.name
                "Policy Name" = "ForgedTransmits"
                "Policy Value" = $portgroup.spec.policy.security.ForgedTransmits
				"Expected Value" = "False"
            })}
    }
	foreach($portgroup in $vmhostnetv.networkconfig.portgroup){
        If($portgroup.spec.vlanid -eq "1" -or $portgroup.spec.vlanid -In 4094..4095 -or $portgroup.spec.vlanid -In 1001..1024 -or $portgroup.spec.vlanid -In 3968..4047){
    	    $vsspgvlanfound += New-Object PSObject -Property ([ordered]@{
                HostName = $vmhost.Name
                PortGroup = $portgroup.spec.name
                "VLAN ID" = $portgroup.spec.vlanid
				"Expected Value" = "Native,Reserved, and VGT VLAN IDs should not be used"
            })}
        }
	}
	
#Check for IPv6 Enabled
Write-ToConsole "...Checking ESXi Hosts for IPv6 Enabled on $vcenter"    
foreach($vmhost in $vmhostsv | sort Name){
    If($vmhost.config.network.Ipv6Enabled -eq $true -and $vmhost.config.network.IpRouteConfig.IpV6DefaultGateway -eq $null){
        $ipv6found += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "IPv6 Enabled" = $vmhost.config.network.Ipv6Enabled
			"IPv6 Default Gateway" = $vmhost.config.network.IpRouteConfig.IpV6DefaultGateway
			"Expected Value" = "IPv6 disabled if not in use."
        })
    }
}
	
#Check for updated ESXi build
Write-ToConsole "...Checking ESXi Hosts for correct build number on $vcenter"
foreach($vmhost in $vmhostsv | sort Name){
    If($vmhost.config.product.build -ne "$esxibuildnum"){
        $oldbuildfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Current Build Number" = $vmhost.config.product.build
			"Expected Value" = "Build Number: $esxibuildnum"
        })
    }
}	
	
#Check for host joined to AD
Write-ToConsole "...Checking ESXi Hosts joined to Active Directory and Smart Card authentication on $vcenter"
foreach($vmhost in $vmhostsv | sort Name){
	$adauth = Get-View $vmhost.ConfigManager.AuthenticationManager
	$adauthinfo = $adauth.info.AuthConfig | Where {$_ -is [VMware.Vim.HostActiveDirectoryInfo]}
    If($adauthinfo.Enabled -ne $true){
        $noADfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "AD Enabled" = $adauthinfo.Enabled
			"Expected Value" = "Host joined to AD"
        })
    }
	If($adauthinfo.SmartCardAuthenticationEnabled -ne $true){
        $noCACfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "CAC Enabled" = $adauthinfo.SmartCardAuthenticationEnabled
			"Domain Status" = $adauthinfo.DomainMembershipStatus
			"Joined Domain" = $adauthinfo.JoinedDomain
			"Expected Value" = "Host joined to AD have Smart Card Authentication enabled"
        })
    }
}
		
#Check for correct ESXi advanced settings
foreach($setting in ($esxiSettings.GetEnumerator() | Sort Name)){
	$name = $setting.name
	$value = $setting.value
    Write-ToConsole "...Checking ESXi Hosts for $name on $vcenter"
    $hostsfound = @()
    foreach($vmhost in $vmhostsv | sort Name){
        If($vmhost.config.option.key -contains "$name"){
            $currentvalue = $vmhost.config.option | where {$_.key -eq "$name"}
            If($currentvalue.value -ne $value){
            $hostsfound += New-Object PSObject -Property ([ordered]@{
                "Host Name" = $vmhost.name
                "Advanced Setting" = $currentvalue.key
                "Current Value" = $currentvalue.value
				"Expected Value" = $value
            })
        }
    }
    If($vmhost.config.option.key -notcontains "$name"){
        $hostsfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Advanced Setting" = $name
            "Current Value" = "Setting does not exist and must be created!"
			"Expected Value" = $value
        })
    }
}
$MyReport += Get-CustomHeader "Hosts with $name not set to $value : $(@($hostsfound).count)"
$MyReport += Get-HTMLTable $hostsfound
$MyReport += Get-CustomHeaderClose
}
	
#Check for correct ESXi /etc/issue file
Write-ToConsole "...Checking ESXi Hosts for Config.Etc.issue on $vcenter"
foreach($vmhost in $vmhostsv | sort Name){
    If($vmhost.config.option.key -contains "Config.Etc.issue"){
        $currentvalue = $vmhost.config.option | where {$_.key -eq "Config.Etc.issue"}
        If($currentvalue.value.Contains("You are accessing a U.S. Government")){}
		else{
            $issuefound += New-Object PSObject -Property ([ordered]@{
                "Host Name" = $vmhost.name
                "Advanced Setting" = $currentvalue.key
                "Current Value" = $currentvalue.value
				"Expected Value" = "You are accessing a U.S. Government (USG) Information System (IS) that is provided for USG-authorized use only. By using this IS (which includes any device attached to this IS), you consent to the following conditions: -The USG routinely intercepts and monitors communications on this IS for purposes including, but not limited to, penetration testing, COMSEC monitoring, network operations and defense, personnel misconduct (PM), law enforcement (LE), and counterintelligence (CI) investigations. -At any time, the USG may inspect and seize data stored on this IS. -Communications using, or data stored on, this IS are not private, are subject to routine monitoring, interception, and search, and may be disclosed or used for any USG-authorized purpose. -This IS includes security measures (e.g., authentication and access controls) to protect USG interests--not for your personal benefit or privacy. -Notwithstanding the above, using this IS does not constitute consent to PM, LE or CI investigative searching or monitoring of the content of privileged communications, or work product, related to personal representation or services by attorneys, psychotherapists, or clergy, and their assistants. Such communications and work product are private and confidential. See User Agreement for details."
            })
        }
    }
    If($vmhost.config.option.key -notcontains "Annotations.WelcomeMessage"){
        $issuefound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Advanced Setting" = "Config.Etc.issue"
            "Current Value" = "Setting does not exist and must be created!"
			"Expected Value" = "You are accessing a U.S. Government (USG) Information System (IS) that is provided for USG-authorized use only. By using this IS (which includes any device attached to this IS), you consent to the following conditions: -The USG routinely intercepts and monitors communications on this IS for purposes including, but not limited to, penetration testing, COMSEC monitoring, network operations and defense, personnel misconduct (PM), law enforcement (LE), and counterintelligence (CI) investigations. -At any time, the USG may inspect and seize data stored on this IS. -Communications using, or data stored on, this IS are not private, are subject to routine monitoring, interception, and search, and may be disclosed or used for any USG-authorized purpose. -This IS includes security measures (e.g., authentication and access controls) to protect USG interests--not for your personal benefit or privacy. -Notwithstanding the above, using this IS does not constitute consent to PM, LE or CI investigative searching or monitoring of the content of privileged communications, or work product, related to personal representation or services by attorneys, psychotherapists, or clergy, and their assistants. Such communications and work product are private and confidential. See User Agreement for details."
            })
    }
}
	
#Check for correct ESXi /etc/vmware/welcome file
Write-ToConsole "...Checking ESXi Hosts for Annotations.WelcomeMessage on $vcenter"
foreach($vmhost in $vmhostsv | sort Name){
    If($vmhost.config.option.key -contains "Annotations.WelcomeMessage"){
        $currentvalue = $vmhost.config.option | where {$_.key -eq "Annotations.WelcomeMessage"}
        If($currentvalue.value.Contains("You are accessing a U.S. Government")){}
		else{
        $welcomefound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Advanced Setting" = $currentvalue.key
            "Current Value" = $currentvalue.value
			"Expected Value" = "See STIG finding for expected value."
            })
        }
    }
    If($vmhost.config.option.key -notcontains "Annotations.WelcomeMessage"){
        $welcomefound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Advanced Setting" = "Annotations.WelcomeMessage"
            "Current Value" = "Setting does not exist and must be created!"
			"Expected Value" = "See STIG finding for expected value."
            })
    }
}
	
#Check for lockdown mode enabled
Write-ToConsole "...Checking ESXi Hosts for lockdown mode enabled on $vcenter"
foreach($vmhost in $vmhostsv | sort Name){
    If($vmhost.config.LockdownMode -eq "lockdownDisabled"){
        $lockdownfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Lockdown Mode" = $vmhost.config.LockdownMode
			"Expected Value" = "Lockdown mode enabled"
        })
    }
}
	
#Check for iSCSI CHAP not enabled
Write-ToConsole "...Checking ESXi Hosts for iSCSI CHAP not required on $vcenter"
foreach($vmhost in $vmhostsv){
	$iscsihbas = $vmhost.config.storagedevice.hostbusadapter | Where Model -like iSCSI*
	foreach($hba in $iscsihbas){
		If($hba.authenticationproperties.ChapAuthenticationType -ne "chapRequired" -or $hba.authenticationproperties.MutualChapAuthenticationType -ne "chapRequired"){
			$chapconffound += New-Object PSObject -Property ([ordered]@{
           		"Host Name" = $vmhost.name
               	"Host Bus Adapter" = $hba.Device
				"Host Bus Adapter Status" = $hba.Status
				"CHAP Enabled" = $hba.authenticationproperties.chapauthenabled
				"CHAP Required" = $hba.authenticationproperties.ChapAuthenticationType
				"Mutual CHAP Required" = $hba.authenticationproperties.MutualChapAuthenticationType
				"Expected Value" = "Mutual CHAP Enabled"
           	})
		}		
	}
}
	
#Check for ESXi service status
foreach($service in ($esxiServices.GetEnumerator() | Sort Name)){
	$name = $service.name
	$value = $service.value
    Write-ToConsole "...Checking ESXi Hosts for $name service status on $vcenter"
    $servicesfound = @()
    foreach($vmhost in $vmhostsv | sort Name){
        If($vmhost.config.service.service | Where {$_.Label -eq "$name"} | Where {$_.Running -ne $value}){
            $currentvalue = $vmhost.config.service.service | where {$_.label -eq "$name"}
            $servicesfound += New-Object PSObject -Property ([ordered]@{
                "Host Name" = $vmhost.name
                "Service Name" = $name
                "Service Running" = $currentvalue.Running
				"Expected Value" = $value
            })
        }
    }
	$MyReport += Get-CustomHeader "Hosts with $name service not in the correct running state : $(@($servicesfound).count)"
	$MyReport += Get-HTMLTable $servicesfound
    $MyReport += Get-CustomHeaderClose
}

#Check for correct NTP servers
Write-ToConsole "...Checking ESXi Hosts for correct NTP servers on $vcenter"  
foreach($vmhost in $vmhostsv){
	$currentntp = $vmhost.config.DateTimeInfo.ntpconfig.server
	If($currentntp.count -eq "0"){
		$ntpfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Current NTP Servers" = "No NTP servers configured!"
			"Expected NTP Servers" = [String]::Join(',',$vcntp)
        })  
	}else{
	   	If($vcntp[0] -ne $currentntp[0] -or $vcntp[1] -ne $currentntp[1]){
       	$ntpfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Current NTP Servers" = [String]::Join(',',$currentntp)
			"Expected NTP Servers" = [String]::Join(',',$vcntp)
        })    
    	}
	}
}
		
#Check for default firewall policy not set to block
Write-ToConsole "...Checking ESXi Hosts for default firewall policy not set to block on $vcenter"
foreach($vmhost in $vmhostsv | sort Name){
	If($vmhost.config.firewall.defaultpolicy.incomingblocked -ne $true -or $vmhost.config.firewall.defaultpolicy.outgoingblocked -ne $true){
		$fwpolicyfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "IncomingBlocked" = $vmhost.config.firewall.defaultpolicy.incomingblocked
			"OutgoingBlocked" = $vmhost.config.firewall.defaultpolicy.outgoingblocked
			"Expected Value" = "Incoming and Outgoing traffic is blocked."
        })
	}
}
	
#Check for firewall rules set to allow all IPs
Write-ToConsole "...Checking ESXi Hosts for firewall rules set to allow all IPs on $vcenter"
foreach($vmhost in $vmhostsv | sort Name){
	$fwrules = $vmhost.config.firewall.ruleset | Where {$_.Enabled -eq $true}
    foreach($fwrule in $fwrules){
		If($fwrule.allowedhosts.AllIp -eq $true){
			$fwrulesfound += New-Object PSObject -Property ([ordered]@{
               	"Host Name" = $vmhost.name
               	"Service" = $fwrule.label
				"Service Enabled" = $fwrule.Enabled
				"All IPs Enabled" = $fwrule.allowedhosts.AllIp
				"Expected Value" = "Firewall rules restricted to a specific IP range."
           	})
		}
	}	
}
	
#Check for TCP/IP stacks configured
Write-ToConsole "...Checking ESXi Hosts for system TCP/IP stacks not configured on $vcenter"
foreach($vmhost in $vmhostsv | sort Name){
	$stacks = $vmhost.config.Network.NetStackInstance
	foreach($stack in ($stacks | Where {$_.iprouteconfig.DefaultGateway -eq $null})){
		$stacksfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "TCP/IP Stack" = $stack.Key
			"Stack Gateway" = $stack.iprouteconfig.defaultgateway
			"Expected Value" = "Default system TCP/IP stacks(Management,vMotion,Provisioning) configured for use."
        })
	}
}
    	
#Insert Data into report format
	
$MyReport += Get-CustomHeader "Hosts with non-persistent local log locations : $(@($syslogpersistfound).count)"
$MyReport += Get-HTMLTable $syslogpersistfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with core dumps not enabled : $(@($dumpfound).count)"
$MyReport += Get-HTMLTable $dumpfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with acceptance level not correctly set : $(@($acceptlvlfound).count)"
$MyReport += Get-HTMLTable $acceptlvlfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with vibs installed at the community supported acceptance level : $(@($acceptlvlinstallfound).count)"
$MyReport += Get-HTMLTable $acceptlvlinstallfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with SNMP enabled and not using v3 targets : $(@($snmpenfound).count)"
$MyReport += Get-HTMLTable $snmpenfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with incorrect settings in /etc/ssh/sshd_config : $(@($sshdaemonfound).count)"
$MyReport += Get-HTMLTable $sshdaemonfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with authorized_keys file not empty in /etc/ssh/keys-root/authorized_keys : $(@($authkeysfound).count)"
$MyReport += Get-HTMLTable $authkeysfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with password remember setting not set in /etc/pam.d/passwd : $(@($rememberfound).count)"
$MyReport += Get-HTMLTable $rememberfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with password hash setting not set in /etc/pam.d/passwd : $(@($passhashfound).count)"
$MyReport += Get-HTMLTable $passhashfound
$MyReport += Get-CustomHeaderClose
		
$MyReport += Get-CustomHeader "Hosts with virtual standard switches with security policies not configured correctly : $(@($vsssecfound).count)"
$MyReport += Get-HTMLTable $vsssecfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with virtual standard port groups with security policies not configured correctly : $(@($vsspgsecfound).count)"
$MyReport += Get-HTMLTable $vsspgsecfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with virtual standard port groups with Native,Reserved, or VGT VLAN IDs configured : $(@($vsspgvlanfound).count)"
$MyReport += Get-HTMLTable $vsspgvlanfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with IPv6 enabled : $(@($ipv6found).count)"
$MyReport += Get-HTMLTable $ipv6found
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts not joined to Active Directory : $(@($noADfound).count)"
$MyReport += Get-HTMLTable $noADfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts without Smart Card authentication enabled : $(@($noCACfound).count)"
$MyReport += Get-HTMLTable $noCACfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with outdated patch level : $(@($oldbuildfound).count)"
$MyReport += Get-HTMLTable $oldbuildfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with $welcomename not set to contain the DoD banner on the DCUI login screen : $(@($issuefound).count)"
$MyReport += Get-HTMLTable $issuefound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with $welcomename not set to contain the DoD banner on the DCUI login screen : $(@($welcomefound).count)"
$MyReport += Get-HTMLTable $welcomefound
$MyReport += Get-CustomHeaderClose
		
$MyReport += Get-CustomHeader "Hosts with Lockdown mode not enabled : $(@($lockdownfound).count)"
$MyReport += Get-HTMLTable $lockdownfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with Lockdown mode exception users configured : $(@($lockdownusersfound).count)"
$MyReport += Get-HTMLTable $lockdownusersfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with iSCSI adapters and mutual CHAP not required : $(@($chapconffound).count)"
$MyReport += Get-HTMLTable $chapconffound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with incorrect NTP servers set : $(@($ntpfound).count)"
$MyReport += Get-HTMLTable $ntpfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with default firewall policy not set to block : $(@($fwpolicyfound).count)"
$MyReport += Get-HTMLTable $fwpolicyfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with firewall rules set to allow all IPs for a service : $(@($fwrulesfound).count)"
$MyReport += Get-HTMLTable $fwrulesfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with system TCP/IP stacks not configured : $(@($stacksfound).count)"
$MyReport += Get-HTMLTable $stacksfound
$MyReport += Get-CustomHeaderClose
	
## End STIG Checks
$MyReport += Get-CustomHeader0Close

## Disconnect from vCenter
Write-ToConsole "...Disconnecting from vCenter Server $vcenter"
Disconnect-VIServer -Server $vcenter -Force -Confirm:$false


## Generate Report
$MyReport | out-file -encoding ASCII -filepath $ReportName

## Display report on screen after completetion
if ($DisplayToScreen) {
	Write-ToConsole "...Displaying STIG Compliance Report"
	Invoke-Item $ReportName
}

## Stop Transcript
Stop-Transcript
