/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC       } from '../modules/nf-core/fastqc/main'
include { MULTIQC      } from '../modules/nf-core/multiqc/main'
include { TRIMGALORE   } from '../modules/nf-core/trimgalore/main'
include { STAR_ALIGN   } from '../modules/nf-core/star/align/main'
include { SALMON_QUANT } from '../modules/nf-core/salmon/quant/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SEMINAR {

    take:
    ch_samplesheet

    main:

    ch_multiqc_files = Channel.empty()

    // ch_star_index    = Channel.value(file(params.star_index))
    // ch_gtf           = Channel.value(file(params.gtf))
    // ch_salmon_index  = Channel.value(file(params.salmon_index))
    // ch_transcriptome = Channel.value(file(params.transcriptome))

    ch_star_index    = Channel.value([ [id: 'genome'], file(params.star_index) ])
    ch_gtf           = Channel.value([ [id: 'genome'], file(params.gtf) ])
    ch_salmon_index  = Channel.value([ [id: 'transcriptome'], file(params.salmon_index) ])
    ch_transcriptome = Channel.value([ [id: 'transcriptome'], file(params.transcriptome) ])

    //
    // MODULE: Run FastQC
    //
    FASTQC(
        ch_samplesheet
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect { it[1] })

    //
    // MODULE: Run TrimGalore
    //
    TRIMGALORE(
        ch_samplesheet
    )
    ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.zip.collect { it[1] })
    ch_multiqc_files = ch_multiqc_files.mix(TRIMGALORE.out.log.collect { it[1] })

    //
    // MODULE: Run STAR align
    //
    STAR_ALIGN(
        TRIMGALORE.out.reads,
        ch_star_index,
        ch_gtf,
        false
    )
    ch_multiqc_files = ch_multiqc_files.mix(STAR_ALIGN.out.log_final.collect { it[1] })

    //
    // MODULE: Run Salmon quant
    //
    SALMON_QUANT(
        TRIMGALORE.out.reads,
        ch_salmon_index,
        ch_gtf,
        ch_transcriptome,
        false,
        false
    )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config, checkIfExists: true) : Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ? Channel.fromPath(params.multiqc_logo, checkIfExists: true) : Channel.empty()

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList()
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/