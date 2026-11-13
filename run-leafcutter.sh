#!/usr/bin/env bash
set -euo pipefail

if [[ $# != 3 ]]; then
  echo 'Usage: run-leafcutter.sh SAMPLE_LIST BAM_DIRECTORY NEW_RUN_DIRECTORY' >&2
  exit 2
fi
sample_list=$1
bam_dir=$2
run_dir=$3

# Use the BAM basename as the matrix column label.
samples=()
declare -A seen=()
while IFS= read -r sample || [[ -n $sample ]]; do
  sample=${sample%$'\r'}
  [[ -n $sample ]] || continue
  if [[ ! $sample =~ ^[a-zA-Z0-9_-][a-zA-Z0-9._-]*$ || $sample == *.junc* ]]; then
    echo "Invalid sample label: $sample" >&2
    exit 1
  fi
  if [[ -n ${seen[$sample]:-} ]]; then
    echo "Duplicate sample label: $sample" >&2
    exit 1
  fi
  bam="$bam_dir/$sample.bam"
  if [[ ! -r $bam ]]; then
    echo "Missing or unreadable BAM: $bam" >&2
    exit 1
  fi
  if [[ ! -r $bam.bai && ! -r ${bam%.bam}.bai && ! -r $bam.csi && ! -r ${bam%.bam}.csi ]]; then
    echo "Missing or unreadable BAM index: $bam" >&2
    exit 1
  fi
  seen[$sample]=1
  samples+=("$sample")
done < "$sample_list"
if [[ ${#samples[@]} -eq 0 ]]; then
  echo 'The sample list is empty.' >&2
  exit 1
fi

# Reserve a new directory so a retry or concurrent run cannot overwrite results.
mkdir -- "$run_dir"
mkdir -- "$run_dir/junctions"
junction_list="$run_dir/junction_files.txt"
for sample in "${samples[@]}"; do
  junction="$run_dir/junctions/$sample.junc"
  regtools junctions extract -a 8 -m 50 -M 500000 -s RF \
    -o "$junction" "$bam_dir/$sample.bam"
  printf '%s\n' "$junction" >> "$junction_list"
done

prefix=ALS_all_batch_regtools_cluster
python3 /opt/leafcutter/clustering/leafcutter_cluster_regtools.py \
  -j "$junction_list" -m 50 -l 500000 -o "$prefix" -r "$run_dir"
for suffix in perind perind_numers; do
  gzip -t "$run_dir/${prefix}_${suffix}.counts.gz"
done
echo "Count matrices written to $run_dir"
