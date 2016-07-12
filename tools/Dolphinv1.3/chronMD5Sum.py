#!/usr/bin/env python
 
import os, re, string, sys
import warnings
import json
import time
import urllib,urllib2
from sys import argv, exit, stderr
from optparse import OptionParser
sys.path.insert(0, sys.path[0]+"/../../src")
from config import *
from funcs import *

class chronMD5Sum:
    url=""
    f=""
    def __init__(self, url, f ):
        self.url = url
        self.f = f
    def getAllFastqInfo(self):  
        data = urllib.urlencode({'func':'getAllFastqInfo'})
        ret = self.f.queryAPI(self.url, data)
        if (ret):
            ret=json.loads(ret)
        return ret
    def runMD5SumUpdate(self, clusteruser, backup_dir, file_name):
        data = urllib.urlencode({'func':'runMD5SumUpdate', 'clusteruser':str(clusteruser), 'backup_dir':str(backup_dir), 'file_name':str(file_name)})
        ret = self.f.queryAPI(self.url, data)
    
def main():
    try:
        parser = OptionParser()
        parser.add_option('-c', '--config', help='config parameters section', dest='config')
        (options, args) = parser.parse_args()
    except:
        parser.print_help()
        print "for help use --help"
        sys.exit(2)
    
    CONFIG                  = options.config
    
    f = funcs()
    config = getConfig(CONFIG)
    md5sum = chronMD5Sum(config['url'], f)
    
    filelist = md5sum.getAllFastqInfo()
    print "\n"
    for f in filelist:
        clusteruser=f['clusteruser']
        backup_dir=f['backup_dir']
        file_name=f['file_name']
        print file_name
        md5sum.runMD5SumUpdate(clusteruser, backup_dir, file_name)
        print "\n"
    
main()