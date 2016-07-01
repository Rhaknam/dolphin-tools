#!/usr/bin/env perl

#########################################################################################
#                                       stepTophat2.pl
#########################################################################################
# 
#  This program uses GATK Haplotype Caller for variant calling 
#
#########################################################################################
# AUTHORS:
#
# Nicholas Merowsky
# 
#########################################################################################


############## LIBRARIES AND PRAGMAS ################

use List::Util qw[min max];
use strict;
use File::Basename;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;

#################### VARIABLES ######################
my $outdir           = "";
my $genome           = "";
my $previous         = "";
my $samtools         = "";
my $haplobed         = "";
my $haploCmd         = "";
my $multiCmd         = "";
my $picardCmd        = "";
my $bedCmd           = "";
my $smctfc           = "";
my $smctfe           = "";
my $mbqs             = "";
my $mrpas            = "";
my $mrirps           = "";
my $merge            = "";
my $common           = "";
my $clinical         = "";
my $motifs           = "";
my $enhancer         = "";
my $promoter         = "";
my $comparePeaks     = "";
my $type             = "";
my $jobsubmit        = "";
my $servicename      = "";
my $help             = "";
my $print_version    = "";
my $version          = "1.0.0";

################### PARAMETER PARSING ####################

my $command=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
	'outdir=s'       => \$outdir,
	'genome=s'       => \$genome,
	'previous=s'     => \$previous,
	'samtools=s'     => \$samtools,
	'haplobed=s'     => \$haplobed,
	'haplocmd=s'     => \$haploCmd,
	'multicmd=s'     => \$multiCmd,
	'picardCmd=s'    => \$picardCmd,
	'bedCmd=s'       => \$bedCmd,
	'smctfc=s'       => \$smctfc,
    'smctfe=s'       => \$smctfe,
    'mbqs=s'         => \$mbqs,
    'mrpas=s'        => \$mrpas,
    'mrirps=s'       => \$mrirps,
	'merge=s'        => \$merge,
	'common=s'       => \$common,
	'clinical=s'     => \$clinical,
	'motifs=s'       => \$motifs,
	'enhancer=s'     => \$enhancer,
	'promoter=s'     => \$promoter,
	'comparePeaks=s' => \$comparePeaks,
	'type=s'         => \$type,
	'jobsubmit=s'    => \$jobsubmit,
	'servicename=s'  => \$servicename,
	'help'           => \$help, 
	'version'        => \$print_version,
) or die("Unrecognized options.\nFor help, run this script with -help option.\n");

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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($genome eq "") or ($outdir eq "") or ($haploCmd eq "") or ($picardCmd eq ""));	

 
################### MAIN PROGRAM ####################
my $inputdir="";
print "$previous\n";

my $sorted=".sorted";
$sorted = "" if ($type=~/^dedup/);
if ($type =~/^chip$/) {
	$type = "seqmapping/$type";
}

my $dir_test = `ls $outdir/$type`;
my $input_file_cmd = "";

if ($dir_test !~/No such file or directory/){
	$inputdir = "$outdir/$type";
	$input_file_cmd = "ls $inputdir/*$sorted.bam 2>&1";
}else{
	die "Error 256: cannot find bam file directory:";
}

my $original_outdir = $outdir;
$outdir   = "$outdir/haplotypecaller";
`mkdir -p $outdir`;
die "Error 15: Cannot create the directory:".$outdir if ($?);

my $com="";
print $input_file_cmd;
$com=`$input_file_cmd`;
die "Error 64: please check the if you defined the parameters right:" unless ($com !~/No such file or directory/);

print $com;
my @files = split(/[\n\r\s\t,]+/, $com);

if ($merge eq "yes"){
	if ($comparePeaks eq "yes") {
		my $peaksfilecom = `ls $original_outdir/macs/*peaks.bed`;
		my @peaksfiles = split(/[\n\r\s\t,]+/, $peaksfilecom);
		my $peaksstr = "$multiCmd -i " . join(" ", @peaksfiles) . " > $outdir/all_peaks.bed";
		print $peaksstr;
		print "\@\@\@test\@\@\@";
		my $peakscom=`$peaksstr`;
		die "Error 64: please check the if you defined the parameters right:" unless ($peakscom !~/No such file or directory/);
	}
	my $mergestr = "$samtools merge $outdir/mergeall.bam " . join(' ', @files) . " -f";
	print $mergestr;
	print "\@\@\@test\@\@\@";
	my $mergecom = `$mergestr`;
	print $mergecom;
	die "Error 64: please check the if you defined the parameters right:" unless ($mergecom !~/No such file or directory/);
	@files = ("$outdir/mergeall.bam");
}

