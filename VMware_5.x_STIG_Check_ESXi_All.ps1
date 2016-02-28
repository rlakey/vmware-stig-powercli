<#
.SYNOPSIS
	vSphere 5.x STIG ESXi Host Compliance Check HTML Report Script
	Created by: Ryan Lakey, rlakey@vmware.com
	Updated for STIG: vSphere 5 ESXi Server - Version 1, Release 8
	Provided as is and is not supported by VMware
.DESCRIPTION
	This script will check compliance of all ESXi Hosts in the target vCenter.  You will be prompted for a username and password to SSH into each host.  You will also be prompted for vCenter credentials.
	
	This script checks 97 out of 136 ESXi STIG control items with 4 vCenter related items in a seperate vCenter check script.
	
	This script will turn off lock down mode and SSH into each host to check for compliance settings like SSH Daemon configuration, password complexity, and login banners.  Lockdown mode will be turned back on if it was turned off.
	
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
   ./VMware_5.x_STIG_Check_ESXi.ps1 -vcenter vcenter.test.lab
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
$esxibuildnum = "3116895"
## ESXi Advanced host settings to check
$esxiSettings = @{"UserVars.ESXiShellTimeOut" = "600"; ## SRG-OS-000126-ESXI5, SRG-OS-000163-ESXI5
"Net.DVFilterBindIpAddress" = ""; ## SRG-OS-99999-ESXI5-000151
#Only applies if hosts are joined to Active Directory
"Config.HostAgent.plugins.hostsvc.esxAdminsGroup" = "vCenter Admins"; ## SRG-OS-99999-ESXI5-000155
#Edit syslog server setting to reflect correct value for your environment
"Syslog.global.logHost" = "tcp://yoursyslog.server.here:514"; ## GEN005540-ESXI5-000078,GEN005460-ESXI5-000060
}
## ESXi services to check status
$esxiServices = @{"SSH" = $false; ## SRG-OS-99999-ESXI5-000138
"ESXi Shell" = $false; ## SRG-OS-99999-ESXI5-000136
"NTP Daemon" = $true; ## SRG-OS-000056-ESXI5, GEN000240-ESXI5-000058, SRG-OS-99999-ESXI5-000131
"Direct Console UI" = $false; ## SRG-OS-99999-ESXI5-000135
}
## One or more NTP servers to check configurations for on ESXi hosts.
$vcntp = "192.168.23.10","192.168.23.11" ## SRG-OS-000056-ESXI5, GEN000240-ESXI5-000058, SRG-OS-99999-ESXI5-000131
## SSH Daemon settings to check
$sshsettings = @("AcceptEnv LOCALE","AllowGroups root","AllowTcpForwarding no","Banner /etc/issue","Compression no","GatewayPorts no","MACs hmac-sha1,hmac-sha1-96","MaxSessions 1","PermitRootLogin no","PermitTunnel no","PermitUserEnvironment no","Protocol 2","StrictModes yes","X11Forwarding no");
## SSH Client settings to check
$sshcsettings = @("AllowTcpForwarding no","Ciphers aes128-ctr,aes192-ctr,aes256-ctr","GatewayPorts no","MACs hmac-sha1,hmac-sha1-96","PermitTunnel no","Protocol 2","SendEnv LOCALE","X11Forwarding no");
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
$MyReport = Get-CustomHTML "VMware vSphere 5.x ESXi STIG Compliance Report"

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
$sshclientfound = @()
$bannerfound = @()
$authkeysfound = @()
$rememberfound = @()
$passhashfound = @()
$pwcomplexfound = @()
$mobfound = @()
$ldpreloadfound = @()
$useridsfound = @()
$usersfound = @()
$fwrulesfound = @()
$fwpolicyfound = @()
$ntpfound = @()
$chapconffound = @()
$lockdownfound = @()
$noADfound = @()
$oldbuildfound = @()
$ipv6found = @()
$vsssecfound = @()
$vsspgsecfound = @()
$vsspgvlanfound = @()
$nogatewayfound = @()
$hostseqfound = @()
$rhostsfound = @()
$setuidfound = @()
$fstabfound = @()
$setgidfound = @()
$profpathfound = @()
$initdfound = @()
$libsearchfound = @()
$hostdnsfound = @()
$noshellsfound = @()
$badshellsfound = @()
$extdevfilesfound = @()
$dhcpfound = @()
	
Write-ToConsole "...Gathering ESXi 5.x host information for $vcenter"
$vmhosts = Get-VMHost | Where {$_.version -match "^5.*"} | Sort Name
$vmhostsv = Get-View -ViewType "HostSystem" | Where {$_.config.product.version -match "^5.*"} | Sort Name

