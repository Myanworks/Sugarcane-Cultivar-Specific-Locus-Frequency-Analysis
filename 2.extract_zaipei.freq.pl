#!/usr/bin/perl
use strict;
use warnings;

# Script Description: Retrieve cultivar frequency information based on specific site file
# Usage: perl script.pl <specific_sites_file> <cultivar_freq_file> <output_file>

# Get command line arguments
my ($specific_sites_file, $cultivar_freq_file, $output_file) = @ARGV;

if (not defined $output_file) {
    die "Usage: perl script.pl <specific_sites_file> <cultivar_freq_file> <output_file>\n";
}

print "Reading specific sites file...\n";
my %specific_sites;
open(my $spec_fh, '<', $specific_sites_file) or die "Cannot open specific sites file: $!";

# Read header line
my $header = <$spec_fh>;
chomp($header);

# Validate header format
unless ($header =~ /^CHR\s+POS\s+P_value\s+Origin$/) {
    die "Incorrect header format for specific sites file. Expected: CHR POS P_value Origin\n";
}

# Store specific site information
my @site_info;
while (<$spec_fh>) {
    chomp;
    next if /^\s*$/;  # Skip blank lines
    
    my ($chr, $pos, $p_value, $origin) = split(/\s+/, $_);
    next unless defined $chr and defined $pos;
    
    # Create key for lookup
    my $key = "$chr\t$pos";
    $specific_sites{$key} = {
        'p_value' => $p_value,
        'origin' => $origin,
        'original_line' => $_  # Save original line information
    };
    
    # Also save to array to preserve original order
    push @site_info, {
        'key' => $key,
        'chr' => $chr,
        'pos' => $pos,
        'p_value' => $p_value,
        'origin' => $origin
    };
}
close($spec_fh);

print "Found " . scalar(@site_info) . " specific sites\n";

print "Reading cultivar frequency file and building index...\n";
# Use hash to store frequency file information for efficient lookup
my %freq_index;
open(my $freq_fh, '<', $cultivar_freq_file) or die "Cannot open cultivar frequency file: $!";

# Read frequency file header line
my $freq_header = <$freq_fh>;
chomp($freq_header);

# Validate frequency file format
unless ($freq_header =~ /^CHROM\s+POS\s+N_ALLELES\s+N_CHR\s+\{ALLELE:FREQ\}$/) {
    die "Incorrect header format for cultivar frequency file. Expected: CHROM POS N_ALLELES N_CHR {ALLELE:FREQ}\n";
}

# Build index for frequency file
my $freq_count = 0;
while (<$freq_fh>) {
    chomp;
    next if /^\s*$/;  # Skip blank lines
    
    my @fields = split(/\s+/, $_);
    next if @fields < 5;  # At least 5 columns required
    
    my $chr = $fields[0];
    my $pos = $fields[1];
    
    # Create key
    my $key = "$chr\t$pos";
    
    # Store full line information (exclude first two columns as CHR and POS are used for lookup)
    my $n_alleles = $fields[2];
    my $n_chr = $fields[3];
    my $allele_freq = join("\t", @fields[4..$#fields]);
    
    $freq_index{$key} = {
        'n_alleles' => $n_alleles,
        'n_chr' => $n_chr,
        'allele_freq' => $allele_freq,
        'full_line' => $_  # Save full line for later use
    };
    
    $freq_count++;
    
    # Progress display (show every 100,000 lines)
    if ($freq_count % 100000 == 0) {
        print "  Processed $freq_count lines...\n";
    }
}
close($freq_fh);

print "Frequency file contains $freq_count sites, index built successfully\n";

print "Generating output file...\n";
open(my $out_fh, '>', $output_file) or die "Cannot create output file: $!";

# Write new file header
print $out_fh "CHR\tPOS\tP_value\tOrigin\tN_ALLELES\tN_CHR\t{ALLELE:FREQ}\n";

# Statistical information
my $found_count = 0;
my $not_found_count = 0;
my @not_found_sites;

# Look up frequency information for each specific site
foreach my $site (@site_info) {
    my $key = $site->{'key'};
    
    if (exists $freq_index{$key}) {
        $found_count++;
        
        # Get frequency information
        my $freq_info = $freq_index{$key};
        
        # Output new line
        print $out_fh join("\t", 
            $site->{'chr'},
            $site->{'pos'},
            $site->{'p_value'},
            $site->{'origin'},
            $freq_info->{'n_alleles'},
            $freq_info->{'n_chr'},
            $freq_info->{'allele_freq'}
        ) . "\n";
    } else {
        $not_found_count++;
        push @not_found_sites, $key;
        
        # Optional: Output sites with missing frequency information (fill with NA)
        # print $out_fh join("\t", 
        #     $site->{'chr'},
        #     $site->{'pos'},
        #     $site->{'p_value'},
        #     $site->{'origin'},
        #     "NA",  # N_ALLELES
        #     "NA",  # N_CHR
        #     "NA"   # {ALLELE:FREQ}
        # ) . "\n";
    }
}
close($out_fh);

print "Processing complete! Results saved to: $output_file\n";

# Print statistical information
print "\n========== Statistical Summary ==========\n";
print "Total specific sites: " . scalar(@site_info) . "\n";
print "Sites with matching frequency information: $found_count\n";
print "Sites with no frequency information found: $not_found_count\n";
printf "Match rate: %.2f%%\n", ($found_count/scalar(@site_info))*100;

# Print first few missing sites for inspection if any
if ($not_found_count > 0 and $not_found_count <= 20) {
    print "\nSites with no frequency data found (first $not_found_count):\n";
    foreach my $site (@not_found_sites) {
        print "  $site\n";
    }
} elsif ($not_found_count > 20) {
    print "\nSites with no frequency data found (first 20):\n";
    for (my $i = 0; $i < 20 && $i < $not_found_count; $i++) {
        print "  $not_found_sites[$i]\n";
    }
    print "  ... (". ($not_found_count - 20) . " more not shown)\n";
}

# Provide warnings for low match rate
if (($found_count/scalar(@site_info)) < 0.9) {
    print "\n⚠️  Warning: Low match rate! Possible reasons:\n";
    print "1. Chromosome naming inconsistencies between files (e.g., Chr1A vs chr1A)\n";
    print "2. Position information discrepancies\n";
    print "3. Duplicate sites in files\n";
    
    # Check chromosome naming patterns
    my %chr_patterns;
    foreach my $site (@site_info) {
        my $chr = $site->{'chr'};
        $chr_patterns{$chr} = 1;
    }
    
    print "\nExamples of chromosome formats in specific sites file:\n";
    my @sample_chrs = (keys %chr_patterns)[0..4];
    foreach my $chr (@sample_chrs) {
        print "  $chr\n";
    }
}