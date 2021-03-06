#!/usr/bin/env perl

#########################################################################################
#                                       stepMethylKit.pl
#########################################################################################
# 
#  This program  run methylKit in R.
#
#
#########################################################################################
# AUTHORS:
#
# Alper Kucukural, PhD 
# Jan 14, 2016
#########################################################################################


############## LIBRARIES AND PRAGMAS ################

 use List::Util qw[min max];
 use strict;
 use File::Basename;
 use Getopt::Long;
 use Pod::Usage; 

#################### VARIABLES ######################
 my $samplenames      = "";
 my $gbuild           = "";
 my $outdir           = "";
 my $strand           = "";
 my $tilesize         = "";
 my $stepsize         = "";
 my $topN             = "";
 my $mincoverage      = "";
 my $rscriptCMD       = "";
 my $pubdir           = "";
 my $wkey             = "";
 my $jobsubmit        = "";
 my $servicename      = "";
 my $help             = "";
 my $print_version    = "";
 my $version          = "1.0.0";
################### PARAMETER PARSING ####################

my $cmd=$0." ".join(" ",@ARGV); ####command line copy

GetOptions( 
    'samplenames=s'  => \$samplenames,
    'gbuild=s'       => \$gbuild,
    'outdir=s'       => \$outdir,
    'topN=s'         => \$topN,
    'mincoverage=s'  => \$mincoverage,
    'strand=s'       => \$strand,
    'tilesize=s'     => \$tilesize,
    'stepsize=s'     => \$stepsize,
    'rscriptCMD=s'   => \$rscriptCMD,
    'pubdir=s'       => \$pubdir,
    'wkey=s'         => \$wkey,
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

pod2usage( {'-verbose' => 0, '-exitval' => 1,} ) if ( ($samplenames eq "") or ($outdir eq "") );	

################### MAIN PROGRAM ####################
#    maps the reads to the ribosome and put the files under $outdir/after_ribosome directory

my $inputdir = "$outdir/mcall";
my $input_file_suffix = ".methylkit.txt";
$mincoverage=5 if ($mincoverage=/^$/);
$topN = 2000 if ($topN=/^$/);
$tilesize=300 if ($tilesize=/^$/);
$stepsize=300 if ($stepsize=/^$/);

$outdir   = "$outdir/methylKit";
`mkdir -p $outdir`;
$samplenames=~s/[\s\t]+//g;
my @inputarr=split(/:/,$samplenames);
my @sarr=();
foreach my $line (@inputarr)
{
   my @samples=split(/,/,$line);
   push(@sarr, $samples[0]);
}
$samplenames=join(',', @sarr);
$samplenames=~s/,/\",\"/g;
$samplenames="c(\"$samplenames\")";

if (lc($strand) !~/^no/) {
    $strand = "T";
}
else{
    $strand ="F";
}

my $puboutdir   = "$pubdir/$wkey";
`mkdir -p $puboutdir`;

runMethylKit($inputdir, $input_file_suffix, $samplenames, $gbuild, $outdir, $strand, $tilesize,  $stepsize,$mincoverage, $topN, $puboutdir, $wkey);

`cp -R $outdir $puboutdir/.`;

sub runMethylKit
{
my ($inputdir, $input_file_suffix, $samplenames, $gbuild, $outdir, $strand, $tilesize, $stepsize, $mincoverage, $topN, $puboutdir, $wkey)=@_;
my $output = "$outdir/rscript_methylKit.R";
my $sessioninfo = "$outdir/sessionInfo.txt";

open(OUT, ">$output");
my $rscript = qq/
library("methylKit")

push <- function(l, ...) c(l, list(...))
outerJoin <- function(data1, data2,data3, fields)
{
  d1 <- merge(data1, data2, by=fields, all=TRUE)
  d2 <- merge(data3, d1,  by=fields, all=TRUE)
  d2[,fields]
}
inputdir<-"$inputdir";input_file_suffix<-"$input_file_suffix"; samplenames<-$samplenames; gbuild<-"$gbuild"; outdir<-"$outdir"; strand<-$strand; tilesize<-$tilesize; stepsize<-$stepsize; mincoverage<-$mincoverage; topN<-$topN
  statspdf<-paste0(outdir,"\/stats.pdf")
  analysispdf<-paste0(outdir,"\/analysis.pdf")
  file.list<-list()

  for (i in seq(samplenames))
  {
    file.list<-push(file.list, paste0(inputdir, "\/", samplenames[i], input_file_suffix))
  }
  snames<-list()
  for (i in seq(samplenames))
  {
    snames<-push(snames, samplenames[i])
  }
  conds<-rep(0,length(samplenames))
  myobj=read( file.list,
              sample.id=snames,assembly=gbuild,treatment=conds)
  
  myobj.cpgcov<-myobj
  for (i in seq(samplenames))
  {
    myobj.cpgcov[[i]]\$coverage<-1
  }
  
  pdf(statspdf) 
  for (i in seq(samplenames))
  {
    getMethylationStats(myobj[[i]],plot=T,both.strands=F)
    getCoverageStats(myobj[[i]],plot=T,both.strands=F)
  }
  
  dev.off()
  meth=unite(myobj)
  
  tiles<-tileMethylCounts(myobj,win.size=tilesize,step.size=stepsize)
  tiles_cpgcov<-tileMethylCounts(myobj.cpgcov,win.size=tilesize,step.size=stepsize)
  
  meth_tiles<-unite(tiles)
  meth_tiles_cpgcov<-unite(tiles_cpgcov)
  
  try({
   pdf(analysispdf) 
   getCorrelation(meth_tiles,plot=T)
   clusterSamples(meth_tiles, dist="correlation", method="ward", plot=T)
   PCASamples(meth_tiles, screeplot=T)
   PCASamples(meth_tiles,screeplot=FALSE, adj.lim=c(0.0004,0.1),
             scale=TRUE,center=TRUE,comp=c(1,2),transpose=TRUE,sd.filter=TRUE,
             sd.threshold=0.5,filterByQuantile=TRUE,obj.return=FALSE)
   dev.off()
  },  silent = TRUE)
  
  tiles_comp=reorganize(meth_tiles,sample.ids=samplenames,
                        treatment=conds )
   
  data<-getData(meth_tiles)
  data_cpgcov<-getData(meth_tiles_cpgcov)
  
  rownames(data)<-paste(data\$chr,data\$start, data\$end,sep="_")
  
  cols<-c()
  for (i in seq(samplenames))
  {
    cols<-c(cols, paste0("coverage", i) )
  }
  
  norm_data<-cbind(rowSums(data[, cols]),
                   rowSums(data_cpgcov[, cols]))
  for (i in seq(samplenames))
  {
    norm_data<-cbind(norm_data, data[,paste0("numCs", i)]\/data[, paste0("coverage", i) ] )
  }
  
  rownames(norm_data) <- rownames(data)
  colnames(norm_data) <- c("Cov", "Cpg", samplenames)
  snames<-samplenames
  
  filtmincoverage<-cbind(apply(norm_data[norm_data[,"Cov"]\/norm_data[,"Cpg"]>mincoverage,3:dim(norm_data)[2]], 1, function(x) max(x)),1)
  
  lowelim<-norm_data[filtmincoverage[,1]>0.6, ]
  
  write.table(lowelim, paste0(outdir,"\/after_elimination.tsv"))
  
  cv<-cbind(apply(lowelim, 1, function(x) (sd(x,na.rm=TRUE)\/mean(x,na.rm=TRUE))), 1)
  colnames(cv)<-c("coeff", "a")
  
  withcvlowelim<-cbind(cv[,1], lowelim)
  colnames(withcvlowelim)[1]<-"Coeff"
  write.table(withcvlowelim, paste0(outdir,"\/after_elimination_with_coeff.tsv"))
  
  cvsort<-cv[order(cv[,1],decreasing=TRUE),]
  topindex<-dim(cvsort)[1]
  if (topindex>topN)
  {
     topindex<-topN
  }
  cvsort_top <- cvsort[1:topindex,]
  
  selected<-data.frame(norm_data[rownames(cvsort_top),snames])
  colnames(selected) <- snames
  write.table(selected, paste0(outdir,"\/most_cv_top.tsv"))
  
  save(meth_tiles, meth_tiles_cpgcov, file=paste0(outdir,"\/calcdata.rda"))
/;
print $rscript; 


print OUT $rscript; 
close(OUT);

my $com="$rscriptCMD $output > $sessioninfo 2>&1";

my $job=$jobsubmit." -n $servicename -c \"$com\"";
print $job."\n";   
`$job`;
die "Error 25: Cannot run the job:".$job if ($?);
my $verstring =`grep methylKit_ $sessioninfo`;
$verstring =~/(methylKit[^\s]+)/;
my $methtylit_ver=$1;
#$com.="echo \"$wkey\t$methtylit_ver\tdeseq\t$deseqdir/alldetected_$type.tsv\" >> $puboutdir/reports.tsv && ";
#$com.="echo \"$wkey\t$methtylit_ver\tdeseq\t$deseqdir/selected_log2fc_$type.tsv\" >> $puboutdir/reports.tsv && ";
#$com.="echo \"$wkey\t$methtylit_ver\tdeseq\t$deseqdir/rscript_$type.R\" >> $puboutdir/reports.tsv ";
#`$com`;
#die "Error 21: Cannot run DESeq2 output files:" if ($?);
}

__END__


=head1 NAME

stepMethylKit.pl

=head1 SYNOPSIS  

stepMethylKit.pl -sa samplenames <comma separated> 
            -o outdir <output directory> 

stepMethylKit.pl -help

stepMethylKit.pl -version

For help, run this script with -help option.

=head1 OPTIONS

=head2 -sa  samplnames 

{samples}.mehtylkit.txt will be input files.
    
=head2 -o outdir <output directory>

the output files will be "$outdir" 


=head2 -help

Display this documentation.

=head2 -version

Display the version

=head1 DESCRIPTION

 This program runs MethylKit in R

=head1 EXAMPLE


stepMethylKit.pl -c conds
            -o ~/out

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