print Dumper(@files);

my @vcf_input = ("");
my @vcf_files = ("");
my $peaks = "";

foreach my $file (@files)
{
	my $input_file = $file;
	$file=~/.*\/(.*)/;
	my $str_file=$1;
	die "Error 64: please check the file:".$file unless (checkFile($file));
	@vcf_input = ("");
	@vcf_files = ($input_file);
	
	if ($comparePeaks eq "yes") {
		if ($merge eq "yes") {
			$peaks = "$bedCmd intersect -abam $file -b $outdir/all_peaks.bed > $outdir/peaks_$str_file &&";
			$str_file = "peaks_$str_file";
			$input_file = "$outdir/$str_file";
		}else{
			$str_file=~/(.*).sorted.bam/;
			my $sample_name = $1;
			$peaks = "$bedCmd intersect -abam $inputdir/".$sample_name.$sorted.".bam -b $original_outdir/macs/".$sample_name."_peaks.bed > $outdir/peaks_$str_file &&";
			$str_file = "peaks_$str_file";
			$input_file = "$outdir/$str_file";
		}
	}
	
	############	Start SNP File Type Calls
	if ($motifs eq "yes") {
		if ($common eq "yes" ) {
			if ($enhancer == "yes") {
				intersectBed($peaks, $bedCmd, $input_file, $haplobed, "motif_enhancer_commonSNPs.bed", "motif_common_enhancer", $outdir, $str_file);
			}
			if ($promoter eq "yes") {
				intersectBed($peaks, $bedCmd, $input_file, $haplobed, "motif_promoter_commonSNPs.bed", "motif_common_promoter", $outdir, $str_file);
			}
			intersectBed($peaks, $bedCmd, $input_file, $haplobed, "motif_commonSNPs.bed", "motif_common", $outdir, $str_file);
		}
		
		if($clinical eq "yes"){
			if ($enhancer eq "yes") {
				intersectBed($peaks, $bedCmd, $input_file, $haplobed, "motif_enhancer_clincial_commonSNPs.bed", "motif_clinical_enhancer", $outdir, $str_file);
			}
			if ($promoter eq "yes") {
				intersectBed($peaks, $bedCmd, $input_file, $haplobed, "motif_promoter_clincial_commonSNPs.bed", "motif_clinical_promoter", $outdir, $str_file);
			}
			intersectBed($peaks, $bedCmd, $input_file, $haplobed, "motif_clinical_commonSNPs.bed", "motif_clinical", $outdir, $str_file);
		}
		
		if ($enhancer eq "yes") {
			intersectBed($peaks, $bedCmd, $input_file, $haplobed, "motif_enhancer_regions.bed", "motif_enhancer", $outdir, $str_file);
		}
		if ($promoter eq "yes") {
			intersectBed($peaks, $bedCmd, $input_file, $haplobed, "motif_promoter_regions.bed", "motif_promoter", $outdir, $str_file);
		}
		intersectBed($peaks, $bedCmd, $input_file, $haplobed, "motifs_human_merged_atac_peaks.bed", "motif", $outdir, $str_file);
	}
	
	if($common eq "yes"){
		if ($enhancer eq "yes") {
			intersectBed($peaks, $bedCmd, $input_file, $haplobed, "enhancer_commonSNPs.bed", "common_enhancer", $outdir, $str_file);
		}
		if ($promoter eq "yes") {
			intersectBed($peaks, $bedCmd, $input_file, $haplobed, "promoter_commonSNPs.bed", "common_promoter", $outdir, $str_file);
		}
		intersectBed($peaks, $bedCmd, $input_file, $haplobed, "commonSNPs.bed", "common", $outdir, $str_file);
	}
	
	if($clinical eq "yes"){
		if ($enhancer eq "yes") {
			intersectBed($peaks, $bedCmd, $input_file, $haplobed, "enhancer_clinical_commonSNPs.bed", "clinical_enhancer", $outdir, $str_file);
		}
		if ($promoter eq "yes") {
			intersectBed($peaks, $bedCmd, $input_file, $haplobed, "promoter_clinical_commonSNPs.bed", "clinical_promoter", $outdir, $str_file);
		}
		intersectBed($peaks, $bedCmd, $input_file, $haplobed, "clinical_commonSNPs.bed", "clinical", $outdir, $str_file);
	}
	
	if ($enhancer eq "yes") {
		intersectBed($peaks, $bedCmd, $input_file, $haplobed, "enhancer_atac_peaks_human.bed", "enhancer", $outdir, $str_file);
	}
	
	if ($promoter eq "yes") {
		intersectBed($peaks, $bedCmd, $input_file, $haplobed, "promoter_atac_peaks_human.bed", "promoter", $outdir, $str_file);
	}
	
	############	End SNP File Type Calls
	
	############	Start HaplotypeCaller Calls
	my $index = 0;
	foreach my $new_file (@vcf_files)
	{
		my $input_file = $new_file;
		$new_file=~/.*\/(.*)/;
		my $str_file=$1;
		$str_file=~/(.*).*\./;
		my $bname=$1;
		my $com="";
		##	Make sure bam isn't malformed
		$com.= $vcf_input[$index];
		$com.="$picardCmd AddOrReplaceReadGroups I=$input_file O=$outdir/hg_$str_file RGID=4 RGLB=lib1 RGPL=illumina RGPU=unit1 RGSM=20";
		if ($index != 0) {
			$com.=" && rm $input_file " if ($com!~/^$/);
		}
		$com.=" && " if ($com!~/^$/);
		##	Make sure bam is ordered properly
		$com.=" $picardCmd ReorderSam I=$outdir/hg_$str_file O=$outdir/reordered_$str_file R=$genome CREATE_INDEX=TRUE";
		##	Remove hg_file
		$com.=" && rm $outdir/hg_$str_file " if ($com!~/^$/);
		$com.=" && " if ($com!~/^$/);
		##	Run HaplotypeCaller
		$com.="$haploCmd -R $genome -T HaplotypeCaller -I $outdir/reordered_$str_file -o $outdir/$bname.vcf --filter_reads_with_N_cigar --fix_misencoded_quality_scores";
		$com.=" --standard_min_confidence_threshold_for_calling $smctfc --standard_min_confidence_threshold_for_emitting $smctfe --min_base_quality_score $mbqs";
		$com.=" --minReadsPerAlignmentStart $mrpas --maxReadsInRegionPerSample $mrirps";
		##	Remove reordered bam files
		$com.=" && rm $outdir/reordered_$str_file " if ($com!~/^$/);
		$com.=" && rm $outdir/reordered_$bname.bai " if ($com!~/^$/);
		############	End HaplotypeCaller Calls
		
		$index++;
		my $job=$jobsubmit." -n ".$servicename."_".$bname." -c \"$com\"";
		print $job."\n";
		`$job`;
		die "Error 25: Cannot run the job:".$job if ($?);
	}
}

