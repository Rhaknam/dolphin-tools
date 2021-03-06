#!/share/bin/python

from optparse import OptionParser
import warnings

import sys

import os
import re
import time


class File(file):
    """ An helper class for file reading  """

    def __init__(self, *args, **kwargs):
        super(File, self).__init__(*args, **kwargs)
        self.BLOCKSIZE = 4096

    def head(self, lines_2find=1):
        self.seek(0)                            #Rewind file
        return [super(File, self).next() for x in xrange(lines_2find)]

    def tail(self, lines_2find=1):  
        self.seek(0, 2)                         #Go to end of file
        bytes_in_file = self.tell()
        lines_found, total_bytes_scanned = 0, 0
        while (lines_2find + 1 > lines_found and
               bytes_in_file > total_bytes_scanned): 
            byte_block = min(
                self.BLOCKSIZE,
                bytes_in_file - total_bytes_scanned)
            self.seek( -(byte_block + total_bytes_scanned), 2)
            total_bytes_scanned += byte_block
            lines_found += self.read(self.BLOCKSIZE).count('\n')
        self.seek(-total_bytes_scanned, 2)
        line_list = list(self.readlines())
        return line_list[-lines_2find:]

    def backward(self):
        self.seek(0, 2)                         #Go to end of file
        blocksize = self.BLOCKSIZE
        last_row = ''
        while self.tell() != 0:
            try:
                self.seek(-blocksize, 1)
            except IOError:
                blocksize = self.tell()
                self.seek(-blocksize, 1)
            block = self.read(blocksize)
            self.seek(-blocksize, 1)
            rows = block.split('\n')
            rows[-1] = rows[-1] + last_row
            while rows:
                last_row = rows.pop(-1)
                if rows and last_row:
                    yield last_row
        yield last_row

def simplecount(fname):
   command=command = "wc -l "+str(fname)
   child = os.popen(command)
   result = child.read()
   err = child.close()
   if err:
        raise RuntimeError, 'ERROR: %s failed w/ exit code %d' % (command, err) 
  

   return int(result.strip().split()[0])

def main():

    try:
        parser = OptionParser()
        parser.add_option('-f', '--filename', help='filename', dest='filename')
        (options, args) = parser.parse_args()
    except:
        print "OptionParser Error:for help use --help"
        sys.exit(2)

    FILENAME = options.filename
    count = simplecount(str(FILENAME))
    
  
    with File(str(FILENAME)) as f:
       if (count<40):
          for row in f.head(count):
             print row.rstrip()
       else:
          for row in f.head(20):
             print row.rstrip()
          print "...\n"
          for row in f.tail(20):
             print row.rstrip()


if __name__ == "__main__":
    main()
