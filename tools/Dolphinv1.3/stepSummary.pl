#!/usr/bin/env perl

#########################################################################################
#                                       stepSummary.pl
#########################################################################################
# 
#  This program creates a summary file for table generation.
#
#
#########################################################################################
# AUTHORS:
#
# Alper Kucukural, PhD
# Nicholas Merowsky
# Jul 4, 2014
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
 my $pubdir           = "";
 my $wkey             = "";
 my $samtools         = "";
 my $username         = "";
 my $config           = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $command=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
	'outdir=s'       => \$outdir,
    'pubdir=s'       => \$pubdir,
    'wkey=s'         => \$wkey,
	'samtools=s'     => \$samtools,
    'config=s'       => \$config,
    'username=s'     => \$username,
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
# Obtain summary information and create file

my $reportfile   = "$pubdir/$wkey/reports.tsv";
my $reportsummarydir = "$pubdir/$wkey/summary";
my $outd   = "$outdir/summary";
`mkdir -p $reportsummarydir`;
`mkdir -p $outd`;

my %tsv;
my @headers = ();
my $count_files = `ls $outdir/counts/*.summary.tsv 2>/dev/null`;

push(@headers, 'Sample');
push(@headers, 'Total Reads');

print $count_files+"\n";

if ( $count_files ne ""){
	my @files = split(/[\n\r\s\t,]+/, $count_files);
	my $filestr="";
	foreach my $file (@files)
	{
		if ($file eq $files[-1]) {
			#append final counts
			parseRNACountFile($file, 1);
		}else{
			#only add specific counts
			parseRNACountFile($file, 0);
		}
	}
}else{
	parseNormalCounts();
}

my $rsem_dir = getDirectory($outdir, 'rsem');
if ($rsem_dir ne "") {
	checkAlignmentType($rsem_dir, "rsem");
}

my $tophat_dir = getDirectory($outdir, 'tophat');
if ($tophat_dir ne "") {
	checkAlignmentType($tophat_dir, "tophat");
}

my $chip_dir = getDirectory($outdir, 'chip');
if ($chip_dir ne "") {
	checkAlignmentType($chip_dir, "chip");
}else{
	my $chip_seq_dir = getDirectory($outdir, "seqmapping/chip");
	if ($chip_seq_dir ne "") {
		checkAlignmentType($chip_seq_dir, "chip");
	}
}

my @keys = keys %tsv;
my $summary = "$outd/summary_data.tsv";
my $header_string = join("\t", @headers);
`echo "$header_string" > $summary`;
`echo "$header_string" > $reportsummarydir/summary.tsv`;
foreach my $key (@keys){
	my $values = join("\t", @{ $tsv{$key} });
	`echo "$values" >> $summary`;
	`echo "$values" >> $reportsummarydir/summary.tsv`;
}

`echo "$wkey\t$version\tsummary\tsummary/summary.tsv" >> $reportfile`;

###############
# SUBROUTINES #
###############

sub parseRNACountFile
{
	my ($file) = $_[0];
	my ($end_file) = $_[1];
	my $contents_full = `cat $file`;
	my @contents_array = split(/[\n\r,]+/, $contents_full);
	my %unmapped_dir = {};
	foreach my $contents_sample (@contents_array)
	{
		my @contents_sample_array = split(/[\t,]+/, $contents_sample);
		if ($contents_sample_array[0] ne 'File') {
			if ($tsv{$contents_sample_array[0]} eq undef) {
				$tsv{$contents_sample_array[0]} = [$contents_sample_array[0], $contents_sample_array[1]];
			}
			if ($tsv{$contents_sample_array[0]}[1] != undef) {
				if ($tsv{$contents_sample_array[0]}[1] < $contents_sample_array[1]) {
					$tsv{$contents_sample_array[0]}[1]= $contents_sample_array[1];
				}
			}
			if ($tsv{$contents_sample_array[0]}[1] != undef) {
				if ($tsv{$contents_sample_array[0]}[1] < $contents_sample_array[1]) {
					$tsv{$contents_sample_array[0]}[1]= $contents_sample_array[1];
				}
			}
			
			my @totalreads = split(/[\s\t,]+/, $contents_sample_array[2]);
			if ($unmapped_dir{$contents_sample_array[0]} == undef || $unmapped_dir{$contents_sample_array[0]} >= $totalreads[0]) {
				$unmapped_dir{$contents_sample_array[0]} = $totalreads[0];
			}
			
			my @reads1 = split(/[\s,]+/, $contents_sample_array[5]);
			push($tsv{$contents_sample_array[0]}, $reads1[0]);
			if ($end_file) {
				push($tsv{$contents_sample_array[0]}, $unmapped_dir{$contents_sample_array[0]});
			}
		}
	}
	my @split_file = split(/[\/]+/, $file);
	my @split_name = split(/[\.]+/, $split_file[-1]);
	push(@headers, $split_name[0]);
	if ($end_file) {
		push(@headers, 'Total align');
	}
}

