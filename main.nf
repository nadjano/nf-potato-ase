
/*
=================================================================================================
Title : Nextflow workflow on mapping strategy comparison for ASE analysis 
=================================================================================================

Author : Nadja Nolte
=================================================================================================
*/


/*
=================================================================================================
Input Directories
=================================================================================================

*/


params.designfile = "${baseDir}/assets/samples.csv"
params.reference = "${baseDir}/assets/reference.csv"

params.fastq_dir="${baseDir}/fastq_reads"

/*
=================================================================================================
Ouput Directories
=================================================================================================

*/
params.outdir = "${baseDir}/results"


/*
=================================================================================================
Include Modules
=================================================================================================
*/
include {MINIMAP2} from "./modules/minimap2"
include {GFFREAD} from "./modules/nf-core/gffread"
include {MINIMAP2_ALIGN} from "./modules/nf-core/minimap/align"
include {OARFISH} from "./modules/oarfish"
include {BAM2COUNTS} from "./modules/bam2counts"
include {MERGE_COUNTS} from "./modules/mergeCounts"
include {ALLELEFINDER} from "./modules/local/allelefinder"



/*
=================================================================================================
Channels
=================================================================================================

*/



Channel
    .fromPath(params.reference)
    .splitCsv(header: true, sep: ",")
    .map { row -> 
        tuple(id: row.organism,
            row.fasta, 
            row.gtf,
            row.ploidy
        ) 
    }
    .set { reference_ch }

    Channel
    .fromPath(params.designfile)
    .splitCsv(header: true, sep: ",")
    .map { row -> 
        tuple(
            row.organism,
            row.condition, 
            row.replicate,
            row.sample,
            row.fastq_read
        ) 
    }
    .set { samples_ch }
/*
=================================================================================================
                                    Workflow 
=================================================================================================

*/

workflow {

    reference_ch.map {
        id, fasta, gtf, ploidy -> 
        tuple(id, gtf)
    } 
    .set { ch_gtf }

    reference_ch.view()

    reference_ch.map {
        id, fasta, gtf, ploidy -> 
        fasta
    } 
    .set { ch_fasta }

    reference_ch.map {
        id, fasta, gtf, ploidy -> 
        tuple(id, fasta, gtf)
    } 
    .set { ch_fasta_gtf }


    samples_ch
        .map { organism,condition,replicate,sample,fastq_read ->
        tuple(meta = [id: sample, condition: condition, replicate: replicate, organism: organism], fastq_read)
        }
        .set { ch_fastq_reads }


    ch_fastq_reads.view()


    // ectract gene regions
    gffread_ch = GFFREAD(ch_gtf, ch_fasta)

    ch_fasta_gtf.join(gffread_ch.gffread_fasta).view()
    ALLELEFINDER(ch_fasta_gtf.join(gffread_ch.gffread_fasta))

    // QC for syntelog reference gene lengths
    //ch_gene_lengths = REFERENCE_LENGTHPLOT(gffread_ch.gffread_fasta)

    // // map reads to reference
    // ch_alignment = MINIMAP2_ALIGN(ch_fastq_reads.combine(gffread_ch.gffread_fasta),
    //         Channel.value(false),
    //         Channel.value("bai"),
    //         Channel.value(false),
    //         Channel.value(false))

    // ch_alignment.bam.view()
    // ch_gene_counts = BAM2COUNTS(ch_alignment.bam.combine(gffread_ch.gffread_fasta), Channel.value("false"))
    // collect the gene counts for all samples



    // merged_counts = MERGE_COUNTS(ch_gene_counts.counts.groupTuple(by: 0).view(), Channel.value("true"))

}   

