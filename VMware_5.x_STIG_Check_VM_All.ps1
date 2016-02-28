<#
.SYNOPSIS
	vSphere 5.0 STIG Virtual Machine Compliance Check HTML Report Script
	Updated for STIG: vSphere 5 Virtual Machine - Version 1, Release 5
	Created by: Ryan Lakey, rlakey@vmware.com
	Provided as is and is not supported by VMware
.DESCRIPTION
	This script will check compliance of all Virtual Machines in the target vCenter.
	
	!!Please read and know what this script it doing before running!!
	
	Requirements to run script
	-PowerCLI 6.0+ and Powershell 3+
	-Powershell allowed to run unsigned/remote scripts
.PARAMETER vcenter
   vCenter server to run script against and check Virtual Machines for compliance.
.PARAMETER cred
   This will prompt user for credentials that will be used to connect to vCenter specified.
.EXAMPLE
   ./VMware_5.x_STIG_Check_VM_All.ps1 -vcenter vcenter.test.lab
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
$ReportName = $ReportFolder + "\VMware_VM_STIG_Compliance_Report" + "_" + $Date.Month + "-" + $Date.Day + "-" + $Date.Year + "_" + $Date.Hour + "-" + $Date.Minute + "-" + $Date.Second + ".html"
## Start Transcript
$TranscriptName = $ReportFolder + "\VMware_VM_STIG_Compliance_Report_Transcript" + "_" + $Date.Month + "-" + $Date.Day + "-" + $Date.Year + "_" + $Date.Hour + "-" + $Date.Minute + "-" + $Date.Second + ".txt"
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

