#!/usr/bin/env perl

#########################################################################################
#                                       stepBAM2BW.pl
#########################################################################################
# 
#  Converts bam files for UCSC visualization.
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
 my $genomesize       = "";
 my $type             = "";
 my $GCB              = "";
 my $W2BW             = "";
 my $outdir           = "";
 my $pubdir           = "";
 my $wkey             = "";
 my $jobsubmit        = "";
 my $samtools         = "";
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $command=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
    'outdir=s'       => \$outdir,
    'type=s'         => \$type,
    'coverage=s'     => \$GCB,
    'wig2bigwig=s'   => \$W2BW,
    'samtools=s'     => \$samtools,
    'pubdir=s'       => \$pubdir,
    'wkey=s'         => \$wkey,
    'jobsubmit=s'    => \$jobsubmit,
    'servicename=s'  => \$servicename,
    'genomesize=s'   => \$genomesize,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($W2BW eq "") or ($genomesize eq "") or ($outdir eq "") );	

 
################### MAIN PROGRAM ####################
#   converts the mapped reads for IGV visualization

my $name=basename($outdir);
 
`mkdir -p $outdir/ucsc_$type`;
die "Error 15: Cannot create the directory:$outdir/ucsc_$type" if ($?);

my $puboutdir   = "$pubdir/$wkey";
`mkdir -p $puboutdir`;
die "Error 15: Cannot create the directory:$puboutdir" if ($?);

my @files=();
my $indir="";
my $sorted=".sorted";
if (uc($type) eq "RSEM")
{
   $indir   = "$outdir/rsem";
   @files = <$indir/*/*.genome$sorted.bam>;
   if (@files==0){
     $sorted="";
     @files = <$indir/pipe*/*.genome.bam>;
   }
}
elsif ($type eq "tophat")
{
   $indir   = "$outdir/tophat";
   @files = <$indir/*/*.sorted.bam>;
}
elsif ($type eq "chip")
{
   $indir   = "$outdir/seqmapping/chip";
   @files = <$indir/*.sorted.bam>;
}
elsif ($type eq "atac")
{
	$indir   = "$outdir/seqmapping/atac";
   @files = <$indir/*.sorted.bam>;
}
elsif ($type eq "hisat2")
{
   $indir   = "$outdir/$type";
   @files = <$indir/*/*.sorted.bam>;
}
else
{
   $indir   = "$outdir/$type";
   @files = <$indir/*.bam>;
}

foreach my $d (@files){ 
  my $libname="";
  my $com="";
  if (lc($type) eq "rsem")
  {
     $libname=basename($d, ".genome$sorted.bam");
     if ($sorted=~/^$/)
     { 
       $com.=" $samtools sort $d $outdir/ucsc_$type/$libname && ";
       $com.=" $samtools index $outdir/ucsc_$type/$libname.bam && ";
       $d="$outdir/ucsc_$type/$libname.bam";
     }
  }
  else
  {
     $libname=basename($d, ".sorted.bam") if ($libname =~ /\.sorted.bam/);
     $libname=basename($d, ".bam") if ($libname !~ /\.sorted.bam/);
  }
  my $outputbg="$outdir/ucsc_$type/$libname.bg";
  my $outputbw="$outdir/ucsc_$type/$libname.bw";

  $com.= "$GCB -split -bg -ibam $d -g $genomesize > $outputbg && ";
  $com.= "$W2BW -clip -itemsPerSlot=1 $outputbg $genomesize $outputbw && ";
  $com.="rm -rf $outputbg && ";
  $com.="mkdir -p $puboutdir/ucsc_$type && ";
  $com.="cp -R $outdir/ucsc_$type/*.bw $puboutdir/ucsc_$type/.";

  my $job=$jobsubmit." -n ".$servicename."_".$libname." -c \"$com\"";
  print "\n".$job."\n";   
  `$job`;
  die "Error 25: Cannot run the job:".$job if ($?);
}

__END__


=head1 NAME

stepBAM2BW.pl

=head1 SYNOPSIS  

stepBAM2BW.pl 
            -o outdir <output directory> 
            -g genomesize <genome size file> 

stepBAM2BW.pl -help

stepBAM2BW.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -o outdir <output directory>

the output files will be "$outdir/after_ribosome/tdf" 

=head2  -g genomesize <genome size file> 

Genome size file. (Full path)

Samtools full path

=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

 This program maps the reads using tophat2

=head1 EXAMPLE

stepBAM2BW.pl 
            -o outdir <output directory> 
            -g genome <genome files> 
            -s samtools <samtools fullpath> 

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



