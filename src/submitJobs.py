#!/bin/env python

import logging
from optparse import OptionParser
import sys
import os
import re
import string
import subprocess
import math
import json

sys.path.insert(0, sys.path[0])
from config import *
from funcs import *


class submitJobs:
    url = ""
    f=""
    def __init__(self, url, f ):
        self.url = url
        self.f = f

    def getJobParams(self, servicename,name, wkey, logging):
        queue = "short"
        cputime = 240
        memory = 16096
        cpu = 1 

        if (servicename != name):
           data = urllib.urlencode({'func':'getJobParams', 'servicename':servicename, 'name':name, 'wkey':wkey})
           jobparams=self.f.queryAPI(self.url, data, servicename, logging)
           data    = json.loads(jobparams)
           cputime_pred = int(math.floor(int(data['cputime'])/60)+60)
           memory = int(math.floor(int(data['maxmemory']))+1024)
           if(servicename=="stepTophat2" or servicename=="stepRSEM" or servicename=="stepBSMap"):
               cpu=4
               cputime_pred=cputime_pred*2
           if("picard" in servicename.lower() or "rseqc" in servicename.lower()):
               cputime_pred = 2000
               memory = 64000
        
           # Set cputime and queue
           if(cputime_pred>240):
              queue = "long"
              cputime=cputime_pred
           if(cputime_pred>=20000):
              cputime = 20000
           if(memory>=1000000):
              memory = 1000000
        alist = (queue, str(cputime), str(memory), str(cpu))
        return list(alist)

    def checkJob(self, jobname, wkey, logging):
        data = urllib.urlencode({'func':'checkJob', 'jobname':jobname, 'wkey':wkey})
        return json.loads(self.f.queryAPI(self.url, data, jobname, logging))['Result']
        

    def runcmd(self, command): 
        #print command
        child = os.popen(command)
        data = child.read()
        #print data
        err = child.close()
        if err:
           return 'ERROR: %s failed w/ exit code %d' % (command, err)
        return data
 
