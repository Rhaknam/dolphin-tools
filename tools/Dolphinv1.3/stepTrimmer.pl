#!/usr/bin/env perl

#########################################################################################
#                                       stepTrimmer.pl
#########################################################################################
# 
#  This program trims the reads in the files. 
#
#
#########################################################################################
# AUTHORS:
#
# Alper Kucukural, PhD 
# Jul 4, 2014
#########################################################################################


############## LIBRARIES AND PRAGMAS ################

 use List::Util qw[min max];
 use strict;
 use File::Basename;
 use Getopt::Long;
 use Pod::Usage; 

#################### VARIABLES ######################
 my $trim             = "";
 my $outdir           = "";
 my $jobsubmit        = "";
 my $spaired          = "";
 my $previous         = ""; 
 my $cmd              = ""; 
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $command=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
    'trim=s'         => \$trim,
    'outdir=s'       => \$outdir,
    'dspaired=s'     => \$spaired,
    'previous=s'     => \$previous,
    'cmd=s'          => \$cmd,
    'servicename=s'  => \$servicename,
    'jobsubmit=s'    => \$jobsubmit,
    'help'           => \$help, 
    'version'        => \$print_version,
) or die("Unrecognized optioins.\nFor help, run this script with -help option.\n");

if($help){
    pod2usage( {
		'-verbose' => 2, 
		'-exitval' => 1,
	} );
}

if($print_version){
  print "Version ".$version."\n";
  exit;
}

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($trim eq "") or ($outdir eq "") );	

################### MAIN PROGRAM ####################
#    maps the reads to the ribosome and put the files under $outdir/after_ribosome directory

my $inputdir="";
print "$previous\n";
if ($previous=~/NONE/g)
{
  $inputdir = "$outdir/input";
}
else
{
  $inputdir = "$outdir/seqmapping/".lc($previous);
}

$outdir   = "$outdir/seqmapping/trim";
`mkdir -p $outdir`;
die "Error 15: Cannot create the directory:".$outdir if ($?);

my $com="";
if (lc($spaired)=~/^no/)
{
 $com=`ls $inputdir/*.fastq 2>&1`;
 print $com;
}
else
{
 $com=`ls $inputdir/*.1.fastq 2>&1`;
}
die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);

print $com;
my @files = split(/[\n\r\s\t,]+/, $com);

foreach my $file (@files)
{
 die "Error 64: please check the file:".$file unless (checkFile($file));
 if (lc($spaired)=~/^no/)
 {
    $file=~/.*\/(.*).fastq/;
    my $bname=$1;
    my ($format, $len)=getFormat($file);
    trimFiles($file, $trim, $bname, $format, $len);
 }
 else
 {
    print "PAIRED\n\n";
    $file=~/(.*\/(.*)).1.fastq/;
    my $bname=$2;
    my $file2=$1.".2.fastq";
    die "Error 64: please check the file:".$file2 unless (checkFile($file2));
    $trim=~/([\d]*[:,][\d]*)[:,]([\d]*[:,][\d]*)/;
    my $trim1=$1;
    my $trim2=$2;
	my @nts1=split(/[,:\s\t]+/,$trim1);
	my @nts2=split(/[,:\s\t]+/,$trim2);
	my ($format, $len)=getFormat($file);
	print "[$len]\n";
	trimFiles($file, $trim1, $bname.".1", $format, $len);
	my ($format, $len)=getFormat($file2);
	print "[$len]\n";
	trimFiles($file2, $trim2, $bname.".2", $format, $len);
 }
}

sub trimFiles
{
  my ($file, $trim, $bname, $format, $len)=@_;
    my @nts=split(/[,:\s\t]+/,$trim);
    print "\n$bname\n\n";
    my $inpfile="";
    my $com="";
    my $i=1;
    my $outfile="";
    my $param="";
    my $quality="";
    #if ($format eq "sanger")
    #{   
      $quality="-Q33";
    #}
    if (scalar(@nts)==2)
    {
      $param = "-f ".($nts[0]+1) if (exists($nts[0]) && $nts[0] >= 0 );
      $param .= " -l ".($len-$nts[1]) if (exists($nts[0]) && $nts[1] > 0 );
      $outfile="$outdir/$bname.fastq.$i.tmp";  
      $com="$cmd $quality -v $param -o $outfile -i $file && " if ((exists($nts[0]) && $nts[0] > 0) || (exists($nts[0]) && $nts[1] > 0 ));
      $file=$outfile;
    }
    if ($com!~/^$/)
    {
      $com.="mv $outfile $outdir/$bname.fastq";
      my $job=$jobsubmit." -n ".$servicename."_".$bname." -c \"$com\"";
      print $job."\n";   
      `$job`;
	  die "Error 25: Cannot run the job:".$job if ($?);
    }else{
	  $com="ln -s $file $outdir/$bname.fastq";
	  `$com`;
	  die "Error 25: Cannot run the job:".$com if ($?);
	}
}

