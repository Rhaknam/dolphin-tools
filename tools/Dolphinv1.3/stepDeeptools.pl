#!/usr/bin/env perl

#########################################################################################
#                                    StepDeeptools.pl
#########################################################################################
# 
#  This step creates custom plots using deeptools
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
 my $jobsubmit        = "";
 my $type             = "";
 my $genomebed        = "";
 my $plottype         = "";
 my $reftype          = "";
 my $deeptoolsheat    = "";
 my $compdeeptools    = "";
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $cmd=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
    'outdir=s'         => \$outdir,
    'type=s'           => \$type,
	'genomedir=s'      => \$genomebed,
	'plottype=s'       => \$plottype,
	'reftype=s'        => \$reftype,
	'deeptoolshead=s'  => \$deeptoolsheat,
	'compdeeptools=s'  => \$compdeeptools,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($outdir eq "") );	

################### MAIN PROGRAM ####################
#  It runs macs14 to find the peaks using alined peaks   

my $com = "";
my $inputdir = "";
my $bwdir = "$outdir/ucsc_$type";
if ($plottype =~/reference-point/) {
	$reftype = " --referencePoint $reftype";
}else{
	$reftype = "";
}

print $type;
if ($type =~/atac/ or $type =~/chip/) {	
	$inputdir = "$outdir/agg";
	$outdir  = "$outdir/deeptools";
	`mkdir -p $outdir`;
	die "Error 15: Cannot create the directory:$outdir" if ($?);
	$com=`ls $inputdir/*.bed`;
	die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);
	print $com;
	
	my @files = split(/[\n\r\s\t,]+/, $com);
	$com=`ls $bwdir/*.sorted.bw`;
	my $sorted=".sorted";
	if ($com !~/No such file or directory/) {
		$com=`ls $bwdir/*.bw`;
		$sorted="";
	}
	
	my $jobcom = "";
	foreach my $file (@files){
		$file=~/(.*\/(.*)).bed/;
		my $bname=$2;
		$com="$compdeeptools $plottype$reftype -S $bwdir/$bname$sorted.bw -R $file -out $outdir/$bname.mat.gz";
		$com.=" && ";
		$com.="$deeptoolsheat -m $outdir/$bname.mat.gz -out $outdir/$bname.heatmap.png 2> /dev/null";
		my $job=$jobsubmit." -n ".$servicename."_".$bname." -c \"$com\"";
		print $job."\n";   
		`$job`;
		die "Error 25: Cannot run the job:".$job if ($?);
	}
}elsif ($type =~/rsem/ or $type =~/tophat/ or $type =~/bsmap/){
	$outdir  = "$outdir/deeptools";
	`mkdir -p $outdir`;
	die "Error 15: Cannot create the directory:$outdir" if ($?);
	$com=`ls $genomebed`;
	die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);
	print $com;
	
	$com=`ls $bwdir/*.sorted.bw`;
	my $sorted=".sorted";
	if ($com !~/No such file or directory/) {
		$sorted="";
		$com=`ls $bwdir/*.bw`;
		die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);
	}
	my @files = split(/[\n\r\s\t,]+/, $com);
	
	my $jobcom = "";
	foreach my $file (@files){
		$file=~/(.*\/(.*))$sorted.bw/;
		my $bname=$2;
		$com="$compdeeptools $plottype$reftype -S $file -R $genomebed -out $outdir/$bname.mat.gz";
		$com.=" && ";
		$com.="$deeptoolsheat -m $outdir/$bname.mat.gz -out $outdir/$bname.heatmap.png";
		my $job=$jobsubmit." -n ".$servicename."_".$bname." -c \"$com\"";
		print $job."\n";   
		`$job`;
		die "Error 25: Cannot run the job:".$job if ($?);
	}
}else{
	die "Error 64: Incorrect input type: ($type)";
}


__END__

=head1 NAME

stepDeeptools.pl

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


