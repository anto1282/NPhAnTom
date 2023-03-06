#!/usr/bin/env nextflow


process SPADES {
    conda "spades=3.15.4 conda-forge::openmp"
    publishDir "${params.outdir}/${pair_id}/Assembly", mode: 'copy'

    cpus = 4
    input: 
    tuple val(pair_id), path(reads)

    output:
    path('assembly/contigs.fasta.gz')

    script:
    def (r1, r2) = reads
    
    """
    spades.py -o assembly -1 ${r1} -2 ${r2} --meta --phred-offset 33
    gzip -n assembly/contigs.fasta
    """
}



process offsetdetector {
    input:
    tuple val(pair_id), path(reads)

    output:
    val (phredscore)
    script:
    
    def (r1, r2) = reads
    
    phredscore = """
    python3 ${projectDir}/offsetdetector.py ${r1} ${r2}
    
    """
}

process SubSampling {
    conda 'agbiome::bbtools'
    input:
    val(pair_id)
    path(reads)
    val samplerate
    val sampleseed

    output:
    path(subsampled_reads)

    script:
    def (r1,r2) = reads

    subsampled_reads = reads.collect{
        "${it.baseName}_subsampled.fastq"
    }

    """
    reformat.sh in=${r1} in2=${r2} out=${subsampled_reads[0]} out2=${subsampled_reads[1]} samplerate=${samplerate} sampleseed=${sampleseed}
    """

}

