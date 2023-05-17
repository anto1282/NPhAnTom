#!/usr/bin/env nextflow
nextflow.enable.dsl=2

include {FASTERQDUMP;TRIM; KRAKEN; TAXREMOVE; FASTQC} from "./Trimming.nf"
include {SPADES; OFFSETDETECTOR; N50} from "./Assembly.nf"
include {DVF;VIRSORTER;CHECKV; SEEKER; PHAGER; VIREXTRACTOR;DEEPVIREXTRACTOR} from "./VirPredictions.nf"
include {PHAROKKA; PHAROKKA_PLOTTER; RESULTS_COMPILATION;FASTASPLITTER; PHAROKKASPLITTER} from "./Pharokka.nf"
include {IPHOP} from "./HostPredictor.nf"



// Main workflow script for the pipeline

workflow{
    
    if (params.IDS != false && params.pair_file_names == false)
    {
    // CREATES A NEXTFLOW CHANNEL CONTAINING THE READ IDS
    Channel
        .value(params.IDS)
        .flatten()
        .set { read_IDS_ch }

    // DOWNLOADS THE CORRESPONDING READS USING FASTERQDUMP 
    read_pairs_ch = FASTERQDUMP(read_IDS_ch)
    }
    else if (params.pair_file_names != false && params.IDS == false)
    {
    // CREATING CHANNEL WITH TWO READS FROM PROVIDED FILEPATH
    // MUST BE IN THE FORM OF path/to/directory/SOMESRANR_{R1,R2}.fastq.gz
    // OR FOR MULTIPLE SAMPLES path/to/directory/*_{R1,R2}.fastq.gz
    Channel
        .fromFilePairs(params.pair_file_names)
        .set {read_pairs_ch}
    }
    else {
        error("Error: You are not allowed to specify both --IDS and --pair_file_names")
        
    }
    

    
    // // DETECTING WHICH OFFSET IS USED FOR THE READS
    // OFFSET = OFFSETDETECTOR(read_pairs_ch)
    

    // TRIMS BAD QUALITY READS
    TrimmedFiles_ch = TRIM(read_pairs_ch)

    FASTQC(TrimmedFiles_ch)
    
    // REMOVES EUKARYOTIC READS USING KRAKEN
    CleanedReads_ch = KRAKEN(TrimmedFiles_ch)
    
    
    // ASSEMBLES THE CLEANED READS USING SPADES
    ASSEMBLY_ch = SPADES(CleanedReads_ch,params.phredoffset)

    // CALCULATES N50 FROM THE ASSEMBLY
    N50CONTIG = N50(ASSEMBLY_ch)
    
    if (params.server) {
         // VIRUS PREDICTION TOOLS
        DVF_ch = DVF(ASSEMBLY_ch)
        SEEKER_ch = SEEKER(ASSEMBLY_ch)
        PHAGER_ch = PHAGER(ASSEMBLY_ch)

        ASSEMBLY_ch.combine(DVF_ch,by:0).combine(SEEKER_ch, by: 0).combine(PHAGER_ch, by: 0).set {COMBINED_PREDS_ch}
        COMBINED_PREDS_ch.view()
        // EXTRACTS AND JOINS VIRAL PHAGE CONTIGS FROM THE THREE VIRUS PREDICTION TOOLS
        VIRAL_CONTIGS_ch = VIREXTRACTOR(COMBINED_PREDS_ch)   
    }
    else {
        // Simpler virus prediction using only deepvirfinder, when running locally
        // VIRUS PREDICTION TOOLS

        DVF_ch = DVF(ASSEMBLY_ch)
        ASSEMBLY_ch.combine(DVF_ch, by:0).set{COMBINED_PREDS_ch}

        VIRAL_CONTIGS_ch = DEEPVIREXTRACTOR(COMBINED_PREDS_ch)
    }

    //ANNOTATION OF VIRAL CONTIGS USING PHAROKKA
    PHAROKKA_ANNOTATION_ch = PHAROKKA(VIRAL_CONTIGS_ch[0])


        if (params.iphopDB != false) {
            // If a iphop database path is provided, run the hostprediction
            // HOSTPREDICTION TOOL
            HOSTPREDICTION_ch = IPHOP(VIRAL_CONTIGS_ch[0]) 
        }
        
        // CREATING PLOTS OF EACH PHAGE
        PHAROKKA_SPLITS_ch = PHAROKKASPLITTER(PHAROKKA_ANNOTATION_ch[0]) 
        
        
        PHAROKKA_PLOTTER_ch = PHAROKKA_PLOTTER(PHAROKKA_SPLITS_ch.transpose()) 
        // CHECKS THE QUALITY OF THE VIRAL CONTIGS
        CHECKV_ch = CHECKV(VIRAL_CONTIGS_ch[0])

        if (params.iphopDB != false) {
            VIRAL_CONTIGS_ch[0].combine(HOSTPREDICTION_ch, by: 0).combine(CHECKV_ch, by: 0).set {COMBINED_RESULTS_ch}
            RESULTS_COMPILATION_ch = RESULTS_COMPILATION(COMBINED_RESULTS_ch)
        }
        else {
            // EMPTYFILE_ch = Channel.fromPath('/path/that/doesnt/exist.txt') //Replaces the hostprediction channel
            
            VIRAL_CONTIGS_ch[0].combine(DVF_ch, by: 0).combine(CHECKV_ch, by: 0).set {COMBINED_RESULTS_ch} // CHECK_V twice to act as empty path for missing iphop results
            
            RESULTS_COMPILATION_ch = RESULTS_COMPILATION(COMBINED_RESULTS_ch)
        }  
}