#Plink Settings
$plinkoptions = '-l $hostuser -pw $rootpwdec'

#Plink Commands
$plinkcommand1 = 'cat /etc/ssh/sshd_config'
$plinkcommand2 = 'cat /etc/ssh/keys-root/authorized_keys'
$plinkcommand3 = 'grep -i "^password" /etc/pam.d/passwd | grep sufficient'
$plinkcommand4 = 'cat /etc/vmware/snmp.xml'
$plinkcommand5 = 'grep -i "^password" /etc/pam.d/passwd | grep requisite'
$plinkcommand6 = 'vim-cmd proxysvc/service_list | grep proxy-mob'
$plinkcommand7 = 'grep LD_PRELOAD /etc/vmware/config'
$plinkcommand8 = 'cat /etc/ssh/ssh_config'
$plinkcommand9 = 'cat /etc/issue'
$plinkcommand10 = 'cat /etc/passwd | cut -f 3 -d ":"'
$plinkcommand11 = 'cat /etc/passwd | cut -f 1 -d ":"'
$plinkcommand12 = 'find / | grep hosts.equiv'
$plinkcommand13 = 'find / | grep .rhosts'
$plinkcommand14 = 'find / -perm -4000 -exec ls -lL {} \;'
$plinkcommand15 = 'cat /etc/fstab | grep -v "^#"'
$plinkcommand16 = 'find / -perm -2000 -exec ls -lL {} \;'
$plinkcommand17 = 'grep PATH /etc/profile'
$plinkcommand18 = 'cat /var/run/inetd.conf'
$plinkcommand19 = 'grep libdir /etc/vmware/config'
$plinkcommand20 = 'cat /etc/shells'
$plinkcommand21 = 'find / \( -type b -o -type c \) -exec ls -lL {} \;'
$remoteCommand1 = '"' + $plinkcommand1 + '"'
$remoteCommand2 = '"' + $plinkcommand2 + '"'
$remoteCommand3 = '"' + $plinkcommand3 + '"'
$remoteCommand4 = '"' + $plinkcommand4 + '"'
$remoteCommand5 = '"' + $plinkcommand5 + '"'
$remoteCommand6 = '"' + $plinkcommand6 + '"'
$remoteCommand7 = '"' + $plinkcommand7 + '"'
$remoteCommand8 = '"' + $plinkcommand8 + '"'
$remoteCommand9 = '"' + $plinkcommand9 + '"'
$remoteCommand10 = '"' + $plinkcommand10 + '"'
$remoteCommand11 = '"' + $plinkcommand11 + '"'
$remoteCommand12 = '"' + $plinkcommand12 + '"'
$remoteCommand13 = '"' + $plinkcommand13 + '"'
$remoteCommand14 = '"' + $plinkcommand14 + '"'
$remoteCommand15 = '"' + $plinkcommand15 + '"'
$remoteCommand16 = '"' + $plinkcommand16 + '"'
$remoteCommand17 = '"' + $plinkcommand17 + '"'
$remoteCommand18 = '"' + $plinkcommand18 + '"'
$remoteCommand19 = '"' + $plinkcommand19 + '"'
$remoteCommand20 = '"' + $plinkcommand20 + '"'
$remoteCommand21 = '"' + $plinkcommand21 + '"'

$MyReport += Get-CustomHeader0 "ESXi Host STIG checks for vCenter server: $vcenter"	
	
