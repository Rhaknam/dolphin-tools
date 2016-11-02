#!/usr/bin/env perl

#########################################################################################
#                                       stepMACS.pl
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
 my $chipinput        = "";
 my $outdir           = "";
 my $jobsubmit        = "";
 my $type             = "";
 my $previous         = ""; 
 my $acmd             = "";
 my $extraparams      = "";
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $cmd=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
    'inputchip=s'    => \$chipinput,
    'outdir=s'       => \$outdir,
    'previous=s'     => \$previous,
    'type=s'         => \$type,
    'acmd=s'         => \$acmd,
	'extraparams=s'  => \$extraparams,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($chipinput eq "") or ($outdir eq "") );	

################### MAIN PROGRAM ####################
#  It runs macs14 to find the peaks using alined peaks   

my $inputdir = "";
if ($type eq "chip")
{
  $inputdir = "$outdir/seqmapping/chip";
}
else
{
  $inputdir = "$outdir/$type";
}


$outdir  = "$outdir/macs";
`mkdir -p $outdir`;
die "Error 15: Cannot create the directory:$outdir" if ($?);

my @chiplibs=split(/:/,$chipinput);
my $bname="";
foreach my $chipline (@chiplibs)
{
 print $chipline."\n";
 my @chipinput=split(/__tt__/,$chipline);
 $bname=$chipinput[0];
 my $chipfiles=getFiles($inputdir,$chipinput[1]);
 $extraparams =~ s/,/ /g;
 $extraparams =~ s/__cr____cn__/ /g;
 my $com="$acmd $extraparams -t $chipfiles ";
 
 if (@chipinput>2 && length($chipinput[2])>=1)
 {
   my $inputfiles=getFiles($inputdir,$chipinput[2]);
   $com.="-c $inputfiles "; 
 }
 if (checkFile($inputdir."/".$bname.".adjust.bam")) {
	$com.="-f BED ";
 }elsif(checkFile($inputdir."/".$bname.".sorted.adjust.bam")){
	$com.="-f BED ";
 }
 
 
 $com .= " --name=$outdir/$bname";

 my $job=$jobsubmit." -n ".$servicename."_".$bname." -c \"$com\"";
 print $job."\n";   
 `$job`;
 die "Error 25: Cannot run the job:".$job if ($?);
}

sub getFiles
{
 my ($inputdir, $libs)=@_; 
 my @libnames = split(",",$libs);
 my @files=();
 foreach my $lib (@libnames)
 {
   my $file= $inputdir."/".$lib.".bam";
   $file=$inputdir."/".$lib.".sorted.bam" unless (checkFile($file));
   $file=$inputdir."/".$lib.".adjust.bed" unless (checkFile($file));
   $file=$inputdir."/".$lib.".sorted.adjust.bed" unless (checkFile($file));
   die "Error 64: please check the file:".$file unless (checkFile($file));
   push(@files, $file);
 }
 return join(' ', @files);
 return $files[0];
}

sub checkFile
{
 my ($file) = $_[0];
 return 1 if (-e $file);
 return 0;
}

__END__


=head1 NAME

stepMACS.pl

=head1 SYNOPSIS  

stepMACS.pl -o outdir <output directory> 
            -p previous 
            -n #reads

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

 This program map the reads to rRNAs and put the rest into other files 

=head1 EXAMPLE


stepMACS.pl 
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


