#!/bin/bash

# Define the sets of starting and ending sequences
sets=(
"GGTTCTAGT TCTAATTCT AGAATTAGA ACTAGAACC 18 6 cgd1_470_1429"
"ATGAGCCCG CGCGGAATG CATTCCGCG CGGGCTCAT 18 15 cgd4_2350_796"
"GTTAAGGAAGGA CCTGTAGAG CTCTACAGG TCCTTCCTTAAC 21 12 cgd5_10_310"
"GAACGGAAC AAAAACCAG CTGGTTTTT GTTCCGTTC 18 6 cgd5_4490_2941"
"TTATCATTA ACTTCTTCT AGAAGAAGT TAATGATAA 18 3 cgd6_4290_9811"
"CTTTGGCTT AAGCTTAAA TTTAAGCTT AAGCCAAAG 18 6 cgd8_NC_4440_505"
"AATTCAGTA GGAGTTGGT ACCAACTCC TACTGAATT 18 6 cgd8_4840_6355"
)

input_dir=$1
output_dir=$2

for barcode in $input_dir/*; do
    if [ -d "$barcode" ]; then
        echo "Processing directory: $barcode"
        
        output_prefix="$output_dir/$(basename "$barcode")"

        seqkit fq2fa <(cat "$barcode"/*.fastq.gz) > "$output_prefix"_raw.fasta

        MLVA_code=""
        frequencies=""
        percentages=""

        for set in "${sets[@]}"; do
            start1=$(echo $set | cut -d' ' -f1)
            end1=$(echo $set | cut -d' ' -f2)
            start2=$(echo $set | cut -d' ' -f3)
            end2=$(echo $set | cut -d' ' -f4)
            start_stop_len=$(echo $set | cut -d' ' -f5)
            repeat_len=$(echo $set | cut -d' ' -f6)
            gene=$(echo $set | cut -d' ' -f7)

            echo "Processing gene: $gene ($start1-$end1 and $start2-$end2)"

            # Select sequences matching either set and calculate their lengths
            awk -v start1="$start1" -v end1="$end1" -v start2="$start2" -v end2="$end2" '
            BEGIN { OFS = "" }
            /^>/ {next} 
            {
                sequence = $0
                if (match(sequence, "(" start1 ".*" end1 ")", arr) || match(sequence, "(" start2 ".*" end2 ")", arr)) {
                    print length(arr[1])
                }
            }
            ' "$output_prefix"_raw.fasta > "$output_prefix"_"$gene"_fragment_lengths.txt

            # Calculate number of repeats for every sequence length
            cat "$output_prefix"_"$gene"_fragment_lengths.txt | sort | awk -v ss_len="$start_stop_len" -v rep_len="$repeat_len" '{ result = ($1 - ss_len) / rep_len; print result }' > "$output_prefix"_"$gene"_repeats.txt

            modus=$(cat "$output_prefix"_"$gene"_repeats.txt | sort | uniq -c | sort -nr | awk 'NR==1 {print int($2 + 0.5)}')
            MLVA_code+="$modus-"

            frequency=$(cat "$output_prefix"_"$gene"_repeats.txt | sort | uniq -c | sort -nr | awk 'NR==1 {print $1}')
            frequencies+="$frequency - "

            percentage=$(cat "$output_prefix"_"$gene"_repeats.txt | sort | uniq -c | sort -nr | awk 'NR==1{first=$1} {sum+=$1} END {printf "%.2f\n", 100*first/sum}')
            percentages+="$percentage - "

            rm "$output_prefix"_"$gene"_fragment_lengths.txt

        done

        MLVA_code=${MLVA_code%-}
        echo $MLVA_code > "$output_prefix"_MLVA_code.txt

        frequencies=${frequencies% - }
        echo "Frequencies: ${frequencies}" >> "$output_prefix"_MLVA_code.txt

        percentages=${percentages% - }
        echo "Percentages: ${percentages}" >> "$output_prefix"_MLVA_code.txt

        python /data/BioGrid/witdnt/projects/13_couscous/mlva/plot_repeat_histograms.py --output_prefix $output_prefix
    
    fi

done

# Output CSV header
echo -n "filename" >> ${output_dir}/MLVA_codes_combined.csv
echo -n ",MLVAcode" >> ${output_dir}/MLVA_codes_combined.csv
for i in {1..7}; do echo -n ",MLVA$i"; done >> ${output_dir}/MLVA_codes_combined.csv
for i in {1..7}; do echo -n ",Freq$i"; done >> ${output_dir}/MLVA_codes_combined.csv
for i in {1..7}; do echo -n ",Perc$i"; done >> ${output_dir}/MLVA_codes_combined.csv
echo >> ${output_dir}/MLVA_codes_combined.csv

# Process each file
for file in $output_dir/*_MLVA_code.txt; do
    # Get basename up to first '_'
    base=$(basename "$file")
    fname="${base%%_*}"

    # Read line 1,2,3
    read -r vals < "$file"
    freqs=$(grep 'Frequencies:' "$file" | sed -E 's/Frequencies://; s/ - /,/g; s/^[[:space:]]+//; s/[[:space:]]+$//')
    percs=$(grep 'Percentages:' "$file" | sed -E 's/Percentages://; s/ - /,/g; s/^[[:space:]]+//; s/[[:space:]]+$//')
    values=$(echo "$vals" | sed 's/-/,/g')

    echo "$fname,$vals,$values,$freqs,$percs" >> ${output_dir}/MLVA_codes_combined.csv

done

rm ${output_dir}/barcode*_repeats.txt
rm ${output_dir}/barcode*_raw.fasta
