#!/bin/env python
import logging
from optparse import OptionParser
import json
import subprocess
import urllib,urllib2
import os
from os import path, access, R_OK
import getpass
import re
import random 
import string
import time
import sys
sys.path.insert(0, sys.path[0])
from config import *
from funcs import *
from os.path import basename

class runWorkflow:
    url=""
    f=""
    def __init__(self, url, f ):
        self.url = url
        self.f = f

    def remove_comments(self, line, sep):
        for s in sep:
            line = line.split(s)[0]
        line += "\n"    
        return line


    def import_workflow(self, input_file, logging):
        wf = list()

        with open(input_file, 'r') as infile:
          for line in infile.readlines():
            line=self.remove_comments(line, '#')
            if (len(line) < 5): continue

            servicename, command, waittime = re.split(r'[\t\,]+', line)
            logging.info( "servicename=[%s]\ncommand=[%s]waittime=[%s]"%(servicename, command, waittime) )
            wf.append(Service(servicename,command,waittime))
        return wf

    def import_param(self, input_file=None):
        wf = list()
        whole_input = ""
        with open(input_file, 'r') as fo:
          for line in fo.readlines():
            line=self.remove_comments(line, '#')
            if (len(line) < 2): continue
            whole_input += line
        whole_input=re.sub('[\t\s]*[\n\r]','\n', whole_input)
        whole_input=re.sub('\n@',';@', whole_input)
        whole_input=re.sub('\n',':', whole_input)
        whole_input=re.sub(r'[\t\s]*=+[\t\s:]*', '=', whole_input)
        whole_input=re.sub(r'[\t\s]+', ',', whole_input)
        whole_input=re.sub(r':@?$', '', whole_input)
        return whole_input

    def updateRunParams(self, wkey, rpid, logging):
        data = urllib.urlencode({'func':'updateRunParams', 'wkey':wkey, 'runparamsid':rpid })
        self.f.queryAPI(self.url, data, "updateRunParams:"+wkey, logging)

    def startWorkflow(self, inputparam, defaultparam, username, wfname, wkey, outdir, slen, logging): 
        data = urllib.urlencode({'func':'startWorkflow', 'inputparam':inputparam, 
                   'defaultparam':defaultparam, 'username':username, 
                   'workflow':wfname, 'wkey':wkey, 'outdir':outdir, 'services':slen})
        return self.f.queryAPI(self.url, data, "workflow started:"+wkey, logging)

    def startService(self, service, wkey, username, logging):
        data = urllib.urlencode({'func':'startService', 'servicename':service.servicename, 
                 'wkey':wkey, 'command':service.command, 'username':username})
        return self.f.queryAPI(self.url, data, "service started:"+service.servicename, logging)

    def endWorkflow(self, wkey, logging):
        data = urllib.urlencode({'func':'endWorkflow',  'wkey':wkey})
        return self.f.queryAPI(self.url, data, "endworkflow:"+wkey, logging)

    def checkPermissions(self, username, outdir):
        data = urllib.urlencode({'func':'checkPermissions',  'username':username, 'outdir':outdir})
        return self.f.queryAPI(self.url, data, None, None)

class Service:
    def __init__(self, servicename="service", command="command", waittime="60"):
      self.servicename  = servicename
      self.command      = command
      self.waittime     = waittime
        
