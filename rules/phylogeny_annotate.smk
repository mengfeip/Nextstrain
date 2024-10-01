"""
This part of the workflow creates annotations for the phylogenetic tree.

REQUIRED INPUTS:
    sequences  = {build_dir}/{build_name}/masked.fasta
    metadata   = {build_dir}/{build_name}/metadata.tsv
    tree       = {build_dir}/{build_name}/tree.nwk
    clades     = config["clades"]

OUTPUTS:
    nt_muts             = {build_dir}/{build_name}/nt_muts.json
    aa_muts             = {build_dir}/{build_name}/aa_muts.json
    traits              = {build_dir}/{build_name}/traits.json
    clades              = {build_dir}/{build_name}/clades.json
    mutation_context    = {build_dir}/{build_name}/mutation_context.json
    recency             = {build_dir}/{build_name}/recency.json
"""


rule ancestral:
    input:
        tree=build_dir + "/{build_name}/tree.nwk",
        alignment=build_dir + "/{build_name}/masked.fasta",
    params:
        inference="joint",
    output:
        node_data=build_dir + "/{build_name}/nt_muts.json",
    shell:
        """
        augur ancestral \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --output-node-data {output.node_data} \
            --inference {params.inference}
        """


rule translate:
    input:
        tree=build_dir + "/{build_name}/tree.nwk",
        node_data=build_dir + "/{build_name}/nt_muts.json",
        genome_annotation=config["genome_annotation"],
    output:
        node_data=build_dir + "/{build_name}/aa_muts.json",
    shell:
        """
        augur translate \
            --tree {input.tree} \
            --ancestral-sequences {input.node_data} \
            --reference-sequence {input.genome_annotation} \
            --output {output.node_data}
        """


rule traits:
    input:
        tree=build_dir + "/{build_name}/tree.nwk",
        metadata=build_dir + "/{build_name}/metadata.tsv",
    params:
        columns=config["traits"]["columns"],
        sampling_bias_correction=config["traits"]["sampling_bias_correction"],
        strain_id=config["strain_id_field"],
    output:
        node_data=build_dir + "/{build_name}/traits.json",
    shell:
        """
        augur traits \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --output {output.node_data} \
            --columns {params.columns} \
            --confidence \
            --sampling-bias-correction {params.sampling_bias_correction}
        """


rule clades:
    input:
        tree=build_dir + "/{build_name}/tree.nwk",
        aa_muts=build_dir + "/{build_name}/aa_muts.json",
        nuc_muts=build_dir + "/{build_name}/nt_muts.json",
    params:
        clades=config["clades"],
    output:
        node_data=build_dir + "/{build_name}/clades_raw.json",
    shell:
        """
        augur clades \
            --tree {input.tree} \
            --mutations {input.nuc_muts} {input.aa_muts} \
            --clades {params.clades} \
            --output-node-data {output.node_data}
        """


rule rename_clades:
    input:
        build_dir + "/{build_name}/clades_raw.json",
    output:
        node_data=build_dir + "/{build_name}/clades.json",
    shell:
        """
        python scripts/rename_clade.py \
        --input-node-data {input} \
        --output-node-data {output.node_data}
        """


rule mutation_context:
    input:
        tree=build_dir + "/{build_name}/tree.nwk",
        node_data=build_dir + "/{build_name}/nt_muts.json",
    output:
        node_data=build_dir + "/{build_name}/mutation_context.json",
    shell:
        """
        python3 scripts/contextualize_mutation.py \
            --tree {input.tree} \
            --mutations {input.node_data} \
            --output {output.node_data}
        """


rule recency:
    input:
        metadata=build_dir + "/{build_name}/metadata.tsv",
    output:
        node_data=build_dir + "/{build_name}/recency.json",
    params:
        strain_id=config["strain_id_field"],
    shell:
        """
        python3 scripts/construct_recency.py \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --output {output} 2>&1
        """
