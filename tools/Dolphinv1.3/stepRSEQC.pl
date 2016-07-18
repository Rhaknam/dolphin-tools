#!/usr/bin/env perl

#########################################################################################
#                                       stepRSEQC.pl
#########################################################################################
# 
#  This program runs the RSeQC 
#
#########################################################################################
# AUTHORS:
#
# Alper Kucukural, PhD 
# 
#########################################################################################

############## LIBRARIES AND PRAGMAS ################

 use List::Util qw[min max];
 use strict;
 use File::Basename;
 use Getopt::Long;
 use Pod::Usage; 
 
#################### VARIABLES ######################
 my $bed12file        = "";
 my $outdir           = "";
 my $rseqccmd         = "";
 my $type             = "";
 my $jobsubmit        = "";
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $cmd=$0." ".join(" ",@ARGV); ####command line copy

GetOptions(
    'outdir=s'        => \$outdir,
    'bed12file=s'     => \$bed12file,
    'rseqccmd=s'      => \$rseqccmd,
    'type=s'          => \$type,
    'jobsubmit=s'     => \$jobsubmit,
    'servicename=s'   => \$servicename,
    'help'            => \$help, 
    'version'         => \$print_version,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($outdir eq "") or ($bed12file eq "") );	

################### MAIN PROGRAM ####################
# runs the picard program

my $outd  = "$outdir/RSeQC_$type";

`mkdir -p $outd`;

my @files=();
print $type."\n";
my $indir = "";
my $sorted=".sorted";
if (lc($type) eq "rsem")
{ 
   $indir   = "$outdir/rsem";
   @files = <$indir/pipe*/*.genome.sorted.bam>;
   if (@files==0){
      $sorted="";
      @files = <$indir/pipe*/*.genome.bam> 
   }
}
elsif(lc($type) eq "tophat")
{
   $indir   = "$outdir/tophat";
   print $indir."\n";
   @files = <$indir/pipe*/*.sorted.bam>;
}
elsif (lc($type) eq "hisat2")
{
   my $indir   = "$outdir/hisat2";
   print $indir."\n";
   @files = <$indir/pipe*/*.sorted.bam>;
}
elsif (lc($type) eq "star")
{
   my $indir   = "$outdir/star";
   print $indir."\n";
   @files = <$indir/pipe*/*.sorted.bam>;
}
else
{
   $indir   = "$outdir/$type";
   print $indir."\n";
   @files = <$indir/*.bam>;
}

foreach my $d (@files){ 
  my $dirname=dirname($d);
  my $libname=basename($d, "$sorted.bam");
  my $com="$rseqccmd -i $d -r $bed12file > $outd/RSeQC.$libname.out"; 
  
  my $job=$jobsubmit." -n ".$servicename."_".$libname." -c \"$com\"";
  print "\n\n".$com."\n\n";
  `$job`;
  die "Error 25: Cannot run the job:".$job if ($?);
}
__END__


=head1 NAME

stepRSEQC.pl

=head1 SYNOPSIS  

stepRSEQC.pl 
            -o outdir <output directory> 
            -b bedfile <bed file> 
            -r rseqccmd <picard full path> 

stepRSEQC.pl -help

stepRSEQC.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -o outdir <output directory>

the output files will be stored

=head2 -r rseqccmd <rseqc command> 

=head2  -b bedile <bedfile>  

ucsc refflat file

=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

This program runs RSEQC program

=head1 EXAMPLE

stepRSEQC.pl 
            -o outdir <output directory> 
            -b bedfile <bed file> 
            -r rseqccmd <picard full path>
            
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

