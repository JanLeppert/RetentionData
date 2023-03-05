var documenterSearchIndex = {"docs":
[{"location":"filestructure/#Structure-of-filenames:","page":"File structure","title":"Structure of filenames:","text":"","category":"section"},{"location":"filestructure/","page":"File structure","title":"File structure","text":"The general structure of filenames in this Database is the following:","category":"page"},{"location":"filestructure/","page":"File structure","title":"File structure","text":"Source_Datatype_(Substances)or(Table)_StationaryPhase_PhaseRatio_(AddParameters).csv","category":"page"},{"location":"filestructure/","page":"File structure","title":"File structure","text":"with:","category":"page"},{"location":"filestructure/","page":"File structure","title":"File structure","text":"Source: Name of the source, identical with the key of the BibTex file references.bib (name of first author and year). For not yet publicized datasets (folder Measurements) the name consists of the name of the primary person which measured the data and the year.\nDatatype: Which data is in the file\nParameters: One of the following sets of retention parameters (or combinations):\nA, B, C\nDeltaHref, DeltaSref, DeltaCp\nTchar, thetachar, DeltaCp\nlnk-T: The measured lnk-values (natural logarithm of the retention factor) of the substances for isothermal GC measurements at defined temperatures T. The retention parameters can be estimated from these measurements by fitting of the model.\nlog10k-T: The measured log10(k)-values (decadic logarithm of the retention factor) of the substances for isothermal GC measurements at defined temperatures T. The retention parameters can be estimated from these measurements by fitting of the model.\ntR-T: The measured tR-values (retention time) of the substances for isothermal GC measurements at defined temperatures T. Also, the hold-up time tM must be included (measured or calculated), to calculate lnk from this data and estimate the retention parameters by model fitting. \nAllParam: retention parameters of all three sets are in the data, also a reference temperature Tref, the phase ratio beta (see below), and the argument for the Lambert W function are included \nIDList: A list of at least two columns. First column has the shortname or number (ID), the second column has a full name or alternative name. Some data (Parameters, lnk-T or tR-T) use the shortname/ID-number instead of a full name. This file can be used to convert the ID to full name.\n(Substances): Optional. A label for the substances in the file, e.g. Mix1 or Alkanes. \n(Table): Table + Number of the table in the source.\nStationaryPhase: The name of the stationary phase. Spaces or hyphens are removed from the name. The name is follows in general the name given by the manufacturer.\nPhaseRatio: The nominal phase ratio of the used column according the the data of the manufacturer. Calculated by the approximation beta approx 14 dd_f\n(AddParameters): Additional parameters (the value follows the parameters without spaces):\nTref: Reference temperature for the retention parameters DeltaHref and DeltaSref\ngas: The type of gas used as stationary phase for the measurement of isothermal chromatograms or retention parameters, e.g. He or H2.\nd: The diameter of the column used for the measurements of isothermal chromatograms or retention parameters, e.g. 0.10 or 0.32.","category":"page"},{"location":"filestructure/#Structure-of-the-files:","page":"File structure","title":"Structure of the files:","text":"","category":"section"},{"location":"filestructure/","page":"File structure","title":"File structure","text":"comma separated\nfirst column with the names of the substance (header can be different)\nfollowing columns depend on the Datatype\nParameters: three columns of the different retention parameter sets (or multiple for multiple datasets)\nlnk_T: several columns with the lnk-values at the several temperatures T. Every columns stands for one temperature.\ntR_T: similar to lnk_T plus an additional column with the hold-up time tM\noptional columns containing information about affiliations of the substances to different classes or categories, name with Cat or Category or Cat_1 (important is the string \"Cat\") \nfirst row contains the name of the columns, resp. in case of lnk_Tor tR_T the name of the column is the value of the temperature\n(Optional) second row contains the units corresponding to the values in the columns\nif no row with units is present, it is assumed, that the values have their corresponding SI-units\ntemperatures are assumed to be measured in °C","category":"page"},{"location":"#RetentionData.jl","page":"Home","title":"RetentionData.jl","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for RetentionData.jl","category":"page"},{"location":"","page":"Home","title":"Home","text":"RetentionData.jl","category":"page"},{"location":"docstrings/","page":"Docstrings","title":"Docstrings","text":"RetentionData","category":"page"},{"location":"docstrings/#Module-Index","page":"Docstrings","title":"Module Index","text":"","category":"section"},{"location":"docstrings/","page":"Docstrings","title":"Docstrings","text":"Modules = [RetentionData]\nOrder   = [:constant, :type, :function, :macro]","category":"page"},{"location":"docstrings/#Detailed-API","page":"Docstrings","title":"Detailed API","text":"","category":"section"},{"location":"docstrings/","page":"Docstrings","title":"Docstrings","text":"Modules = [RetentionData]\nOrder   = [:constant, :type, :function, :macro]","category":"page"},{"location":"docstrings/#RetentionData.ABC-Tuple{Any, Any}","page":"Docstrings","title":"RetentionData.ABC","text":"ABC(x, p)\n\nThe ABC-model for the relationship lnk(T). \n\nArguments:\n\nx: temperature T in K\np[1] = A - lnβ\np[2] = B in K\np[3] = C\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.ABC_to_Kcentric-NTuple{4, Any}","page":"Docstrings","title":"RetentionData.ABC_to_Kcentric","text":"ABC_to_Kcentric(A, B, C, KRef)\n\nConvert the parameters of the ABC set (A, B, C) to the parameters of the K-centric set (Tchar, θchar, ΔCp). The reference distribution coefficient KRef is a needed additional information (normally, it should be equal to the phase ratio β of the reference column, where the parameters where measured). The parameter should have been measured in the following units:\n\nA (without unit)\nB in K\nC (without unit)\nKRef (without unit)\n\nOutput\n\nTchar in °C\nθchar in °C\nΔCp in J mol⁻¹ K⁻¹\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.ABC_to_TD-NTuple{4, Any}","page":"Docstrings","title":"RetentionData.ABC_to_TD","text":"ABC_to_TD(A, B, C, Tref)\n\nConvert the parameters of the ABC set (A, B, C) to the parameters of the thermodynamic set (ΔHref, ΔSref, ΔCp). The reference temperature Tref is a needed additional information. The parameter should have been measured in the following units:\n\nA (without unit)\nB in K\nC (without unit)\nTref in °C\n\nOutput\n\nΔHref in J mol⁻¹\nΔSref in J mol⁻¹ K⁻¹\nΔCp in J mol⁻¹ K⁻¹\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.AcceptTest-Tuple{Any, Any}","page":"Docstrings","title":"RetentionData.AcceptTest","text":"AcceptTest(Dataset, Check; ftrusted=0.7)\n\nMake the fit of lnk over T for a all solutes of a Dataset with the Kcentric-model. With the boolean variable Check a test for outliers, using a robust fit (RAFF.jl), is executed. \n\nOutput\n\nThe fit results and additional statistics are exported as a DataFrame. Categories, which are included in the measured lnk-data are appended to the DataFrame.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.Kcentric-Tuple{Any, Any}","page":"Docstrings","title":"RetentionData.Kcentric","text":"Kcentric(x, p)\n\nThe K-centric model for the relationship lnk(T).\n\nArguments\n\nx: temperature T in K\np[1] = Tchar + Tst in K\np[2] = θchar in °C\np[3] = ΔCp/R\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.Kcentric_to_ABC-NTuple{4, Any}","page":"Docstrings","title":"RetentionData.Kcentric_to_ABC","text":"Kcentric_to_ABC(Tchar, θchar, ΔCp, KRef)\n\nConvert the parameters of the K-centric set (Tchar, θchar, ΔCp) to the parameters of the ABC set (A, B, C). The reference distribution coefficient KRef is a needed additional information (normally, it should be equal to the phase ratio β of the reference column, where the parameters where measured). The parameter should have been measured in the following units:\n\nTchar in °C\nθchar in °C\nΔCp in J mol⁻¹ K⁻¹\nKRef (without unit)\n\nOutput\n\nA (without unit)\nB in K\nC (without unit)\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.TD_to_ABC-NTuple{4, Any}","page":"Docstrings","title":"RetentionData.TD_to_ABC","text":"TD_to_ABC(ΔHref, ΔSref, ΔCp, Tref)\n\nConvert the parameters of the thermodynamic set (ΔHref, ΔSref, ΔCp) to the parameters of the ABC set (A, B, C). The reference temperature Tref is a needed additional information. The parameter should have been measured in the following units:\n\nΔHref in J mol⁻¹\nΔSref in J mol⁻¹ K⁻¹\nΔCp in J mol⁻¹ K⁻¹\nTref in °C\n\nOutput\n\nA (without unit)\nB in K\nC (without unit)\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.T_column_names_to_Float-Tuple{DataFrames.DataFrame}","page":"Docstrings","title":"RetentionData.T_column_names_to_Float","text":"T_column_names_to_Float(data::DataFrame)\n\nTranslates the column names of the dataframe data containing the values of isothermal temperature to Float64. For the case of identical temperatures, a number is appended, separated by an underscore _. If this is the case the string is splited at the _ and only the first part is used.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.add_group_to_Cat!-Tuple{Any}","page":"Docstrings","title":"RetentionData.add_group_to_Cat!","text":"add_group_to_Cat!(newdata)\n\nAdd categories defined by the file groups.csv (group name and a list of CAS numbers)\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.align_categories-Tuple{Any}","page":"Docstrings","title":"RetentionData.align_categories","text":"align_categories(newdata)\n\nAligns the entrys for categorys for the same substances (same CAS number).\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.all_parameters!-Tuple{Any}","page":"Docstrings","title":"RetentionData.all_parameters!","text":"all_parameters!(meta_data)\n\nCalculate the other parameter sets from the given parameter sets and replace the data in meta_data with the following:\n\nA new array of dataframes. The dataframes have the following columns:\n\nName: Name of the substance\nA: parameter A of the ABC set\nB: parameter B of the ABC set\nC: parameter B of the ABC set\nTchar: parameter Tchar of the K-centric set\nthetachar: parameter θchar of the K-centric set\nDeltaCp: parameter ΔCp of the K-centric and TD set\nDeltaHref: parameter ΔHref of the TD set\nDeltaSref: parameter ΔSref of the TD set\nTref: the reference temperature of the TD set\nbeta0: the phase ratio β0, for which the retention was measured, KRef=β0 of the K-centric set\nlambertw_x: the argument of the Lambert W function used in the conversion of the ABC set to the K-centric set. The value should be -1/e ≤ x < 0\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.all_parameters-Tuple{Vector{DataFrames.DataFrame}, Vector{Vector{String}}, Vector{Dict}, Vector{Float64}, Vector{Union{Missing, Float64}}}","page":"Docstrings","title":"RetentionData.all_parameters","text":"all_parameters(data::Array{DataFrame,1}, paramset::Array{Array{String,1},1}, paramindex::Array{Dict,1})\n\nCalculate the other parameter sets from the given parameter sets and return them in a new array of dataframes.\n\nOutput\n\nA new array of dataframes. The dataframes have the following columns:\n\nName: Name of the substance\nA: parameter A of the ABC set\nB: parameter B of the ABC set\nC: parameter B of the ABC set\nTchar: parameter Tchar of the K-centric set\nthetachar: parameter θchar of the K-centric set\nDeltaCp: parameter ΔCp of the K-centric and TD set\nDeltaHref: parameter ΔHref of the TD set\nDeltaSref: parameter ΔSref of the TD set\nTref: the reference temperature of the TD set\nbeta0: the phase ratio β0, for which the retention was measured, KRef=β0 of the K-centric set\nlambertw_x: the argument of the Lambert W function used in the conversion of the ABC set to the K-centric set. The value should be -1/e ≤ x < 0\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.coeff_of_determination-NTuple{4, Any}","page":"Docstrings","title":"RetentionData.coeff_of_determination","text":"coeff_of_determination(fit, y)\n\nCalculate the coefficient of determination R² for LsqFit.jl result fit and measured data y.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.collect_categories-Tuple{Any}","page":"Docstrings","title":"RetentionData.collect_categories","text":"collect_categories(meta_data)\n\nCollect the category entrys of the substances in the different datasets of meta_data, if they are available in a multidimensionsal array.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.collect_csv_paths-Tuple{Any}","page":"Docstrings","title":"RetentionData.collect_csv_paths","text":"collect_csv_paths(folder)\n\nCollect the paths of all .csv-files in the folder and all its sub-folders in an array of Strings.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.dataframe_of_all-Tuple{Any}","page":"Docstrings","title":"RetentionData.dataframe_of_all","text":"datafram_of_all(meta_data::DataFrame)\n\nCombine the separate dataframes with the parameter sets of the different entrys of the meta_data dataframe into one big dataframe.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.duplicated_data-Tuple{Any}","page":"Docstrings","title":"RetentionData.duplicated_data","text":"duplicated_data(alldata)\n\nFind the duplicated data entrys in alldata based on identical CAS-number and identical stationary phase. The dataframe alldata must not have missing CAS-number entrys.\n\nOutput\n\narray of dataframe duplicated_data: every array element has a dataframe of the duplicated data\narray of Bool duplicated_entry: true, if data has a duplicated, fals if not.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.extract_meta_data-Tuple{Vector{String}}","page":"Docstrings","title":"RetentionData.extract_meta_data","text":"extract_meta_data(csv_paths::Array{String,1})\n\nExtract the meta data contained in the filename of a collection of paths to .csv-files. A dataframe with the columns:\n\npath\nfilename\nsource\nphase\nbeta0\nTref\nd\ngas\n\nis returned. For the correct format of the filename see 'Note.md'.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.extract_parameters_from_fit-Tuple{Any, Any}","page":"Docstrings","title":"RetentionData.extract_parameters_from_fit","text":"extract_paramaters_from_fit(fit, β0)\n\nExtract the parameters A, B, C, Tchar, θchar and ΔCp from the fits of lnk over T data with the ABC-model and the Kcentric-model.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.fit-NTuple{5, Any}","page":"Docstrings","title":"RetentionData.fit","text":"fit(model, T, lnk, lb, ub; weighted=false, threshold=NaN)\n\nOld version. Fit the model-function to lnk over T data, with parameter lower boundaries lb and upper boundaries ub.  Data points with a residuum above threshold are excluded and the fit is recalculated, until all residua are below the threshold or only three data points are left (unless threshold = NaN, which is default).  If weighted = true the residuals of an unwheighted fit (OLS) are used as weights for a second fit (w_i = 1res_i^2)\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.fit-Tuple{Any, Any, Any}","page":"Docstrings","title":"RetentionData.fit","text":"fit(model, T, lnk; check=true, ftrusted=0.7)\n\nNew version. Fit the model-function to lnk over T data. If check is true than a robust fit (RAFF.jl, parameter ftrusted) is executed and outliers are excluded from the fit with LsqFit.jl. If check is false than the outliers found with RAFF.jl are still used for the fit with LsqFit.jl.\n\nOutput\n\nfit - the result from LsqFit.jl\nrobust - the result from RAFF.jl\noutlier - the outliers found with RAFF.jl as a tuple of (T, lnk)\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.fit_models!-Tuple{DataFrames.DataFrame, Any}","page":"Docstrings","title":"RetentionData.fit_models!","text":"fit_models!(meta_data::DataFrame, CheckBase; ftrusted=0.7)\n\nNew version. Fit the K-centric-model at the lnk(T) data of the data-array of dataframes, using RAFF.jl and LsqFit.jl and add the result in a new column (fit) of `meta_data \n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.fit_models!-Tuple{DataFrames.DataFrame}","page":"Docstrings","title":"RetentionData.fit_models!","text":"fit_models!(meta_data::DataFrame; weighted=false, threshold=NaN, lb_ABC=[-Inf, 0.0, 0.0], ub_ABC=[0.0, Inf, 50.0], lb_Kcentric=[0.0, 0.0, 0.0], ub_Kcentric=[Inf, Inf, 500.0])\n\nOld version. Fit the ABC-model and the K-centric-model at the lnk(T) data of the data-array of dataframes, using LsqFit.jl and add the result in a new column (fit) of `meta_data \n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.fit_models-Tuple{Array{DataFrames.DataFrame}, Any}","page":"Docstrings","title":"RetentionData.fit_models","text":"fit_models(data::Array{DataFrame}, β0::Array{Float64})\n\nNew version. Fit the K-centric-model at the lnk(T) data of the data-array of dataframes, using LsqFit.jl \n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.fit_models-Tuple{Array{DataFrames.DataFrame}}","page":"Docstrings","title":"RetentionData.fit_models","text":"fit_models(data::Array{DataFrame}, β0::Array{Float64})\n\nOld version. Fit the ABC-model and the K-centric-model at the lnk(T) data of the data-array of dataframes, using LsqFit.jl \n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.flag-Tuple{Any}","page":"Docstrings","title":"RetentionData.flag","text":"flag(data)\n\nCreate a flag if certain conditions for the parameters are not fullfilled: \t- value of lambertw_x is < -1/e or > 0 \t- value of A > 0 \t- value of B < 0 \t- value of C < 0 \t- value of Tchar < -Tst \t- value of θchar < 0\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.flagged_data-Tuple{DataFrames.DataFrame}","page":"Docstrings","title":"RetentionData.flagged_data","text":"flagged_data(alldata::DataFrame)\n\nFilter the parameter data for flagged and not-flagged datasets. \n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.formula_to_dict-Tuple{Any}","page":"Docstrings","title":"RetentionData.formula_to_dict","text":"formula_to_dict(formula)\n\nTranslate the formula string of a chemical substance into a dictionary, where the elements contained in the substance are the keys and the number of atoms are the values.\n\nExample\n\njulia> formula_to_dict(\"C14H20O\")\nDict{String, Int64}(\"C\" => 14, \"H\" => 20, \"O\" => 1)\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.indentify_parameters-Tuple{Array{DataFrames.DataFrame}}","page":"Docstrings","title":"RetentionData.indentify_parameters","text":"identify_parameters(data::Array{DataFrame})\n\nExtract the column indices of the parameters and identify the type of parameters sets stored in the dataframes of data.  \n\nABC-parameters:\n\ncolumn name containing \"A\" -> A\ncolumn name containing \"B\" -> B\ncolumn name containing \"C_\" or column name == \"C\" -> C\n\nK-centric:\n\ncolumn name containing \"Tchar\" -> Tchar\ncolumn name containing \"thetachar\" -> thetachar\ncolumn name containing \"DeltaCp\" -> DeltaCp\n\nthermodynamic parameters at reference temperature Tref\n\ncolumn name containing \"DeltaHref\" -> DeltaHref\ncolumn name containing \"DeltaSref\" -> DeltaSref\ncolumn name containing \"DeltaCp\" -> DeltaCp\nadditionally from meta_data a value for Tref is needed\n\nOutput\n\nparam_set: Array of Arrays of string, listening the types of parameter sets, possible values \"ABC\", \"K-centric\", \"TD\"\nindex: Array of dictionaries with the colum index of the parameters (parameters name is the key, the index is the value)\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.lambertw_x-NTuple{4, Any}","page":"Docstrings","title":"RetentionData.lambertw_x","text":"lambertw_x(A, B, C, KRef)\n\nCalculate the argument for the Lambert W function (-1 branch) used to convert the ABC set to the K-centric set. The reference distribution coefficient KRef is a needed additional information (normally, it should be equal to the phase ratio β of the reference column, where the parameters where measured). The value should be -1/e ≤ x < 0.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.load_allparameter_data-Tuple{Any}","page":"Docstrings","title":"RetentionData.load_allparameter_data","text":"load_allparameter_data(db_path)\n\nLoad the data files (.csv format) with the Parameters data from the folder db_path including all subfolders. Based on the loaded parameters, the parameters of the not included parameter sets are calculated. Additional information from the filenames are also saved.\n\nOutput\n\nA dataframes with the following columns:\n\npath: Path of the folder from where the data was loaded.\nfilename: Name of the file from where the data was loaded.\nsource: Short name for the source from where the data original is taken.\nphase: Name of the stationary phase corresponding to the data.\nbeta0: The phase ratio corresponding to the data.\nTref: The reference temperature used for the thermodynamic parameter set. Optional parameter, if not available it has the value missing.\nd: The column diameter. Optional parameter, if not available it has the value missing.\ngas: The used gas for the mobile phase. Optional parameter, if not available it has the value missing.\ndata: Dataframes with the parameters of the three different parameter sets. See function all_parameters().\n\nNote\n\nFor the naming convention of the filenames see Note.md.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.load_csv_data!-Tuple{DataFrames.DataFrame}","page":"Docstrings","title":"RetentionData.load_csv_data!","text":"load_csv_data!(meta_data::DataFrame)\n\nLoad the data from the .csv-file located at meta_data.path, meta_data.filename. Data for DeltaHref is multiplied by 1000, if the corresponding unit is kJ/mol. The loaded data is returned in an additional column data in the meta_data dataframe.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.load_csv_data-Tuple{DataFrames.DataFrame}","page":"Docstrings","title":"RetentionData.load_csv_data","text":"load_csv_data(meta_data::DataFrame)\n\nLoad the data from the .csv-file located at meta_data.path, meta_data.filename. Data for DeltaHref is multiplied by 1000, if the corresponding unit is kJ/mol. The loaded data is returned in a dataframe. If an ID-list is available in the same folder the shortname/number will be looked up in the ID-list and replaced by the full name given in the ID-List.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.load_custom_CI_database-Tuple{Any}","page":"Docstrings","title":"RetentionData.load_custom_CI_database","text":"load_custom_CI_database(custom_database_url)\n\nLoad a custom database for ChemicalIdentifiers.jl from the location custom_database_url, if the custom database is not already loaded.\t\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.load_lnkT_data-Tuple{Any}","page":"Docstrings","title":"RetentionData.load_lnkT_data","text":"load_lnkT_data(db_path)\n\nLoad the data files (.csv format) with lnk-T data from the folder db_path including all subfolders.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.load_parameter_data-Tuple{Any}","page":"Docstrings","title":"RetentionData.load_parameter_data","text":"load_parameter_data(db_path)\n\nLoad the data files (.csv format) with the Parameters data from the folder db_path including all subfolders. Based on the loaded parameters, the parameters of the not included parameter sets are calculated. Additional information from the filenames are also saved.\n\nOutput\n\nA dataframes with the following columns:\n\npath: Path of the folder from where the data was loaded.\nfilename: Name of the file from where the data was loaded.\nsource: Short name for the source from where the data original is taken.\nphase: Name of the stationary phase corresponding to the data.\nbeta0: The phase ratio corresponding to the data.\nTref: The reference temperature used for the thermodynamic parameter set. Optional parameter, if not available it has the value missing.\nd: The column diameter. Optional parameter, if not available it has the value missing.\ngas: The used gas for the mobile phase. Optional parameter, if not available it has the value missing.\ndata: Dataframes with the parameters of the three different parameter sets. See function all_parameters().\n\nNote\n\nFor the naming convention of the filenames see Note.md.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.new_database_format-Tuple{Any}","page":"Docstrings","title":"RetentionData.new_database_format","text":"new_database_format(data; ParSet=\"Kcentric\")\n\nExport the data into the new database format with the columns:\n\nName\nCAS\nPhase\nTchar resp. A\nthetachar resp. B\nDeltaCp resp. C\nphi0\nSource\nCat ... several columns with categories \n\nWith the parameters ParSet=\"ABC\" the ABC-parameters are exported, with ParSet=\"Kcentric\" (default) the K-centric parameters are exported.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.old_database_format-Tuple{Any}","page":"Docstrings","title":"RetentionData.old_database_format","text":"old_database_format(data)\n\nExport the data into the old database format with the columns:\n\nName\nCAS\nCnumber\nHnumber\nOnumber\nNnumber\nRingnumber\nMolmass\nPhase\nTchar\nthetachar\nDeltaCp\nphi0\nAnnotation\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.plot_lnk_fit-Tuple{Any, Any, Any}","page":"Docstrings","title":"RetentionData.plot_lnk_fit","text":"plot_lnk_fit(fit, i, j)\n\nPlot the lnk-values over T of the selected dataset i of the selected substance j. Also the fit solution for the ABC-model and the K-centric-model are shown over the extended temperature range from 0°C to 400°C.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.plot_res_lnk_fit-Tuple{Any, Any, Any}","page":"Docstrings","title":"RetentionData.plot_res_lnk_fit","text":"plot_res_lnk_fit(fit, i, j)\n\nPlot the absolute residuals (not the weighted) of lnk-values over T of the selected dataset i of the selected substance j to the fitted models.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.ring_number-Tuple{Any}","page":"Docstrings","title":"RetentionData.ring_number","text":"ring_number(smiles)\n\nExtract the number of rings of a substance defined by its SMILES. The highest digit contained in the SMILES is returned as the number of rings. Only single digit ring numbers are recognized.\n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.save_all_parameter_data-Tuple{DataFrames.DataFrame}","page":"Docstrings","title":"RetentionData.save_all_parameter_data","text":"save_all_parameter_data(meta_data::DataFrame)\n\nSave the data in the meta_data dataframe in new .csv-files in the same folder as the original data using the new filename Source_AllParam_Tablename_statPhase(_d)(_gas).csv. Source is the name of the source of the original data, statPhase is the stationary phase corresponding to the data and Tablename the name of the table of the original data. The optional entrys d and gas stand for the column diameter and the gas of the mobile phase. \n\n\n\n\n\n","category":"method"},{"location":"docstrings/#RetentionData.substance_identification-Tuple{DataFrames.DataFrame}","page":"Docstrings","title":"RetentionData.substance_identification","text":"substance_identification(data::DataFrame)\n\nLook up the substance name from the data dataframe with ChemicalIdentifiers.jl to find the CAS-number, the formula, the molecular weight MW and the smiles-identifier. If the name is not found in the database of ChemicalIdentifiers.jl a list with alternative names (shortnames.csv) is used. If there are still no matches, missing is used.\n\n\n\n\n\n","category":"method"}]
}
