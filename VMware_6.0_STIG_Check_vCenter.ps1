<#
.SYNOPSIS
	vSphere 6.0 STIG Windows vCenter Compliance Check HTML Report Script
	Created by: Ryan Lakey, rlakey@vmware.com
	Updated for STIG: vSphere 6 Windows vCenter - Version 1, Release 1
	Provided as is and is not supported by VMware
.DESCRIPTION
	This script will check compliance of a Windows vCenter server for items that can be scripted.
	
	!!Please read and know what this script it doing before running!!
	
	Requirements to run script
	-PowerCLI 6.0+ and Powershell 3+
	-Powershell allowed to run unsigned/remote scripts
	-Update report folder location variable
.PARAMETER vcenter
   vCenter server to run script against and check vCenter for compliance.
.PARAMETER cred
   This will prompt user for credentials that will be used to connect to vCenter specified.
.EXAMPLE
   ./VMware_6.0_STIG_Check_vCenter.ps1 -vcenter vcenter.test.lab
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$vcenter,
	[Parameter(Mandatory=$True,Position=2)]
	[Management.Automation.PSCredential]$cred
)

## Script Configuration Variables
## Capture Date variable
$Date = Get-Date
## Path to store the generated report
$ReportFolder = "C:\PowerCLI\Output"
$ReportName = $ReportFolder + "\VMware_vCenter_STIG_Compliance_Report" + "_" + $Date.Month + "-" + $Date.Day + "-" + $Date.Year + "_" + $Date.Hour + "-" + $Date.Minute + "-" + $Date.Second + ".html"
## Start Transcript
$TranscriptName = $ReportFolder + "\VMware_vCenter_STIG_Compliance_Report_Transcript" + "_" + $Date.Month + "-" + $Date.Day + "-" + $Date.Year + "_" + $Date.Hour + "-" + $Date.Minute + "-" + $Date.Second + ".txt"
Start-Transcript -Path $TranscriptName
## Display report after completion
$DisplayToScreen = $true
## Report Colors
$bgcolor = "494a4d"
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

## vCenter Advanced Settings to Check
$VCAdvSettings = @{"config.nfc.useSSL" = $true; ## VCW-06-000021
	"VirtualCenter.VimPasswordExpirationInDays" = "30"; ## VCW-06-000023
	"config.vpxd.hostPasswordLength" = "32"; ## VCW-06-000024
	"config.log.level" = "info"; ## VCW-06-000036
	}
	
## vCenter Service account name that vCenter services should be running as
$vcserviceaccount = "LAB\vcwinservice"

Function Write-ToConsole ($Details){
	$LogDate = Get-Date -Format T
	Write-Host "$($LogDate) $Details"
}