sub parseNormalCounts
{
	chomp(my $contents = `ls $outdir/input`);
	my @files = split(/[\n]+/, $contents);
	foreach my $file (@files){
		my @split_name = split(/[\.]+/, $file);
		chomp(my $rawcount = `wc -l $outdir/input/$file`);
		my @counts = split(/[ ]+/, $rawcount);
		my $finalcount = $counts[0]/4;
		$tsv{$split_name[0]} = [$split_name[0], $finalcount];
	}
}

sub checkAlignmentType
{
	my $directories = $_[0];
	my $type = $_[1];
	my $deduptype = $type;
	$deduptype = $type."_ref.transcripts" if ($type eq "rsem");
	my @dirs = split(/[\n]+/, $directories);
	if(grep( /^$outdir\/dedupmerge$deduptype$/, @dirs )) {
		dedupReadsAligned("$outdir/dedupmerge$deduptype", $type);
	}elsif(grep( /^$outdir\/dedup$deduptype$/, @dirs )){
		dedupReadsAligned("$outdir/dedup$deduptype", $type);
	}elsif(grep( /^$outdir\/merge$type$/, @dirs )){
		searchAligned("$outdir/merge$type", $type, "*.bam");
	}elsif(grep( /^$outdir\/$type$/, @dirs )){
		if ($type eq "tophat"){
			alteredAligned("$outdir/$type", $type, "*/accepted_hits.bam");
		}elsif ($type eq "rsem"){
			my $genome_check = `ls $outdir/$type/*/*genome.bam`;
			if ($genome_check !~ /No such file or directory/) {
				alteredAligned("$outdir/$type", $type, "*/*genome.bam");
			}else{
				alteredAligned("$outdir/$type", $type, "*/*transcript.bam");
			}
		}else{
			searchAligned("$outdir/$type", $type, "*.bam");
		}
	}elsif($type eq "chip"){
		searchAligned("$outdir/seqmapping/chip", $type, "*.bam");
	}
}

sub dedupReadsAligned
{
	my ($directory) = $_[0];
	my ($type) = $_[1];
	chomp(my $contents = `ls $directory/*PCR_duplicates`);
	print $contents;
	my @files = split(/[\n]+/, $contents);
	push(@headers, "Duplicated Reads $type");
	push(@headers, "Multimapped Reads Aligned $type");
	push(@headers, "Unique Reads Aligned $type");
	foreach my $file (@files){
		my $multimapped;
		my @split_name = split(/[\/]+/, $file);
		my @namelist = split(/[\.]+/, $split_name[-1]);
		my $name = $namelist[0];
		my @namelist2 = split(/_PCR_duplicates/, $name);
		$name = $namelist2[0];
		if ($type eq 'rsem') {
			print "awk 'NR == 2 {print \$3}' $outdir/rsem/pipe.rsem.$name/rsem.out.$name.stat/rsem.out.$name.cnt";
			chomp($multimapped = `awk 'NR == 2 {print \$3}' $outdir/rsem/pipe.rsem.$name/rsem.out.$name.stat/rsem.out.$name.cnt`)
		}else{
			print "$samtools view -f 256 $directory/$name*.bam | awk '{print \$1}' | sort -u | wc -l";
			chomp($multimapped = `$samtools view -f 256 $directory/$name*.bam | awk '{print \$1}' | sort -u | wc -l`);
		}
		chomp(my $aligned = `cat $file | grep -A 1 \"LIB\" | grep -v \"LIB\"`);
		my @values = split("\t", $aligned);
		my $dedup = int($values[5]) + int($values[4]);
		my $total = int($values[2]) + int($values[1]) - $dedup - int($multimapped);
		push($tsv{$name}, $dedup.'');
		push($tsv{$name}, $multimapped.'');
		push($tsv{$name}, $total.'');
	}
}