# automatic format detection
sub getFormat
{
   my ($filename)=@_;
   # set function variables
   open (IN, $filename);
   my $j=1;
   my $qualities="";
   my $len=0;
   while((my $line=<IN>) && $j<10  )
   {
     chomp($line);
     if ($j%4==0)
     {
        $len=length($line);
  
        $qualities.=$line;
     }
     $j++;
   }
   close(IN);
  
   my $format = "";

   # set regular expressions
   my $sanger_regexp = qr/[!"#$%&'()*+,-.\/0123456789:]/;
   my $solexa_regexp = qr/[\;<=>\?]/;
   my $solill_regexp = qr/[JKLMNOPQRSTUVWXYZ\[\]\^\_\`abcdefgh]/;
   my $all_regexp = qr/[\@ABCDEFGHI]/;

   # set counters
   my $sanger_counter = 0;
   my $solexa_counter = 0;
   my $solill_counter = 0;

   # check qualities
   if( $qualities =~ m/$sanger_regexp/ ){
          $sanger_counter = 1;
   }
   if( $qualities =~ m/$solexa_regexp/ ){
          $solexa_counter = 1;
   }
   if( $qualities =~ m/$solill_regexp/ ){
           $solill_counter = 1;
   }

   # determine format
   if( $sanger_counter ){
        $format = "sanger";
    }elsif( !$sanger_counter && $solexa_counter ){
        $format = "solexa";
    }elsif( !$sanger_counter && !$solexa_counter && $solill_counter ){
        $format = "illumina";
    }

    # return file format
    return( $format, $len );
}



sub checkFile
{
 my ($file) = $_[0];
 return 1 if (-e $file);
 return 0;
}

__END__


=head1 NAME

stepTrimmer.pl

=head1 SYNOPSIS  

stepTrimmer.pl -i input <fastq> 
            -o outdir <output directory> 
            -b bowtieCmd <bowtie dir and file> 
            -p params <bowtie params> 
            -r ribosomeInd <ribosome Index file>

stepTrimmer.pl -help

stepTrimmer.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -i  input file <fastq format> 

fastq files has to be separated with ":". If it is paired end the paired end files has to ber separated by ","

Ex: For single end;

test1.fastq:test2.fastq:ctrl1.fastq:ctrl2.fastq

for paired end;

test1_R1.fastq,test1_R2.fastq:ctrl1_R1.fastq,ctrl1_R2.fastq

    
=head2 -o outdir <output directory>

the output files will be "$outdir/after_ribosome" 

=head2 -b bowtieCmd <bowtie dir and file> 

Fullpath of bowtie executable file. Ex: ~/bowtie_dir/bowtie

=head2  -p params <bowtie params> 

Bowtie running parameteres. Ex: "-p 8 -n 2 -l 20 -M 1 -a --strata --best"

=head2  -r ribosomeInd <ribosome Index file>

Ribosomal index files. Ex: ~/bowtie_ind/rRNA


=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

 This program map the reads to rRNAs and put the rest into other files 

=head1 EXAMPLE


stepTrimmer.pl -i test1.fastq:test2.fastq:ctrl1.fastq:ctrl2.fastq
            -o ~/out
            -b ~/bowtie_dir/bowtie
            -p "-p 8 -n 2 -l 20 -M 1 -a --strata --best"
            -r ~/bowtie_ind/rRNA

=head1 AUTHORS

 Alper Kucukural, PhD

 
=head1 LICENSE AND COPYING

 This program is free software; you can redistribute it and / or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, a copy is available at
 http://www.gnu.org/licenses/licenses.html