Function Get-vCenterPlugin {
[CmdletBinding()]
param(
[Parameter(Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
[System.String]
$Name
)

begin {
$ExtensionManager = Get-View ExtensionManager
}
 
process {
 
if ($Name){
$ExtensionManager.ExtensionList | Select-Object @{Name='Description';Expression={$_.Description.Label}},Key,Company,Version | Where-Object {$_.Description -eq $Name}
}
 
else {
$ExtensionManager.ExtensionList | Select-Object @{Name='Description';Expression={$_.Description.Label}},Key,Company,Version | Sort-Object Description
}
}
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

## Check for PowerCLI modules loaded and if not load them
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
$MyReport = Get-CustomHTML "VMware vSphere 6.0 Windows vCenter STIG Compliance Report"

## Connect to vCenter Server
Try{
	Write-ToConsole "...Connecting to vCenter Server $vcenter"
	Connect-VIServer -Server $vcenter -ErrorAction Stop -Credential $cred | Out-Null
}
Catch{
	Write-ToConsole "...Could not connect to $vcenter with supplied credentials...exiting script"
	Exit
}

## Gather information about target vCenter
Write-ToConsole "...Gathering vCenter information for $vcenter"
## Collect vCenter permissions
$vcperms = Get-VIPermission | Sort Role | Select @{N="vCenter Name";E={$vcenter}},Role,Principal,Entity,Propagate,IsGroup
## Collect vCenter webclient.properties file contents
$webpropsfile = Get-Content -Path "\\$vcenter\C$\ProgramData\VMware\vCenterServer\cfg\vsphere-client\webclient.properties"
## Collect vCenter vpxd.cfg file contents
$vpxdcfg = Get-Content -Path "\\$vcenter\C$\ProgramData\VMware\vCenterServer\cfg\vmware-vpx\vpxd.cfg"
## Collect Distribued vSwitch information
$dvswitches = Get-VDSwitch | Sort Name
$dvpgs = Get-VDPortGroup | Sort Name
$dvpgsv = Get-View -ViewType DistributedVirtualPortgroup | Sort Name
## Collect vCenter alarm definitions
$alarms = Get-AlarmDefinition
## Collect vCenter Advanced Settings
$vcsettings = Get-AdvancedSetting -Entity $vcenter
## Collect vCenter service info
$vcservices = Get-WmiObject win32_service -ComputerName $vcenter | Where {$_.Name -eq "vpxd" -or $_.Name -eq "vmware-perfcharts" -or $_.Name -eq "invsvc" -or $_.Name -eq "vdcs"}
## Collect vCenter Plugins
$vcplugins = Get-vCenterPlugin

$MyReport += Get-CustomHeader0 "vCenter STIG checks for vCenter server: $vcenter"

## Add vCenter permissions to report
$MyReport += Get-CustomHeader "VCW-06-000005 vCenter Server permissions verification: $(@($vcperms).count)"
$MyReport += Get-HTMLTable $vcperms
$MyReport += Get-CustomHeaderClose		
		
## Check for web client timeout value set
$webclienttimeout = @()
Write-ToConsole "...Checking for web client timeout not set correctly on $vcenter"
## Regular Expressions for this check
$regex1 = [regex]"^session.timeout = 10"
$regex2 = [regex]"^session.timeout*"

ForEach($result in $webpropsfile){
	If($result -match $regex2 -and $result -notmatch $regex1){
		$webclienttimeout += New-Object PSObject -Property ([ordered]@{
			"vCenter Server" = $vcenter
			"Current Value" = $result
			"Expected Value" = "session.timeout = 10"
        })
	}
	$webclientcount = (($webpropsfile -like "*session.timeout*").count)
	If($webclientcount -eq 0){
		$webclienttimeout += New-Object PSObject -Property ([ordered]@{
			"vCenter Server" = $vcenter
			"Current Value" = "session.timeout = 10 is not present in webclient.properties file"
			"Expected Value" = "session.timeout = 10"
        })
	}
}
$MyReport += Get-CustomHeader "VCW-06-000004 vCenter Server with web client timeout not set: $(@($webclienttimeout).count)"
$MyReport += Get-HTMLTable $webclienttimeout
$MyReport += Get-CustomHeaderClose

## Check for distrbuted vswitches without NIOC enabled
$niocdisabled = @()
Write-ToConsole "...Checking for dVSwitches without Network I/O Control enabled on $vcenter"
ForEach($dvswitch in $dvswitches){
	If($dvswitch.ExtensionData.config.NetworkResourceManagementEnabled -eq $false){
		$niocdisabled += New-Object PSObject -Property ([ordered]@{
			"vCenter Server" = $vcenter
			"vDSwitch Name" = $dvswitch.Name
			"Network I/O Control Enabled" = $dvswitch.ExtensionData.config.NetworkResourceManagementEnabled
			"Expected Value" = "Network I/O Control is enabled"
        })
	}
}
$MyReport += Get-CustomHeader "VCW-06-000007 vCenter Server dVSwitch with Network I/O Control disabled: $(@($niocdisabled).count)"
$MyReport += Get-HTMLTable $niocdisabled
$MyReport += Get-CustomHeaderClose

## Check for syslog failure alarm
$syslogalarm = @()
Write-ToConsole "...Checking for alarm to detect syslog failures on ESXi hosts on $vcenter"
$syslogalarmcount = (($alarms | Where {$_.ExtensionData.Info.Expression.Expression.EventTypeId -eq "esx.problem.vmsyslogd.remote.failure"}).count)
If($syslogalarmcount -eq 0){
	$syslogalarm += New-Object PSObject -Property ([ordered]@{
		"vCenter Server" = $vcenter
		"Current Value" = "No alarms exist to detect syslog failures on hosts"
		"Expected Value" = "An alarm is created to detect syslog failures on hosts"
    })
}
$MyReport += Get-CustomHeader "VCW-06-000008 vCenter Server with no syslog failure alarm created: $(@($syslogalarm).count)"
$MyReport += Get-HTMLTable $syslogalarm
$MyReport += Get-CustomHeaderClose

## Check for permission event alarm
$permissionalarm = @()
Write-ToConsole "...Checking for alarm to detect permission change events on $vcenter"
$permissionalarmcount = (($alarms | Where {$_.ExtensionData.Info.Expression.Expression.EventTypeId -eq "vim.event.PermissionAddedEvent" -or $_.ExtensionData.Info.Expression.Expression.EventTypeId -eq "vim.event.PermissionRemovedEvent" -or $_.ExtensionData.Info.Expression.Expression.EventTypeId -eq "vim.event.PermissionUpdatedEvent"}).count)
If($permissionalarmcount -eq 0){
	$permissionalarm += New-Object PSObject -Property ([ordered]@{
		"vCenter Server" = $vcenter
		"Current Value" = "No alarms exist to detect permission changes"
		"Expected Value" = "An alarm is created to detect permission changes on vCenter"
    })
}
$MyReport += Get-CustomHeader "VCW-06-000011 vCenter Server with no permission change alarm created: $(@($permissionalarm).count)"
$MyReport += Get-HTMLTable $permissionalarm
$MyReport += Get-CustomHeaderClose

## Check for distrbuted vswitches with health check enabled
$vdshcenabled = @()
Write-ToConsole "...Checking for dVSwitches with health check enabled on $vcenter"
ForEach($dvswitch in $dvswitches){
	If($dvswitch.ExtensionData.Config.HealthCheckConfig.Enable -eq $true){
		$vdshcenabled += New-Object PSObject -Property ([ordered]@{
			"vCenter Server" = $vcenter
			"vDSwitch Name" = $dvswitch.Name
			"Health Check Enabled" = &{If($dvswitch.ExtensionData.Config.HealthCheckConfig.Enable){([String]::Join(',',$dvswitch.ExtensionData.Config.HealthCheckConfig.Enable))}else{"Health check setting not found."}}
			"Expected Value" = "Health Check is disabled"
        })
	}
}
$MyReport += Get-CustomHeader "VCW-06-000012 vCenter Server dVSwitch with health check enabled: $(@($vdshcenabled).count)"
$MyReport += Get-HTMLTable $vdshcenabled
$MyReport += Get-CustomHeaderClose

## Check for distrbuted port groups with security settings not set to false
$dvpgpromsecurity = @()
$dvpgforgesecurity = @()
$dvpgmacsecurity = @()
Write-ToConsole "...Checking for distributed port groups with security settings not set to false/reject on $vcenter"
ForEach($dvpg in $dvpgsv){
	If($dvpg.config.defaultportconfig.securitypolicy.allowpromiscuous.value -ne $false){
		$dvpgpromsecurity += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy Name" = "AllowPromiscuous"
			"Policy Value" = $dvpg.config.defaultportconfig.securitypolicy.allowpromiscuous.value
			"Expected Value" = "False or Reject"
		})
	}
	If($dvpg.config.defaultportconfig.securitypolicy.forgedtransmits.value -ne $false){
		$dvpgforgesecurity += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy Name" = "ForgedTransmits"
			"Policy Value" = $dvpg.config.defaultportconfig.securitypolicy.forgedtransmits.value
			"Expected Value" = "False or Reject"
		})
	}
	If($dvpg.config.defaultportconfig.securitypolicy.macchanges.value -ne $false){
		$dvpgmacsecurity += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy Name" = "MacChanges"
			"Policy Value" = $dvpg.config.defaultportconfig.securitypolicy.macchanges.value
			"Expected Value" = "False or Reject"
		})
	}
}
$MyReport += Get-CustomHeader "VCW-06-000013 vCenter Server distributed port group with forged transmits enabled: $(@($dvpgforgesecurity).count)"
$MyReport += Get-HTMLTable $dvpgforgesecurity
$MyReport += Get-CustomHeaderClose
$MyReport += Get-CustomHeader "VCW-06-000014 vCenter Server distributed port group with MAC address changes enabled: $(@($dvpgmacsecurity).count)"
$MyReport += Get-HTMLTable $dvpgmacsecurity
$MyReport += Get-CustomHeaderClose
$MyReport += Get-CustomHeader "VCW-06-000015 vCenter Server distributed port group with Allow Promiscuous enabled: $(@($dvpgpromsecurity).count)"
$MyReport += Get-HTMLTable $dvpgpromsecurity
$MyReport += Get-CustomHeaderClose

