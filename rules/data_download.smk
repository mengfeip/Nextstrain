"""
This part of the workflow download Nextstrain dataset for sequences preparation.
Currently sourcing sequences and metadata from GenBank/GISAID_Ingest workflow instead.
"""


rule download:
    input:
        sequences_url="https://data.nextstrain.org/files/workflows/mpox/sequences.fasta.xz",
        metadata_url="https://data.nextstrain.org/files/workflows/mpox/metadata.tsv.gz",
    output:
        sequences="data/sequences.fasta.xz",
        metadata="data/metadata.tsv.gz",
    shell:
        """
        curl -fsSL --compressed {input.sequences_url:q} --output {output.sequences}
        curl -fsSL --compressed {input.metadata_url:q} --output {output.metadata}
        """


rule decompress:
    input:
        sequences="data/sequences.fasta.xz",
        metadata="data/metadata.tsv.gz",
    output:
        sequences="data/sequences.fasta",
        metadata="data/metadata.tsv",
    shell:
        """
        gzip --decompress --keep {input.metadata}
        xz --decompress --keep {input.sequences}
        """