#ESXCLI/SSH based checks
foreach($vmhost in $vmhosts){
		
	#Disable Lockdown Mode if enabled	
    If($vmhost.extensiondata.config.admindisabled -eq $true){
		Write-ToConsole "...Disabling Lockdown Mode on $vmhost"
		$hostview = Get-VMHost $vmhost | Get-View
        $hostview.ExitLockdownMode()
		$lockdownon = $true
        }
	else{$lockdownon = $false}
		
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
	
	$command4 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand4
    $resultsssh4 = Invoke-Expression -command $command4
	
	$command5 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand5
    $resultsssh5 = Invoke-Expression -command $command5
	
	$command6 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand6
    $resultsssh6 = Invoke-Expression -command $command6
	
	$command7 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand7
    $resultsssh7 = Invoke-Expression -command $command7
	
	$command8 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand8
    $resultsssh8 = Invoke-Expression -command $command8
	
	$command9 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand9
    $resultsssh9 = Invoke-Expression -command $command9
	
	$command10 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand10
    $resultsssh10 = Invoke-Expression -command $command10
	
	$command11 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand11
    $resultsssh11 = Invoke-Expression -command $command11
	
	$command12 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand12
    $resultsssh12 = Invoke-Expression -command $command12
	
	$command13 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand13
    $resultsssh13 = Invoke-Expression -command $command13
	
	$command14 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand14
    $resultsssh14 = Invoke-Expression -command $command14
	
	$command15 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand15
    $resultsssh15 = Invoke-Expression -command $command15
	
	$command16 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand16
    $resultsssh16 = Invoke-Expression -command $command16
	
	$command17 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand17
    $resultsssh17 = Invoke-Expression -command $command17
	
	$command18 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand18
    $resultsssh18 = Invoke-Expression -command $command18
	
	$command19 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand19
    $resultsssh19 = Invoke-Expression -command $command19
	
	$command20 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand20
    $resultsssh20 = Invoke-Expression -command $command20
	
	$command21 = $plink + " " + $vmhost.Name + " " + $plinkoptions + " " + $remotecommand21
    $resultsssh21 = Invoke-Expression -command $command21
		
	#Stop SSH service
    Write-ToConsole "...Stopping SSH on $vmhost"
    Stop-VMHostService -HostService $sshService -Confirm:$false | Out-Null

    #Re-Enable Lockdown Mode
	If($lockdownon){
        Write-ToConsole "...Enabling Lockdown Mode on $vmhost"
        $hostview.EnterLockdownMode()
	}
		
	#Check for persistent local log location SRG-OS-99999-ESXI5-000132
	$syslogloc = $esxcli.system.syslog.config.get()
	If($syslogloc.LocalLogOutputIsPersistent -eq $false){
		$syslogpersistfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Log Location" = $syslogloc.LocalLogOutput
            "LocalLogOutputIsPersistent" = $syslogloc.LocalLogOutputIsPersistent
			"Expected Value" = "True"
        })
	}
			
	#Check for kernel core dumps enabled GEN003510-ESXI5-006660
	$dumploc = $esxcli.system.coredump.partition.get()
	$dumpnet = $esxcli.system.coredump.network.get()
	If($dumpnet.Enabled -eq $false -and $dumploc.Active -eq ""){
		$dumpfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Active Partition" = $dumploc.Active
            "Network Dump Enabled" = $dumpnet.Enabled
			"Expected Value" = "Network Dumps Enabled or Active local partition configured on a partition > 100MB."
        })
	}
			
	#Check for acceptance level SRG-OS-000193-ESXI5
	$acceptlvl = $esxcli.software.acceptance.get()
	If($acceptlvl -eq "CommunitySupported"){
		$acceptlvlfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Acceptance Level" = $acceptlvl
			"Expected Value" = "VMware Accepted,VMware Certified,Partner Supported"
        })
	}
			
	#Check for vibs installed with community supported acceptance level SRG-OS-99999-ESXI5-000158
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
		
	#Check for GEN005300-ESXI5-000099, SRG-OS-99999-ESXI5-000144 for snmp enabled/misconfigured 
    $regex1 = [regex]'<enable>true</enable>'
    $regex2 = [regex]"public"
    $regex3 = [regex]"private"
    $regex4 = [regex]"password"

    foreach($result in $resultsssh4){
    	if($result -match $regex1){
            $row = "" | Select HostName, ExpectedValue, CurrentValue
            $row.HostName = $vmhost
            $row.ExpectedValue = "Not enabled if not in use"
            $row.CurrentValue = $result
            $snmpenfound += $row
        }
        if($result -match $regex2 -or $result -match $regex3 -or $result -match $regex4){
            $row = "" | Select HostName, ExpectedValue, CurrentValue
            $row.HostName = $vmhost
            $row.ExpectedValue = "public, private, password do not exist"
            $row.CurrentValue = $result
            $snmpenfound += $row
        }
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
	
	#Check SSH Client settings
	If($resultsssh8 -notmatch "No such file or directory"){
		foreach($sshcsetting in $sshcsettings){
			$separator = " "
			$splitsetting = $sshsetting.split($separator)
			$sshcsettingleft = $splitsetting[0]
			
       		$regex1 = [regex]"^$sshcsetting$"
       		$regex2 = [regex]"^$sshcsettingleft*"

       		foreach($result in $resultsssh8){
       			if($result -match $regex2 -and $result -notmatch $regex1){
           			$sshclientfound += New-Object PSObject -Property ([ordered]@{
               		"Host Name" = $vmhost.name
               		"SSH Setting" = $result
					"Expected Value" = $sshsetting
               		})			
        		}
        	}
        	$resultsssh8count = (($resultsssh8 -match $regex2).count)
        	if($resultsssh8count -eq 0){
           		$sshclientfound += New-Object PSObject -Property ([ordered]@{
            	"Host Name" = $vmhost.name
            	"SSH Setting" = "Setting $sshsetting not found in /etc/ssh/ssh_config!"
				"Expected Value" = $sshsetting
            	})
        	}
		}
	}
	
	#Check for banner file with the DoD banner SRG-OS-000023-ESXI5
	$resultsssh9count = (($resultsssh9).count)
    if($resultsssh9count -ne 0){
    	if($resultsssh9 -notmatch "You are accessing a U.S. Government"){
        	$bannerfound += New-Object PSObject -Property ([ordered]@{
        	"Host Name" = $vmhost.name
        	"/etc/issue contents" = $resultsssh9 | Out-String
			"Expected Value" = "You are accessing a U.S. Government (USG) Information System (IS) that is provided for USG-authorized use only. By using this IS (which includes any device attached to this IS), you consent to the following conditions: -The USG routinely intercepts and monitors communications on this IS for purposes including, but not limited to, penetration testing, COMSEC monitoring, network operations and defense, personnel misconduct (PM), law enforcement (LE), and counterintelligence (CI) investigations. -At any time, the USG may inspect and seize data stored on this IS. -Communications using, or data stored on, this IS are not private, are subject to routine monitoring, interception, and search, and may be disclosed or used for any USG-authorized purpose. -This IS includes security measures (e.g., authentication and access controls) to protect USG interests--not for your personal benefit or privacy. -Notwithstanding the above, using this IS does not constitute consent to PM, LE or CI investigative searching or monitoring of the content of privileged communications, or work product, related to personal representation or services by attorneys, psychotherapists, or clergy, and their assistants. Such communications and work product are private and confidential. See User Agreement for details."
        	})
    	}
	}
	if($resultsssh9count -eq 0){
        $bannerfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "/etc/issue contents" = "/etc/issue file empty!"
		"Expected Value" = "You are accessing a U.S. Government (USG) Information System (IS) that is provided for USG-authorized use only. By using this IS (which includes any device attached to this IS), you consent to the following conditions: -The USG routinely intercepts and monitors communications on this IS for purposes including, but not limited to, penetration testing, COMSEC monitoring, network operations and defense, personnel misconduct (PM), law enforcement (LE), and counterintelligence (CI) investigations. -At any time, the USG may inspect and seize data stored on this IS. -Communications using, or data stored on, this IS are not private, are subject to routine monitoring, interception, and search, and may be disclosed or used for any USG-authorized purpose. -This IS includes security measures (e.g., authentication and access controls) to protect USG interests--not for your personal benefit or privacy. -Notwithstanding the above, using this IS does not constitute consent to PM, LE or CI investigative searching or monitoring of the content of privileged communications, or work product, related to personal representation or services by attorneys, psychotherapists, or clergy, and their assistants. Such communications and work product are private and confidential. See User Agreement for details."
        })
    }
		
    #Check for ssh authorized_keys file not empty in /etc/ssh/keys-root/authorized_keys SRG-OS-99999-ESXI5-000152
    $resultsssh2count = (($resultsssh2).count)
    if($resultsssh2count -ne 0){
        $authkeysfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "Authorized Keys" = $resultsssh2 | Out-String
		"Expected Value" = "/etc/ssh/keys-root/authorized_keys should be empty!"
        })
    }
		
	#Check for password remember setting and password hash algorithm SRG-OS-000077-ESXI5, SRG-OS-000120-ESXI5
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
	
	#Check for password complexity settings SRG-OS-000069-ESXI, SRG-OS-000070-ESXI5, SRG-OS-000071-ESXI5, SRG-OS-000072-ESXI5, SRG-OS-000078-ESXI5, SRG-OS-000266-ESXI5, GEN000585-ESXI5-000080, GEN000790-ESXI5-000085
    if($resultsssh5 -notmatch "pam_passwdqc.so similar=deny retry=3 min=disabled,disabled,disabled,disabled,14"){
        $pwcomplexfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "Password Complexity Setting" = $resultsssh5 | Out-String
		"Expected Value" = "password   requisite    /lib/security/$ISA/pam_passwdqc.so similar=deny retry=3 min=disabled,disabled,disabled,disabled,14"
        })
    }
	
	#Check for managed object browser running SRG-OS-99999-ESXI5-000137, SRG-OS-99999-ESXI5-000156
    $resultsssh6count = (($resultsssh6).count)
    if($resultsssh6count -ne 0){
        $mobfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "MOB Result" = $resultsssh6 | Out-String
		"Expected Value" = "MOB is not running on hosts"
        })
    }
	
	#Check for root libraries preloaded in /etc/vmware/config GEN000950-ESXI5-444
    $resultsssh7count = (($resultsssh7).count)
    if($resultsssh7count -ne 0){
        $ldpreloadfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "LD_PRELOAD Result" = $resultsssh7 | Out-String
		"Expected Value" = "LD_PRELOAD does not exist in /etc/vmware/config"
        })
    }
	
	#Check for unique user IDs in /etc/passwd SRG-OS-000104-ESXI5
	$useridsfound += New-Object PSObject -Property ([ordered]@{
	"Host Name" = $vmhost.name
	"Host UIDs" = $resultsssh10 | Sort | Out-String
	"Expected Value" = "Verify no duplicate UIDs on host"
    })
	
	#Check for unique user names in /etc/passwd SRG-OS-000121-ESXI5
	$usersfound += New-Object PSObject -Property ([ordered]@{
	"Host Name" = $vmhost.name
	"Host UIDs" = $resultsssh11 | Sort | Out-String
	"Expected Value" = "Verify no duplicate user names on host"
    })
	
	#Check for hosts.equiv files on host SRG-OS-000248-ESXI5
    $resultsssh12count = (($resultsssh12).count)
    if($resultsssh12count -ne 0){
        $hostseqfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "hosts.equiv Results" = $resultsssh12 | Out-String
		"Expected Value" = "hosts.equiv file does not exist on host!"
        })
    }
	
	#Check for .rhosts files on host SRG-OS-000248-ESXI5
    $resultsssh13count = (($resultsssh13).count)
    if($resultsssh13count -ne 0){
        $rhostsfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "rhosts Results" = $resultsssh13 | Out-String
		"Expected Value" = ".rhosts files do not exist on host!"
        })
    }
	
	#Check for unauthorized setuid files GEN002400-ESXI5-10047
	ForEach($result in $resultsssh14){
		$setuidfound += New-Object PSObject -Property ([ordered]@{
		"Host Name" = $vmhost.name
		"Files with setuid bit" = $result
		"Expected Value" = "Verify no unauthorized setuid files exist and no unauthorized modifications"
    	})
	}
	
	#Check for unauthorized setuid files GEN002460-ESXI5-20047
	ForEach($result in $resultsssh16){
		$setgidfound += New-Object PSObject -Property ([ordered]@{
		"Host Name" = $vmhost.name
		"Files with setgid bit" = $result
		"Expected Value" = "Verify no unauthorized setgid files exist and no unauthorized modifications"
    	})
	}
	
	#Check for fstab entries mounted correctly GEN002420-ESXI5-00878, GEN005900-ESXI5-00891, GEN002430-ESXI5
	ForEach($result in $resultsssh15){
		$fstabfound += New-Object PSObject -Property ([ordered]@{
		"Host Name" = $vmhost.name
		"/etc/fstab entries" = $result
		"Expected Value" = "If the nosuid mount OPTION is not used on file systems mounted from removable media, network shares, or any other file system that does not contain approved setuid or setgid files OR if the mounted NFS file systems do not use the nodev option, this is a finding."
    	})
	}
	
	#Check for root path GEN000940-ESXI5-000042
    $regex1 = [regex]"PATH=/bin:/sbin"
    $regex2 = [regex]"PATH=/bin"
    $regex3 = [regex]"^export PATH$"

    ForEach($result in $resultsssh17){
    	if($result -notmatch $regex1 -and $result -notmatch $regex2 -and $result -notmatch $regex3){
            $profpathfound += New-Object PSObject -Property ([ordered]@{
                "Host Name" = $vmhost.name
                "Profile Path Found" = $result
				"Expected Value" = "Profile path found that is not /bin or /sbin"
            })
        }
	}
	
	#Check for unauthorized services running through inetd SRG-OS-000095-ESXI5
    $regex1 = [regex]"^#"
    $regex2 = [regex]"^$"
    $regex3 = [regex]"^ssh"
	$regex4 = [regex]"^sshd"
	$regex5 = [regex]"^authd"

    ForEach($result in $resultsssh18){
    	if($result -notmatch $regex1 -and $result -notmatch $regex2 -and $result -notmatch $regex3 -and $result -notmatch $regex4 -and $result -notmatch $regex5){
            $initdfound += New-Object PSObject -Property ([ordered]@{
                "Host Name" = $vmhost.name
                "Non-default entry found in /var/run/inetd.conf" = $result
				"Expected Value" = "No unauthorized services running out of inetd"
            })
        }
	}
	
	#Check for root library search path path GEN000945-ESXI5-000333
    $regex1 = [regex]"libdir = ""/usr/lib/vmware"""

    ForEach($result in $resultsssh19){
    	if($result -notmatch $regex1){
            $libsearchfound += New-Object PSObject -Property ([ordered]@{
                "Host Name" = $vmhost.name
                "Library Search Path Found" = $result
				"Expected Value" = "Library search path is set to /usr/lib/vmware"
            })
        }
	}
	
	#Check for /etc/shells on host GEN002120-ESXI5-000045
    $resultsssh20count = (($resultsssh20).count)
    if($resultsssh20count -eq 0){
        $noshellsfound += New-Object PSObject -Property ([ordered]@{
        "Host Name" = $vmhost.name
        "Current Value" = "/etc/shells does not exist"
		"Expected Value" = "/etc/shells exists on host"
        })
    }
	
	#Check for approved shells in /etc/shells GEN002140-ESXI5-000046
    $regex1 = [regex]"^/bin/ash$"
    $regex2 = [regex]"^/bin/sh$"

    ForEach($result in $resultsssh20){
    	if($result -notmatch $regex1 -and $result -notmatch $regex2){
            $badshellsfound += New-Object PSObject -Property ([ordered]@{
                "Host Name" = $vmhost.name
                "Non-default entry found in /etc/shells" = $result
				"Expected Value" = "/bin/ash and /bin/sh are the default shells in /etc/shells"
            })
        }
	}
	
	#Check for extraneous device files GEN002260-ESXI5-000047
	ForEach($result in $resultsssh21){
		$extdevfilesfound += New-Object PSObject -Property ([ordered]@{
		"Host Name" = $vmhost.name
		"Extraneous Device Files" = $result
		"Expected Value" = "If an unauthorized device is allowed to exist on the system, there is the possibility the system may perform unauthorized operations.  Verify files are authorized on a weekly basis."
    	})
	}
}
	