## Check for distrbuted switches with NetFlow enabled to verify settings
$dvswnetflow = @()
Write-ToConsole "...Checking for distributed virtual switches with NetFlow enabled on $vcenter"
ForEach($dvswitch in $dvswitches){
	If($dvswitch.ExtensionData.Config.ipfixConfig.CollectorIpAddress -ne $null){
		$dvswnetflow += New-Object PSObject -Property ([ordered]@{
			"Distributed Switch" = $dvswitch.Name
			"Collector IP Address" = $dvswitch.ExtensionData.Config.ipfixConfig.CollectorIpAddress
			"Expected Value" = "Verify Collector IP is valid and in use for troubleshooting"
		})
	}
}
$MyReport += Get-CustomHeader "VCW-06-000016 vCenter Server distributed switch with NetFlow enabled: $(@($dvswnetflow).count)"
$MyReport += Get-HTMLTable $dvswnetflow
$MyReport += Get-CustomHeaderClose

## Check for distrbuted port groups with NetFlow enabled to verify settings
$dvpgnetflow = @()
Write-ToConsole "...Checking for distributed port groups with NetFlow enabled on $vcenter"
ForEach($dvpg in $dvpgsv){
	If($dvpg.Config.defaultPortConfig.ipfixEnabled.Value -eq $true){
		$dvpgnetflow += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"NetFlow Enabled" = $dvpg.Config.defaultPortConfig.ipfixEnabled.Value
			"Expected Value" = "False or verify settings are valid"
		})
	}
}
$MyReport += Get-CustomHeader "VCW-06-000016 vCenter Server distributed port group with NetFlow enabled: $(@($dvpgnetflow).count)"
$MyReport += Get-HTMLTable $dvpgnetflow
$MyReport += Get-CustomHeaderClose

