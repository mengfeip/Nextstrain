"""
This part of the workflow constructs the phylogenetic tree.

REQUIRED INPUTS:
    sequences   = {build_dir}/{build_name}/masked.fasta
    metadata    = {build_dir}/{build_name}/metadata.tsv
    tree_mask   = config["tree_mask"]

OUTPUTS:
    tree            = {build_dir}/{build_name}/tree.nwk
    branch_lengths  = {build_dir}/{build_name}/branch_lengths.json
"""


rule tree:
    input:
        alignment=build_dir + "/{build_name}/masked.fasta",
    params:
        tree_mask=config["tree_mask"],
    output:
        tree=build_dir + "/{build_name}/tree_raw.nwk",
    threads: workflow.cores
    shell:
        """
        export AUGUR_RECURSION_LIMIT=1000000
        augur tree \
            --alignment {input.alignment} \
            --exclude-sites {params.tree_mask} \
            --tree-builder-args="-redo" \
            --output {output.tree} \
            --nthreads {threads}
        """


rule fix_tree:
    input:
        tree=build_dir + "/{build_name}/tree_raw.nwk",
        alignment=build_dir + "/{build_name}/masked.fasta",
    params:
        root=lambda w: config.get("treefix_root", ""),
    output:
        tree=build_dir + "/{build_name}/tree_fixed.nwk",
    shell:
        """
        python3 scripts/fix_tree.py \
            --alignment {input.alignment} \
            --input-tree {input.tree} \
            {params.root} \
            --output {output.tree}
        """


rule refine:
    input:
        tree=(
            build_dir + "/{build_name}/tree_fixed.nwk"
            if config["fix_tree"]
            else build_dir + "/{build_name}/tree_raw.nwk"
        ),
        alignment=build_dir + "/{build_name}/masked.fasta",
        metadata=build_dir + "/{build_name}/metadata.tsv",
    params:
        coalescent="opt",
        date_inference="marginal",
        clock_filter_iqd=0,
        root=config["root"],
        clock_rate=(
            f"--clock-rate {config['clock_rate']}" if "clock_rate" in config else ""
        ),
        clock_std_dev=(
            f"--clock-std-dev {config['clock_std_dev']}"
            if "clock_std_dev" in config
            else ""
        ),
        strain_id=config["strain_id_field"],
        divergence_units=config["divergence_units"],
    output:
        tree=build_dir + "/{build_name}/tree.nwk",
        node_data=build_dir + "/{build_name}/branch_lengths.json",
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.strain_id} \
            --output-tree {output.tree} \
            --timetree \
            --root {params.root} \
            --precision 3 \
            --keep-polytomies \
            --use-fft \
            {params.clock_rate} \
            {params.clock_std_dev} \
            --output-node-data {output.node_data} \
            --coalescent {params.coalescent} \
            --date-inference {params.date_inference} \
            --date-confidence \
            --divergence-units {params.divergence_units} \
            --clock-filter-iqd {params.clock_filter_iqd}
        """


rule tip_frequencies:
    input:
        tree=build_dir + "/{build_name}/tree.nwk",
        metadata=build_dir + "/{build_name}/metadata.tsv",
    params:
        min_date=config["frequency"].get("min_date", "3Y"),
        max_date="2D",
        pivot_interval=1,
        pivot_interval_units="weeks",
    output:
        tip_freq=build_dir + "/{build_name}/tip_frequencies.json",
    shell:
        """
        augur frequencies \
            --method kde \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --pivot-interval {params.pivot_interval} \
            --pivot-interval-units {params.pivot_interval_units} \
            --min-date {params.min_date} \
            --max-date {params.max_date} \
            --output {output.tip_freq}
        """