#Check vSwitch Security Settings ESXI5-VMNET-000013, ESXI5-VMNET-000016, ESXI5-VMNET-000018
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
	
#Check for IPv6 Enabled GEN005570-ESXI5-000115, GEN007700-ESXI5-000116, GEN007740-ESXI5-000118
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

#Check for 2 DNS servers configured on host GEN001375-ESXI5-000086
Write-ToConsole "...Checking ESXi Hosts for multiple DNS servers configured on $vcenter"    
foreach($vmhost in $vmhostsv | sort Name){
	$hostdns = $vmhost.config.network.dnsconfig.address        
    $hostdnscount = (($hostdns).count)
    If($hostdnscount -lt 2){
        $hostdnsfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "DNS Servers Configured" = $hostdns | Out-String
			"Expected Value" = "Multiple DNS servers configured on host."
        })
    }
}

#Check for DHCP enabled on hosts GEN007840-ESXI5-000119
Write-ToConsole "...Checking ESXi Hosts for DHCP Enabled on $vcenter"    
foreach($vmhost in $vmhostsv | sort Name){
    If($vmhost.config.network.dhcp -ne $null){
        $dhcpfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "DHCP Enabled" = $vmhost.config.network.Dhcp
			"Expected Value" = "DHCP disabled if not in use."
        })
    }
}	
	
