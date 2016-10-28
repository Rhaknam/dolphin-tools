#!/usr/bin/perl

use File::Basename;

my $bedfile = $ARGV[0]; # input bed file
my $outdir = $ARGV[1];  # bam outdirectory
my $genome = $ARGV[2];  # bedtools genome file
my $tlength = 9;        # 9 is the length of the region on which transposase acts
my $outsideRead = 10;   # outside length adjust
my $insideRead = 10;    # inside length adjust
my %chrom2len = ();

open(GEN,"<$genome") || die("Cannot open $genome.\n");
while(<GEN>){
    chomp;
    my @chr = split("\t");
    $chrom2len{$chr[0]} = $chr[1];
}
close(GEN);

if ( !($bedfile =~ /\.bed$/)){
    die("Expected input file to have .bed extension.\n");
}

$bedfile=~/(.*\/(.*)).bed/;
my $bedname = $2;
my $out = "$outdir/$bedname.adjust.bed";\

open(BED,"<$bedfile") || die("Cannot open input file, $bedfile.\n");
open(OUT,">$out") || die("Cannot open output file, $out.\n");

while(<BED>){
    chomp;
    my @linepts = split("\t");
    if (( ! exists $chrom2len{$linepts[0]}) || ( ! defined $chrom2len{$linepts[0]})){
        next;
    }
    if ($linepts[5] eq "+"){
        $linepts[2] = $linepts[1] + $tlength + $insideRead;
        $linepts[1] = $linepts[1] - $outsideRead;
    }elsif($linepts[5] eq "-"){
        $linepts[1] = $linepts[2] - $tlength - $insideRead;
        $linepts[2] = $linepts[2] + $outsideRead;
    }
    if ($linepts[1] < 0){
        $linepts[1] = 0;
    }
    if ($linepts[2] > $chrom2len{$linepts[0]}){
        $linepts[2] = $chrom2len{$linepts[0]};
    }
    if ($linepts[1] != $linepts[2]){
        my $outline = join("\t",@linepts);
        print OUT $outline,"\n";
    }
}
close(BED);
close(OUT);