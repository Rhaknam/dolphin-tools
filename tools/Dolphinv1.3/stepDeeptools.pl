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
 my $strandspec       = "";
 my $mergeallsamps    = "";
 my $kmeans           = "";
 my $plottype         = "";
 my $reftype          = "";
 my $before           = "";
 my $after            = "";
 my $lengthbody       = "";
 my $quality          = "";
 my $bedtoolsint      = "";
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
	'strandspec=s'     => \$strandspec,
	'mergeallsamps=s'  => \$mergeallsamps,
	'kmeans=s'         => \$kmeans,
	'plottype=s'       => \$plottype,
	'reftype=s'        => \$reftype,
	'before=s'         => \$before,
	'after=s'          => \$after,
	'lengthbody=s'     => \$lengthbody,
	'quality=s'        => \$quality,
	'bedtoolsint=s'    => \$bedtoolsint,
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
my $bwdir = "$outdir/ucsc_$type";
if ($plottype =~/reference-point/) {
	$reftype = " --referencePoint $reftype";
}else{
	$reftype = "";
}

if ($kmeans !~/none/) {
	$kmeans = " --kmeans $kmeans";
}else{
	$kmeans = "";
}

my $bedinputdir = "$outdir/macs";
$outdir  = "$outdir/deeptools/$type";
`mkdir -p $outdir`;
die "Error 15: Cannot create the directory:$outdir" if ($?);

print $type;
if ($type =~/atac/ or $type =~/chip/) {	
	$com=`ls $bedinputdir/*_peaks.narrowPeak`;
	die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);
	my @files = split(/[\n\r\s\t,]+/, $com);
	$com=`ls $bwdir/*.sorted.bw`;
	my @bwfiles = split(/[\n\r\s\t,]+/, $com);
	my $jobcom = "";
	my $strandflag = " -s";
	if ($strandspec!~/yes/) {
		$strandflag = "";
	}
	if ($mergeallsamps=~/yes/) {
		my $mergebw = join(' ', @bwfiles);
		my $mergebed = join (' -i ', @files);
		$com="$bedtoolsint merge -i $mergebed | awk '{if(\\\$5>$quality)print \\\$1\\\"\\\\t\\\"(\\\$2-$before)\\\"\\\\t\\\"(\\\$3+$after)\\\"\\\\t\\\"\\\$4\\\"\\\\t\\\"\\\$5\\\"\\\\t\\\"\\\$6\\\"\\\\t\\\"\\\$7\\\"\\\\t\\\"\\\$8\\\"\\\\t\\\"\\\$9\\\"\\\\t\\\"\\\$10}' > $outdir/merged_quality.bed";
		$com.=" && ";
		$com.="sort -k1,1b -k2,2n $outdir/merged_quality.bed > $outdir/merged_quality.sorted.bed";
		$com.=" && ";
		$com.="$bedtoolsint intersect$strandflag -u -a $genomebed -b $outdir/merged_quality.sorted.bed > $outdir/merged_quality.intersect.sorted.bed";
		$com.=" && ";
		$com.="$compdeeptools $plottype$reftype -S $mergebw -R $outdir/merged_quality.intersect.sorted.bed -p 4 -a $before -b $after -m $lengthbody --skipZeros -out $outdir/mergedsamps.mat.gz";
		$com.=" && ";
		$com.="$deeptoolsheat$kmeans -m $outdir/mergedsamps.mat.gz --heatmapHeight 15 -out $outdir/mergedsamps.heatmap.png";
		my $job=$jobsubmit." -n ".$servicename."_merged -c \"$com\"";
		print $job."\n";   
		`$job`;
		die "Error 25: Cannot run the job:".$job if ($?);
	}else{
		foreach my $file (@files){
			$file=~/(.*\/(.*))_peaks.narrowPeak/;
			my $bname=$2;
			$com="cat $bedinputdir/$bname\_peaks.narrowPeak | awk '{if(\\\$5>$quality)print \\\$1\\\"\\\\t\\\"(\\\$2-$before)\\\"\\\\t\\\"(\\\$3+$after)\\\"\\\\t\\\"\\\$4\\\"\\\\t\\\"\\\$5\\\"\\\\t\\\"\\\$6\\\"\\\\t\\\"\\\$7\\\"\\\\t\\\"\\\$8\\\"\\\\t\\\"\\\$9\\\"\\\\t\\\"\\\$10}' > $outdir/$bname\_quality.bed";
			$com.=" && ";
			$com.="sort -k1,1b -k2,2n $outdir/$bname\_quality.bed > $outdir/$bname\_quality.sorted.bed";
			$com.=" && ";
			$com.="$bedtoolsint intersect$strandflag -u -a $genomebed -b $outdir/$bname\_quality.sorted.bed > $outdir/$bname\_quality.inersect.sorted.bed";
			$com.=" && ";
			$com.="$compdeeptools $plottype$reftype -S $bwdir/$bname.sorted.bw -R $outdir/$bname\_quality.inersect.sorted.bed -p 4 -a $before -b $after -m $lengthbody --skipZeros -out $outdir/$bname.mat.gz";
			$com.=" && ";
			$com.="$deeptoolsheat$kmeans -m $outdir/$bname.mat.gz --heatmapHeight 15 -out $outdir/$bname.heatmap.png";
			my $job=$jobsubmit." -n ".$servicename."_".$bname." -c \"$com\"";
			print $job."\n";   
			`$job`;
			die "Error 25: Cannot run the job:".$job if ($?);
		}
	}
}elsif ($type =~/rsem/ or $type =~/tophat/ or $type =~/bsmap/ or $type =~/star/ or $type =~/hisat2/){
	$com=`ls $genomebed`;
	die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);
	$com=`ls $bwdir/*.sorted.bw`;
	my $sorted=".sorted";
	if ($com !~/No such file or directory/) {
		$sorted="";
		$com=`ls $bwdir/*.bw`;
		die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);
	}
	my @files = split(/[\n\r\s\t,]+/, $com);
	my $jobcom = "";
	if ($mergeallsamps=~/yes/) {
		my $mergebw = join (' ', @files);
		$com="$compdeeptools $plottype$reftype -S $mergebw -R $genomebed -p 4 -a $before -b $after -m $lengthbody --skipZeros -out $outdir/mergedsamps.mat.gz";
		$com.=" && ";
		$com.="$deeptoolsheat$kmeans -m $outdir/mergedsamps.mat.gz --heatmapHeight 15 -out $outdir/mergedsamps.heatmap.png";
		my $job=$jobsubmit." -n ".$servicename."_merged -c \"$com\"";
		print $job."\n";   
		`$job`;
		die "Error 25: Cannot run the job:".$job if ($?);
	}else{
		foreach my $file (@files){
			$file=~/(.*\/(.*))$sorted.bw/;
			my $bname=$2;
			$com="$compdeeptools $plottype$reftype -S $file -R $genomebed -p 4 -a $before -b $after -m $lengthbody --skipZeros -out $outdir/$bname.mat.gz";
			$com.=" && ";
			$com.="$deeptoolsheat -m $outdir/$bname.mat.gz --heatmapHeight 15 -out $outdir/$bname.heatmap.png";
			my $job=$jobsubmit." -n ".$servicename."_".$bname." -c \"$com\"";
			print $job."\n";   
			`$job`;
			die "Error 25: Cannot run the job:".$job if ($?);
		}
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


