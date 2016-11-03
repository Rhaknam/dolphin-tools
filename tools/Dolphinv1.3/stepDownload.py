#!/usr/bin/env python

import ConfigParser, os, re, string, sys, commands
import warnings
import json
import GEOparse
from sys import argv, exit, stderr
from optparse import OptionParser

sys.path.insert(0, sys.path[0]+"/../../src")
from config import *
from funcs import *

class stepDownload:
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
  
  def getGSMs(self, runparamsid):  
    data = urllib.urlencode({'func':'getGSMs', 'runparamsid':str(runparamsid)})
    ret = self.f.queryAPI(self.url, data, "getGSMs:"+runparamsid)
    if (ret):
       ret=json.loads(ret)
    return ret

  def submitJob(self, JOBSUBMIT, name, command):
    child = os.popen(JOBSUBMIT+' -n stepDownLoad_'+name+' -c "'+command+'"')
    print JOBSUBMIT+' -n stepDownload_'+name+' -c "'+command+'"'+"\n\n"
    jobout = child.read().rstrip()
    err = child.close()
    return jobout

  def parseGEO(self, name, sra_file, outdir, run_id, FASTQDUMP, JOBSUBMIT):
    geo_accession = sra_file.split(".")[0]
    geo_dir = outdir+'/geo'
    geo_sample_dir = geo_dir+"/"+geo_accession
    child = os.popen('mkdir -p '+geo_dir)
    err = child.close()
    geo = GEOparse.get_GEO(geo=geo_accession, destdir=geo_dir)
    geo.download_SRA('alper.kucukural@umassmed.edu', filetype='sra', directory=geo_dir)
    print 'mkdir -p '+geo_sample_dir+' && mv '+geo_dir+'/Supp_'+geo_accession+'*/*.sra '+geo_sample_dir+' && '+FASTQDUMP+' --split-files '+geo_sample_dir+'/*.sra'
    child2 = os.popen('mkdir -p '+geo_sample_dir+' && mv '+geo_dir+'/Supp_'+geo_accession+'*/*.sra '+geo_sample_dir+' && cd '+geo_sample_dir+' && '+FASTQDUMP+' --split-files '+geo_sample_dir+'/*.sra')
    file_list = child2.read().rstrip()
    print file_list
    err = child2.close()
    
  def cleanGEO(self, sample_id, sra_file, name, fastq_dir, outdir, run_id):
    geo_accession = sra_file.split(".")[0]
    geo_dir = outdir+'/geo'
    geo_sample_dir = geo_dir+"/"+geo_accession
    child = os.popen('ls '+geo_sample_dir+'/*.fastq')
    file_list = child.read().rstrip()
    err = child.close()
    file_array = file_list.split("\n")
    for fastq in file_array:
        paired = False
        print fastq
        if "_1.fastq" in fastq:
            child2 = os.popen('mv '+geo_sample_dir+'/*_1.fastq '+fastq_dir+'/'+name+'_1.fastq')
            err = child2.close()
        if "_2.fastq" in fastq:
            paired = True
            child2 = os.popen('mv '+geo_sample_dir+'/*_2.fastq '+fastq_dir+'/'+name+'_2.fastq')
            err = child2.close()
    
  # error
  def stop_err(self, msg ):
        sys.stderr.write( "%s\n" % msg )
        sys.exit(2)

def main():
  try:
        parser = OptionParser()
        parser.add_option('-b', '--barcode', help='barcode', dest='barcode')
        parser.add_option('-j', '--jobsubmit', help='jobsubmit', dest='jobsubmit')
        parser.add_option('-r', '--runparamsid', help='group id', dest='runparamsid')
        parser.add_option('-u', '--username', help='username', dest='username')
        parser.add_option('-f', '--fastqdump', help='fastqdump', dest='fastqdump')
        parser.add_option('-o', '--outdir', help='output directory', dest='outdir')
        parser.add_option('-c', '--config', help='config parameters section', dest='config')

        (options, args) = parser.parse_args()
  except:
        parser.print_help()
        print "for help use --help"
        sys.exit(2)


  BARCODE                 = options.barcode
  USERNAME                = options.username
  FASTQDUMP               = options.fastqdump
  RUNPARAMSID             = options.runparamsid
  JOBSUBMIT               = options.jobsubmit
  OUTDIR                  = options.outdir
  CONFIG                  = options.config

  f = funcs()
  config = getConfig(CONFIG)
  download = stepDownload(config['url'], f)
  
  if (OUTDIR == None or JOBSUBMIT == None):
    print "for help use --help"
    sys.exit(2)

  print BARCODE
  print JOBSUBMIT
  print OUTDIR
  print USERNAME
  
  filelist=download.getFileList(RUNPARAMSID, BARCODE)
  sralist=download.getGSMs(RUNPARAMSID)
  print filelist;
  
  for sample in filelist:
    libname=sample['samplename']
    sample_id=sample['sample_id']
    filename=sample['file_name']
    fastq_dir=sample['fastq_dir']
    dir_id = sample['dir_id']
    backup_dir=sample['backup_dir']
    for gsm in sralist:
      if sample_id == gsm['id']:
        sra_file = gsm['title']
    
    print libname
    print filename
    print fastq_dir
    print backup_dir
    
    download.parseGEO(libname, sra_file, OUTDIR, RUNPARAMSID, FASTQDUMP, JOBSUBMIT)
    download.cleanGEO(sample_id, sra_file, libname, fastq_dir, OUTDIR, RUNPARAMSID)
  sys.exit(0)
    
if __name__ == "__main__":
    main()
    