#!/usr/bin/env python
 
import os, re, string, sys, cgi
import warnings
import json
import time
import urllib,urllib2
from optparse import OptionParser
sys.path.insert(0, sys.path[0]+"/../../src")
from config import *
from funcs import *

class stepMD5Sum:
    url=""
    f=""
    def __init__(self, url, f ):
        self.url = url
        self.f = f
    def calcMD5Sum(self, file_name, backup_dir):
        files=file_name.split(',')
        if (len(files)>1):
            hashstr1=calcHash(backup_dir + "/" + files[0].strip())
            hashstr2=calcHash(backup_dir + "/" + files[1].strip())
            hashstr=hashstr1+","+hashstr2
        else:
            hashstr=calcHash(backup_dir + "/" + input.strip())
        print hashstr
        return hashstr
    def runDBMD5SumUpdate(self, backup_dir, file_name, calcsum):
        data = urllib.urlencode({'func':'dbMd5sumUpdate', 'md5sum':str(calcsum), 'backup_dir':str(backup_dir), 'file_name':str(file_name)})
        ret = self.f.queryAPI(self.url, data)

def getValfromFile(filename):
    val=''
    if (os.path.isfile(filename)):
        infile = open(filename+".md5sum")
        val = infile.readlines()[0].rstrip()
    else:
        val = "none"
    return val

def calcHash(inputfile):
    command ="md5sum "+inputfile+" > "+inputfile+".md5sum;"
    print command
    child = os.popen(command)
    jobout = child.read().rstrip()
    err = child.close()
    hashstr = getValfromFile(inputfile).split(" ")[0]
    child = os.popen(command)
    print hashstr
    return hashstr

def main():
    try:
        parser = OptionParser()
        parser.add_option('-o', '--outdir', help='output directory', dest='outdir')
        parser.add_option('-f', '--file', help='file', dest='file')
        parser.add_option('-u', '--username', help='username', dest='username')
        parser.add_option('-c', '--config', help='config parameters section', dest='config')
        (options, args) = parser.parse_args()
    except:
        parser.print_help()
        print "Fail Try\n"
        print "for help use --help"
        sys.exit(2)
    
    FILE                    = options.file
    USERNAME                = options.username
    OUTDIR                  = options.outdir
    CONFIG                  = options.config
    
    f = funcs()
    config = getConfig(CONFIG)
    md5sum = stepMD5Sum(config['url'], f)
    calcsum = md5sum.calcMD5Sum(FILE, OUTDIR)
    print calcsum
    if calcsum == "none,none" or calcsum == "none":
        md5sum.runDBMD5SumUpdate(OUTDIR, FILE, "NULL")
    else:    
        md5sum.runDBMD5SumUpdate(OUTDIR, FILE, calcsum)
    
main()