sub checkFile
{
	my ($file) = $_[0];
	return 1 if (-e $file);
	return 0;
}

sub intersectBed
{
	my ($peaks, $bedCmd, $input_file, $haplobed, $bedfile, $bedprefix, $outdir, $str_file) = @_;
	my $cmd = "";
	$cmd.="$peaks $bedCmd intersect -abam $input_file -b $haplobed/$bedfile > $outdir/$bedprefix"."_"."$str_file &&";
	push(@vcf_input, $cmd);
	push(@vcf_files, "$outdir/$bedprefix"."_"."$str_file");
}

__END__


=head1 NAME

stepHaplotype.pl

=head1 SYNOPSIS  

stepHaplotype.pl 
            -o outdir <output directory> 
            -g genome <genome fasta file> 
            -ha haploCmd <haplotypecaller command>
			-pi picardCmd <picard command>

stepHaplotype.pl -help

stepHaplotype.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -o outdir <output directory>

the output files will be "$outdir/variant_calls" 

=head2  -g genome <genome files> 

Genome fasta file. (Full path)

=head2 -ha haploCmd <Haplotypecaller dir and file> 

Full path of haplotypecaller

=head2  -pi picardCmd <picard dir and file>

Full path of picard

=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

This program finds SNP variants using GATK HaplotypeCaller

=head1 EXAMPLE

stepHaplotype.pl 
            -o outdir <output directory> 
            -g genome <genome fasta file> 
            -ha haploCmd <haplotypecaller dir and file>
			-pi picardCmd <picard dir and file>

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




