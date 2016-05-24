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

#################### VARIABLES ######################
 my $outdir           = "";
 my $level            = "";
 my $pubdir           = "";
 my $wkey             = "";
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
my $outd   = "$outdir/summary";
`mkdir -p $outdir`;
die "Error 15: Cannot create the directory:".$outdir if ($?);

my %tsv;
my $count_files = `ls $outdir/counts/*.summary.tsv`;

print $count_files."\n";
if ($count_files !~/No such file or directory/)
{
	my @files = split(/[\n\r\s\t,]+/, $count_files);
	my $filestr="";
	foreach my $file (@files)
	{
		if ($file eq $files[-1]) {
			#append final counts
			parseCountFile($file, 1);
		}else{
			#only add specific counts
			parseCountFile($file, 0);
		}
	}
}

my $rsem_dir = getDirectory($outdir, 'rsem');
my $tophat_dir = getDirectory($outdir, 'tophat');
my $chip_dir = getDirectory($outdir, 'chip');

sub parseCountFile
{
	my ($file) = $_[0];
	my ($end_file) = $_[1];
	my $contents_full = `cat $file`;
	my @contents_array = split(/[\n\r,]+/, $count_files);
	foreach my $contents_sample (@contents_array)
	{
		my @contents_sample_array = split(/[\t,]+/, $contents_sample);
		if ($tsv{$contents_sample_array[0]} eq undef) {
			$tsv{$contents_sample_array[0]} = [$contents_sample_array[1]];
		}
		
		my @reads1 = split(/[\s,]+/, $contents_sample_array[3]);
		my @readsgt1 = split(/[\s,]+/, $contents_sample_array[4]);
		
		$tsv{$contents_sample_array[0]} = push($tsv{$contents_sample_array[0]}, ($reads1[0] + $readsgt1[0]));
		if ($end_file eq 1) {
			$tsv{$contents_sample_array[0]} = push($tsv{$contents_sample_array[0]}, $contents_sample_array[2]);
		}
	}
}

sub getDirectory
{
	my ($outdir) = $_[0];
	my ($type) = $_[1];
	my $directories = `ls -d $outdir/*$type*`;
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