#Check for updated ESXi build GEN000100-ESXI5-000062
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
	
#Check for host joined to AD SRG-OS-99999-ESXI5-000154
Write-ToConsole "...Checking ESXi Hosts joined to Active Directory $vcenter"
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
	
#Check for lockdown mode enabled SRG-OS-000092-ESXI5
Write-ToConsole "...Checking ESXi Hosts for lockdown mode enabled on $vcenter"
foreach($vmhost in $vmhostsv | sort Name){
    If($vmhost.config.admindisabled -ne $true){
        $lockdownfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Lockdown Mode" = $vmhost.config.admindisabled
			"Expected Value" = "Lockdown mode enabled"
        })
    }
}
	
#Check for iSCSI CHAP not enabled SRG-OS-99999-ESXI5-000141, SRG-OS-99999-ESXI5-000147
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

#Check for correct NTP servers SRG-OS-000056-ESXI5, GEN000240-ESXI5-000058, SRG-OS-99999-ESXI5-000131
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
	
#Check for firewall rules set to allow all IPs SRG-OS-000144-ESXI5, SRG-OS-000147-ESXI5, SRG-OS-000152-ESXI5, SRG-OS-000231-ESXI5
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

#Check for default gateway not null on hosts SRG-OS-000145-ESXI5
Write-ToConsole "...Checking ESXi Hosts for default gateway set on $vcenter"
foreach($vmhost in $vmhostsv | sort Name){
    If($vmhost.config.network.IpRouteConfig.DefaultGateway -eq ""){
        $nogatewayfound += New-Object PSObject -Property ([ordered]@{
            "Host Name" = $vmhost.name
            "Current Default Gateway" = $vmhost.config.network.IpRouteConfig.DefaultGateway
			"Expected Value" = "A default gateway should be set!"
        })
    }
}

}
    	
