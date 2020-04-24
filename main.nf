params.outdir = "results"
params.batchfile = "data/manifest.csv"

// create a channel 
Channel.from(file(params.batchfile))
    .splitCsv(header: true, sep: ",")
    .map { sample ->
    [sample.name, file(sample.readcounts_csv_gz), file(sample.metadata_csv), sample.formula]}
    .set{ input_channel}

// declare process
process runCorncob {
    tag "Perform corncob analysis"
    
    container "quay.io/fhcrc-microbiome/corncob"
    
    label "mem_veryhigh"
    
    errorStrategy "retry"
    
    publishDir params.outdir

    input:
    set name, file(readcounts_csv_gz), file(metadata_csv), formula from input_channel
   
    output:
    file "${name}.corncob.results.csv" into junkbonds

    """
    #!/usr/bin/env Rscript

    # Get the arguments passed in by the user

    library(tidyverse)
    library(corncob)
    library(parallel)

    Sys.setenv("VROOM_CONNECTION_SIZE" = 13107200 * ${task.attempt})

    numCores = ${task.cpus}

    ##  READCOUNTS CSV should have columns `specimen` (first col) and `total` (last column).
    ##  METADATA CSV should have columns `specimen` (which matches up with `specimen` from
    ##         the recounts file), and additional columns with covariates matching `formula`

    ##  corncob analysis (coefficients and p-values) are written to OUTPUT CSV on completion

    print("Reading in ${metadata_csv}")
    metadata <- vroom::vroom("${metadata_csv}", delim=",")

    print("Reading in ${readcounts_csv_gz}")
    counts <- vroom::vroom("${readcounts_csv_gz}", delim=",")

    if (dim(counts)[2] > 25){
        counts = counts[,1:25]
    }
    if ("total" %in% names(counts)){
        print("total not found")
        total_counts <- counts[,c("specimen", "total")]
    }else{
        counts["total"] = apply(counts[,-which(names(counts) %in% c("specimen"))],1,sum)
        total_counts = counts[,c("specimen", "total")]
    }
    
    print("Merging total counts with metadata")
    total_and_meta <- metadata %>% 
    right_join(total_counts, by = c("specimen" = "specimen"))
    
    print(head(total_and_meta))

    #### Run the analysis for every individual CAG
    print(sprintf("Starting to process %s columns (CAGs)", dim(counts)[2]))
    corn_tib <- do.call(rbind, mclapply(
        c(2:(dim(counts)[2] - 1)),
        function(i){
            try_bbdml <- try(
                counts[,c(1, i)] %>%
                rename(W = 2) %>%
                right_join(
                    total_and_meta, 
                    by = c("specimen" = "specimen")
                ) %>%
                corncob::bbdml(
                    formula = cbind(W, total - W) ~ ${formula},
                    phi.formula = ~ 1,
                    data = .
                )
            )

        if (class(try_bbdml) == "bbdml") {
            return(
                summary(
                    try_bbdml
                )\$coef %>%
                as_tibble %>%
                mutate("parameter" = summary(try_bbdml)\$coef %>% row.names) %>%
                rename(
                    "estimate" = Estimate,
                    "std_error" = `Std. Error`,
                    "p_value" = `Pr(>|t|)`
                ) %>%
                select(-`t value`) %>%
                gather(key = type, ...=estimate:p_value) %>%
                mutate("CAG" = names(counts)[i])
            )
        } else {
            return(
                tibble(
                    "parameter" = "all",
                    "type" = "failed", 
                    "value" = NA, 
                    "CAG" = names(counts)[i]
                )
            )
        }   
        },
        mc.cores = numCores
    ))

    print(sprintf("Writing out %s rows to corncob.results.csv", nrow(corn_tib)))
    print(head(corn_tib))
    write_csv(corn_tib, "${name}.corncob.results.csv")
    """
}