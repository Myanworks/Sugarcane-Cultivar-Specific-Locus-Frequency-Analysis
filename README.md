# Sugarcane Homozygous Specific Locus Analysis

This repository contains two Perl scripts for analyzing homozygous specific loci in sugarcane genomes (Saccharum officinarum and Saccharum spontaneum) and calculating genotype frequency distribution in cultivated sugarcane varieties.

## Script Descriptions

### 1. find.homozygous.pl
**Function**: Identify homozygous specific loci of *Saccharum officinarum* (tropical sugarcane) and *Saccharum spontaneum* (wild sugarcane), and determine the ancestral origin of each locus.  

**Input Files**:  

- Tropical sugarcane AF frequency file (must include CHROM, POS, N_CHR, ALLELE:FREQ fields)
  
- *S. spontaneum* AF frequency file (same format as above)

- GWAS locus file (must include CHROM and POS columns for locus information)
  
**Output File**: GWAS file with an additional `Origin` column, labeling locus ancestry as `soff.R-spon.A`/`soff.A-spon.R`/`unknown`.  

**Usage**:  

```bash

perl 1.find.homozygous.pl <Tropical_AF_File> <S_spontaneum_AF_File> <GWAS_File> <Output_File>

**### 2. extract_zaipei.freq.pl**
Function: Extract genotype frequency distribution of homozygous specific loci in cultivated sugarcane varieties based on a list of specific loci.Input Files:
Specific locus file (must include CHR, POS, P_value, Origin columns)

Cultivar frequency file (must include CHROM, POS, N_ALLELES, N_CHR, {ALLELE:FREQ} fields)

Output File: Combined table of specific locus information and cultivar frequency data.

**Usage**:  

```bash

perl extract_zaipei.freq.pl <Specific_Sites_File> <Cultivar_Freq_File> <Output_File>
