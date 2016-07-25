#!/usr/bin/env perl

#########################################################################################
#                                       stepQuality.pl
#########################################################################################
# 
#  This program is for quality trimming  
#
#
#########################################################################################
# AUTHORS:
#
# Alper Kucukural, PhD 
# Aug 20, 2014
#########################################################################################


############## LIBRARIES AND PRAGMAS ################

 use List::Util qw[min max];
 use strict;
 use File::Basename;
 use Getopt::Long;
 use Pod::Usage; 

#################### VARIABLES ######################
 my $quality          = "";
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
    'quality=s'      => \$quality,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($quality eq "") or ($outdir eq "") );	

################### MAIN PROGRAM ####################
# Filters out low quality reads

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

$outdir   = "$outdir/seqmapping/quality";
`mkdir -p $outdir`;
die "Error 15: Cannot create the directory:".$outdir  if ($?);

my $com="";
if (lc($spaired) =~ /^no/)
{
 $com=`ls $inputdir/*.fastq 2>&1`;
}
else
{
 $com=`ls $inputdir/*.1.fastq 2>&1`;
}
die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);

print $com;
my @files = split(/[\n\r\s\t,]+/, $com);

my @quals=split(/:/,$quality);
my $param="SLIDINGWINDOW:".$quals[0].":".$quals[1];
$param.=" LEADING:".$quals[2];
$param.=" TRAILING:".$quals[3];
$param.=" MINLEN:".$quals[4];

foreach my $file (@files)
{
 die "Error 64: please check the file:".$file unless (checkFile($file));
 my $format=getFormat($file);
 my $quality="";
 if ($format eq "sanger")
 {   
   $quality="-phred33";
 }
 elsif ($format eq "ilumina")
 {
   $quality="-phred64";
 }


 my $bname="";
 my $pairtypecmd = "";
 if (lc($spaired) =~/^no/)
 {
    $file=~/.*\/(.*).fastq/;
    $bname=$1;
    print $file."\n\n";
	$pairtypecmd = "Surviving: 0";
    $com="$cmd SE -threads 1 $quality -trimlog $outdir/$bname.log $file $outdir/$bname.fastq $param &> $outdir/".$bname."_summary.log && cat $outdir/$bname\_summary.log";  
 }
 else
 {
    print "PAIRED\n\n";
    $file=~/(.*\/(.*)).1.fastq/;
    $bname=$2;
    my $file2=$1.".2.fastq";
    die "Error 64: please check the file:".$file2 unless (checkFile($file2));
    print "$file:$file2\n\n";
	$pairtypecmd = "Both Surviving: 0";
    $com="$cmd PE -threads 1 $quality -trimlog $outdir/$bname.log $file $file2 $outdir/$bname.1.fastq $outdir/$bname.1.fastq.unpaired $outdir/$bname.2.fastq $outdir/$bname.1.fastq.unpaired $param &> $outdir/".$bname."_summary.log && cat $outdir/$bname\_summary.log";  
 }
 
 my $job=$jobsubmit." -n ".$servicename."_".$bname." -c \"$com\"";
 print $job."\n";
 `$job`;
 die "Error 25: Cannot run the job:".$job if ($?);
 my $jobbool = 0;
 my $jobout = `cat $outdir/$bname\_summary.log`;
 $jobbool = 1 if (`grep "$pairtypecmd" $outdir/$bname\_summary.log` ne "");
 die "Error 25: Quality step returns 0 surviving reads, job:".$jobout if ($jobbool)
}

# automatic format detection
sub getFormat
{
   my ($filename)=@_;

   # set function variables
   open (IN, $filename);
   my $j=1;
   my $qualities="";
   while(my $line=<IN> && $j<10 )
   {
     if ($j%4==0)
     {
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
    return( $format );
}


sub checkFile
{
 my ($file) = $_[0];
 return 1 if (-e $file);
 return 0;
}

__END__


=head1 NAME

stepQuality.pl

=head1 SYNOPSIS  

stepQuality.pl -i input <fastq> 
            -o outdir <output directory> 

stepQuality.pl -help

stepQuality.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -i  input file <fastq format> 

Ex: For single end;

=head2 -o outdir <output directory>

the output files will be "$outdir/after_ribosome" 

=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

This program is for quality trimming  

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


