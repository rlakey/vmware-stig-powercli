#    Name: OutputLog_VMware_Functions.py 
#    Author: Steven Boffardi 
#   Requires: Python, the ability to transfer the file to the VMware vCenter Server Appliance.
#    Version History:  
#        1.0 Initial Release.
#   Description: This script contains common logging and reporting functions used within the VMware Enviroment

import datetime
import os
import socket

def WriteLog (Cat,Message): # this function writes information to a log
	Now=datetime.datetime.now()
	Date=Now.strftime("%d-%b-%Y %H:%M:%S")
	FileOperation.write("["+Date+"]["+Cat+"] "+Message+"\n")

def NewLogFile(LogFile,HeaderMessage):  # Creates the Log File
	global FileOperation # varible used to open and write to the logfile
	FileOperation = open(LogFile + ".txt", "w") #gets the hostname and makes a text file
	OuputCategory="Header"
	OutputMessage=HeaderMessage
	WriteLog(OuputCategory,OutputMessage)
