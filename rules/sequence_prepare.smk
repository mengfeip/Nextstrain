"""
This part of the workflow prepares sequences for constructing phylogeny.

REQUIRED INPUTS:
    include           = config["include"]
    reference         = config["reference"]
    genome_annotation = config["genome_annotation"]
    maskfile          = config["mask"]["maskfile"]

OUTPUTS:
    prepared_sequences = {build_dir}/{build_name}/masked.fasta
"""


rule filter:
    input:
        sequences="data/sequences_" + database + ".fasta",
        metadata="data/metadata_" + database + ".tsv",
    params:
        exclude=config["exclude"],
        min_date=config["filter"]["min_date"],
        min_length=config["filter"]["min_length"],
        strain_id=config["strain_id_field"],
        exclude_where=lambda w: (
            f"--exclude-where {config['filter']['exclude_where']}"
            if "exclude_where" in config["filter"]
            else ""
        ),
    output:
        sequences=build_dir + "/{build_name}/good_sequences.fasta",
        metadata=build_dir + "/{build_name}/good_metadata.tsv",
        log=build_dir + "/{build_name}/good_filter.log",
    shell:
        """
        augur filter \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --output-sequences {output.sequences} \
            --output-metadata {output.metadata} \
            --exclude {params.exclude} \
            {params.exclude_where} \
            --min-date {params.min_date} \
            --min-length {params.min_length} \
            --query "(QC_rare_mutations == 'good' | QC_rare_mutations == 'mediocre')" \
            --output-log {output.log}
        """


rule subsample:
    input:
        metadata=build_dir + "/{build_name}/good_metadata.tsv",
    params:
        group_by=lambda w: config["subsample"][w.sample]["group_by"],
        sequences_per_group=lambda w: config["subsample"][w.sample][
            "sequences_per_group"
        ],
        query=lambda w: (
            f"--query {config['subsample'][w.sample]['query']}"
            if "query" in config["subsample"][w.sample]
            else ""
        ),
        other_filters=lambda w: config["subsample"][w.sample].get("other_filters", ""),
        exclude=lambda w: (
            f"--exclude-where {' '.join([f'lineage={l}' for l in config['subsample'][w.sample]['exclude_lineages']])}"
            if "exclude_lineages" in config["subsample"][w.sample]
            else ""
        ),
        strain_id=config["strain_id_field"],
    output:
        strains=build_dir + "/{build_name}/{sample}_strains.txt",
        log=build_dir + "/{build_name}/{sample}_filter.log",
    shell:
        """
        augur filter \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --output-strains {output.strains} \
            {params.group_by} \
            {params.sequences_per_group} \
            {params.query} \
            {params.exclude} \
            {params.other_filters} \
            --output-log {output.log}
        """


rule combine_samples:
    input:
        strains=lambda w: [
            f"{build_dir}/{w.build_name}/{sample}_strains.txt"
            for sample in config["subsample"]
        ],
        sequences=build_dir + "/{build_name}/good_sequences.fasta",
        metadata=build_dir + "/{build_name}/good_metadata.tsv",
    params:
        strain_id=config["strain_id_field"],
        include=config["include"],
    output:
        sequences=build_dir + "/{build_name}/filtered.fasta",
        metadata=build_dir + "/{build_name}/metadata.tsv",
    shell:
        """
        augur filter \
            --metadata-id-columns {params.strain_id} \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --exclude-all \
            --include {input.strains} {params.include}\
            --output-sequences {output.sequences} \
            --output-metadata {output.metadata}
        """


rule reverse_complements:
    input:
        metadata=build_dir + "/{build_name}/metadata.tsv",
        sequences=build_dir + "/{build_name}/filtered.fasta",
    output:
        build_dir + "/{build_name}/reversed.fasta",
    shell:
        """
        python3 scripts/reverse_complement.py \
            --metadata {input.metadata} \
            --sequences {input.sequences} \
            --output {output}
        """


rule align:
    input:
        sequences=build_dir + "/{build_name}/reversed.fasta",
        reference=config["reference"],
        genome_annotation=config["genome_annotation"],
    params:
        excess_bandwidth=100,
        terminal_bandwidth=300,
        window_size=40,
        min_seed_cover=0.1,
        allowed_mismatches=8,
        gap_alignment_side="left",
    output:
        alignment=build_dir + "/{build_name}/aligned.fasta",
    threads: workflow.cores
    shell:
        """
        nextclade3 run \
            --jobs {threads} \
            --input-ref {input.reference} \
            --input-annotation {input.genome_annotation} \
            --excess-bandwidth {params.excess_bandwidth} \
            --terminal-bandwidth {params.terminal_bandwidth} \
            --window-size {params.window_size} \
            --min-seed-cover {params.min_seed_cover} \
            --allowed-mismatches {params.allowed_mismatches} \
            --gap-alignment-side {params.gap_alignment_side} \
            --output-fasta - \
            {input.sequences} | seqkit seq -i > {output.alignment}
        """


rule mask:
    input:
        sequences=build_dir + "/{build_name}/aligned.fasta",
    params:
        mask=config["mask"]["maskfile"],
        from_start=config["mask"]["from_beginning"],
        from_end=config["mask"]["from_end"],
    output:
        build_dir + "/{build_name}/masked.fasta",
    shell:
        """
        augur mask \
            --sequences {input.sequences} \
            --mask {params.mask} \
            --mask-from-beginning {params.from_start} \
            --mask-from-end {params.from_end} --output {output}
        """
