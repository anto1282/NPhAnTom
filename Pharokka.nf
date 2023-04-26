#!/usr/bin/env nextflow


process PHAROKKA {
    errorStrategy= "finish"
    if (params.server){
        container = "docker://quay.io/biocontainers/pharokka:1.3.1--hdfd78af_0"
        cpus 8
    }
    else{
        conda 'pharokka=1.3.1'
        //container = "shub://quay.io/biocontainers/pharokka:1.3.1--hdfd78af_0"
        cpus 8
    }
    
    publishDir "${params.outdir}/${pair_id}", mode: 'copy'

    input: 
    tuple val(pair_id), path(viralcontigs) 

    
    output:
    tuple(val(pair_id), path("pharokka_${pair_id}/pharokka.g*"))
    
    
    script:

    """
    
    pharokka.py -i ${viralcontigs} -o pharokka_${pair_id} -f -t ${task.cpus} -d ${params.phaDB} -g prodigal -m
    
    """
    
}


process FASTASPLITTER {
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



process PHAROKKASPLITTER {
    
    input:
    tuple(val(pair_id), path(files))
    

    output:
    path("NODE_*.gff") 
    path("NODE_*.gbk")
    path("NODE_*.fasta")

    script:
  
    """
    python3 ${projectDir}/PharokkaSplitter.py ${files[1]} ${files[0]}
    """
}


process PHAROKKA_PLOTTER {
    errorStrategy= "finish"
    if (params.server){
        container = "docker://quay.io/biocontainers/pharokka:1.3.1--hdfd78af_0"
        cpus 1
        memory '2 GB'
        time = 1.h
        // time = 1.m
    }
    else{
        container = "docker://quay.io/biocontainers/pharokka:1.3.1-hdfd78af_0"
        //conda 'pharokka'
        cpus 1
        memory '2 GB'
        time = 1.h
    }
    
    publishDir "${params.outdir}/${pair_id}/results", mode: 'copy'

    input: 
    path(gffFile)
    path(gbkFile)
    path(phage_contig)

    output:
    path("*")

    script:

    """ 
    pharokka_plotter.py -i ${phage_contig} -n ${gffFile.simpleName} --gff ${gffFile} --genbank ${gbkFile} --label_hypotheticals 
    """
    
}

process RESULTS_COMPILATION {
    cpus 1
    memory '2 GB'
    time = 1.m
    errorStrategy = 'finish'
    
    publishDir "${params.outdir}/${pair_id}/results", mode: 'copy'

    
    input:        
    
    tuple val(pair_id), path(viralcontigs)

    path(iphop_predictions)
    
    path(checkv_results)
    
    output:
    path ("compiled_results.html")
    
   
    script:

    if (params.server) {
    """   
    python3 ${projectDir}/nphantom_compilation.py compiled_results.html ${viralcontigs} ${iphop_predictions}/Host_prediction_to_genus_m90.csv ${checkv_results}/completeness.tsv ${projectDir}/${params.outdir}/${pair_id}/assemblyStats ${pair_id}
    """
    }
    else {
    """   
    python3 ${projectDir}/nphantom_compilation.py compiled_results.html ${viralcontigs} NOIPHOP ${checkv_results}/completeness.tsv ${projectDir}/${params.outdir}/${pair_id}/assemblyStats ${pair_id}
    """
    }
}