#Insert Data into report format
	
$MyReport += Get-CustomHeader "SRG-OS-99999-ESXI5-000132 Hosts with non-persistent local log locations : $(@($syslogpersistfound).count)"
$MyReport += Get-HTMLTable $syslogpersistfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "GEN003510-ESXI5-006660 Hosts with core dumps not enabled : $(@($dumpfound).count)"
$MyReport += Get-HTMLTable $dumpfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "SRG-OS-000193-ESXI5 Hosts with acceptance level not correctly set : $(@($acceptlvlfound).count)"
$MyReport += Get-HTMLTable $acceptlvlfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "SRG-OS-99999-ESXI5-000158 Hosts with vibs installed at the community supported acceptance level : $(@($acceptlvlinstallfound).count)"
$MyReport += Get-HTMLTable $acceptlvlinstallfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "GEN005300-ESXI5-000099, SRG-OS-99999-ESXI5-000144 Hosts with SNMP enabled and/or misconfigured : $(@($snmpenfound).count)"
$MyReport += Get-HTMLTable $snmpenfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "Hosts with incorrect SSH daemon settings in /etc/ssh/sshd_config : $(@($sshdaemonfound).count)"
$MyReport += Get-HTMLTable $sshdaemonfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "Hosts with incorrect SSH client settings in /etc/ssh/ssh_config : $(@($sshclientfound).count)"
$MyReport += Get-HTMLTable $sshclientfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "SRG-OS-000023-ESXI5 Hosts with incorrect login banner in /etc/issue : $(@($bannerfound).count)"
$MyReport += Get-HTMLTable $bannerfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "SRG-OS-99999-ESXI5-000152 Hosts with authorized_keys file not empty in /etc/ssh/keys-root/authorized_keys : $(@($authkeysfound).count)"
$MyReport += Get-HTMLTable $authkeysfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "SRG-OS-000077-ESXI5 Hosts with password remember setting not set in /etc/pam.d/passwd : $(@($rememberfound).count)"
$MyReport += Get-HTMLTable $rememberfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "SRG-OS-000120-ESXI5 Hosts with password hash setting not set in /etc/pam.d/passwd : $(@($passhashfound).count)"
$MyReport += Get-HTMLTable $passhashfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "Hosts with password complexity settings not set correctly in /etc/pam.d/passwd : $(@($pwcomplexfound).count)"
$MyReport += Get-HTMLTable $pwcomplexfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "SRG-OS-99999-ESXI5-000137, SRG-OS-99999-ESXI5-000156 Hosts with the managed object browser running: $(@($mobfound).count)"
$MyReport += Get-HTMLTable $mobfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "SRG-OS-000145-ESXI5 Hosts with no default gateway set : $(@($nogatewayfound).count)"
$MyReport += Get-HTMLTable $nogatewayfound
$MyReport += Get-CustomHeaderClose
		
