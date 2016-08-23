#!/bin/env python
import os,sys
from optparse import OptionParser
from ConfigParser import SafeConfigParser

def getConfig(params_section):
   parser = SafeConfigParser()
   filename = sys.path[0]+"/../default_params/config.ini"
   
   #if (not params_section):
   #   params_section = "Biocore"

   parser.read(filename)
   if (os.environ.has_key('DOLPHIN_PARAMS_SECTION')):
      params_section=os.environ['DOLPHIN_PARAMS_SECTION']

   config={}
   for name, value in parser.items(params_section):
      config[name]=value
   return config

def main():

   try:
      config = getConfig()
      print config
   except:
      sys.exit(2)

if __name__ == "__main__":
    main()