def main():
   try:
        parser = OptionParser()
        parser.add_option('-u', '--username', help='defined user in the cluster', dest='username')
        parser.add_option('-k', '--key', help='defined key for the workflow', dest='wkey')
        parser.add_option('-s', '--servicename', help='service name', dest='servicename')
        parser.add_option('-c', '--command', help='command that is goinf to be run', dest='com')
        parser.add_option('-n', '--name', help='name of the run', dest='name')
        parser.add_option('-o', '--outdir', help='output directory', dest='outdir')
        parser.add_option('-f', '--config', help='configuration parameter section', dest='config')
        parser.add_option('-r', '--force', help='force subission', dest='force')
        (options, args) = parser.parse_args()
   except:
        print "OptionParser Error:for help use --help"
        sys.exit(2)
        
   USERNAME    = options.username
   WKEY        = options.wkey 
   OUTDIR      = options.outdir 
   SERVICENAME = options.servicename
   NAME        = options.name
   COM         = options.com
   CONFIG      = options.config
   FORCE       = (options.force if (options.force) else "no" )
   python      = "module load python/2.7.5 && python"

   config=getConfig(CONFIG)
   f = funcs()
   submitjobs = submitJobs(config['url'], f)
   submitCommand = f.getCommand(sys.argv)


   exec_dir=os.path.dirname(os.path.abspath(__file__))
   #print "EXECDIR" + exec_dir
   sdir=config['tooldir']+"/src"
   track=OUTDIR + "/tmp/track"
   src=OUTDIR + "/tmp/src"
   logs=OUTDIR + "/tmp/logs"

   if (NAME == None):
        NAME="job";

   success_file = track+"/"+str(NAME)+".success";
   if (not os.path.exists(success_file) or FORCE != "no"):
  
     os.system("mkdir -p "+track)
     os.system("mkdir -p "+src)
     os.system("mkdir -p "+logs)

     logfile="%s/JOB.%s.log"%(logs, NAME)
     logging.basicConfig(filename=logfile, filemode='a',format='%(asctime)s %(message)s', datefmt='%m/%d/%Y %I:%M:%S %p', level=logging.DEBUG)
     logging.info("File Path:%s"%os.getcwd())
     print "checkJob\n";
     result = submitjobs.checkJob(NAME, WKEY, logging)
     print result+"\n"
     if (result != "START" and FORCE == "no" ):
        sys.exit(0)
     print "checkJob[DONE]\n";
      
     print "getJobParams\n";
     (QUEUE, TIME, MEMORY, CPU) = submitjobs.getJobParams(SERVICENAME, NAME,WKEY, logging)
     resources = "\'{\\\"queue\\\":\\\"%s\\\",\\\"cputime\\\":\\\"%s\\\",\\\"memory\\\":\\\"%s\\\",\\\"cpu\\\":\\\"%s\\\"}\'"%(QUEUE, TIME, MEMORY, CPU)
     logging.info("resources => :%s"%(resources))
     print "getJobParams["+resources+"]\n";
   
     if (USERNAME==None):
        USERNAME=subprocess.check_output("whoami", shell=True).rstrip()
   
     print "USER:"+str(USERNAME)+"\n";

     if (OUTDIR == None):
        OUTDIR="~/out";
     if (QUEUE == None):
        queue="-q short"
     else: 
        queue="-q "+str(QUEUE)
  
     COM.replace('\"{','\'{')
     COM.replace('}\"','}\'')
     print "COMMAND: [" + COM + "]\n"
     print "NAME: [" + NAME + "]\n"
     print "cpu: [" + CPU + "]\n"


     jobstatus_cmd = python + " %(sdir)s/jobStatus.py -f %(CONFIG)s -u %(USERNAME)s -k %(WKEY)s -s %(SERVICENAME)s -t %(TYPE)s -o %(OUTDIR)s -j %(NAME)s -m %(MESSAGE)s -r %(resources)s"
  
     f=open(src+"/"+NAME+".tmp.bash", 'w')
     f.write("#!/bin/bash\n")
     f.write("#BEGINING-OF-FILE\n")
     f.write("cd " + exec_dir + "\n")
     MESSAGE="2"
     TYPE="dbSetStartTime"
     f.write(jobstatus_cmd % locals() + " -n $LSB_JOBID")
     f.write("\n   retval=$?\n   if [ $retval -ne 0 ]; then\n     exit 66\n   fi\n")
     COMSTR=re.sub(r"'",r"''", COM)
     f.write("echo '"+str(COMSTR)+"'\n")
     f.write("\n\n"+ str(COM) +"\n\n")
     f.write("retval=$?\necho \"[\"$retval\"]\"\nif [ $retval -eq 0 ]; then\n")
     if (str(NAME) != str(SERVICENAME)):
       f.write("touch "+success_file+"\n")
     MESSAGE="3"
     TYPE="dbSetEndTime"
     f.write(jobstatus_cmd % locals() + " -n $LSB_JOBID")     
     f.write("\n    retval=$?\n   if [ $retval -ne 0 ]; then\n     exit 66\n   fi\n")
     f.write("  echo success\nelse\n  echo failed\n")
     MESSAGE="0"
     f.write(jobstatus_cmd % locals() + " -n $LSB_JOBID")
     f.write("\n    retval=$?\n   if [ $retval -ne 0 ]; then\n     exit 66\n   fi\n")
     f.write("  exit 127\nfi\ndate\n")

     f.write("#END-OF-FILE\n")
     f.close();
     os.system("chmod 755 "+src+"/"+NAME+".tmp.bash")
     f=open(src+"/"+NAME+".submit.bash", 'w')
     f.write(src + "/" +NAME + ".tmp.bash > " + logs + "/$LSB_JOBID.std 2>&1")
     f.close();

     os.system("chmod 755 "+src+"/"+NAME+".submit.bash")

     f=open(src+"/"+NAME+".submit.log", 'w')

     #CHANGE this submition script according to the system.
     #PUT TRY CATCH HERE 
     command="bsub "+queue+" -R \"select[os=rh6.4 || os=rh6.5]\" -P dolphin -R \"span[hosts=1]\" -n "+str(CPU)+" -W "+str(TIME)+" -R \"rusage[mem="+str(MEMORY)+"]\" -J "+NAME+" -o "+logs+" < "+src+"/"+NAME+".submit.bash"
     print command
     f.write("SUBMIT SCRIPT[" + command +"]\n\n")
     output = submitjobs.runcmd(command)
     f.write("SUBMIT OUT:[" + str(output) + "]\n")
     words = re.split('[\<\>]+', str(output))
     num = words[1]

     MESSAGE="1"
     TYPE="dbSubmitJob"
     submitCommand=re.sub(r"'",r"''", submitCommand)
     jobstatus_cmd = jobstatus_cmd + " -n %(num)s -c '"+submitCommand+"'"
     command = jobstatus_cmd % locals()
     f.write("RUN COMMAND:\n" + str(command) + "\n")
     if num>0:
        return submitjobs.runcmd(command)
     f.close()
 
if __name__ == "__main__":
    main()
