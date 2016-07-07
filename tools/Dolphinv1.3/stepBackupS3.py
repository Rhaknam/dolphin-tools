#!/usr/bin/env python

import ConfigParser, os, re, string, sys, commands
import warnings
import json

import boto3
from boto3.s3.transfer import S3Transfer
from botocore.client import Config
from sys import argv, exit, stderr
from optparse import OptionParser
from binascii import hexlify, unhexlify
from simplecrypt import encrypt, decrypt

sys.path.insert(0, sys.path[0]+"/../../src")
from config import *
from funcs import *

class stepBackup:
  url=""
  f=""
  def __init__(self, url, f ):
      self.url = url
      self.f = f
      
  def getSampleList(self, runparamsid, barcode):  
    data = urllib.urlencode({'func':'getSampleList', 'runparamsid':str(runparamsid), 'barcode':str(barcode)})
    ret = self.f.queryAPI(self.url, data, "getSampleList:"+runparamsid)
    if (ret):
       ret=json.loads(ret)
    return ret
  
  def uploadFile(self, amazon, amazon_bucket, fastq_dir, filename ):
    try:
       passgrab = ConfigParser.ConfigParser()
       passgrab.readfp(open('config/.salt'))
       s3 = boto3.resource('s3', 'us-east-1',
       aws_access_key_id=decrypt(passgrab.get('Dolphin', 'AMAZON_SALT'), unhexlify(amazon['aws_access_key_id'])),
       aws_secret_access_key=decrypt(passgrab.get('Dolphin', 'AMAZON_SALT'), unhexlify(amazon['aws_secret_access_key'])),
       config=Config(signature_version='s3v4'))

       p = amazon_bucket.split("/")
       s3_file_name = "%s/%s"%(str(re.sub(p[0]+'/', '', amazon_bucket)), filename)
       inputfile = "%s/%s"%(fastq_dir.strip(), filename)
       amazon_bucket = p[0]

       print 'Upload started[%s]=>[%s]'%(inputfile, s3_file_name)
       s3_bucket = s3.Bucket(str(amazon_bucket))

       s3_object = s3_bucket.Object(s3_file_name)
       mpu = s3_object.initiate_multipart_upload()

       # chunk , min size 5mb
       CHUNK = 5 * 1024 * 1024

       part_info = {
           'Parts': []
       }

       with open(inputfile, 'rb') as f:

          while True:

            # read chunk from file
            chunk = f.read(CHUNK)

            if not chunk:
                # complete
                mpu.complete(MultipartUpload=part_info)
                break

            # part number
            part_nr = len(part_info['Parts'])+1
            # create part
            part = mpu.Part(part_nr)

            # upload
            response = part.upload(Body=chunk)

            # add part
            part_info['Parts'].append({
                'PartNumber': part_nr,
                'ETag': response['ETag'] 
            })

    except Exception, ex:
        self.stop_err('Error (line:%s)running stepBackupS3.py\n%s'%(format(sys.exc_info()[-1].tb_lineno), str(ex)))

  def getAmazonCredentials(self, username):
    data = urllib.urlencode({'func':'getAmazonCredentials', 'username':username})
    ret = self.f.queryAPI(self.url, data, "getAmazonCredentials:"+str(username))
    if (len(ret)>2):
      ret=json.loads(ret)[0]
    else:
      ret=''
    return ret

  def updateInitialFileCounts(self, file_id, tablename, inputdir, filename, paired, dir_id):
   try: 
      count=-1
      if (paired):
          files=filename.split(',')
          firstCount=self.getValfromFile(inputdir+'/tmp/'+files[0]+'.'+dir_id+'.count')
          secondCount=self.getValfromFile(inputdir+'/tmp/'+files[1]+'.'+dir_id+'.count')
  
          if (firstCount == secondCount):
              count=firstCount
          else:
              print "ERROR 85: The # of reads in paired end libary not equal"
              print "%s"%(inputdir+'/tmp/'+files[0]+'.count')
              print "%s"%(inputdir+'/tmp/'+files[1]+'.count')
              #sys.exit(85)
      else:
          count=self.getValfromFile(inputdir+'/tmp/'+filename+'.'+dir_id+'.count')
      if (count != ""):
         data = urllib.urlencode({'func':'updateInitialFileCounts', 'tablename':str(tablename), 'total_reads':str(count), 'file_id':str(file_id)})
         ret = eval(self.f.queryAPI(self.url, data, "updateInitialFileCounts:"+str(count)))
   except Exception, ex:
      self.stop_err('Error (line:%s)running stepBackupS3.py updateInitialFileCounts\n%s'%(format(sys.exc_info()[-1].tb_lineno), str(ex)))



  def getValfromFile(self,filename):
    val=''
    if (os.path.isfile(filename)):
    	infile = open(filename)
    	val = infile.readlines()[0].rstrip()
    else:
        print "Filename:"+filename
        sys.exit(84)
    return val

  def getFastqFileId(self, sample):
    data = urllib.urlencode({'func':'getFastqFileId', 'sample_id':str(sample['sample_id'])})
    ret = self.f.queryAPI(self.url, data, "getFastqFileId:"+str(sample['sample_id']))
    ret=json.loads(ret)
    if (len(ret)>0):
      ret=ret[0]['sample_id']
    else:
      ret=0
    return ret

  def updateFastqFile(self, md5sum, count, filename, sample):
    sample_id=sample['sample_id']
    owner_id=sample['owner_id']
    if (count!=""):
       data = urllib.urlencode({'func':'upadateFastqFile', 'sample_id':str(sample_id), 'owner_id':str(owner_id), 'md5sum':str(md5sum), 'total_reads':str(count)})
       ret = eval(self.f.queryAPI(self.url, data, "upadateFastqFile:"+str(sample_id)))
    
  def insertFastqFile(self, checksum, total_reads, filename, sample):
    if (total_reads != ""):
       data = urllib.urlencode({'func':'insertFastqFile', 'filename':str(filename),'total_reads':str(total_reads),'checksum':str(checksum), 'sample_id':str(sample['sample_id']),'lane_id':str(sample['lane_id']),'dir_id': str(sample['dir_id']),'owner_id':str(sample['owner_id']), 'group_id':str(sample['group_id']), 'perms':str(sample['perms'])})
       ret = eval(self.f.queryAPI(self.url, data, "insertFastqFile:"+str(sample['sample_id'])))
    
  def checkReadCounts(self, sample_id, tablename):
    data = urllib.urlencode({'func':'checkReadCounts', 'sample_id':str(sample_id), 'tablename':str(tablename)})
    ret = self.f.queryAPI(self.url, data, "checkReadCounts:"+str(sample_id))
    ret = json.loads(ret)
    return ret['Result']
    
    
  def processFastqFiles(self, sample, paired):
    try:
      md5sum=''
      count=''
      libname=sample['samplename']
      backup_dir=sample['backup_dir']
      filename=''

      if (paired):
          firstCount=self.getValfromFile(backup_dir+'/'+libname+'.1.fastq.gz.count')
          secondCount=self.getValfromFile(backup_dir+'/'+libname+'.2.fastq.gz.count')
          if (firstCount == secondCount):
              count=firstCount
              filename= libname+'.1.fastq.gz,'+libname+'.2.fastq.gz'
              firstmd5sum=self.getValfromFile(backup_dir+'/'+libname+'.1.fastq.gz.md5sum').split(' ')[0]
              secondmd5sum=self.getValfromFile(backup_dir+'/'+libname+'.2.fastq.gz.md5sum').split(' ')[0]
              md5sum=firstmd5sum+','+secondmd5sum
          else:
              print "ERROR 85: The # of reads in paired end libary not equal"
              print "%s"%(backup_dir+'/'+libname+'.1.fastq.gz.count')
              #sys.exit(85)
      else:
          filename= libname+'.fastq.gz'
          count=self.getValfromFile(backup_dir+'/'+libname+'.fastq.gz.count')
          md5sum=self.getValfromFile(backup_dir+'/'+libname+'.fastq.gz.md5sum').split(' ')[0]
      sample_id=self.getFastqFileId(sample)
      
      if (sample_id>0):
          self.updateFastqFile( md5sum, count, filename, sample)
      else:
          self.insertFastqFile(md5sum, count, filename, sample)

    except Exception, ex:
      self.stop_err('Error (line:%s)running stepBackupS3.py processFastqFiles\n%s'%(format(sys.exc_info()[-1].tb_lineno), str(ex)))


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
        parser.add_option('-p', '--pairedend', help='pairedend', dest='paired')
        parser.add_option('-a', '--amazonupload', help='amazonupload', dest='amazonupload')
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
  AMAZONUPLOAD            = options.amazonupload
  CONFIG                  = options.config

  f = funcs()
  config = getConfig(CONFIG)
  backup = stepBackup(config['url'], f)
  
  try:
    if (OUTDIR == None or JOBSUBMIT == None):
        print "for help use --help"
        sys.exit(2)

    print BARCODE
    print PAIRED
    print JOBSUBMIT
    print OUTDIR
    print USERNAME
    
    amazon = backup.getAmazonCredentials(USERNAME)
     
    samplelist=backup.getSampleList(RUNPARAMSID, BARCODE)
    
    inputdir=OUTDIR+"/input"
    tablename="ngs_temp_sample_files"
    if (BARCODE != "NONE"):
        inputdir=OUTDIR+"/seqmapping/barcode"
        tablename="ngs_temp_lane_files"
    
    processedLibs=[]
    amazon_bucket=""
    for sample in samplelist:
        sample_id=sample['sample_id']
        file_id=sample['file_id']
        libname=sample['samplename']  
        filename=sample['file_name']
        backup_dir=sample['backup_dir']
        amazon_bucket=sample['amazon_bucket']
        dir_id=sample['dir_id']

        PAIRED=None
        if (filename.find(',')!=-1):
           PAIRED="Yes"
    
        backup.updateInitialFileCounts(file_id, tablename, inputdir, filename, PAIRED, dir_id)
        if (not [libname, sample_id] in processedLibs):
            backup.processFastqFiles(sample, PAIRED)
            processedLibs.append([libname, sample_id])
    print processedLibs

    if (AMAZONUPLOAD.lower() != "no" and amazon!=() and amazon_bucket!=""):
      amazon_bucket = str(re.sub('s3://', '', amazon_bucket))
      for libname, sample_id in processedLibs:
        print libname + ":" + str(sample_id)
        if (backup.checkReadCounts(sample_id, tablename) and amazon):
            if (filename.find(',')!=-1):
                files=filename.split(',')
                backup.uploadFile(amazon, amazon_bucket, backup_dir, libname+'.1.fastq.gz' )
                backup.uploadFile(amazon, amazon_bucket, backup_dir, libname+'.2.fastq.gz' )
            else:
                backup.uploadFile(amazon, amazon_bucket, backup_dir, libname+'.fastq.gz' )
        else:
            print "ERROR 86: The # of read counts doesn't match: %s",libname
            sys.exit(86)
  except Exception, ex:
        backup.stop_err('Error (line:%s)running stepBackupS3.py\n%s'%(format(sys.exc_info()[-1].tb_lineno), str(ex)))

  sys.exit(0)

if __name__ == "__main__":
    main()
