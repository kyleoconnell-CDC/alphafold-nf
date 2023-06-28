
process RUN_ALPHAFOLD2 {
    tag "$meta.id"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'docker://nfcore/proteinfold_alphafold2_standard:1.0.0' :
        'nfcore/proteinfold_alphafold2_standard:1.0.0' }"

    input:
    tuple val(meta), path(fasta)
    val   max_num_preds
    val   date
    path (data_dir)
    val   model_preset
    val   use_gpu
    val   copy_dbs

    output:
    path ("${fasta.baseName}*")
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    if (params.copy_dbs ) { 
        aws s3 cp ${data_dir} alphafold --recursive
        ${data_dir} = alphafold

    }

    python3 /app/alphafold/run_alphafold.py \
        --fasta_paths=${fasta} \
        --max_template_date=${date} \
        --data_dir=${data_dir} \
        --model_preset=${model_preset} \
        --num_multimer_predictions_per_model=${max_num_preds} \
        --output_dir=. \
        --bfd_database_path=${data_dir}/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt \
        --uniprot_database_path=${data_dir}/uniprot/uniprot.fasta \
        --pdb_seqres_database_path=${data_dir}/pdb_seqres/pdb_seqres.txt \
        --uniclust30_database_path=${data_dir}/uniclust30/uniclust30_2018_08/* \
        --uniref90_database_path=${data_dir}/uniref90/uniref90.fasta \
        --mgnify_database_path=${data_dir}/mgnify/mgy_clusters_2018_12.fa \
        --template_mmcif_dir=${data_dir}/pdb_mmcif/mmcif_files \
        --obsolete_pdbs_path=${data_dir}/pdb_mmcif/obsolete.dat \
        --use_gpu_relax=${use_gpu} \
        --random_seed=53343

    cp "${fasta.baseName}"/ranked_0.pdb ./"${fasta.baseName}".alphafold.pdb
    cd "${fasta.baseName}"
    awk '{print \$6"\\t"\$11}' ranked_0.pdb | uniq > ranked_0_plddt.tsv
    for i in 1 2 3 4
        do awk '{print \$6"\\t"\$11}' ranked_\$i.pdb | uniq | awk '{print \$2}' > ranked_"\$i"_plddt.tsv
    done
    paste ranked_0_plddt.tsv ranked_1_plddt.tsv ranked_2_plddt.tsv ranked_3_plddt.tsv ranked_4_plddt.tsv > plddt.tsv
    echo -e Positions"\\t"rank_0"\\t"rank_1"\\t"rank_2"\\t"rank_3"\\t"rank_4 > header.tsv
    cat header.tsv plddt.tsv > ../"${fasta.baseName}"_plddt_mqc.tsv
    cd ..

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python3 --version | sed 's/Python //g')
    END_VERSIONS
    """
}