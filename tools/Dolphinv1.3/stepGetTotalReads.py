#!/usr/bin/env python
 
import os, re, string, sys, commands
import warnings
import json
from sys import argv, exit, stderr
from optparse import OptionParser


sys.path.insert(0, sys.path[0]+"/../../src")
from config import *
from funcs import *


class stepGetTotalReads:
  url=""
  f=""
  def __init__(self, url, f ):
      self.url = url
      self.f = f

  def getFileList(self, runparamsid, barcode):  
    data = urllib.urlencode({'func':'getSampleList', 'runparamsid':str(runparamsid), 'barcode':str(barcode)})
    ret = self.f.queryAPI(self.url, data, "getSampleList:"+runparamsid)
    if (ret):
       ret=json.loads(ret)
    return ret

  def submitJob(self, JOBSUBMIT, name, command):
    child = os.popen(JOBSUBMIT+' -n stepGetTotalReads_'+name+' -c "'+command+'"')
    print JOBSUBMIT+' -n stepGetTotalReads_'+name+' -c "'+command+'"'+"\n\n"
    jobout = child.read().rstrip()
    err = child.close()
    return jobout
        
  def gzipFileAndGetCount(self, JOBSUBMIT, inputdir, filename, backupdir):
    command = "mkdir -p "+backupdir+" && gzip -c "+inputdir+"/"+filename+" > "+backupdir+"/"+filename+".gz && s=\$(zcat "+backupdir+"/"+filename+".gz|wc -l) && echo \$((\$s/4)) > "+backupdir+"/"+filename+".gz.count && md5sum "+backupdir+"/"+filename+".gz> "+backupdir+"/"+filename+".gz.md5sum"
    self.submitJob(JOBSUBMIT, "gzip_"+filename, command)

  def getCount(self, JOBSUBMIT, outputdir, inputdir, filename, dir_id):
    cat = "cat"
    if ('.gz' in filename):
        cat = "zcat"
    command = "mkdir -p "+outputdir+" && s=\$("+cat+" "+inputdir+"/"+filename+"|wc -l) && echo \$((\$s/4))  > "+outputdir+"/"+filename+".count"
    self.submitJob(JOBSUBMIT, "count_"+filename+"_"+str(dir_id), command)
    
def main():
    try:
        parser = OptionParser()
        parser.add_option('-b', '--barcode', help='barcode', dest='barcode')
        parser.add_option('-j', '--jobsubmit', help='jobsubmit', dest='jobsubmit')
        parser.add_option('-r', '--runparamsid', help='run params id', dest='runparamsid')
        parser.add_option('-u', '--username', help='username', dest='username')
        parser.add_option('-p', '--pairedend', help='pairedend', dest='paired')
        parser.add_option('-o', '--outdir', help='output directory', dest='outdir')
        parser.add_option('-c', '--config', help='config parameters section', dest='config')

        (options, args) = parser.parse_args()
    except:
        parser.print_help()
        print "for help use --help"
        sys.exit(2)
 
    BARCODE                 = options.barcode
    PAIRED                  = options.paired
    USERNAME                = options.username
    RUNPARAMSID             = options.runparamsid
    JOBSUBMIT               = options.jobsubmit
    OUTDIR                  = options.outdir
    CONFIG                  = options.config

    f = funcs()
    config = getConfig(CONFIG)
    totalReads = stepGetTotalReads(config['url'], f)
    
    if (OUTDIR == None or JOBSUBMIT == None):
        print "for help use --help"
        sys.exit(2)

    print BARCODE
    print PAIRED
    print JOBSUBMIT
    print OUTDIR
    print USERNAME
    print RUNPARAMSID
    
    filelist=totalReads.getFileList(RUNPARAMSID, BARCODE)
    
    inputdir=OUTDIR+"/input"
    if (BARCODE != "NONE"):
        inputdir=OUTDIR+"/seqmapping/barcode"
    
    processedLibs=[]
    for sample in filelist:
        libname=sample['samplename']  
        filename=sample['file_name']
        fastq_dir=sample['fastq_dir']
        dir_id = sample['dir_id']
        backup_dir=sample['backup_dir']
        
        print libname
        print filename
        print fastq_dir
        print backup_dir
        
        if (filename.find(',')!=-1):
            files=filename.split(',')
            totalReads.getCount(JOBSUBMIT, inputdir + "/tmp", fastq_dir,  files[0], dir_id)
            totalReads.getCount(JOBSUBMIT, inputdir + "/tmp", fastq_dir,  files[1], dir_id)
            if (not libname in processedLibs):
                totalReads.gzipFileAndGetCount(JOBSUBMIT, inputdir, libname+".1.fastq", backup_dir)
                totalReads.gzipFileAndGetCount(JOBSUBMIT, inputdir, libname+".2.fastq", backup_dir)
        else:
            totalReads.getCount(JOBSUBMIT, inputdir + "/tmp", fastq_dir,  filename, dir_id)
            if (not libname in processedLibs):
                totalReads.gzipFileAndGetCount(JOBSUBMIT, inputdir, libname+".fastq", backup_dir)
        processedLibs.append(libname)
        
    sys.exit(0)

if __name__ == "__main__":
    main()
