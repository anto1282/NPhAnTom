#!/usr/bin/env nextflow


process PHAROKKA {
    //errorStrategy 'retry'
    //errorStrategy {task.attempt == 1 ? 'retry' : 'ignore'}
    //maxRetries  = 2
    if (params.server){
        container = "docker://quay.io/biocontainers/pharokka:1.3.1--hdfd78af_0"
        cpus 8
    }
    else{
        conda 'conda-forge::pycirclize bioconda::pharokka=1.3.1 mash==2.2 bcbio-gff'
        cpus 8
    }
    
    publishDir "${params.outdir}/${pair_id}", mode: 'copy'

    input: 
    tuple val(pair_id), path(viralcontigs) 
    val (fastacount)
    
    output:
    tuple(val(pair_id), path("Pharokka/pharokka.g*"))
    path("Pharokka/")
    
    script:
    // if (task.attempt == 1){
    // """
    // pharokka.py -i ${viralcontigs} -o Pharokka -f -t ${task.cpus} -d ${params.phaDB} -g prodigal -m
    // """   
    // }
    // else{    
    // """
    // pharokka.py -i ${viralcontigs} -o Pharokka -f -t ${task.cpus} -d ${params.phaDB} -g prodigal 

    // """
    // }
    """
    echo Size of viral contigs fasta file: ${viralcontigs.size()} bytes
    """
    if (fastacount >= 2) {
    """
    echo "2 or more entries found in fasta file, running Pharokka with the -metagenomic tag"
    pharokka.py -i ${viralcontigs} -o Pharokka -f -t ${task.cpus} -d ${params.phaDB} -g prodigal -m
    """ 
    }
    else {
        if (viralcontigs.size() >= 20000){
        """
        echo "Only one entry in fasta file, running Pharokka without the -metagenomic tag"
        pharokka.py -i ${viralcontigs} -o Pharokka -f -t ${task.cpus} -d ${params.phaDB} -g prodigal 
        """   
        }
        else {
        """
        echo "No phages found with size above 20000\nPharokka was not run"
        """
        }
    }
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


process PHAROKKA_PLOTTER {
    //errorStrategy= "ignore"
    if (params.server){
        container = "docker://quay.io/biocontainers/pharokka:1.3.1--hdfd78af_0"
        cpus 2
        memory '2 GB'
        time = 2.m
        // time = 1.m
    }
    else{
        conda "conda-forge::pycirclize bioconda::pharokka=1.3.1 mash==2.2 bcbio-gff"
        //conda 'pharokka'
        cpus 1
        memory '2 GB'
        time = 2.m
    }
    
    publishDir "${params.outdir}/${pair_id}/CompiledResults", mode: 'copy'

    input: 
    
    //tuple path(pair_id_txt), path(gffFile), path(gbkFile), path(phage_contig)
    tuple val(pair_id), path(gffFile), path(gbkFile), path(phage_contig)
    // tuple val(pair_id_txt), path(phage_contig)

    output:
    path("*")

    script:

    """ 
    pharokka_plotter.py -i ${phage_contig} -n ${gffFile.baseName} --gff ${gffFile} --genbank ${gbkFile} -t ${phage_contig.baseName}
    """
    // """ 
    // pharokka_plotter.py -i ${phage_contig} -n ${phage_contig.baseName} --gff ${phage_contig.baseName}.gff --genbank ${phage_contig.baseName}.gbk --label_hypotheticals -t ${phage_contig.baseName}
    // """
    
}

process RESULTS_COMPILATION {
    cpus {1 * task.attempt}
    memory {2.GB * task.attempt}
    time = {1.m * task.attempt}
    //errorStrategy = 'ignore'
    errorStrategy {task.attempt == 1 ? 'retry' : 'ignore'}
    
    publishDir "${params.outdir}/${pair_id}/CompiledResults", mode: 'copy'

    
    input:        
    
    tuple val(pair_id), path(viralcontigs), path(iphop_predictions), path(checkv_results)
    
    output:
    path ("compiled_results.html")
    
   
    script:

    if (params.iphopDB != false) {
    """   
    python3 ${projectDir}/nphantom_compilation.py compiled_results.html ${viralcontigs} ${iphop_predictions}/Host_prediction_to_genus_m90.csv  ${iphop_predictions}/Host_prediction_to_genome_m90.csv ${checkv_results}/completeness.tsv ${projectDir}/${params.outdir}/${pair_id}/Assembly/assemblyStats.txt ${pair_id}
    """
    }
    else {
    """   
    python3 ${projectDir}/nphantom_compilation.py compiled_results.html ${viralcontigs} NOIPHOP NOIPHOP ${checkv_results}/completeness.tsv ${projectDir}/${params.outdir}/${pair_id}/Assembly/assemblyStats.txt ${pair_id}
    """
    }
}