$MyReport += Get-CustomHeader "ESXI5-VMNET-000013, ESXI5-VMNET-000016, ESXI5-VMNET-000018 Hosts with virtual standard switches with security policies not configured correctly : $(@($vsssecfound).count)"
$MyReport += Get-HTMLTable $vsssecfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "ESXI5-VMNET-000013, ESXI5-VMNET-000016, ESXI5-VMNET-000018 Hosts with virtual standard port groups with security policies not configured correctly : $(@($vsspgsecfound).count)"
$MyReport += Get-HTMLTable $vsspgsecfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "ESXI5-VMNET-000010, ESXI5-VMNET-000011, ESXI5-VMNET-000012 Hosts with virtual standard port groups with Native,Reserved, or VGT VLAN IDs configured : $(@($vsspgvlanfound).count)"
$MyReport += Get-HTMLTable $vsspgvlanfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "GEN005570-ESXI5-000115, GEN007700-ESXI5-000116, GEN007740-ESXI5-000118 Hosts with IPv6 enabled : $(@($ipv6found).count)"
$MyReport += Get-HTMLTable $ipv6found
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "SRG-OS-99999-ESXI5-000154 Hosts not joined to Active Directory : $(@($noADfound).count)"
$MyReport += Get-HTMLTable $noADfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN001375-ESXI5-000086 Hosts without multiple DNS servers configured : $(@($hostdnsfound).count)"
$MyReport += Get-HTMLTable $hostdnsfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN007840-ESXI5-000119 Hosts with DHCP enabled : $(@($dhcpfound).count)"
$MyReport += Get-HTMLTable $dhcpfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "GEN000100-ESXI5-000062 Hosts with outdated patch level : $(@($oldbuildfound).count)"
$MyReport += Get-HTMLTable $oldbuildfound
$MyReport += Get-CustomHeaderClose
		
