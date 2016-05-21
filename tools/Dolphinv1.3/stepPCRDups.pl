#!/usr/bin/env perl

#########################################################################################
#                                       stepMergePicard.pl
#########################################################################################
# 
#  This program merges the multiple sample picard output into single file 
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
 my $outdir           = "";
 my $type             = "";
 my $mergepicard      = "";
 my $pubdir           = "";
 my $wkey             = "";
 my $jobsubmit        = "";
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "picard_tools 1.131";
################### PARAMETER PARSING ####################

my $cmd=$0." ".join(" ",@ARGV); ####command line copy

GetOptions(
    'outdir=s'        => \$outdir,
    'type=s'          => \$type,
    'mergepicard=s'   => \$mergepicard,
    'pubdir=s'        => \$pubdir,
    'wkey=s'          => \$wkey,
	'jobsubmit=s'     => \$jobsubmit,
    'servicename=s'   => \$servicename,
    'help'            => \$help, 
    'version'         => \$print_version,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($type eq "") or ($outdir eq "") );	

################### MAIN PROGRAM ####################

my $indir  = "$outdir/$type";
my $outd  = "$outdir/picard_$type";

`mkdir -p $outd`;
die "Error 15: Cannot create the directory:".$outd if ($?);

my $puboutdir   = "$pubdir/$wkey";
`mkdir -p $puboutdir`;
die "Error 15: Cannot create the directory:".$puboutdir if ($?);

print "INDIR:$indir\n";
print "OUTDIR:$outdir\n";
my $com="head -8 $indir/*.PCR_duplicates|grep -v \"#\"|grep -v \"LIB\" | sed \"s/==> //\" |sed \"s/.*0\./0\./\"|sed \"s/\t.*//\"|sed \":a;{N;s/<==\n\n//g};ba\" | grep \" \" > $outd/pcrdups.txt";
$com.= " && mkdir -p $puboutdir/$type";
$com.= " && cp $outd/pcrdups.txt $puboutdir/$type/"; 
$com.= " && echo -e \"$wkey\t$version\tsummary\t$type/pcrdups.txt\" >> $puboutdir/reports.tsv ";
`$com`;

__END__


=head1 NAME

stepPCRDups.pl

=head1 SYNOPSIS  

stepPCRDups.pl
            -o outdir <output directory> 
            -t type <Tophat|ChipSeq>
            -p pubdir <the path of publicly accessible dir>
            -w wkey <key of the run> 

stepPCRDups.pl -help

stepPCRDups.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -o outdir <output directory>

the output files will be stored "$outdir/picard_$type" 

=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

This program merges the multiple sample picard output into single file 

=head1 EXAMPLE

stepPCRDups.pl
            -o outdir <output directory> 
            -t type <Tophat|ChipSeq>
            -p pubdir <the path of publicly accessible dir>
            -w wkey <key of the run> 

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
