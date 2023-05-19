#!/usr/bin/env python

"""
  IBM Confidential
  
  OCO Source Materials
  
  IBM TotalStorage Tape Diagnostic Tool
  
  (C) Copyright IBM Corp. 2014 All Rights Reserved.
  
  The source code for this program is not published or
  otherwise divested of its trade secrets, irrespective of
  what has been deposited with the U.S. Copyright Office.
"""

import hashlib              #to get algorithm SHA256
import subprocess           #to call system commands
from platform import system #info about platform (Windows, Linux, Darwin) 
import sys                  #to get application arguments
import os                   #to walk across folders       
import logging              #for logging purposes
import re                   #for regular expression

checkSum = 0
retVal = 0
verboseFlag = False

#Logger function
logger = logging.getLogger('IBM ltfs checksum tool')
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')

# create console handler with a error log level
consoleHandler = logging.StreamHandler()
consoleHandler.setLevel(logging.ERROR)
consoleHandler.setFormatter(formatter)
logger.addHandler(consoleHandler)

#check if the LTFS tool exist and if it is executable..
def checkExecutable(fpath):   
    if (os.path.isfile(fpath) and os.access(fpath, os.X_OK)):
        return True
    else: 
        return False

#setEAs on LTFS File System 
#parameters are the filename to be modified and the checksum to be written
def setExtendedAttribute(fileName,checkSum):
    operatingSystem = system()
    commandString = ''
    if operatingSystem == 'Linux':
        #attr -s user.ltfsdif.checksum -V checkSum fileName
        fpath = "/usr/bin/attr"
        if (checkExecutable(fpath) == False):
            logger.error("required executable : " + fpath + " not found")
            exit(1)
        commandString = fpath + " -s user.ltfsdif.checksum -V " + checkSum + " " + fileName
    elif operatingSystem == 'Windows':
        #ltfssetea fileName user.ltfsdif.checksum checkSum
        fpath = "ltfssetea.exe"
        if (checkExecutable(fpath) == False):
            pathString = "C:\Program Files\IBM\LTFS\\"
            fpath = pathString + fpath
            if (checkExecutable(fpath) == False):
                logger.error("required executable : " + fpath + " not found")
                exit(1)
        commandString = fpath + " "  + fileName + " user.ltfsdif.checksum " + checkSum
    elif operatingSystem == 'Darwin':
        #xattr -w user.ltfsdif.checksum checkSum fileName
        fpath = "/usr/bin/xattr"
        if (checkExecutable(fpath) == False):
            logger.error("required executable : " + fpath + " not found")
            exit(1)
        commandString = fpath + " -w user.ltfsdif.checksum " +checkSum + " " + fileName
    doSystemCall(commandString)

#getEAs from LTFS File System and compare with given checksum
#parameters are the filename to check and the checksum to compare with
def getExtendedAttribute(fileName,checkSum):
    operatingSystem = system()
    commandString = ''
    regEx = ''
    if operatingSystem == 'Linux':
        #attr -n user.ltfsdif.checksum fileName
        fpath = "/usr/bin/attr"
        regEx = r"[a-z0-9]{1,2}(:[a-z0-9]{1,2}){1,}"
        if (checkExecutable(fpath) == False):
            logger.error("required executable : " + fpath + " not found")
            exit(1)
        commandString = fpath + " -g user.ltfsdif.checksum " + fileName
    elif operatingSystem == 'Windows':
        #ltfsgetea fileName user.ltfsdif.checksum
        fpath = "ltfsgetea.exe"
        regEx = r"\"[a-z0-9]{1,2}(:[a-z0-9]{1,2}){1,}"
        if (checkExecutable(fpath) == False):
            pathString = "C:\Program Files\IBM\LTFS\\"
            fpath = pathString + fpath
            if (checkExecutable(fpath) == False):
                logger.error("required executable : " + fpath + " not found")
                exit(1)
        commandString = fpath + " " + fileName + " user.ltfsdif.checksum"
    elif operatingSystem == 'Darwin':
        #xattr -p user.ltfsdif.checksum checkSum fileName
        fpath = "/usr/bin/xattr"
        regEx = r"[a-z0-9]{1,2}(:[a-z0-9]{1,2}){1,}"
        if (checkExecutable(fpath) == False):
            logger.error("required executable : " + fpath + " not found")
            exit(1)
        commandString = fpath + " -p user.ltfsdif.checksum " + fileName
    output = doSystemCall(commandString)
    gotCheckSum = re.search(regEx,output)
    
    if gotCheckSum :
        fileCheckSum =  gotCheckSum.group()
        #remove the first " at windows string
        fileCheckSum = fileCheckSum.replace('\"', "")
        if (checkSum == fileCheckSum ):
            logger.info("Checksum for: " + fileName + " matches!")
            print "Checksum for: " + fileName + " matches!"
            logger.info("Calculated checksum: " + checkSum + " vs " + fileCheckSum )
            if (verboseFlag):
                print "Calculated checksum: " + checkSum + " vs " + fileCheckSum
        else:
            logger.error("Checksum for: " + fileName + " does not match!")
            logger.error("Calculated checksum: " + checkSum + " vs " + fileCheckSum )
    else: 
        logger.error("no checksum found")