$MyReport += Get-CustomHeader "SRG-OS-000092-ESXI5 Hosts with Lockdown mode not enabled : $(@($lockdownfound).count)"
$MyReport += Get-HTMLTable $lockdownfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "SRG-OS-99999-ESXI5-000141, SRG-OS-99999-ESXI5-000147 Hosts with iSCSI adapters and mutual CHAP not required : $(@($chapconffound).count)"
$MyReport += Get-HTMLTable $chapconffound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "SRG-OS-000056-ESXI5, GEN000240-ESXI5-000058, SRG-OS-99999-ESXI5-000131 Hosts with incorrect NTP servers set : $(@($ntpfound).count)"
$MyReport += Get-HTMLTable $ntpfound
$MyReport += Get-CustomHeaderClose
	
$MyReport += Get-CustomHeader "SRG-OS-000144-ESXI5, SRG-OS-000147-ESXI5, SRG-OS-000152-ESXI5, SRG-OS-000231-ESXI5 Hosts with firewall rules set to allow all IPs for a service : $(@($fwrulesfound).count)"
$MyReport += Get-HTMLTable $fwrulesfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN000950-ESXI5-444 Hosts with root libraries preloaded in /etc/vmware/config: $(@($ldpreloadfound).count)"
$MyReport += Get-HTMLTable $ldpreloadfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "SRG-OS-000104-ESXI5 Verify no duplicate User IDs exist on each host : $(@($useridsfound).count)"
$MyReport += Get-HTMLTable $useridsfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "SRG-OS-000121-ESXI5 Verify no duplicate User names exist on each host : $(@($usersfound).count)"
$MyReport += Get-HTMLTable $usersfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "SRG-OS-000248-ESXI5 Verify no hosts.equiv files exist on host : $(@($hostseqfound).count)"
$MyReport += Get-HTMLTable $hostseqfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "SRG-OS-000248-ESXI5 Verify no .rhosts files exist on host : $(@($rhostsfound).count)"
$MyReport += Get-HTMLTable $rhostsfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN002400-ESXI5-10047 Verify no unauthorized files exist with setuid bit set exist on host : $(@($setuidfound).count)"
$MyReport += Get-HTMLTable $setuidfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN002460-ESXI5-20047 Verify no unauthorized files exist with setgid bit set exist on host : $(@($setgidfound).count)"
$MyReport += Get-HTMLTable $setgidfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN002420-ESXI5-00878, GEN005900-ESXI5-00891, GEN002430-ESXI5 Host FSTAB entries found on 5.0 hosts : $(@($fstabfound).count)"
$MyReport += Get-HTMLTable $fstabfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN000940-ESXI5-000042 Hosts with non default profile paths : $(@($profpathfound).count)"
$MyReport += Get-HTMLTable $profpathfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "SRG-OS-000095-ESXI5 Hosts with non default services running out of inetd : $(@($initdfound).count)"
$MyReport += Get-HTMLTable $initdfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN000945-ESXI5-000333 Hosts with non default library search path found : $(@($libsearchfound).count)"
$MyReport += Get-HTMLTable $libsearchfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN002120-ESXI5-000045 Hosts with no /etc/shells found : $(@($noshellsfound).count)"
$MyReport += Get-HTMLTable $noshellsfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN002140-ESXI5-000046 Hosts with non default shells in /etc/shells found : $(@($badshellsfound).count)"
$MyReport += Get-HTMLTable $badshellsfound
$MyReport += Get-CustomHeaderClose

$MyReport += Get-CustomHeader "GEN002260-ESXI5-000047 Verify extraneous devices files found on host : $(@($extdevfilesfound).count)"
$MyReport += Get-HTMLTable $extdevfilesfound
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