from packaging import version
from augur.__version__ import __version__ as augur_version
import sys

min_augur_version = "22.2.0"
if version.parse(augur_version) < version.parse(min_augur_version):
    print(f"Current augur version: {augur_version}. Minimum required: {min_augur_version}")
    sys.exit(1)


if not config:
    configfile: "config/All-Clades/config.yaml"


build_dir = "results"
auspice_dir = "auspice"

prefix = config.get("auspice_prefix", None)
AUSPICE_PREFIX = ("trial_" + prefix + "_") if prefix is not None else ""
AUSPICE_FILENAME = AUSPICE_PREFIX + config.get("auspice_name", config["build_name"])

database = config["database"]


rule all:
    input:
        auspice_json=build_dir + f"/{config['build_name']}/tree.json",
        root_sequence=build_dir + f"/{config['build_name']}/tree_root-sequence.json",
        tip_frequency=build_dir + f"/{config['build_name']}/tip_frequencies.json",
    params:
        nextstrain_url="nextstrain.org/groups/MPOX-CDC/"
    output:
        auspice_json=f"{auspice_dir}/{AUSPICE_FILENAME}.json",
        root_sequence_json=f"{auspice_dir}/{AUSPICE_FILENAME}_root-sequence.json",
        tip_frequency_json=f"{auspice_dir}/{AUSPICE_FILENAME}_tip-frequencies.json",
    shell:
        """
        cp {input.auspice_json} {output.auspice_json}
        cp {input.root_sequence} {output.root_sequence_json}
        cp {input.tip_frequency} {output.tip_frequency_json}
        export REQUESTS_CA_BUNDLE=/etc/pki/tls/cert.pem
        nextstrain login --username vjb0
        nextstrain remote upload {params.nextstrain_url} {output}
        """


include: "rules/sequence_prepare.smk"
include: "rules/phylogeny_construct.smk"
include: "rules/phylogeny_annotate.smk"
include: "rules/dataset_export.smk"


if "custom_rules" in config:
    for rule_file in config["custom_rules"]:
        include: rule_file


rule clean_all:
    """
    Clean results and auspice directories
    """
    params:
        results=build_dir,
        auspice=auspice_dir + f"/*.json",
        auspice_history=auspice_dir + f"/history/",
    shell:
        """
        rm -rf {params.results}
        mv -f {params.auspice} {params.auspice_history}
        """