#detEAs at LTFS File System   
#parameters are filename at which the checksum attribute has to be deleted 
def delExtendedAttribute(fileName):
    operatingSystem = system()
    commandString = ''
    if operatingSystem == 'Linux':
        #attr -x user.ltfsdif.checksum fileName
        fpath = "/usr/bin/attr"
        if (checkExecutable(fpath) == False):
            logger.error("required executable : " + fpath + " not found")
            exit(1)
        commandString = fpath + " -r user.ltfsdif.checksum " + fileName
    elif operatingSystem == 'Windows':
        #ltfsremoveea fileName user.ltfsdif.checksum
        fpath = "ltfsremoveea.exe"
        if (checkExecutable(fpath) == False):
            pathString = "C:\Program Files\IBM\LTFS\\"
            fpath = pathString + fpath
            if (checkExecutable(fpath) == False):
                logger.error("required executable : " + fpath + " not found")
                exit(1)
        commandString = fpath + " " + fileName + " user.ltfsdif.checksum"
    elif operatingSystem == 'Darwin':
        #xattr -d user.ltfsdif.checksum fileName
        fpath = "/usr/bin/xattr"
        if (checkExecutable(fpath) == False):
            logger.error("required executable : " + fpath + " not found")
            exit(1)
        commandString = fpath + " -d user.ltfsdif.checksum " + fileName
    doSystemCall(commandString)
    
#show the online help
def callHelp():
    print "Available parameters are:"
    print "-v     - verbose mode"
    print "-h     - shows help"
    print "-gen   - generates checksum"
    print "-ver   - verifies checksum"
    print "-del   - deletes checksum extended attribute user.ltfsdif.checksum"
    print "-log   - enables log mode"
    print "-f folder/mount point  - starts scan at this point"
    
#do a system call to set/get/del attributes        
def doSystemCall(commandString):  
    operatingSystem = system()
    if operatingSystem == 'Windows':
        shellValue = False 
    else:
        shellValue = True
    try:
        process = subprocess.Popen(commandString, shell = shellValue,
                                      stdout=subprocess.PIPE,
                                      stderr=subprocess.PIPE)
        output, errors = process.communicate()
        errcode = process.returncode
        #if execution works
        return output
        
    except Exception as err:
        logger.error("System Call execution failed for command: " + commandString + " with error: " +str(err))
        return ""
    
#split files into small blocks to ba able to handle also big files and create hash    
def hashfile(workFile, hashAlgorithm, blockSize=65536):
    fileBuffer = workFile.read(blockSize)
    while len(fileBuffer) > 0:
        hashAlgorithm.update(fileBuffer)
        fileBuffer = workFile.read(blockSize)
    return hashAlgorithm.digest()

#walk across the folder and do the required operation (generate, verify or delete)  
def doOperation(verbose,path,operation):
    whichOs = system()
    if whichOs == 'Windows':
        separator = '\\'
    else: 
        separator = '/'
    if (len(path) <= 2):
        path += separator 
    for (path, subFolders, files) in os.walk(path):
        try: #skip LTFS EE meta data folder
            subFolders.remove('.LTFSEE_DATA')
        except ValueError:
            pass
        for myFile in files:
            #print path + file
            Name =  path + separator +  myFile
            try:
                hashval = hashfile(open(Name, 'rb'), hashlib.sha256())
            except OSError as e:
                logger.error("Execution failed for command: " + commandString + " with error: ")
                logger.error(e)
            except :
                logger.error("Critical file: " + Name)
            hexHashVal = ":".join("{0:x}".format(ord(c)) for c in hashval)
            logger.info("hash for %s is :  %s " % (Name,hexHashVal))
            if (verboseFlag):
                print "checksum for %s is :  %s " % (Name,hexHashVal)
            if (operation == "verify" ):
                getExtendedAttribute(Name,hexHashVal)
            elif (operation == "delete" ):
                delExtendedAttribute(Name)
                if (verboseFlag):  
                    print "deleting user.ltfsdif.checksum attribute for file: " + Name
            else :
                setExtendedAttribute(Name,hexHashVal)

#check if python version matches
if sys.version_info < (2, 6):
    logger.error( "requires use of python 2.6 or higher!")
    exit(1)

#check application parameters/arguments
arguments = sys.argv[1:]
#starting folder / mount point

print "IBM LTFS checksum tool "
if  arguments.count("-f"):
    position = arguments.index("-f")
    folderValue = arguments[position+1]
    print "start mount point/folder is: " + folderValue
elif arguments.count("-F"):
    position = arguments.index("-F")
    folderValue = arguments[position+1]
    print "start mount point/folder is: " + folderValue
arguments = [element.lower() for element in arguments]

#verbose mode   
if arguments.count("-v"):
    print "verbose mode enabled"
    verboseFlag = True
#verbose mode   
if arguments.count("-log"):
    print "logging mode enabled"
    # create file handler which logs even debug messages
    fileHandler = logging.FileHandler('ltfs_checksum.log')
    fileHandler.setFormatter(formatter)
    logger.addHandler(fileHandler)
#checksum generation    
if arguments.count("-gen"):
    print "checksum generate..."
    doOperation(verboseFlag,folderValue,"generate")
#checksum verification    
elif arguments.count("-ver"):
    print "checksum verification..."
    doOperation(verboseFlag,folderValue,"verify")
#checksum delete    
elif arguments.count("-del"):
    print "checksum delete..."
    doOperation(verboseFlag,folderValue,"delete")
#print help
elif ( arguments.count("-h")|arguments.count("--help")):
    callHelp() 
#wrong parameters
else:
    callHelp() 
print "program finished.."