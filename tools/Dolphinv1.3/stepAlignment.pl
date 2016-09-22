#!/usr/bin/env perl

#########################################################################################
#                                       stepAlignment.pl
#########################################################################################
# 
#  This program quantify the genes using RSEM 
#
#########################################################################################
# AUTHORS:
#
# Alper Kucukural, PhD
# Nicholas Merowsky
# 
#########################################################################################


############## LIBRARIES AND PRAGMAS ################

 use List::Util qw[min max];
 use strict;
 use File::Basename;
 use Getopt::Long;
 use Pod::Usage;
 
#################### VARIABLES ######################
 my $aligner          = "";
 my $outdir           = "";
 my $commandcall      = "";
 my $spaired          = "";
 my $params           = "";
 my $indexref         = "";
 my $previous         = "";
 my $pubdir           = "";
 my $wkey             = "";
 my $jobsubmit        = "";
 my $samtools         = "";
 my $servicename      = "";
 my $gtf              = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "Alignment v1.0.0";

################### PARAMETER PARSING ####################

my $command=$0." ".join(" ",@ARGV); ####command line copy

GetOptions(
	'aligner=s'      => \$aligner,
	'outdir=s'       => \$outdir,
	'commandcall=s'  => \$commandcall,
	'dspaired=s'     => \$spaired,
	'params=s'       => \$params,
	'indexref=s'     => \$indexref,
	'previous=s'     => \$previous,
	'pubdir=s'       => \$pubdir,
	'wkey=s'         => \$wkey,
	'jobsubmit=s'    => \$jobsubmit,
	'samtools=s'     => \$samtools,
	'servicename=s'  => \$servicename,
	'gtf=s'          => \$gtf,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($indexref eq "") or ($outdir eq "") or ($aligner eq "") );	

 
################### MAIN PROGRAM ####################
#    maps the reads to the the genome and put the files under $outdir directory

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

$outdir   = "$outdir/$aligner";
`mkdir -p $outdir`;
die "Error 15: Cannot create the directory:".$outdir if ($?);

my $puboutdir = "$pubdir/$wkey";
`mkdir -p $puboutdir`;
die "Error 15: Cannot create the directory:".$puboutdir if ($?);

$params =~s/,/ /g;
$params=~s/_/-/g;
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



if (lc($params)=~/^no/ || $params=~/^$/)
{
   $params="";
}
foreach my $file (@files)
{ 
 $file=~/.*\/(.*).fastq/;
 my $bname=$1;
 my $str_files=$file;
 die "Error 64: please check the file:".$file unless (checkFile($file));
 if (lc($spaired) !~ /^no/)
 {
    $file=~/(.*\/(.*)).1.fastq/;
    $bname=$2;
    my $file2=$1.".2.fastq";
    die "Error 64: please check the file:".$file2 unless (checkFile($file2));

    $str_files ="$file $file2";
 }
 chomp($wkey);
 my $com="";
 my $outfile="";
 ### Tophat2
 if ($aligner eq "tophat") {
	my $ucsc=$gtf;
	$ucsc=~s/\.gtf/\.fa/;
	my $ti="";
	if (-s $ucsc) {
	  $ucsc=~s/\.fa//;
	  $ti=" --transcriptome-index=$ucsc";
	}
	$com="$commandcall -p 4 $params --keep-tmp -G $gtf $ti -o $outdir/pipe.$aligner.$bname $indexref $str_files " if (!(-s "$outdir/pipe.$aligner.$bname/accepted_hits.bam"));
	$com.=" && " if ($com!~/^$/);
	$outfile = "accepted_hits.bam";
 ### Hisat2
 }elsif($aligner eq "hisat2"){
	my @files = split(/ /, $str_files);
	my $file_input = "";
	if (scalar @files eq 2) {
		$file_input = "-1 ".$files[0]." -2 ".$files[1];
	}else{
		$file_input = "-U $str_files";
	}
	$com="mkdir -p $outdir/pipe.$aligner.$bname " if (!(-s "$outdir/pipe.$aligner.$bname/$bname.bam"));
	$com.=" && " if ($com!~/^$/);
	$com.="$commandcall -p 4 $params -x $indexref $file_input -S $outdir/pipe.$aligner.$bname/$bname.sam &> $outdir/pipe.$aligner.$bname/align_summary.txt " if (!(-s "$outdir/pipe.$aligner.$bname/$bname.bam"));
	$com.=" && " if ($com!~/^$/);
	$com.="$samtools view -bS $outdir/pipe.$aligner.$bname/$bname.sam > $outdir/pipe.$aligner.$bname/$bname.bam " if (!(-s "$outdir/pipe.$aligner.$bname/$bname.bam"));
	$com.=" && " if ($com!~/^$/);
	$com.="rm -rf $outdir/pipe.$aligner.$bname/$bname.sam " if (!(-s "$outdir/pipe.$aligner.$bname/$bname.bam"));
	$com.=" && " if ($com!~/^$/);
	$outfile="$bname.bam";
 ### STAR
 }elsif($aligner eq "star"){
	$com="mkdir -p $outdir/pipe.$aligner.$bname ";
	$com.=" && " if ($com!~/^$/);
	$com.="$commandcall --runThreadN 4 $params --genomeDir $indexref --readFilesIn $str_files --outSAMtype BAM Unsorted --outFileNamePrefix $outdir/pipe.$aligner.$bname/$bname" if (!(-s "$outdir/pipe.$aligner.$bname/$bname.bam"));
	$com.=" && " if ($com!~/^$/);
	$outfile=$bname."Aligned.out.bam"
 }
 
 $com.="$samtools sort $outdir/pipe.$aligner.$bname/$outfile $outdir/pipe.$aligner.$bname/$bname.sorted " if (!(-s "$outdir/pipe.$aligner.$bname/$bname.sorted.bam"));
 $com.=" && " if ($com!~/^$/);
 $com.="$samtools index $outdir/pipe.$aligner.$bname/$bname.sorted.bam " if (!(-s "$outdir/pipe.$aligner.$bname/$bname.sorted.bam.bai"));

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

stepAlignment.pl

=head1 SYNOPSIS  

stepAlignment.pl
			-a aligner <program name>
            -o outdir <output directory> 
            -c commandcall <command dir and file> 
            -r indexref <Index file>

stepAlignment.pl -help

stepAlignment.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -a aligner <program name>

the type of aligner used to align the files

=head2 -o outdir <output directory>

the output files will be "$outdir/<Aligner>" 

=head2 -c commandcall <command dir and file> 

Fullpath of aligner file. Ex: /usr/local/bin/dolphin-bin/STAR

=head2  -r indexref <ref files> 

reference file

=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

 This program maps the reads using the selected aligner

=head1 EXAMPLE

stepAlignment.pl
			-a aligner <program name>
            -o outdir <output directory> 
            -c commandcall <command dir and file> 
            -r indexref <Index file>

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




