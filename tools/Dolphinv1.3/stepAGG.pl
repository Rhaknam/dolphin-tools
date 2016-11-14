#!/usr/bin/env perl

#########################################################################################
#                                       stepAGG.pl
#########################################################################################
# 
#  This program trims the reads in the files. 
#
#
#########################################################################################
# AUTHORS:
#
# Alper Kucukural, PhD 
# Aug 18, 2014
#########################################################################################

############## LIBRARIES AND PRAGMAS ################

 use List::Util qw[min max];
 use strict;
 use File::Basename;
 use Getopt::Long;
 use Pod::Usage; 

#################### VARIABLES ######################
 my $bedtoolsgencov   = "";
 my $genome           = "";
 my $act              = "";
 my $reference        = "";
 my $creationpdf      = "";
 my $outdir           = "";
 my $type             = "";
 my $jobsubmit        = "";
 my $previous         = ""; 
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $command=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
    'bedtoolsgencov=s' => \$bedtoolsgencov,
    'genome=s'         => \$genome, #(hg19.chromInfo)
    'reference=s'      => \$reference, #(refseq4col)
    'act=s'            => \$act,
    'type=s'           => \$type,
    'creationpdf=s'    => \$creationpdf,
    'outdir=s'         => \$outdir,
    'previous=s'       => \$previous,
    'servicename=s'    => \$servicename,
    'jobsubmit=s'      => \$jobsubmit,
    'help'             => \$help, 
    'version'          => \$print_version,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($act eq "") or ($outdir eq "") );	

################### MAIN PROGRAM ####################
#    maps the reads to the ribosome and put the files under $outdir/after_ribosome directory

my $inputdir = "";
if ($type eq "chip"){
  $inputdir = "$outdir/seqmapping/chip";
}elsif ($type eq "atac"){
  $inputdir = "$outdir/seqmapping/atac";
}else{
  $inputdir = "$outdir/$type";
}

$outdir  = "$outdir/agg";
`mkdir -p $outdir`;
die "Error 15: Cannot create the directory:".$outdir  if ($?);

my $com="";
my $ibam=" -i";
$com=`ls $inputdir/*.adjust.bed 2>&1`;
if ($com =~/No such file or directory/) {
	$ibam=" -ibam";
	$com=`ls $inputdir/*.bam 2>&1`;
	die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);
}

print $com;
my @files = split(/[\n\r\s\t,]+/, $com);

foreach my $file (@files)
{
 die "Error 64: please check the file:".$file unless (checkFile($file));
 
 $file=~/.*\/(.*).adjust.bed/;
 my $bname=$1;
 if ($bname == "") {
	$file=~/.*\/(.*).bam/;
	$bname=$1;
 }
 $bname=~s/\.sorted//g;
 $com = "$bedtoolsgencov -bga$ibam $file -g $genome > $outdir/$bname.bed && ";
 $com.= "awk '{print \\\$1\\\"\\\\t\\\"\\\$2\\\"\\\\t\\\"\\\$4}' $outdir/$bname.bed > $outdir/$bname.sig && ";
 $com.= "$act --output=$outdir/$bname.agg_plot.out $reference $outdir/$bname.sig && ";
 $com.= "$creationpdf --args $outdir/$bname.agg_plot.out ";
 #print $com."\n\n";  
 #`$com`;
 my $job=$jobsubmit." -n ".$servicename."_".$bname." -c \"$com\"";
 print $job."\n";   
 `$job`;
 die "Error 25: Cannot run the job:".$job if ($?);
}

sub checkFile
{
 my ($file) = $_[0];
 return 1 if (-e $file);
 return 0;
}

__END__


=head1 NAME

stepAGG.pl

=head1 SYNOPSIS  

stepAGG.pl -o outdir <output directory> 
            -p previous 
            -n #reads

stepAGG.pl -help

stepAGG.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -o outdir <output directory>

the output files will be "$outdir/split" 

=head2  -p previous

previous step


=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

 This program map the reads to rRNAs and put the rest into other files 

=head1 EXAMPLE


stepAGG.pl 
            -o ~/out
            -n 1000
            -p previous

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


