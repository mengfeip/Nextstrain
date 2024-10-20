#! /bin/bash
awk '(NR==1) || (FNR>1)' data/metadata_GenBank.tsv data/metadata_GISAID.tsv > data/metadata_public.tsv
cat data/sequences_GenBank.fasta data/sequences_GISAID.fasta > data/sequences_public_all.fasta
seqkit rmdup -s -i -D data/sequences_public_duplicates.tsv -w 0 -o data/sequences_public.fasta data/sequences_public_all.fasta
