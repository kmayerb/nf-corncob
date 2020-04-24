# nf-corncob

A workflow for running corncob on large datasets

[![Build Status](https://travis-ci.com/kmayerb/nf-corncob.svg?branch=master)](https://travis-ci.com/kmayerb/nf-corncob)

This workflow was adapted from the statistic.nf module in Golob-Minot workflow [geneshot](https://github.com/Golob-Minot/geneshot/blob/master/modules/statistics.nf).

The process makes use of the (fhcrc-microbiome/corncob )[https://quay.io/repository/fhcrc-microbiome/corncob?tag=latest&tab=tags] docker container to run  [corncob](https://github.com/bryandmartin/corncob). Currently the container is tagged as latest, which hopefully will be re-tagged explicitly in the future. We used a version added Aug 26,2019 2:35 PM.

## Inputs

There are two inputs (csv.gz) and (csv) tabular files, whic must both contain the common key 'specimen'.

* `readcounts.csv.gz` (e.g., s3://fh-pi-kublin-j-cf-microbiome-results/nextflow_cf_allfiles_result/abund/CAG.readcounts.csv.gz)
* `metadata.csv` (e.g. manifest.csv)

## Testing

The `/data` folder will contain small inputs.

### Manifest 

```
name,readcounts_csv_gz,metadata_csv,formula
```
* name can be any unique run identifier 
* readcounts_csv_gz - path to the file described in inputs
* metadata_csv - path to the file described in inputs
* formula - is the right hand side of an R formula (i.e. if model is y ~ x1 + x2) then formula is just `x1 + x2`
