# vmware-stig-powercli
The DoD Security Technical Implementation Guide ('STIG') ESXi Script assists in remediating Defense Information Systems Agency STIG controls for ESXi. This VIB has been developed to help customers rapidly implement the more challenging aspects of the vSphere STIG. These include the fact that installation is time consuming and must be done manually on the ESXi hosts. In certain cases, it may require complex scripting, or even development of an in-house VIB that would not be officially digitally signed by VMware (and therefore would not be deployed as a normal patch would). 

**Notes:**
- These scripts assume you have the [DOD STIG VIB](https://flings.vmware.com/dod-security-technical-implementation-guide-stig-esxi-vib) installed already.

### Requirements:
- [PowerCLI 11.3](https://www.powershellgallery.com/packages/VMware.PowerCLI/11.3.0.13990089)
- [Powershell 5](https://docs.microsoft.com/en-us/skypeforbusiness/set-up-your-computer-for-windows-powershell/download-and-install-windows-powershell-5-1)
- [ESXi 6.7 U2+](https://my.vmware.com/web/vmware/downloads/details?downloadGroup=ESXI670&productId=742)

### Legacy Scripts:
**Note:** No longer supported or maintained.
- ```VMware_5.x_STIG_Check_ESXi_All.ps1```
- ```VMware_5.x_STIG_Check_VM_All.ps1```
- ```VMware_5.x_STIG_Remediate_ESXi_All.ps1```
- ```VMware_5.x_STIG_Remediate_ESXi_FromTextFile.ps1```
- ```VMware_5.x_STIG_Remediate_ESXi_Single.ps1```
- ```VMware_5.x_STIG_Remediate_VM_All.ps1```
- ```VMware_5.x_STIG_Remediate_VM_FromTextFile.ps1```
- ```VMware_5.x_STIG_Remediate_VM_Single.ps1```
- ```VMware_6.0_STIG_Check_ESXi_All.ps1```
- ```VMware_6.0_STIG_Check_ESXi_Single.ps1```
- ```VMware_6.0_STIG_Check_vCenter.ps1```
- ```VMware_6.0_STIG_Check_VMs_All.ps1```
- ```VMware_6.0_STIG_Check_VMs_Single.ps1```
- ```VMware_6.0_STIG_Remediate_ESXi_All.ps1```
- ```VMware_6.0_STIG_Remediate_ESXi_FromTextFile.ps1```
- ```VMware_6.0_STIG_Remediate_ESXi_Single.ps1```
- ```VMware_6.0_STIG_Remediate_VM_All.ps1```
- ```VMware_6.0_STIG_Remediate_VM_FromTextFile.ps1```
- ```VMware_6.0_STIG_Remediate_VM_Single.ps1```
- ```vCenter6x_Hardening.py```
- ```OutputLog_VMware_Functions.py```