## Check for distrbuted port groups with port level settings overridden
$dvpgoverride = @()
Write-ToConsole "...Checking for distributed port groups with port level settings overridden on $vcenter"
ForEach($dvpg in $dvpgsv){
	If($dvpg.Config.Policy.VlanOverrideAllowed -eq $true){
		$dvpgoverride += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy" = "VLAN Override Allowed"
			"Current Value" = $dvpg.Config.Policy.VlanOverrideAllowed
			"Expected Value" = "False"
		})
	}
	If($dvpg.Config.Policy.UplinkTeamingOverrideAllowed -eq $true){
		$dvpgoverride += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy" = "Uplink Teaming Override Allowed"
			"Current Value" = $dvpg.Config.Policy.UplinkTeamingOverrideAllowed
			"Expected Value" = "False"
		})
	}
	If($dvpg.Config.Policy.SecurityPolicyOverrideAllowed -eq $true){
		$dvpgoverride += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy" = "Security Policy Override Allowed"
			"Current Value" = $dvpg.Config.Policy.SecurityPolicyOverrideAllowed
			"Expected Value" = "False"
		})
	}
	If($dvpg.Config.Policy.IpfixOverrideAllowed -eq $true){
		$dvpgoverride += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy" = "NetFlow Override Allowed"
			"Current Value" = $dvpg.Config.Policy.IpfixOverrideAllowed
			"Expected Value" = "False"
		})
	}
	If($dvpg.Config.Policy.BlockOverrideAllowed -eq $true){
		$dvpgoverride += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy" = "Block Override Allowed"
			"Current Value" = $dvpg.Config.Policy.BlockOverrideAllowed
			"Expected Value" = "False"
		})
	}
	If($dvpg.Config.Policy.ShapingOverrideAllowed -eq $true){
		$dvpgoverride += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy" = "Traffic Shaping Override Allowed"
			"Current Value" = $dvpg.Config.Policy.ShapingOverrideAllowed
			"Expected Value" = "False"
		})
	}
	If($dvpg.Config.Policy.VendorConfigOverrideAllowed -eq $true){
		$dvpgoverride += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy" = "Vendor Configuration Override Allowed"
			"Current Value" = $dvpg.Config.Policy.VendorConfigOverrideAllowed
			"Expected Value" = "False"
		})
	}
	If($dvpg.Config.Policy.TrafficFilterOverrideAllowed -eq $true){
		$dvpgoverride += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"Policy" = "Traffic Filter Override Allowed"
			"Current Value" = $dvpg.Config.Policy.TrafficFilterOverrideAllowed
			"Expected Value" = "False"
		})
	}
}
$MyReport += Get-CustomHeader "VCW-06-000017 vCenter Server distributed port group with port level overrides enabled: $(@($dvpgoverride).count)"
$MyReport += Get-HTMLTable $dvpgoverride
$MyReport += Get-CustomHeaderClose

