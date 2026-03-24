#!/usr/bin/perl
use strict;
use warnings;

# Get command line arguments
my ($Rf_soff_file, $Rf_spon_file, $gwas_file, $output_file) = @ARGV;

if (not defined $output_file) {
    die "Usage: perl script.pl <Tropical AF file> <S. spontaneum AF file> <GWAS file> <Output file>\n";
}

# Hash to store all statistical data
my %stats;


print "Reading Tropical AF file...\n";
open(my $soff_fh, '<', $Rf_soff_file) or die "Cannot open Tropical AF file: $!";
while (<$soff_fh>) {
    chomp;
    next if /^\s*$/;
    next if /CHROM/;
    
    my @fields = split(/\t/, $_);
    next if @fields < 6;  # Require 6 fields
    
    my $chr = $fields[0];
    my $pos = $fields[1];
    my $n_chr = $fields[3];  # 4th field should be N_CHR
    my $Rf_info = $fields[4];
    my $Af_info = $fields[5];
    
    # Check if N_CHR >= 10
    next if $n_chr < 10;
    
    # Parse ALLELE:FREQ format
    my $Rf = 0;
    if ($Rf_info =~ /([^:]+):([0-9.eE-]+)/) {
        $Rf = $2;
    }
    
    my $Af = 0;
    if ($Af_info =~ /([^:]+):([0-9.eE-]+)/) {
        $Af = $2;
    }
    
    my $key = "$chr\_$pos";
    $stats{$key}{'Rf_soff'} = $Rf;
    $stats{$key}{'Af_soff'} = $Af;
}
close($soff_fh);

print "Reading S. spontaneum AF file...\n";
open(my $spon_fh, '<', $Rf_spon_file) or die "Cannot open S. spontaneum AF file: $!";
while (<$spon_fh>) {
    chomp;
    next if /^\s*$/;
    next if /CHROM/;
    
    my @fields = split(/\t/, $_);
    next if @fields < 6;  # Require 6 fields
    
    my $chr = $fields[0];
    my $pos = $fields[1];
    my $n_chr = $fields[3];
    my $Rf_info = $fields[4];
    my $Af_info = $fields[5];
    
    next if $n_chr < 10;
    
    my $Rf = 0;
    if ($Rf_info =~ /([^:]+):([0-9.eE-]+)/) {
        $Rf = $2;
    }
    my $Af = 0;
    if ($Af_info =~ /([^:]+):([0-9.eE-]+)/) {
        $Af = $2;
    }
    
    my $key = "$chr\_$pos";
    $stats{$key}{'Rf_spon'} = $Rf;
    $stats{$key}{'Af_spon'} = $Af;
}
close($spon_fh);

print "Processing GWAS file and determining ancestry...\n";
open(my $gwas_fh, '<', $gwas_file) or die "Cannot open GWAS file: $!";
open(my $out_fh, '>', $output_file) or die "Cannot create output file: $!";

my $header = <$gwas_fh>;
chomp($header);
print $out_fh "$header\tOrigin\n" if defined $header;

# Statistical information
my $processed = 0;
my $found = 0;
my %origin_counts = (
    'soff.R-spon.A' => 0,
    'soff.A-spon.R' => 0,
    'common_ancestry' => 0,
    'ambiguous' => 0,
    'unknown' => 0
);

while (<$gwas_fh>) {
    chomp;
    $processed++;
    my @fields = split(/\t/, $_);
    
    my $chr = $fields[0];
    my $pos = $fields[1];
    my $key = "$chr\_$pos";
    
    my $origin = "unknown";
    
    # Check if all required data for the site exists
    if (exists $stats{$key} and 
        defined $stats{$key}{'Rf_soff'} and 
        defined $stats{$key}{'Rf_spon'} and
        defined $stats{$key}{'Af_soff'} and
        defined $stats{$key}{'Af_spon'}) {
        
        $found++;
        my $Rf_soff = $stats{$key}{'Rf_soff'};
        my $Rf_spon = $stats{$key}{'Rf_spon'};
        my $Af_soff = $stats{$key}{'Af_soff'};  # Fix variable name
        my $Af_spon = $stats{$key}{'Af_spon'};  # Fix variable name
        
        # Logic for determining ancestry 
        if ($Rf_soff == 1 and $Af_spon == 1) {
            $origin = "soff.R-spon.A";  
        }
        elsif ($Rf_spon == 1 and $Af_soff == 1) {
            $origin = "soff.A-spon.R";  
        }
        else {
            $origin = "unknown";
        }
    }
    
    $origin_counts{$origin}++;
    print $out_fh "$_\t$origin\n";
}

close($gwas_fh);
close($out_fh);

print "Processing complete! Results saved to: $output_file\n";

# Print statistical information
print "\n========== Statistical Summary ==========\n";
print "Total GWAS sites processed: $processed\n";
print "Sites with matching data found: $found\n";
printf "Coverage rate: %.2f%%\n", ($found/$processed)*100;
print "\nAncestry classification statistics:\n";
print "soff.R-spon.A: $origin_counts{'soff.R-spon.A'}\n";
print "soff.A-spon.R: $origin_counts{'soff.A-spon.R'}\n";
print "Unknown: $origin_counts{'unknown'}\n";