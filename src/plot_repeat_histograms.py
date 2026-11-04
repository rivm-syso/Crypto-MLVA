import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.backends.backend_pdf import PdfPages
import argparse
from pathlib import Path

# Create parser
parser = argparse.ArgumentParser()

# Add options/arguments
parser.add_argument("-o", "--output_prefix", help="Provide output directory")

# Parse the commandline arguments
args = parser.parse_args()

# Access the values of the options
output_prefix = args.output_prefix

# List of filenames
filenames = [
    f"{output_prefix}_cgd1_470_1429_repeats.txt",
    f"{output_prefix}_cgd4_2350_796_repeats.txt",
    f"{output_prefix}_cgd5_10_310_repeats.txt",
    f"{output_prefix}_cgd5_4490_2941_repeats.txt",
    f"{output_prefix}_cgd6_4290_9811_repeats.txt",
    f"{output_prefix}_cgd8_NC_4440_505_repeats.txt",
    f"{output_prefix}_cgd8_4840_6355_repeats.txt"
]

# Create a PDF file to save the plots
with PdfPages(f'{output_prefix}_MLVA_histograms.pdf') as pdf:
    for filename in filenames:
        # Try reading the data from the file
        try:
            data = pd.read_csv(filename, header=None).squeeze()

            # Check if the file is empty (data will be empty if the file has no text)
            if data.size == 0:
                print(f"File {Path(filename).name} is empty. Skipping.")
                continue

            # Filter out values that occur only once
            value_counts = data.value_counts()
            filtered_values = value_counts[value_counts > 1].index
            filtered_data = data[data.isin(filtered_values)]

            if filtered_data.size == 0:
                print(f"All values in {Path(filename).name} occur only once, nothing to plot. Skipping.")
                continue

            # Create a histogram
            plt.figure()
            plt.hist(filtered_data, bins=100, edgecolor='black')
            plt.title(f'Histogram for {Path(filename).name}')
            plt.xlabel('Number of Repeats')
            plt.ylabel('Frequency')

            # Save the current figure to the PDF
            pdf.savefig()
            plt.close()

        except pd.errors.EmptyDataError:
            # Handle the case where pd.read_csv encounters an empty file
            print(f"File {Path(filename).name} is empty or invalid. Skipping.")

print(f"Histograms have been saved to {output_prefix}_MLVA_histograms.pdf")
