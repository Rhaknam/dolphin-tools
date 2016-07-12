#!/bin/env python 
import logging
from optparse import OptionParser
import sys
import os
import getpass
from os import path, access, R_OK 
import re
#import random 
import string
import subprocess
sys.path.insert(0, sys.path[0])
from config import *

def RemoveComments(text):
  return text.split("#", 1)[0]

def InputParams(inputparams):
    data = {}
    parts = [s.split('=') for s in inputparams.split(';')]
    for param in parts:
        data[param[0]] = param[1]

    return data

      
def Params(params1, path, USERNAME, WKEY, SERVICENAME, OUTDIR, TOOLDIR):
    data = params1
    with open(path, 'r') as fo:
      for line in fo.readlines():
        line = re.sub('\r', "\n", line)
        if (len(line) < 5 or re.match('^#', line)): continue
        
        line=RemoveComments(line)
 
        parts = [s.strip(' :=\t\n') for s in line.split(' ', 1)]
      
        value = parts[1]
        for param in data:
          value = value.replace(param, data[param])
          value = value.replace("@TOOLDIR", TOOLDIR)
          value = value.replace("@USERNAME", USERNAME)
          value = value.replace("@WKEY", WKEY)
          value = value.replace("@SERVICENAME", SERVICENAME)
          value = value.replace("@OUTDIR", OUTDIR)
        data[parts[0]] = value
    return data
        
def main():

    try:
        parser = OptionParser()
        parser.add_option('-i', '--inputparam', help='defined param file in the cluster', dest='inputparam')
        parser.add_option('-p', '--defaultparamfile', help='defined param file in the cluster', dest='paramfile')
        parser.add_option('-u', '--username', help='defined user in the cluster', dest='username')
        parser.add_option('-k', '--key', help='defined key for the workflow', dest='wkey')
        parser.add_option('-s', '--servicename', help='service name', dest='servicename')
        parser.add_option('-c', '--command', help='command that is goinf to be run', dest='com')
        parser.add_option('-n', '--name', help='name of the run', dest='name')
        parser.add_option('-t', '--cpu', help='the # of cpu', dest='cpu')
        parser.add_option('-o', '--outdir', help='oupur directory', dest='outdir')
        parser.add_option('-f', '--config', help='configuration parameter section', dest='config')
        (options, args) = parser.parse_args()
    except:
        print "OptionParser Error:for help use --help"
        sys.exit(2)
    INPUTPARAM  = options.inputparam
    PARAMFILE   = options.paramfile
    USERNAME    = options.username
    WKEY        = options.wkey 
    SERVICENAME = options.servicename
    COM         = options.com
    NAME        = options.name
    CPU         = options.cpu
    OUTDIR      = options.outdir
    CONFIG      = options.config

    config=getConfig(CONFIG)
   
    TOOLDIR     = config['tooldir']
    python      = "python ";
    
    if (USERNAME==None):
        USERNAME=getpass.getuser()

    OUTDIR = OUTDIR.replace("@USERNAME", USERNAME)
    os.system("mkdir -p " + OUTDIR + "/scripts")
    print OUTDIR
    print NAME
    print USERNAME
    
    bash_script_file = OUTDIR + "/scripts/" + NAME + ".bash"

    comstr=""
    COM = re.sub('\n', "\n", COM)
    params={}
    if (INPUTPARAM != None): 
       params = InputParams(INPUTPARAM)

    if (PARAMFILE != None and path.isfile(PARAMFILE) and access(PARAMFILE, R_OK)):
       params = Params(params, PARAMFILE, USERNAME, WKEY, SERVICENAME, OUTDIR, TOOLDIR)

   
    if (len(params)>0):
     for param in params:
       regex=re.compile(param+"([\s\t\=\\\/\r\n]+)")
       COM=re.sub(regex, params[param]+'\\1', COM)
     for param in params:
       COM = COM.replace(param, params[param])
    print "["+COM+"]\n"

    COM = COM.replace("@USERNAME", USERNAME)
    COM = COM.replace("@WKEY", WKEY)
    COM = COM.replace("@SERVICENAME", SERVICENAME)
    COM = COM.replace("@OUTDIR", OUTDIR)
    COM = COM.replace("@TOOLDIR", TOOLDIR)
    COM = COM.replace("@CONFIG", CONFIG )
    COM = COM.replace('\n', ' ')
    COM = COM.replace(r'([\t\s]+)', " ")

    words =  re.split(r'([\t\s;]+)', COM)
 
    for word in words:
         sstr=" "
         if ( re.match(r'[;]', word) ):
             comstr += word
         elif ( re.match(r'\\n', word) ):
             comstr+="\n"
         elif ( re.match(r'[\t\s]', word) ):
             sstr=' '
         else:
             comstr += word+" " 
    else:
      comstr=COM

    logs=OUTDIR + "/tmp/logs"
    os.system("mkdir -p "+logs)

    logfile="%s/SERVICE.%s.log"%(logs, SERVICENAME)
    logging.basicConfig(filename=logfile, filemode='a',format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.DEBUG)
    logging.info(USERNAME+":"+OUTDIR)
    logging.info(comstr)

    f=open(bash_script_file, 'w')
   
    f.write(comstr + "\n")

    f.close()
    os.system("chmod +x " + bash_script_file)
   
    command = python+" " + TOOLDIR  + "/src/"+ config['runjobcmd']+" -f " + CONFIG + " -u "+ USERNAME + " -k "+ WKEY + " -o "+ OUTDIR + " -c " + bash_script_file + " -n " + SERVICENAME  + " -s " + SERVICENAME
    print command
    logging.info(command)
    ## PUT TRY CATCH HERE
    logging.info("STARTED")
    child = os.popen(command)
    
    data = child.read()
    err = child.close()
    #print "\n\nDATA"+str(data)
    #print "\n\nERR"+str(err)
    logging.info("ENDED")

    if err:
       raise RuntimeError, 'ERROR: %s failed w/ exit code %d' % (command, err)
    return data
    
if __name__ == "__main__":
    main()