sub searchAligned
{
	my ($directory) = $_[0];
	my ($type) = $_[1];
	my ($filetype) = $_[2];
	chomp(my $contents = `ls $directory/$filetype`);
	print $contents;
	my @files = split(/[\n]+/, $contents);
	push(@headers, "Multimapped Reads Aligned $type");
	push(@headers, "Unique Reads Aligned $type");
	foreach my $file (@files){
		my $multimapped;
		my $aligned;
		my @split_name = split(/[\/]+/, $file);
		my @namelist = split(/[\.]+/, $split_name[-1]);
		my $name = $namelist[0];
		if ($type eq 'rsem') {
			print "awk 'NR == 1 {print \$2}' $outdir/rsem/pipe.rsem.$name/rsem.out.$name.stat/rsem.out.$name.cnt";
			chomp($aligned = `awk 'NR == 1 {print \$2}' $outdir/rsem/pipe.rsem.$name/rsem.out.$name.stat/rsem.out.$name.cnt`);
			print "awk 'NR == 2 {print \$3}' $outdir/rsem/pipe.rsem.$name/rsem.out.$name.stat/rsem.out.$name.cnt";
			chomp($multimapped = `awk 'NR == 2 {print \$3}' $outdir/rsem/pipe.rsem.$name/rsem.out.$name.stat/rsem.out.$name.cnt`);
			push($tsv{$name}, $multimapped);
			push($tsv{$name}, (int($aligned) - int($multimapped))."");
		}else{
			print "$samtools flagstat $file";
			chomp($aligned = `$samtools flagstat $file`);
			my @aligned_split = split(/[\n]+/, $aligned);
			my @paired = split(/[\s]+/, $aligned_split[9]);
			my @singleton = split(/[\s]+/, $aligned_split[10]);
			print "$samtools view -f 256 $directory/$name*.bam | awk '{print \$1}' | sort -u | wc -l";
			chomp($multimapped = `$samtools view -f 256 $directory/$name*.bam | awk '{print \$1}' | sort -u | wc -l`);
			if (int($paired[0])/2 == 0) {
				print "$samtools view -F 4 $file | awk '{print \$1}' | sort -u | wc -l";
				chomp(my $aligned = `$samtools view -F 4 $file | awk '{print \$1}' | sort -u | wc -l`);
				push($tsv{$name}, $multimapped);
				push($tsv{$name}, (int($aligned) - int($multimapped))."");
			}else{
				push($tsv{$name}, $multimapped);
				push($tsv{$name}, ((int($paired[0])/2 - int($singleton[0])) - int($multimapped))."");
			}
		}
	}
}

sub alteredAligned
{
	my ($directory) = $_[0];
	my ($type) = $_[1];
	my ($filetype) = $_[2];
	chomp(my $contents = `ls $directory/$filetype`);
	print $contents;
	my @files = split(/[\n]+/, $contents);
	push(@headers, "Multimapped Reads Aligned $type");
	push(@headers, "Unique Reads Aligned $type");
	foreach my $file (@files){
		my $multimapped;
		my $aligned;
		my @split_name = split(/[\/]+/, $file);
		my @namelist = split(/[\.]+/, $split_name[-2]);
		my $name = $namelist[2];
		if ($type eq 'rsem') {
			print "awk 'NR == 1 {print \$2}' $outdir/rsem/pipe.rsem.$name/rsem.out.$name.stat/rsem.out.$name.cnt";
			chomp($aligned = `awk 'NR == 1 {print \$2}' $outdir/rsem/pipe.rsem.$name/rsem.out.$name.stat/rsem.out.$name.cnt`);
			print "awk 'NR == 2 {print \$3}' $outdir/rsem/pipe.rsem.$name/rsem.out.$name.stat/rsem.out.$name.cnt";
			chomp($multimapped = `awk 'NR == 2 {print \$3}' $outdir/rsem/pipe.rsem.$name/rsem.out.$name.stat/rsem.out.$name.cnt`);
			push($tsv{$name}, $multimapped);
			push($tsv{$name}, (int($aligned) - int($multimapped))."");
		}else{
			chomp($aligned = `$samtools flagstat $file`);
			my @aligned_split = split(/[\n]+/, $aligned);
			my @paired = split(/[\s]+/, $aligned_split[9]);
			my @singleton = split(/[\s]+/, $aligned_split[10]);
			print "$samtools view -f 256 $directory/$name*.bam | awk '{print \$1}' | sort -u | wc -l";
			chomp($multimapped = `$samtools view -f 256 $directory/$name*.bam | awk '{print \$1}' | sort -u | wc -l`);
			if (int($paired[0])/2 == 0) {
				print "$samtools view -F 4 $file | awk '{print \$1}' | sort -u | wc -l";
				chomp(my $aligned = `$samtools view -F 4 $file | awk '{print \$1}' | sort -u | wc -l`);
				push($tsv{$name}, $multimapped);
				push($tsv{$name}, (int($aligned) - int($multimapped))."");
			}else{
				push($tsv{$name}, $multimapped);
				push($tsv{$name}, ((int($paired[0])/2 - int($singleton[0])) - int($multimapped))."");
			}
		}
	}
}

sub getDirectory
{
	my ($outdir) = $_[0];
	my ($type) = $_[1];
	chomp(my $directories = `ls -d $outdir/*$type* 2>/dev/null`);
	return $directories;
}

__END__


=head1 NAME

stepClean.pl

=head1 SYNOPSIS  

stepSummary.pl -o outdir <output directory> 

stepSummary.pl -help

stepSummary.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -o outdir <output directory>

the output files will be "$outdir/after_ribosome" 

=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

 This program cleans intermediate files

=head1 EXAMPLE

stepClean.pl 
            -o ~/out

=head1 AUTHORS

 Alper Kucukural, PhD
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
