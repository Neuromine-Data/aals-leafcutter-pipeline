# Answer ALS LeafCutter splicing workflow

The Answer ALS splicing release measures how often alternative splice junctions are used in RNA-seq samples from iPSC-derived motor neurons. Researchers can use the matrices to compare splicing patterns across samples or participant groups. This guide explains how to interpret the two released matrices and how to generate the same types of counts from STAR-aligned reads. Get the released files through the [Answer ALS Data Portal](https://dataportal.answerals.org/).

**Research credit.** Stanislav Tsitkov, Akshay Raju, Jie Wu, the Answer ALS Consortium, and their coauthors describe how they quantified splicing in Answer ALS motor neurons for their study of C9orf72 and ALS survival. We thank the participants who made this work possible. The `ucigenomics` team shares the LeafCutter analysis environment on Docker Hub. [Study preprint](https://doi.org/10.64898/2026.02.06.26345684) · [Docker image and usage notes](https://hub.docker.com/r/ucigenomics/leafcutter)

## Using the released matrices

Each sample column is labeled with the ID of a transcriptomics aliquot (`-T`). The release has 1,194 sample columns from 1,040 participants. Cases account for 736 samples from 727 participants and controls account for 458 samples from 313 participants. Some participants contributed multiple samples. Use the sample-to-participant mapping when designing group comparisons.

| Released file | What a cell means |
| --- | --- |
| `ALS_all_batch_regtools_cluster_perind.counts.gz` | Reads supporting this intron divided by total reads supporting its cluster in the same sample, stored as `n/total`. |
| `ALS_all_batch_regtools_cluster_perind_numers.counts.gz` | The numerator from the corresponding cell, stored as an integer count. |

Each row represents an intron, a sequence removed when RNA is spliced. A read spanning the resulting exon–exon junction provides evidence for the intron’s donor and acceptor splice sites. Row IDs typically have the form `chromosome:intron_start:intron_end:cluster_id`. The final field groups related introns that share splice sites and represent alternative splicing choices.

For example, `20/100` in the first matrix and `20` in the corresponding cell of the second mean that 20 of the 100 reads assigned to that cluster in that sample support this intron. Its estimated usage is 20%. Each cluster has its own denominator, so compare the same intron across samples or alternative introns within a cluster. A zero denominator means there were no reads from which to estimate usage. Measuring the abundance of full transcript isoforms or reconstructing complete mRNA sequences requires additional data or analysis.

## Generating counts from aligned RNA-seq

Start with one coordinate-sorted, indexed BAM per sample and the set of samples you want to cluster together. The study aligned RNA-seq reads to GRCh38 with STAR using `--twopassMode Basic` and `--outSAMstrandField intronMotif`. It reports LeafCutter v0.2.9. [Study methods](https://pmc.ncbi.nlm.nih.gov/articles/PMC12919128/)

1. Extract splice junctions separately from each BAM with regtools. The study used an 8 bp minimum anchor, introns from 50 to 500,000 bp, and first-strand (`RF`) library orientation. Check the library orientation before applying these settings to another dataset. [regtools command reference](https://regtools.readthedocs.io/en/latest/commands/junctions-extract/)
2. Supply one list of the resulting junction files to `leafcutter_cluster_regtools.py`. The release pooled samples across batches (`all_batch`) and used `-m 50 -l 500000`. Clustering uses junction support across the input set, so changing the sample set can change which introns appear.

### Run the pipeline

Clone the repository and use its [workflow script](run-leafcutter.sh) with Docker. GitHub access to this repository is required while it is private.

```bash
git clone https://github.com/Neuromine-Data/aals-leafcutter-pipeline.git
cd aals-leafcutter-pipeline
```

Put your indexed BAMs in one directory. In that directory, create `samples.txt` with one BAM basename per line, omitting the `.bam` extension. For instance, `example_A` selects `example_A.bam` and becomes its matrix column label. Use unique labels containing letters, numbers, periods, underscores or hyphens. Leave out spaces and the reserved substring `.junc`. See the [fictional sample list](examples/samples.txt).

From the cloned repository, set the two paths below and run the command. Docker uses the pinned Linux AMD64 build of the UCI image. The input directory is mounted read-only. Choose a fresh run name such as `run-01` for each analysis.

```bash
bam_dir=/absolute/path/to/indexed-bams
output_dir=/absolute/path/to/leafcutter-output
mkdir -p "$output_dir"
docker run --rm --platform linux/amd64 --user "$(id -u):$(id -g)" \
  -v "$PWD:/workflow:ro" -v "$bam_dir:/data:ro" -v "$output_dir:/out" \
  ucigenomics/leafcutter@sha256:bf3e2c9128f83573735d8f78f8be7f596d8aa52f09914262bf53fde094c3baad \
  bash /workflow/run-leafcutter.sh /data/samples.txt /data /out/run-01
```

Both matrices listed above are written to `run-01/` under your output directory. This directory also holds the extracted junctions and the file list used for clustering. The script implements the study’s documented settings, with one clustering run across all samples in your list.

## Citation and downstream use

When using the Answer ALS splicing data, acknowledge the research team and Answer ALS participants and cite Tsitkov et al., *Wild-type C9orf72 expression is a genetic modifier of C9-ALS survival* (medRxiv, 2026). For the quantification method, cite Li et al., *Annotation-free quantification of RNA splicing using LeafCutter* (Nature Genetics, 2018). [Answer ALS study](https://doi.org/10.64898/2026.02.06.26345684) · [LeafCutter method](https://pmc.ncbi.nlm.nih.gov/articles/PMC5742080/) · [LeafCutter source](https://github.com/davidaknowles/leafcutter)

For a downstream differential-splicing analysis, define the sample groups and study design for your question. The container page also explains how to prepare results for viewing with LeafViz. [Differential-splicing guide](https://davidaknowles.github.io/leafcutter/articles/Usage.html) · [Container and LeafViz instructions](https://hub.docker.com/r/ucigenomics/leafcutter)