## Check for distrbuted port groups with reserved vlans
$dvpgvlans = @()
Write-ToConsole "...Checking for distributed port groups with native or reserved VLANs configured on $vcenter"
ForEach($dvpg in $dvpgsv){
	If($dvpg.config.DefaultPortConfig.vlan.vlanid -eq "1" -or $dvpg.config.DefaultPortConfig.vlan.vlanid -In 4094..4095 -or $dvpg.config.DefaultPortConfig.vlan.vlanid -In 1001..1024 -or $dvpg.config.DefaultPortConfig.vlan.vlanid -In 3968..4047){
		$dvpgvlans += New-Object PSObject -Property ([ordered]@{
			"Port Group" = $dvpg.Name
			"VLAN ID" = $dvpg.config.DefaultPortConfig.vlan.vlanid
			"Expected Value" = "Native,Reserved, and VGT VLAN IDs should not be used"
		})
	}
}
$MyReport += Get-CustomHeader "VCW-06-000018,19,20 vCenter Server distributed port group with Native, Reserved, or VGT VLAN IDs in use: $(@($dvpgvlans).count)"
$MyReport += Get-HTMLTable $dvpgvlans
$MyReport += Get-CustomHeaderClose

## Check for correct vCenter advanced settings
foreach($setting in ($VCAdvSettings.GetEnumerator() | Sort Name)){
	$name = $setting.name
	$value = $setting.value
    Write-ToConsole "...Checking for setting $name configured correctly on $vcenter"
    $vcsettingfound = @()
	If($vcsettings.name -contains "$name"){
		$currentvalue = $vcsettings | where {$_.name -eq "$name"} | Select Value
		If($currentvalue.value -ne $value){
            $vcsettingfound += New-Object PSObject -Property ([ordered]@{
                "vCenter Name" = $vcenter
                "Advanced Setting" = $name
                "Current Value" = $currentvalue.value
				"Expected Value" = $value
            })
        }
    }
    If($vcsettings.name -notcontains "$name"){
        $vcsettingfound += New-Object PSObject -Property ([ordered]@{
            "vCenter Name" = $vcenter
            "Advanced Setting" = $name
            "Current Value" = "Setting does not exist and must be created!"
			"Expected Value" = $value
        })
    }
$MyReport += Get-CustomHeader "VCW-06-000021,23,24,26 vCenter Servers with $name not set to $value : $(@($vcsettingfound).count)"
$MyReport += Get-HTMLTable $vcsettingfound
$MyReport += Get-CustomHeaderClose
}