def main():

    try:
        parser = OptionParser()
        parser.add_option('-i', '--inputparam', help='input parameters for the workflow', dest='inputparam')
        parser.add_option('-p', '--defaultparam', help='defined parameter file that will be run on cluster', dest='defaultparam')
        parser.add_option('-u', '--username', help='defined user in the cluster', dest='username')
        parser.add_option('-k', '--wkey', help='defined key for the workflow', dest='wkey')
        parser.add_option('-w', '--workflowfile', help='workflow filename', dest='workflowfile')
        parser.add_option('-d', '--dbhost', help='dbhost name', dest='dbhost')
        parser.add_option('-o', '--outdir', help='output directory in the cluster', dest='outdir')
        parser.add_option('-f', '--config', help='configuration parameter section', dest='config')
        parser.add_option('-r', '--runid', help='runid', dest='runid')
                
        (options, args) = parser.parse_args()
    except:
        print "OptionParser Error:for help use --help"
        sys.exit(2)

    INPUTPARAM      = options.inputparam
    DEFAULTPARAM    = options.defaultparam
    USERNAME        = options.username
    WKEY            = options.wkey 
    WORKFLOWFILE    = options.workflowfile
    DBHOST          = options.dbhost
    OUTDIR          = options.outdir
    CONFIG          = options.config
    RUNID           = options.runid
    
    f = funcs()
    config = getConfig(CONFIG)
    workflow = runWorkflow(config['url'], f)
    LOGPATH=config['logpath']

    #This section is just for username conversion in the cluster can be removed in the future
    if (CONFIG != "Docker" and CONFIG != "Travis"):
       com="grep "+USERNAME+" /project/umw_biocore/svcgalaxy/conv.file|awk '{print $2}'"
       USERNAME=str(os.popen(com).readline().rstrip())
    ########

    if (USERNAME and len(USERNAME)<3): 
        print "Error:Username doesn't exist"
        sys.exit(2)
    
    if (OUTDIR==None):
      OUTDIR="~/out"
    if (OUTDIR.find("/")==-1):
      OUTDIR="~/"+OUTDIR

    if (INPUTPARAM!=None):
        if path.isfile(INPUTPARAM) and access(INPUTPARAM, R_OK):
            INPUTPARAM = workflow.import_param(INPUTPARAM)
        else:
            INPUTPARAM = re.sub(" ", "", INPUTPARAM)

    logging.basicConfig(filename=LOGPATH+'/run'+str(RUNID)+'.log', filemode='a',format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.DEBUG)
    logging.info(USERNAME+":"+OUTDIR)
    logging.info(INPUTPARAM)

    if (WKEY==None):
       WKEY="start"
    else:
       workflow.updateRunParams(WKEY, RUNID, logging)

    services=workflow.import_workflow(WORKFLOWFILE, logging)
    slen=str(len(services))    
  
    wfbase = os.path.splitext(basename(WORKFLOWFILE))[0] 
    wfname = wfbase.split('.')[0]
    wkey =  workflow.startWorkflow(INPUTPARAM, DEFAULTPARAM, USERNAME, wfname, WKEY, OUTDIR, slen,logging) 

    if (wkey.startswith("ERROR")):
                logging.warning("ERROR:"+ wkey)
                print "Check the parameter files:\n"
                sys.exit(2);
    print "WORKFLOW STARTED:"+wkey+"\n"
    logging.info('WORKFLOW STARTED'+wkey+"\n")
    workflow.updateRunParams(wkey, RUNID, logging)

    for service in services:
        br=1
        checkcount=0
        while ( br==1):
            ret=workflow.startService(service, wkey, USERNAME, logging)
            print ret + "\n"
            time.sleep(5)
            if (ret.startswith("RUNNING") and float(service.waittime)>0):
                time.sleep(float(service.waittime))
            elif (ret.startswith("ERROR")):
                print service.servicename + ":" + ret + "\n"
                logging.warning("ERROR:"+ret)
                logging.warning("ERROR:"+service.command)
                print "Check the command:\n"
                print service.command + "\n"
                sys.exit(2);
            elif (ret.startswith("DONE")):
                checkcount=0
                br=0
            checkcount=checkcount+1
    br=1
    print "All the services Ended"    
    while ( br==1):
        res=workflow.endWorkflow(wkey, logging)
        #print ret + "\n"
        if (ret.startswith("WRUNNING")):
            time.sleep(5)
        else:
            br=0

if __name__ == "__main__":
    main()

