# Prediction of methotrexate treatment outcomes in early rheumatoid arthritis

This repository hosts scripts and some non-sensitive data related to an ongoing project on predicting persistence to methotrexate in patients with rheumatoid arthritis, using machine learning methods. An 'alpha' version of this project was finished/made-available on the 25th of June 2024 (current version), which produces the content of the first manuscript draft. This is a *functional* pipeline for performing the analysis, though it is not perfect, and subsequent checks will be needed before the pipeline as a whole, can be executed from start-to-finish.

# 1. SCRIPTS

This project is divided into five primary scripts, all with their supporting secondary scripts available in the `scripts/misc` and `scripts/utils` folders. Scripts `1*.R` and `2*.sh` perform the data extraction, cleaning and general pre-processing of data, the former focusing on the non-genetic training data extracted from the register linkage, the latter focusing on processing and quality control of the fully imputed genotype data. Script `3*.sh` runs the supervised learning for all outcomes, trained on all sets of training data, for all of the desired methods - parallelization makes this (relatively) efficient for all but Random Forest with the largest set of training features. Script `4*.sh` then takes the output models from `3*.sh` and extracts relevant statistics and data in raw, unprocessed formats. This data is then processed in `5*.sh` which returns the results in clean tabular format, for easy copy-pasting into the manuscript.

All bash scripts and their underlying R scripts were built to be executed on a Linux machine, using default command-line tools as well as PLINK (both version 1.9 and 2) and R. Several R packages were used throughout - primarily from the `tidyverse` - though specific package versions were not documented.

# 2. DATA

No personal data is uploaded here. However, I uploaded a helper file that uses information from [this page](https://www.unboundmedicine.com/icd/index/ICD-10-CM/Chapters_and_Sections) to translate ICD-10 subchapters from Swedish (as was reported in the original file) to English, which is used in creating one of the tables of the paper. I decided to upload it here as it may be of use to someone else. More specific information is available in the commit message for the file.