#!/usr/bin/env nextflow


process PHAROKKA{
    errorStrategy {task.attempt == 1 ? 'retry' : 'ignore'}
    if (params.server){
        container = "docker://quay.io/biocontainers/pharokka:1.3.2--hdfd78af_0"
        cpus 8
    }
    else{
        conda 'conda-forge::pycirclize bioconda::pharokka=1.3.2 mash==2.2 bcbio-gff'
        cpus 8
    }
    
    publishDir "${params.outdir}/${pair_id}", mode: 'copy'

    input: 
    tuple val(pair_id), path(viralcontigs) 
    
    output:
    tuple(val(pair_id), path("Pharokka/pharokka.g*"))
    path("Pharokka/")
    
    script:
    if (task.attempt == 1){
    """
    pharokka.py -i ${viralcontigs} -o Pharokka -f -t ${task.cpus} -d ${params.phaDB} -g prodigal -m
    """   
    }
    else{    
    """
    pharokka.py -i ${viralcontigs} -o Pharokka -f -t ${task.cpus} -d ${params.phaDB} -g prodigal 

    """
    }
}


process FASTASPLITTER{
    // publishDir "${params.outdir}/${pair_id}/ViralContigs", mode: 'copy'
    
    // Creates fasta files for each contig
    
    input:
    tuple val(pair_id), path(viralcontigs)

    output:
    //tuple val(pair_id), path("*.fasta")
    //val (pair_id)
    path("*.fasta")
    
    script:

    //Reads a fasta file and saves each sequence to a separate output file.
    //The output file name is the same as the sequence header with a .fasta extension.
    
    """
    python3 ${projectDir}/fastasplitter.py ${viralcontigs}
    """
}



process PHAROKKASPLITTER{
    
    input:
    tuple(val(pair_id), path(files))
    

    output:
    
    //tuple path("${pair_id}._NODE*.txt"), path("${pair_id}_NODE*.gff"), path("${pair_id}_NODE*.gbk"), path("${pair_id}_NODE*.fasta")
    tuple val(pair_id), path("${pair_id}_NODE*.gff"), path("${pair_id}_NODE*.gbk"), path("${pair_id}_NODE*.fasta")
    //tuple path("${pair_id}._NODE*.txt"), path("${pair_id}_NODE*.fasta")
    //tuple path("${pair_id}_NODE*"), path(".")
    //tuple path("${pair_id}._NODE*.txt"), path("${pair_id}_NODE*.gff")
    // tuple path("${pair_id}._NODE*.txt"), path("${pair_id}_NODE*.gbk")
    // tuple path("${pair_id}._NODE*.txt"), path("${pair_id}_NODE*.fasta")

    script:
  
    """
    python3 ${projectDir}/PharokkaSplitter.py ${files[1]} ${files[0]} ${pair_id}
    """
}


process PHAROKKA_PLOTTER{
    errorStrategy {task.attempt  < 3 ? 'retry' : 'ignore'}
    maxRetries 5
    
    //errorStrategy= "ignore"
    if (params.server){
        container = "docker://quay.io/biocontainers/pharokka:1.3.2--hdfd78af_0"
        cpus 1
        memory '2 GB'
        time = {20.m * task.attempt}
        // time = 1.m
    }
    else{
        conda "conda-forge::pycirclize bioconda::pharokka=1.3.2 mash==2.2 bcbio-gff"
        //conda 'pharokka'
        cpus 1
        memory '2 GB'
        time = 1.h
    }
    
    publishDir "${params.outdir}/${pair_id}/CompiledResults", mode: 'copy'

    input: 
    
    //tuple path(pair_id_txt), path(gffFile), path(gbkFile), path(phage_contig)
    tuple val(pair_id), path(gffFile), path(gbkFile), path(phage_contig)
    // tuple val(pair_id_txt), path(phage_contig)

    output:
    path("*")

    script:
    if (task.attempt == 1) { 
    """ 
    pharokka_plotter.py -i ${phage_contig} -n ${gffFile.baseName} --gff ${gffFile} --genbank ${gbkFile} -t ${phage_contig.baseName}
    """    
    }
    else {
    """ 
    pharokka_plotter.py -i ${phage_contig} -n ${gffFile.baseName} --gff ${gffFile} --genbank ${gbkFile} -t ${phage_contig.baseName} --label_hypotheticals
    """
    }
}

process RESULTS_COMPILATION{
    cpus 2
    memory '3 GB'
    time = {1.m * task.attempt }
    errorStrategy {task.attempt  < 3 ? 'retry' : 'ignore'}
    //errorStrategy = 'ignore'
    
    publishDir "${params.outdir}/${pair_id}/CompiledResults", mode: 'copy'

    
    input:        
    
    tuple val(pair_id), path(viralcontigs), path(iphop_predictions), path(checkv_results)
    
    output:
    path ("${pair_id}_compiled_results.html")
    
   
    script:

    if (params.iphopDB != false) {
    """   

    python3 ${projectDir}/nphantom_compilation.py ${pair_id}_compiled_results.html ${viralcontigs} ${iphop_predictions}/Host_prediction_to_genus_m90.csv  ${iphop_predictions}/Host_prediction_to_genome_m90.csv ${checkv_results}/completeness.tsv ${projectDir}/${params.outdir}/${pair_id}/Assembly/assemblyStats.txt ${pair_id}
    """
    }
    else {
    """   
    
    python3 ${projectDir}/nphantom_compilation.py ${pair_id}_compiled_results.html ${viralcontigs} NOIPHOP NOIPHOP ${checkv_results}/completeness.tsv ${projectDir}/${params.outdir}/${pair_id}/Assembly/assemblyStats.txt ${pair_id}
    """
    }
}

