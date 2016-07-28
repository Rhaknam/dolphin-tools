#!/usr/bin/env perl

#########################################################################################
#                                       stepIGVTDF.pl
#########################################################################################
# 
#  Converts bam files for IGV visualization.
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
 my $genome           = "";
 my $type             = "";
 my $pair             = "";
 my $insertlen        = "";
 my $outdir           = "";
 my $pubdir           = "";
 my $extfactor        = "";
 my $wkey             = "";
 my $samtools         = "";
 my $igvtools         = "";
 my $jobsubmit        = "";
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $cmd=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
    'outdir=s'       => \$outdir,
    'type=s'         => \$type,
    'samtools=s'     => \$samtools,
    'igvtools=s'     => \$igvtools,
    'len=s'          => \$insertlen,
    'pair=s'         => \$pair,
    'pubdir=s'       => \$pubdir,
    'extfactor=s'    => \$extfactor,
    'wkey=s'         => \$wkey,
    'jobsubmit=s'    => \$jobsubmit,
    'servicename=s'  => \$servicename,
    'genome=s'       => \$genome,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($samtools eq "") or ($genome eq "") or ($outdir eq "") );	

 
################### MAIN PROGRAM ####################
#   converts the mapped reads for IGV visualization

my $outd  = "$outdir/tdf_$type";
`mkdir -p $outd`;
die "Error 15: Cannot create the directory:$outd" if ($?);

my $puboutdir   = "$pubdir/$wkey/tdf_$type";
`mkdir -p $puboutdir`;
die "Error 15: Cannot create the directory:$puboutdir" if ($?);

my @files=();
print $type."\n";
my $sorted=".sorted";
if ($type eq "RSEM")
{ 
   my $indir   = "$outdir/rsem";
   @files = <$indir/pipe*/*.genome$sorted.bam>;
   if (@files==0){
      $sorted="";
      @files = <$indir/pipe*/*.genome.bam> 
   }
}
elsif ($type eq "tophat")
{ 
   my $indir   = "$outdir/tophat";
   @files = <$indir/pipe*/*.sorted.bam>;
}
else
{
  my $indir = "$outdir/seqmapping/$type";
  @files = <$indir/*.bam>;
}

my $param="";
if ($extfactor!~/^$/ && $extfactor>0)
{
  $param=" -e $extfactor ";
}
if ($pair eq "paired")
{
  $param.=" --pairs ";
}


foreach my $d (@files){ 
  my ($com, $libname, $dirname)=();
  print $d."\n";

  if ($type eq "RSEM")
  {
     $libname=basename($d, ".genome$sorted.bam");
     $dirname=dirname($d);
     $libname=~s/rsem.out.//g;
     if ($sorted=~/^$/)
     {
       $com=": \\\$( $samtools sort $dirname/rsem.out.$libname.genome.bam $outd/$libname ) && ";
       $com.=": \\\$( $samtools index $outd/$libname.bam ) && ";
     }
     else
     {
       $com="cp $dirname/rsem.out.$libname.genome$sorted.bam $outd/$libname.bam && ";
       $com.="cp $dirname/rsem.out.$libname.genome$sorted.bam.bai $outd/$libname.bam.bai && ";
     }
  }
  else
  {
     $dirname=dirname($d);
     $libname=basename($d, ".sorted.bam") if ($libname =~ /\.sorted.bam/);
     $libname=basename($d, ".bam") if ($libname !~ /\.sorted.bam/);
     
     $com="cp $d $outd/$libname.bam && ";
     $com.="cp $d.bai $outd/$libname.bam.bai && ";
  }
 
  $com.="cd $outdir && $igvtools count -w 5 $param $outd/$libname.bam  $outd/$libname.tdf $genome && "; 
  $com.="cp -R $outd/$libname.* $puboutdir/.";
  my $job=$jobsubmit." -n ".$servicename."_".$libname." -c \"$com\"";
  print $job."\n";   
  `$job`;
  die "Error 25: Cannot run the job:".$job if ($?);
}

__END__


=head1 NAME

stepIGVTDF.pl

=head1 SYNOPSIS  

stepIGVTDF.pl 
            -o outdir <output directory> 
            -g genome <genome files> 
            -s samtools <samtools fullpath> 

stepIGVTDF.pl -help

stepIGVTDF.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -o outdir <output directory>

the output files will be "$outdir/after_ribosome/tdf" 

=head2  -g genome <genome files> 

Genome fasta file. (Full path)

=head2   -t samtools <samtools fullpath> 

Samtools full path

=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

 This program maps the reads using tophat2

=head1 EXAMPLE

stepIGVTDF.pl 
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



