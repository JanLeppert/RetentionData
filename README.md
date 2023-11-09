# RetentionData
[![DOI](https://pubs.acs.org/doi/10.1021/acsomega.3c01348)
[![DOI](https://zenodo.org/badge/426138381.svg)](https://zenodo.org/badge/latestdoi/426138381)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://JanLeppert.github.io/RetentionData/dev)

This github is a compilation of retention data in gas chromatography (GC). A corresponding publication is submitted. Supplemental material for this publication can be found [here](https://github.com/JanLeppert/RetentionData/tree/main/Supplemental%20Materials).

**Short introduction to retention factor and the 3 models**

## Databases

Different sets of parameters (A, B, C parameters, thermodynamic parameters or K-centric parameters) from different sources are compiled 
in the folder `Databases`. For every source a separate folder is created containing the original data from the sources as comma separated files, reference information as a BibTex file and processed files (e.g. calculation of the other sets of parameters). In the sub-folder `Measurements` in the folder `Databases` measured retention data, which is not publicized yet, is collected. 

[Latest database](https://github.com/JanLeppert/RetentionData/blob/main/Databases/database_all.csv)

[Latest database without flagged substances](https://github.com/JanLeppert/RetentionData/blob/main/Databases/database_nonflag.csv)

[Latest database for GasChromatographySimulator.jl](https://github.com/JanLeppert/RetentionData/blob/main/Databases/GCSim_database_nonflag.csv)

### How to add data

* Contact us.
 
* Fork the Github project and submit additional data as a new branch.

* New data in form of parameter sets can be added in a sub-folder of folder `Databases`:
  * ($A,B,C$), [example file](https://github.com/JanLeppert/RetentionData/blob/main/Databases/Gaida2021/Gaida2021_Parameters_TableS1_Rxi5ms_beta250.csv) 
  * ($T_{char}$, $\theta_{char}$, $\Delta C_p$) [example file](https://github.com/JanLeppert/RetentionData/blob/main/Databases/Leppert2020b/Leppert2020b_Parameters_TableS1_FS5ms_beta250.csv)
  * ($\Delta S_{ref}$, $\Delta H_{ref}$, $\Delta C_p$, $T_{ref}$) [example file](https://github.com/JanLeppert/RetentionData/blob/main/Databases/McGinitie2012a/McGinitie2012a_Parameters_Table1_Wax_beta250_Tref90.csv)
  * running the notebook [Convert_Parameters.jl](https://github.com/JanLeppert/RetentionData/blob/main/notebooks/Convert_Parameters.jl) converts the given parameter set into the other and saves them in a  `AllParam` file.

* New data in form of $\ln(k)$ over $T$ [example file](https://github.com/JanLeppert/RetentionData/blob/main/Databases/Measurements/PhD_Brehmer/Brehmer2022_lnk-T_BTEX_Rxi17SilMS_beta250.csv) or as $\log_{10}(k)$ over $T$ [example file](https://github.com/JanLeppert/RetentionData/blob/main/Databases/Boswell2012/Boswell2012_log10k-T_TabelS1_DB5ms_beta250.csv) can be added in a sub-folder of folder `Databases`.
  * running the notebook [Fit_lnk-T_Outliers.jl](https://github.com/JanLeppert/RetentionData/blob/main/notebooks/Fit_lnk-T_Outliertest.jl) makes a fit of the $K$-centric model to the data, which can be inspected in this notebook, and converts the parameters into the other parameter sets and saves them in a `AllParam` file.

* alternative: add the data in folders as described above 
  * run the script file [script.jl](https://github.com/JanLeppert/RetentionData/blob/main/scripts/script.jl)
  * fit of all the data is done resp. the conversion of all data is done and the three databases `database_all.csv`, `database_nonflag.csv` and `GCSim_database_nonflag.csv` are constructed.

### Structure of filenames and files:

see [Documentation](https://janleppert.github.io/RetentionData/dev/filestructure/)

## Overview of Notebooks of the Project _RetentionData_

Several notebooks, written in the Julia programming language (https://julialang.org/) and using the Pluto.jl package (https://github.com/fonsp/Pluto.jl), are used to
calculate the retention parameters from retention data (`Fit_lnk-T_Outliertest.jl`) or convert available sets of retention parameters into the other sets (`Convert_Parameters.jl`). These notebooks can be found in the folder `notebooks`. Functions, which are used in these notebooks can be found in the file `RetentionData.jl` in the `src` folder. 

- `Convert_Parameters.jl`:
  - Load all files with the keyword `Parameters` from a folder
  - convert the parameter set from the file into the other parameter sets
  - ToDo: if no column for `CAS` number exists in the data, add one with the `CAS`-numbers from ChemicalIdentifiers.jl (also by using the file `shortname.csv`) resp. from the file `missing.csv` (chemical substances, which are not found in the database of ChemicalIdentifiers.jl)
  - optional: save the data of all three parameter sets into a file with the keyword `AllParam`

- `Fit_lnk-T_Outliertest.jl`
  - Load all files with the keyword `lnk-T` resp. `log10k-T` from a folder
  - fit of the ABC-model and the Kcentric model to the data and convert them to the third parameter set
  - export the parameter sets together with some statistics of the fits
  - ToDo: if no column for `CAS` number exists in the data, add one with the `CAS`-numbers from ChemicalIdentifiers.jl (also by using the file `shortname.csv`) resp. from the file `missing.csv` (chemical substances, which are not found in the database of ChemicalIdentifiers.jl)
  - optional: save the data of all three parameter sets into a file with the keyword `AllParam`

- `Notebook_PCA.jl`: 
  - Loads all `AllParam` files in the `Databases`-folder and its sub-folders
  - compiles a database from all datasets
  - a PCA over the whole dataset is run

- `Database.jl`: 
  - Loads all `AllParam` file in the `Databases`-folder and its sub-folders
  - complies a database from all datasets
  - using optional filters a sub-database can be created in a selected format and can be saved in a .csv file
  