## Virtual Machine Advanced Settings to Check
	$VMAdvSettings = @{"isolation.tools.autoInstall.disable" = $true;  ## ESXI5-VM-000002
	"isolation.tools.copy.disable" = $true; ## ESXI5-VM-000003
	"isolation.tools.dnd.disable" = $true; ## ESXI5-VM-000004
	"isolation.tools.setGUIOptions.enable" = $false; ## ESXI5-VM-000005
	"isolation.tools.paste.disable" = $true; ## ESXI5-VM-000006
	"isolation.tools.diskShrink.disable" = $true; ## ESXI5-VM-000007
	"isolation.tools.diskWiper.disable" = $true;  ## ESXI5-VM-000008
	"isolation.tools.hgfsServerSet.disable" = $true;  ## ESXI5-VM-000009
	"vmci0.unrestricted" = $false;  ## ESXI5-VM-000011
	"logging" = $false;  ## ESXI5-VM-000012
	"isolation.monitor.control.disable" = $true;  ## ESXI5-VM-000013   !!Not Recommended!!
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
$MyReport = Get-CustomHTML "VMware vSphere 5.x Virtual Machine STIG Compliance Report"

## Connect to vCenter Server
    Try{
		Write-ToConsole "...Connecting to vCenter Server $vcenter"
		Connect-VIServer -Server $vcenter -ErrorAction Stop -Credential $cred | Out-Null}
	Catch{
		Write-ToConsole "...Could not connect to $vcenter with supplied credentials...exiting script"
		Exit
	}
	
    Write-ToConsole "...Gathering VM information for $vcenter"
    $vms = Get-VM
    $vmsv = Get-View -ViewType "VirtualMachine"
	$vminddisks = $vms | Get-HardDisk | Where {$_.Persistence -eq "IndependentNonPersistent"} | Select Parent,Name,Filename,Persistence
	$vmfloppys = $vms | Get-FloppyDrive | Select Parent,Name,ConnectionState
	$vmusbdevs = $vms | Get-UsbDevice
	$vmcds = $vms | Get-CDDrive | Where {$_.extensiondata.connectable.connected -eq $true}

    $MyReport += Get-CustomHeader0 "Virtual Machine STIG checks for vCenter server: $vcenter"
		
	#Check for Independent nonpersistent disks
	Write-ToConsole "...Checking VMs for non-persistent disks on $vcenter"
	$vmsnonperdisks = @()
	foreach($disk in $vminddisks | sort Parent){
		$vmsnonperdisks += New-Object PSObject -Property ([ordered]@{
                "Virtual Machine Name" = $disk.Parent
                "Disk" = $disk.Name
                "Filename" = $disk.filename
				"Persistence Type" = $disk.persistence
                })
	}
	$MyReport += Get-CustomHeader "Virtual Machines with nonpersistent disks: $(@($vmsnonperdisks).count)"
    $MyReport += Get-HTMLTable $vmsnonperdisks
    $MyReport += Get-CustomHeaderClose
	
	#Check for connected cd/dvd drives
	Write-ToConsole "...Checking VMs for CD/DVD media on $vcenter"
	$vmswcdscon = @()
	foreach($cd in $vmcds | sort Parent){
		$vmswcdscon += New-Object PSObject -Property ([ordered]@{
                "Virtual Machine Name" = $cd.Parent
                "CD Name" = $cd.Name
                "Connection State" = $cd.ExtensionData.Connectable.Connected
				"CD Info" = $cd.ExtensionData.deviceinfo.summary
                })
	}
	$MyReport += Get-CustomHeader "Virtual Machines with CD/DVD drives connected: $(@($vmswcdscon).count)"
    $MyReport += Get-HTMLTable $vmswcdscon
    $MyReport += Get-CustomHeaderClose
	
	#Check for floppy drives
	Write-ToConsole "...Checking VMs for Floppy drives on $vcenter"
	$vmswfloppys = @()
	foreach($floppy in $vmfloppys | sort Parent){
		$vmswfloppys += New-Object PSObject -Property ([ordered]@{
                "Virtual Machine Name" = $floppy.Parent
                "Floppy Name" = $floppy.Name
                "Connection State" = $floppy.ConnectionState
                })
	}
	$MyReport += Get-CustomHeader "Virtual Machines with floppy drives: $(@($vmswfloppys).count)"
    $MyReport += Get-HTMLTable $vmswfloppys
    $MyReport += Get-CustomHeaderClose
	
	#Check for serial devices
	Write-ToConsole "...Checking VMs for serial devices on $vcenter"
	$vmswserial = @()
	foreach($vm in $vmsv | sort Name){
		$serials = $vm.config.hardware.device.deviceinfo | Where{$_.Label -match "serial"}
		foreach($serial in $serials | Sort Label){
			$vmswserial += New-Object PSObject -Property ([ordered]@{
                "Virtual Machine Name" = $vm.Name
                "Serial Device Name" = $serial.Label
                "Serial Info" = $serial.Summary
                })
		}		
	}
	$MyReport += Get-CustomHeader "Virtual Machines with serial devices: $(@($vmswserial).count)"
    $MyReport += Get-HTMLTable $vmswserial
    $MyReport += Get-CustomHeaderClose
	
	#Check for parallel devices
	Write-ToConsole "...Checking VMs for parallel devices on $vcenter"
	$vmswparallel = @()
	foreach($vm in $vmsv | sort Name){
		$parallels = $vm.config.hardware.device.deviceinfo | Where{$_.Label -match "parallel"}
		foreach($parallel in $parallels | Sort Label){
			$vmswparallel += New-Object PSObject -Property ([ordered]@{
                "Virtual Machine Name" = $vm.Name
                "Serial Device Name" = $parallel.Label
                "Serial Info" = $parallel.Summary
                })
		}		
	}
	$MyReport += Get-CustomHeader "Virtual Machines with parallel devices: $(@($vmswparallel).count)"
    $MyReport += Get-HTMLTable $vmswparallel
    $MyReport += Get-CustomHeaderClose
	
	#Check for USB controllers
	Write-ToConsole "...Checking VMs for USB controllers on $vcenter"
	$vmswusbcon = @()
	foreach($vm in $vmsv | sort Name){
		$usbcons = $vm.config.hardware.device.deviceinfo | Where{$_.Label -match "USB con*"}
		foreach($usbcon in $usbcons | Sort Label){
			$vmswusbcon += New-Object PSObject -Property ([ordered]@{
                "Virtual Machine Name" = $vm.Name
                "Serial Device Name" = $usbcon.Label
                "Serial Info" = $usbcon.Summary
                })
		}		
	}
	$MyReport += Get-CustomHeader "Virtual Machines with USB controllers: $(@($vmswusbcon).count)"
    $MyReport += Get-HTMLTable $vmswusbcon
    $MyReport += Get-CustomHeaderClose
	
	#Check for USB devices
	Write-ToConsole "...Checking VMs for USB devices on $vcenter"
	$vmswusbdev = @()
	foreach($usbdev in $vmusbdevs | sort Parent){
		$vmswusbdev += New-Object PSObject -Property ([ordered]@{
                "Virtual Machine Name" = $usbdev.Parent
                "USB Device Name" = $usbdev.Name
				"USB Device Info" = $usbdev.extensiondata.deviceinfo.summary
                "USB connected from" = $usbdev.extensiondata.backing.hostname
                })
	}
	$MyReport += Get-CustomHeader "Virtual Machines with USB devices: $(@($vmswusbdev).count)"
    $MyReport += Get-HTMLTable $vmswusbdev
    $MyReport += Get-CustomHeaderClose
			
	#Check for correct VM advanced settings
	foreach($setting in ($VMAdvSettings.GetEnumerator() | Sort Name)){
	$name = $setting.name
	$value = $setting.value
    Write-ToConsole "...Checking VMs for $name on $vcenter"
    $vmsfound = @()
    foreach($vm in $vmsv | sort Name){
        If($vm.config.extraconfig.key -contains "$name"){
            $currentvalue = $vm.config.extraconfig | where {$_.key -eq "$name"}
            If($currentvalue.value -ne $value){
            $vmsfound += New-Object PSObject -Property ([ordered]@{
                "Virtual Machine Name" = $vm.name
                "Advanced Setting" = $currentvalue.key
                "Current Value" = $currentvalue.value
                })
            }
        }
        If($vm.config.extraconfig.key -notcontains "$name"){
            $vmsfound += New-Object PSObject -Property ([ordered]@{
                "Virtual Machine Name" = $vm.name
                "Advanced Setting" = $name
				"Current Value" = "Setting does not exist and must be created!"
                "Expected Value" = $value
                })
        }
    }
    $MyReport += Get-CustomHeader "Virtual Machines with $name not set to $value : $(@($vmsfound).count)"
    $MyReport += Get-HTMLTable $vmsfound
    $MyReport += Get-CustomHeaderClose
	}
	
	#Check for dvfilters
    Write-ToConsole "...Checking VMs for dvfilters on $vcenter"
    $vmsdvfilter = @()
    foreach($vm in $vmsv | sort Name){
        $currentvalue = $vm.config.extraconfig | where {$_.key -like "ethernet*.filter*.name"}
            foreach($filter in $currentvalue){
                $vmsdvfilter += New-Object PSObject -Property ([ordered]@{
                VM = $vm.name
                "VMX Setting" = $filter.key
                Value = $filter.value
				"Expected Value" = "If value exists verify it is valid."
                })
            }     
    }
    $MyReport += Get-CustomHeader "Virtual Machines where ethernetX.filterX.name exists: $(@($vmsdvfilter).count)"
    $MyReport += Get-HTMLTable $vmsdvfilter
    $MyReport += Get-CustomHeaderClose
	
	#Check for vmsafe address
    Write-ToConsole "...Checking VMs for vmsafe agent address on $vcenter"
    $vmsagentaddress = @()
    foreach($vm in $vmsv | sort Name){
        $currentvalue = $vm.config.extraconfig | where {$_.key -like "vmsafe.agentAddress"}
            foreach($filter in $currentvalue){
                $vmsagentaddress += New-Object PSObject -Property ([ordered]@{
                VM = $vm.name
                "VMX Setting" = $filter.key
                Value = $filter.value
				"Expected Value" = "If value exists verify it is valid."
                })
            }     
    }
    $MyReport += Get-CustomHeader "Virtual Machines where vmsafe.agentAddress exists: $(@($vmsagentaddress).count)"
    $MyReport += Get-HTMLTable $vmsagentaddress
    $MyReport += Get-CustomHeaderClose
	
	#Check for vmsafe port
    Write-ToConsole "...Checking VMs for vmsafe agent port on $vcenter"
    $vmsagentport = @()
    foreach($vm in $vmsv | sort Name){
        $currentvalue = $vm.config.extraconfig | where {$_.key -like "vmsafe.agentPort"}
            foreach($filter in $currentvalue){
                $vmsagentport += New-Object PSObject -Property ([ordered]@{
                VM = $vm.name
                "VMX Setting" = $filter.key
                Value = $filter.value
				"Expected Value" = "If value exists verify it is valid."
                })
            }     
    }
    $MyReport += Get-CustomHeader "Virtual Machines where vmsafe.agentPort exists: $(@($vmsagentport).count)"
    $MyReport += Get-HTMLTable $vmsagentport
    $MyReport += Get-CustomHeaderClose
	
    ##End VM STIG Checks
    $MyReport += Get-CustomHeader0Close

## Disconnect from vCenter
Write-ToConsole "...Disconnecting from vCenter Server $vcenter"
Disconnect-VIServer -Server $vcenter -Force -Confirm:$false


## Generate Battle Rhythm Report
$MyReport | out-file -encoding ASCII -filepath $ReportName

## Display report on screen after completetion
if ($DisplayToScreen) {
	Write-ToConsole "...Displaying STIG Compliance Report"
	Invoke-Item $ReportName
}

## Stop Transcript
Stop-Transcript