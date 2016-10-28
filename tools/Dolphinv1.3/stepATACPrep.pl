#!/usr/bin/env perl

#########################################################################################
#                                    StepATACPrep.pl
#########################################################################################
# 
#  This program preps reads with custom ATAC Seq parameters
#
#
#########################################################################################
# AUTHORS:
#
# Nicholas Merowsky
# Oct 28, 2016
#########################################################################################

############## LIBRARIES AND PRAGMAS ################

 use List::Util qw[min max];
 use strict;
 use File::Basename;
 use Getopt::Long;
 use Pod::Usage; 

#################### VARIABLES ######################
 my $outdir           = "";
 my $previous         = "";
 my $jobsubmit        = "";
 my $type             = "";
 my $cutadjust        = "";
 my $genome           = "";
 my $bedtools         = "";
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $cmd=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
    'outdir=s'       => \$outdir,
	'previous=s',    => \$previous,
    'type=s'         => \$type,
	'genome=s'       => \$genome, 
	'cutajdust=s'    => \$cutadjust,
	'bedtools=s'     => \$bedtools,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($outdir eq "") );	

################### MAIN PROGRAM ####################
#  It runs macs14 to find the peaks using alined peaks   

my $inputdir = "";
if ($type eq "atac")
{
  $inputdir = "$outdir/seqmapping/atac";
}
else
{
  $inputdir = "$outdir/$type";
}


$outdir  = "$outdir/atac_prep";
`mkdir -p $outdir`;
die "Error 15: Cannot create the directory:$outdir" if ($?);

my $com = "";
$com=`ls $inputdir/*.sorted.bam 2>&1`;
die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);
print $com;
my @files = split(/[\n\r\s\t,]+/, $com);
my $jobcom = "";
foreach my $file (@files){
	$file=~/(.*\/(.*)).sorted.bam/;
	my $bname=$2;
	$jobcom .= "$bedtools bamtobed -i $file | awk '\$5 >= 4 {print}' - > $outdir/$bname.sorted.bed";
	$jobcom .= " && ";
	$jobcom .= "$cutadjust $bname.sorted.bed $outdir $genome";
	$jobcom .= " && ";
	$jobcom .= "$bedtools bedtobam -i $outdir/$bname.sorted.adjust.bed -g $genome > $outdir/$bname.sorted.adjust.bam";
	my $job=$jobsubmit." -n ".$servicename."_".$bname." -c \"$com\"";
	print $job."\n";   
	`$job`;
	die "Error 25: Cannot run the job:".$job if ($?);
}

__END__

=head1 NAME

stepATACPrep.pl

=head1 SYNOPSIS  

stepMACS.pl -o outdir <output directory> 
            -p previous

stepMACS.pl -help

stepMACS.pl -version

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

This program alters bam files for custom atacseq parameters

=head1 EXAMPLE


stepATACPrep.pl 
            -o ~/out
            -p previous

=head1 AUTHORS

 Nicholas Merowsky

 
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


