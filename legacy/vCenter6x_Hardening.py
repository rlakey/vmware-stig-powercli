#    Name: vCenter6x_Harden.py 
#    Author: Steven Boffardi 
#   Requires: Python, the ability to transfer the file to the VMware vCenter Server Appliance. The file OutputLog_VMware_Functions.py  must be in the same directory
#    Version History:  
#        1.0 Initial Release.
#   Description: This srcipt hardens the vCenter Server Appliance acccording to the DISA Stig

from OutputLog_VMware_Functions import WriteLog, NewLogFile#, vCenter-Info, Host-Info   
import datetime
import os
import subprocess
import socket

global HeaderMessage # sets the header message
global SystemHostName # gets the System hostname

SystemHostName=socket.gethostname()
HeaderMessage="VMware vCenter Server Appliance 6.x Hardening"
vCenterVersion=subprocess.check_output("vpxd -v", shell=True)

def CAT_I(): # CAT I STIG Items
	OuputCategory="CAT I"
	OutputMessage="Starting Hardening Process on VMware vCenter Server Appliance "+SystemHostName
	WriteLog(OuputCategory,OutputMessage)
	# End Cat_I

def CAT_II(): # CAT II STIG Items
	OuputCategory="CAT II"
	OutputMessage="Starting Hardening Process on VMware vCenter Server Appliance "+SystemHostName
	WriteLog(OuputCategory,OutputMessage)

	#Begin 6.5 specific hardening
	if "6.5" in vCenterVersion:
		#backs up the webclient properties file 
		os.system('cp /etc/vmware/vsphere-ui/webclient.properties  /etc/vmware/vsphere-ui/webclient.properties.bak')
	
		# working line 36
		os.system('sed -i -e "/^refresh.rate =/{ s/.*/refresh.rate = -1/ }" /etc/vmware/vsphere-ui/webclient.properties')
	
		# working line 32
		os.system('sed -i -e "/session.timeout =/{ s/.*/session.timeout = 10/ }" /etc/vmware/vsphere-ui/webclient.properties')

		# working  line 10
		os.system('sed -i -e "/show.allusers.tasks =/{ s/.*/show.allusers.tasks = true/ }" /etc/vmware/vsphere-ui/webclient.properties')
	#End 6.5 specific hardening
	
	
	#backs up the webclient properties file 
	os.system('cp /etc/vmware/vsphere-client/webclient.properties  /etc/vmware/vsphere-client/webclient.properties.bak')
		
	# working line 36
	os.system('sed -i -e "/^refresh.rate =/{ s/.*/refresh.rate = -1/ }" /etc/vmware/vsphere-client/webclient.properties')
	OutputMessage="Vuln Id = V-63943, Rule = The system must not automatically refresh client sessions. Applied Successfully."
	WriteLog(OuputCategory,OutputMessage)
	
	
	# working line 32
	os.system('sed -i -e "/session.timeout =/{ s/.*/session.timeout = 10/ }" /etc/vmware/vsphere-client/webclient.properties')
	OutputMessage="Vuln Id = V-63947, Rule = The system must terminate management sessions after 10 minutes of inactivity. Applied Successfully."
	WriteLog(OuputCategory,OutputMessage)
	
	
	# working  line 10
	os.system('sed -i -e "/show.allusers.tasks =/{ s/.*/show.allusers.tasks = true/ }" /etc/vmware/vsphere-client/webclient.properties')
	OutputMessage="Vuln Id = V-63995, Rule = The system must enable all tasks to be shown to Administrators in the Web Client. Applied Successfully."
	WriteLog(OuputCategory,OutputMessage)
	
	# End Cat_II

def CAT_III(): # CAT III STIG Items
	OuputCategory="CAT III"
	OutputMessage="Starting Hardening Process on VMware vCenter Server Appliance "+SystemHostName
	WriteLog(OuputCategory,OutputMessage)
	# End Cat_III

NewLogFile(SystemHostName,HeaderMessage)
WriteLog("vCenter Information",vCenterVersion.rstrip('\n'))
WriteLog("Separator","")
CAT_I()
WriteLog("Separator","")
CAT_II()
WriteLog("Separator","")
CAT_III()
WriteLog("Separator","")