## Check for vCenter services running as service account
$vcsvcfound = @()
ForEach($vcservice in $vcservices){
	If($vcservice.StartName -ne $vcserviceaccount){
	$vcsvcfound += New-Object PSObject -Property ([ordered]@{
        "vCenter Name" = $vcenter
        "Service Name" = $vcservice.DisplayName
        "Service Log On As" = $vcservice.StartName
		"Expected Value" = "Service running as $vcserviceaccount"
    })
	}
}
$MyReport += Get-CustomHeader "VCW-06-000022 vCenter Server with services not running as service account $vcserviceaccount : $(@($vcsvcfound).count)"
$MyReport += Get-HTMLTable $vcsvcfound
$MyReport += Get-CustomHeaderClose

## Check for managed object browser disabled
$mobdisabled = @()
Write-ToConsole "...Checking for managed object browser(MOB) enabled on $vcenter"
## Regular Expressions for this check
$regex1 = [regex]"\<enableDebugBrowse\>false\</enableDebugBrowse\>"
$regex2 = [regex]"\<enableDebugBrowse\>*"

ForEach($result in $vpxdcfg){
	If($result -match $regex2 -and $result -notmatch $regex1){
		$mobdisabled += New-Object PSObject -Property ([ordered]@{
			"vCenter Server" = $vcenter
			"Current Value" = "MOB is Enabled"
			"Expected Value" = "MOB is Disabled"
        })
	}
}
$mobdisabledcount = (($vpxdcfg -like "*enableDebugBrowse*").count)
If($mobdisabledcount -eq 0){
	$mobdisabled += New-Object PSObject -Property ([ordered]@{
		"vCenter Server" = $vcenter
		"Current Value" = "MOB setting is not present in vpxd.cfg file"
		"Expected Value" = "MOB is Disabled"
    })
}
$MyReport += Get-CustomHeader "VCW-06-000025 vCenter Server with managed object browser enabled: $(@($mobdisabled).count)"
$MyReport += Get-HTMLTable $mobdisabled
$MyReport += Get-CustomHeaderClose

## Check for web client show all tasks set
$webclienttasks = @()
Write-ToConsole "...Checking for web client show all tasks enabled on $vcenter"
## Regular Expressions for this check
$regex1 = [regex]"^show.allusers.tasks = true"
$regex2 = [regex]"^show.allusers.tasks*"

ForEach($result in $webpropsfile){
	If($result -match $regex2 -and $result -notmatch $regex1){
		$webclienttasks += New-Object PSObject -Property ([ordered]@{
			"vCenter Server" = $vcenter
			"Current Value" = $result
			"Expected Value" = "show.allusers.tasks = true"
        })
	}
	$webclienttaskscount = (($webpropsfile -like "*show.allusers.tasks*").count)
	If($webclienttaskscount -eq 0){
		$webclienttasks += New-Object PSObject -Property ([ordered]@{
			"vCenter Server" = $vcenter
			"Current Value" = "show.allusers.tasks = true is not present in webclient.properties file"
			"Expected Value" = "show.allusers.tasks = true"
        })
	}
}
$MyReport += Get-CustomHeader "VCW-06-000029 vCenter Server with web client show all tasks not enabled: $(@($webclienttasks).count)"
$MyReport += Get-HTMLTable $webclienttasks
$MyReport += Get-CustomHeaderClose

## Check to verify vCenter Plugins
$vcpluginsfound = @()
Write-ToConsole "...Checking for vCenter Plugins on $vcenter"
ForEach($plugin in $vcplugins){
	$vcpluginsfound += New-Object PSObject -Property ([ordered]@{
		"vCenter Server" = $vcenter
		"Plugin Name" = $plugin.Description
		"Plugin Version" = $plugin.version
		"Plugin Company" = $plugin.company
		"Plugin Key" = $plugin.key
		"Expected Value" = "Verify Plugins"
    })
}
$MyReport += Get-CustomHeader "VCW-06-000035 vCenter Server plugins to verify: $(@($vcpluginsfound).count)"
$MyReport += Get-HTMLTable $vcpluginsfound
$MyReport += Get-CustomHeaderClose
 
##End STIG Checks
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