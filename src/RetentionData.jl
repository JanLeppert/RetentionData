module RetentionData

using CSV
using DataFrames
using LambertW
using LsqFit
using Plots
using ChemicalIdentifiers
using Statistics
using Measurements
using RAFF

const R = 8.31446261815324
const Tst = 273.15
const T0 = 90.0
const custom_database_url = "https://raw.githubusercontent.com/JanLeppert/RetentionData/main/data/add_CI_db.tsv"

"""
	collect_csv_paths(folder)

Collect the paths of all .csv-files in the `folder` and all its sub-folders in an array of Strings.
"""
function collect_csv_paths(folder)
	csv_obj = String[]
	
	db_obj = filter(x -> isdir.(x) || endswith.(x, ".csv") || endswith.(x, ".CSV"), readdir(folder, join=true))
	
	for i=1:length(db_obj)
		if endswith(db_obj[i], ".csv")
			push!(csv_obj, db_obj[i])
		elseif isdir(db_obj[i])
			subfolder_obj = collect_csv_paths(db_obj[i])
			for j=1:length(subfolder_obj)
				push!(csv_obj, subfolder_obj[j])
			end
		end
	end
	
	return csv_obj
end

"""
	extract_meta_data(csv_paths::Array{String,1})

Extract the meta data contained in the filename of a collection of paths to .csv-files. A dataframe with the columns:
- path
- filename
- source
- phase
- beta0
- Tref
- d
- gas
is returned. For the correct format of the filename see 'Note.md'.
"""
function extract_meta_data(csv_paths::Array{String,1})
	rg = r"(?<=\D)(?=\d)" # pattern: non-digits followed by digits -> pattern of beta250
	path = Array{String}(undef, length(csv_paths))
	filename = Array{String}(undef, length(csv_paths))
	source = Array{String}(undef, length(csv_paths))
	phase = Array{String}(undef, length(csv_paths))
	beta0 = Array{Float64}(undef, length(csv_paths))
	Tref = missings(Float64, length(csv_paths))
	d = missings(Float64, length(csv_paths))
	gas = missings(String, length(csv_paths))
	# split the filename from the path
	for i=1:length(csv_paths)
		path[i], filename[i] = splitdir(csv_paths[i]) # separate filename from path
		split_fn = split(split(filename[i], r".csv")[1], '_')
		source[i] = split_fn[1]
		phase[i] = split_fn[4]
		for j=5:length(split_fn)
			if contains(split_fn[j], "beta")
				beta0[i] = parse(Float64, split(split_fn[5], rg)[2])
			elseif contains(split_fn[j], "Tref")
				Tref[i] = parse(Float64, split(split_fn[j], "Tref")[2])
			elseif contains(split_fn[j], "d")
				d[i] = parse(Float64, split(split_fn[j], "d")[2])
			elseif contains(split_fn[j], "gas")
				gas[i] = split(split_fn[j], "gas")[2]
			end
		end
	end
	meta_data = DataFrame(path=path, filename=filename, source=source, phase=phase, beta0=beta0, Tref=Tref, d=d, gas=gas)
	return meta_data
end

"""
	load_csv_data(meta_data::DataFrame)

Load the data from the .csv-file located at `meta_data.path`, `meta_data.filename`. Data for `DeltaHref` is multiplied by 1000, if the corresponding unit is `kJ/mol`. The loaded data is returned in a dataframe. If an ID-list is available in the same folder the shortname/number will be looked up in the ID-list and replaced by the full name given in the ID-List.
"""
function load_csv_data(meta_data::DataFrame)
	data = Array{DataFrame}(undef, length(meta_data.filename))
	for i=1:length(meta_data.filename)
		path = joinpath(meta_data.path[i], meta_data.filename[i])
		data_ = DataFrame(CSV.File(path, header=1, stringtype=String))
		# problem: some files have one header, some have two header lines (units in second line)
		if typeof(data_[!, 2]) == Array{Float64, 1} || typeof(data_[!, 2]) == Array{Union{Missing,Float64}, 1} # no second header with units
			data[i] = data_
		else # second header with units 
			data[i] = DataFrame(CSV.File(path, header=1:2, stringtype=String))
		end
		# if a column is DeltaHref and has a unit with kJ, than the values have to be multiplied by 1000
		col_i = findfirst(occursin.("DeltaHref", names(data[i])))
		if typeof(col_i) != Nothing
			if occursin("kJ", names(data[i])[col_i])
				data[i][!, col_i] = data[i][!, col_i].*1000.0
				rename!(data[i], names(data[i])[col_i] => "DeltaHref_J/mol")
			end
		end
		# if the filepath has a file similar to `Source_IDList_...csv` than the names (numbers/shortnames) from the filename should be replaced with the names from the IDList (only one IDList in the same folder)
		IDfile = filter(x -> endswith.(x, ".csv") && contains.(x, "IDList"), readdir(meta_data.path[i]))
		if length(IDfile) == 1
			IDlist = DataFrame(CSV.File(joinpath(meta_data.path[i], IDfile[1]), header=1, stringtype=String))
			for j=1:length(data[i][!,1])
				j_ID = findfirst(data[i][!,1][j].==IDlist[!,1])
				if isnothing(j_ID) != true
					data[i][!,1][j] = IDlist[!,2][j_ID]
				end
			end
		end
		# if the loaded data is `log10k-T` data, than the loaded values hav to be convert to ln(k)-values
		if contains(meta_data.filename[i], "log10k-T")
			data[i][!, 2:end] = data[i][!, 2:end].*log(2)./log10(2)
		end
	end
	return data
end

"""
	load_csv_data!(meta_data::DataFrame)

Load the data from the .csv-file located at `meta_data.path`, `meta_data.filename`. Data for `DeltaHref` is multiplied by 1000, if the corresponding unit is `kJ/mol`. The loaded data is returned in an additional column `data` in the `meta_data` dataframe.
"""
function load_csv_data!(meta_data::DataFrame)
	data = load_csv_data(meta_data)
	meta_data[!, "data"] = data
	return meta_data
end

"""
	identify_parameters(data::Array{DataFrame})

Extract the column indices of the parameters and identify the type of parameters sets stored in the dataframes of `data`.  

ABC-parameters:
- column name containing "A" -> A
- column name containing "B" -> B
- column name containing "C_" or column name == "C" -> C

K-centric:
- column name containing "Tchar" -> Tchar
- column name containing "thetachar" -> thetachar
- column name containing "DeltaCp" -> DeltaCp

thermodynamic parameters at reference temperature Tref
- column name containing "DeltaHref" -> DeltaHref
- column name containing "DeltaSref" -> DeltaSref
- column name containing "DeltaCp" -> DeltaCp
- additionally from meta_data a value for Tref is needed

# Output
- param_set: Array of Arrays of string, listening the types of parameter sets, possible values "ABC", "K-centric", "TD"
- index: Array of dictionaries with the colum index of the parameters (parameters name is the key, the index is the value)
"""
function indentify_parameters(data::Array{DataFrame})
	param_set = Array{Array{String,1}}(undef, length(data))
	index = Array{Dict}(undef, length(data))
	for i=1:length(data)
		# ABC model
		i_A = findfirst(occursin.("A", names(data[i])))
		i_B = findfirst(occursin.("B", names(data[i])))
		i_C = findfirst(occursin.("C_", names(data[i])))
		if typeof(i_C) == Nothing
			i_C = findfirst("C".==names(data[i]))
		end
		# K-centric model
		i_Tchar = findfirst(occursin.("Tchar", names(data[i])))
		i_thetachar = findfirst(occursin.("thetachar", names(data[i])))
		i_DeltaCp = findfirst(occursin.("DeltaCp", names(data[i])))
		# TD model
		i_DeltaHref = findfirst(occursin.("DeltaHref", names(data[i])))
		i_DeltaSref = findfirst(occursin.("DeltaSref", names(data[i])))
		# i_DeltaCp from above
		p_set = String[]
		if typeof(i_A) == Int && typeof(i_B) == Int && typeof(i_C) == Int
			push!(p_set, "ABC")
		end
		if typeof(i_Tchar) == Int && typeof(i_thetachar) == Int && typeof(i_DeltaCp) == Int
			push!(p_set, "K-centric")
		end
		if typeof(i_DeltaHref) == Int && typeof(i_DeltaSref) == Int && typeof(i_DeltaCp) == Int
			push!(p_set, "TD")
		end
		param_set[i] = p_set
		index[i] = Dict("A" => i_A, "B" => i_B, "C" => i_C,
			"Tchar" => i_Tchar, "thetachar" => i_thetachar, "DeltaCp" => i_DeltaCp,
			"DeltaHref" => i_DeltaHref, "DeltaSref" => i_DeltaSref)
	end
	return param_set, index
end

"""
	TD_to_ABC(ΔHref, ΔSref, ΔCp, Tref)

Convert the parameters of the thermodynamic set (`ΔHref`, `ΔSref`, `ΔCp`) to the parameters of the `ABC` set (`A`, `B`, `C`). The reference temperature `Tref` is a needed additional information. The parameter should have been measured in
the following units:
- `ΔHref` in J mol⁻¹
- `ΔSref` in J mol⁻¹ K⁻¹
- `ΔCp` in J mol⁻¹ K⁻¹
- `Tref` in °C

# Output
- `A` (without unit)
- `B` in K
- `C` (without unit)
"""
function TD_to_ABC(ΔHref, ΔSref, ΔCp, Tref)
	A = (ΔSref-ΔCp*(1+log(Tref+Tst)))/R
	B = (ΔCp*(Tref+Tst) - ΔHref)/R
	C = ΔCp/R
	return A, B, C
end

"""
	ABC_to_TD(A, B, C, Tref)

Convert the parameters of the `ABC` set (`A`, `B`, `C`) to the parameters of the thermodynamic set (`ΔHref`, `ΔSref`, `ΔCp`). The reference temperature `Tref` is a needed additional information. The parameter should have been measured in
the following units:
- `A` (without unit)
- `B` in K
- `C` (without unit)
- `Tref` in °C

# Output
- `ΔHref` in J mol⁻¹
- `ΔSref` in J mol⁻¹ K⁻¹
- `ΔCp` in J mol⁻¹ K⁻¹
"""
function ABC_to_TD(A, B, C, Tref)
	ΔHref = R*(C*(Tref+Tst) - B)
	ΔSref = R*(A + C + C*log(Tref+Tst))
	ΔCp = R*C
	return ΔHref, ΔSref, ΔCp
end

"""
	lambertw_x(A, B, C, KRef)

Calculate the argument for the Lambert W function (-1 branch) used to convert the `ABC` set to the K-centric set. The reference distribution coefficient `KRef` is a needed additional information (normally, it should be equal to the phase ratio `β` of the reference column, where the parameters where measured). The value should be -1/e ≤ x < 0.
"""
function lambertw_x(A, B, C, KRef)
	x = -B*exp(A/C)/(C*KRef^(1/C))
	return x
end

"""
	ABC_to_Kcentric(A, B, C, KRef)

Convert the parameters of the `ABC` set (`A`, `B`, `C`) to the parameters of the K-centric set (`Tchar`, `θchar`, `ΔCp`). The reference distribution coefficient `KRef` is a needed additional information (normally, it should be equal to the phase ratio `β` of the reference column, where the parameters where measured). The parameter should have been measured in
the following units:
- `A` (without unit)
- `B` in K
- `C` (without unit)
- `KRef` (without unit)

# Output
- `Tchar` in °C
- `θchar` in °C
- `ΔCp` in J mol⁻¹ K⁻¹
"""
function ABC_to_Kcentric(A, B, C, KRef)
	x = lambertw_x(A, B, C, KRef)
	if x >= -1/exp(1) && x < 0.0
		Wx = lambertw(x,-1)
		Tchar = -B/(C*Wx) - Tst
		θchar = B/(C^2*(1 + Wx)*Wx)
	else
		Wx = lambertw(x,0)
		Tchar = -B/(C*Wx) - Tst
		θchar = B/(C^2*(1 + Wx)*Wx)
	end
	ΔCp = C*R
	return Tchar, θchar, ΔCp
end

"""
	Kcentric_to_ABC(Tchar, θchar, ΔCp, KRef)

Convert the parameters of the K-centric set (`Tchar`, `θchar`, `ΔCp`) to the parameters of the `ABC` set (`A`, `B`, `C`). The reference distribution coefficient `KRef` is a needed additional information (normally, it should be equal to the phase ratio `β` of the reference column, where the parameters where measured). The parameter should have been measured in
the following units:
- `Tchar` in °C
- `θchar` in °C
- `ΔCp` in J mol⁻¹ K⁻¹
- `KRef` (without unit)

# Output
- `A` (without unit)
- `B` in K
- `C` (without unit)
"""
function Kcentric_to_ABC(Tchar, θchar, ΔCp, KRef)
	A = log(KRef) - (Tchar+Tst)/θchar - ΔCp/R*(1 + log(Tchar+Tst))
	B = ΔCp/R*(Tchar+Tst) + (Tchar+Tst)^2/θchar
	C = ΔCp/R
	return A, B, C
end

"""
	all_parameters(data::Array{DataFrame,1}, paramset::Array{Array{String,1},1}, paramindex::Array{Dict,1})

Calculate the other parameter sets from the given parameter sets and return them in a new array of dataframes.

# Output
A new array of dataframes. The dataframes have the following columns:
- `Name`: Name of the substance
- `A`: parameter `A` of the `ABC` set
- `B`: parameter `B` of the `ABC` set
- `C`: parameter `B` of the `ABC` set
- `Tchar`: parameter `Tchar` of the `K-centric` set in °C
- `thetachar`: parameter `θchar` of the `K-centric` set
- `DeltaCp`: parameter `ΔCp` of the `K-centric` and `TD` set
- `DeltaHref`: parameter `ΔHref` of the `TD` set
- `DeltaSref`: parameter `ΔSref` of the `TD` set
- `Tref`: the reference temperature of the `TD` set
- `beta0`: the phase ratio β0, for which the retention was measured, `KRef=β0` of the `K-centric` set
- `lambertw_x`: the argument of the Lambert W function used in the conversion of the `ABC` set to the `K-centric` set. The value should be -1/e ≤ x < 0
"""
function all_parameters(data::Array{DataFrame,1}, paramset::Array{Array{String,1},1}, paramindex::Array{Dict,1}, β0::Array{Float64,1}, T_ref::Array{Union{Missing, Float64},1}) # calculate the not available parameter sets
	new_data = Array{DataFrame}(undef, length(data))
	for i=1:length(data)
		A = Array{Float64}(undef, length(data[i][!, 1]))
		B = Array{Float64}(undef, length(data[i][!, 1]))
		C = Array{Float64}(undef, length(data[i][!, 1]))
		Tchar = Array{Float64}(undef, length(data[i][!, 1]))
		θchar = Array{Float64}(undef, length(data[i][!, 1]))
		ΔCp = Array{Float64}(undef, length(data[i][!, 1]))
		ΔHref = Array{Float64}(undef, length(data[i][!, 1]))
		ΔSref = Array{Float64}(undef, length(data[i][!, 1]))
		ΔHchar = Array{Float64}(undef, length(data[i][!,1])) # modJL
		ΔSchar = Array{Float64}(undef, length(data[i][!,1])) # modJL
 		#Tref = Array{Float64}(undef, length(data[i][!, 1]))
		#beta0 = Array{Float64}(undef, length(data[i][!, 1]))
		beta0 = β0[i].*ones(length(data[i][!, 1]))
		W_x = Array{Float64}(undef, length(data[i][!, 1]))
		if ismissing(T_ref[i])
			Tref = T0.*ones(length(data[i][!, 1]))
		else
			Tref = T_ref[i].*ones(length(data[i][!, 1]))
		end
		for j=1:length(data[i][!, 1])
			if "ABC" in paramset[i] && "K-centric" in paramset[i] && "TD" in paramset[i]
				A[j] = data[i][!, paramindex[i]["A"]][j]
				B[j] = data[i][!, paramindex[i]["B"]][j]
				C[j] = data[i][!, paramindex[i]["C"]][j]
				Tchar[j] = data[i][!, paramindex[i]["Tchar"]][j]
				θchar[j] = data[i][!, paramindex[i]["thetachar"]][j]
				ΔCp[j] = data[i][!, paramindex[i]["DeltaCp"]][j]
				ΔHref[j] = data[i][!, paramindex[i]["DeltaHref"]][j]
				ΔSref[j] = data[i][!, paramindex[i]["DeltaSref"]][j]
			elseif "ABC" in paramset[i] && "K-centric" in paramset[i] &&!("TD" in paramset[i])
				A[j] = data[i][!, paramindex[i]["A"]][j]
				B[j] = data[i][!, paramindex[i]["B"]][j]
				C[j] = data[i][!, paramindex[i]["C"]][j]
				Tchar[j] = data[i][!, paramindex[i]["Tchar"]][j]
				θchar[j] = data[i][!, paramindex[i]["thetachar"]][j]
				ΔCp[j] = data[i][!, paramindex[i]["DeltaCp"]][j]
				TD = ABC_to_TD(A[j], B[j], C[j], Tref[j])
				ΔHref[j] = TD[1]
				ΔSref[j] = TD[2]
			elseif "ABC" in paramset[i] && !("K-centric" in paramset[i]) && "TD" in paramset[i]
				A[j] = data[i][!, paramindex[i]["A"]][j]
				B[j] = data[i][!, paramindex[i]["B"]][j]
				C[j] = data[i][!, paramindex[i]["C"]][j]
				ΔCp[j] = data[i][!, paramindex[i]["DeltaCp"]][j]
				ΔHref[j] = data[i][!, paramindex[i]["DeltaHref"]][j]
				ΔSref[j] = data[i][!, paramindex[i]["DeltaSref"]][j]
				Kcentric = ABC_to_Kcentric(A[j], B[j], C[j], beta0[j])
				Tchar[j] = Kcentric[1]
				θchar[j] = Kcentric[2]
			elseif "ABC" in paramset[i] && !("K-centric" in paramset[i]) && !("TD" in paramset[i])
				A[j] = data[i][!, paramindex[i]["A"]][j]
				B[j] = data[i][!, paramindex[i]["B"]][j]
				C[j] = data[i][!, paramindex[i]["C"]][j]
				Kcentric = ABC_to_Kcentric(A[j], B[j], C[j], beta0[j])
				Tchar[j] = Kcentric[1]
				θchar[j] = Kcentric[2]
				ΔCp[j] = Kcentric[3]
				TD = ABC_to_TD(A[j], B[j], C[j], Tref[j])
				ΔHref[j] = TD[1]
				ΔSref[j] = TD[2]
			elseif !("ABC" in paramset[i]) && "K-centric" in paramset[i] && "TD" in paramset[i]
				Tchar[j] = data[i][!, paramindex[i]["Tchar"]][j]
				θchar[j] = data[i][!, paramindex[i]["thetachar"]][j]
				ΔCp[j] = data[i][!, paramindex[i]["DeltaCp"]][j]
				ΔHref[j] = data[i][!, paramindex[i]["DeltaHref"]][j]
				ΔSref[j] = data[i][!, paramindex[i]["DeltaSref"]][j]
				ABC = Kcentric_to_ABC(Tchar[j], θchar[j], ΔCp[j], beta0[j])
				A[j] = ABC[1]
				B[j] = ABC[2]
				C[j] = ABC[3]
			elseif !("ABC" in paramset[i]) && "K-centric" in paramset[i] && !("TD" in paramset[i])
				Tchar[j] = data[i][!, paramindex[i]["Tchar"]][j]
				θchar[j] = data[i][!, paramindex[i]["thetachar"]][j]
				ΔCp[j] = data[i][!, paramindex[i]["DeltaCp"]][j]
				ABC = Kcentric_to_ABC(Tchar[j], θchar[j], ΔCp[j], beta0[j])
				A[j] = ABC[1]
				B[j] = ABC[2]
				C[j] = ABC[3]
				TD = ABC_to_TD(A[j], B[j], C[j], Tref[j])
				ΔHref[j] = TD[1]
				ΔSref[j] = TD[2]
			elseif !("ABC" in paramset[i]) && !("K-centric" in paramset[i]) && "TD" in paramset[i]
				ΔCp[j] = data[i][!, paramindex[i]["DeltaCp"]][j]
				ΔHref[j] = data[i][!, paramindex[i]["DeltaHref"]][j]
				ΔSref[j] = data[i][!, paramindex[i]["DeltaSref"]][j]
				ABC = TD_to_ABC(ΔHref[j], ΔSref[j], ΔCp[j], Tref[j])
				A[j] = ABC[1]
				B[j] = ABC[2]
				C[j] = ABC[3]
				Kcentric = ABC_to_Kcentric(A[j], B[j], C[j], beta0[j])
				Tchar[j] = Kcentric[1]
				θchar[j] = Kcentric[2]
			end
			ΔHchar[j], ΔSchar[j] = ABC_to_TD(A[j], B[j], C[j], Tchar[j])[1:2] # modJL
			W_x[j] = lambertw_x(A[j], B[j], C[j], beta0[j])
		end
		#new_data[i] = DataFrame(Name=data[i][!, 1], A=A, B=B, C=C, Tchar=Tchar, thetachar=θchar, DeltaCp=ΔCp, DeltaHref=ΔHref, DeltaSref=ΔSref, Tref=Tref, beta0=beta0, lambertw_x=W_x)
		new_data[i] = DataFrame(Name=data[i][!, 1], A=A, B=B, C=C, Tchar=Tchar, thetachar=θchar, DeltaCp=ΔCp, DeltaHchar=ΔHchar, DeltaSchar=ΔSchar, DeltaHref=ΔHref, DeltaSref=ΔSref, Tref=Tref, beta0=beta0, lambertw_x=W_x) # modJL
		# add columns with "Cat" in column name
		i_cat = findall(occursin.("Cat", names(data[i])))
		for j=1:length(i_cat)
			new_data[i][!, "Cat_$(j)"] = data[i][!, i_cat[j]]
		end
	end
	return new_data
end

"""
	all_parameters!(meta_data)

Calculate the other parameter sets from the given parameter sets and replace the `data` in meta_data with the following:

A new array of dataframes. The dataframes have the following columns:
- `Name`: Name of the substance
- `A`: parameter `A` of the `ABC` set
- `B`: parameter `B` of the `ABC` set
- `C`: parameter `B` of the `ABC` set
- `Tchar`: parameter `Tchar` of the `K-centric` set
- `thetachar`: parameter `θchar` of the `K-centric` set
- `DeltaCp`: parameter `ΔCp` of the `K-centric` and `TD` set
- `DeltaHref`: parameter `ΔHref` of the `TD` set
- `DeltaSref`: parameter `ΔSref` of the `TD` set
- `Tref`: the reference temperature of the `TD` set
- `beta0`: the phase ratio β0, for which the retention was measured, `KRef=β0` of the `K-centric` set
- `lambertw_x`: the argument of the Lambert W function used in the conversion of the `ABC` set to the `K-centric` set. The value should be -1/e ≤ x < 0
"""
function all_parameters!(meta_data)
	paramset, paramindex = indentify_parameters(meta_data.data)
	new_data = all_parameters(meta_data.data, paramset, paramindex, meta_data.beta0, meta_data.Tref)
	meta_data[!, "parameters"] = new_data
	return meta_data
end

"""
	load_parameter_data(db_path)

Load the data files (.csv format) with the `Parameters` data from the folder `db_path` including all subfolders. Based on the loaded parameters, the parameters of the not included parameter sets are calculated. Additional information from the filenames are also saved.

# Output
A dataframes with the following columns:
- `path`: Path of the folder from where the data was loaded.
- `filename`: Name of the file from where the data was loaded.
- `source`: Short name for the source from where the data original is taken.
- `phase`: Name of the stationary phase corresponding to the data.
- `beta0`: The phase ratio corresponding to the data.
- `Tref`: The reference temperature used for the thermodynamic parameter set. Optional parameter, if not available it has the value `missing`.
- `d`: The column diameter. Optional parameter, if not available it has the value `missing`.
- `gas`: The used gas for the mobile phase. Optional parameter, if not available it has the value `missing`.
- `data`: Dataframes with the parameters of the three different parameter sets. See function all_parameters().

# Note
For the naming convention of the filenames see Note.md.
"""
function load_parameter_data(db_path)
	all_csv = collect_csv_paths(db_path)
	keyword = "Parameters"
	parameters_csv = filter(contains(keyword), all_csv)
	meta_data = extract_meta_data(parameters_csv)
	load_csv_data!(meta_data)
	all_parameters!(meta_data)
	return meta_data
end

"""
	load_allparameter_data(db_path)

Load the data files (.csv format) with the `Parameters` data from the folder `db_path` including all subfolders. Based on the loaded parameters, the parameters of the not included parameter sets are calculated. Additional information from the filenames are also saved.

# Output
A dataframes with the following columns:
- `path`: Path of the folder from where the data was loaded.
- `filename`: Name of the file from where the data was loaded.
- `source`: Short name for the source from where the data original is taken.
- `phase`: Name of the stationary phase corresponding to the data.
- `beta0`: The phase ratio corresponding to the data.
- `Tref`: The reference temperature used for the thermodynamic parameter set. Optional parameter, if not available it has the value `missing`.
- `d`: The column diameter. Optional parameter, if not available it has the value `missing`.
- `gas`: The used gas for the mobile phase. Optional parameter, if not available it has the value `missing`.
- `data`: Dataframes with the parameters of the three different parameter sets. See function all_parameters().

# Note
For the naming convention of the filenames see Note.md.
"""
function load_allparameter_data(db_path)
	all_csv = collect_csv_paths(db_path)
	keyword = "AllParam"
	parameters_csv = filter(contains(keyword), all_csv)
	meta_data = extract_meta_data(parameters_csv)
	load_csv_data!(meta_data)
	return meta_data
end

"""
	save_all_parameter_data(meta_data::DataFrame)

Save the `data` in the `meta_data` dataframe in new .csv-files in the same folder as the original data using the new filename `Source_AllParam_Tablename_statPhase(_d)(_gas).csv`. `Source` is the name of the source of the original data, `statPhase` is the stationary phase corresponding to the data and `Tablename` the name of the table of the original data. The optional entrys `d` and `gas` stand for the column diameter and the gas of the mobile phase. 
"""
function save_all_parameter_data(meta_data::DataFrame; rounding=true, sigdigits=5, errors=true) # ?add options for rounding resp. for Measurements.value()
	#param_df = Array{Any}(undef, length(meta_data.data))
	for i=1:length(meta_data.data)
		tablename = split(meta_data.filename[i], "_")[3]
		if ismissing(meta_data.d[i]) && ismissing(meta_data.gas[i])
			new_filename = string(meta_data.source[i], "_AllParam_", tablename, "_", meta_data.phase[i], "_", meta_data.beta0[i], ".csv")
		elseif ismissing(meta_data.d[i])
			new_filename = string(meta_data.source[i], "_AllParam_", tablename, "_", meta_data.phase[i], "_", meta_data.beta0[i], "_gas", meta_data.gas[i], ".csv")
		elseif ismissing(meta_data.gas[i])
			new_filename = string(meta_data.source[i], "_AllParam_", tablename, "_", meta_data.phase[i], "_", meta_data.beta0[i], "_d", meta_data.d[i], ".csv")
		else
			new_filename = string(meta_data.source[i], "_AllParam_", tablename, "_", meta_data.phase[i], "_", meta_data.beta0[i], "_d", meta_data.d[i], "_gas", meta_data.gas[i], ".csv")
		end
		# add a round for significant digits
		#if contains(meta_data.filename[i], "Parameters")
		if errors == true
			header = [names(meta_data.parameters[i]); ["err_A", "err_B", "err_C", "err_Tchar", "err_thetachar", "err_DeltaCp", "err_DeltaHchar", "err_DeltaSchar", "err_DeltaHref", "err_DeltaSref"]]
		else
			header = names(meta_data.parameters[i])
		end
		j0 = length(names(meta_data.parameters[i]))
		jj = 1
		param = DataFrame()
		for j=1:j0#length(header)
			if typeof(meta_data.parameters[i][!, j]) == Array{Measurement{Float64}, 1}
				if rounding == true && errors == false# information about std-errors for fits is lost here
					##if errors == true && j > j0
					##	param[!, header[j]] = round.(Measurements.uncertainty.(meta_data.parameters[i][!, j]))
					##else
						param[!, header[j]] = round.(Measurements.value.(meta_data.parameters[i][!, j]); sigdigits=sigdigits)
					##end
				elseif rounding == false && errors == false
					param[!, header[j]] = Measurements.value.(meta_data.parameters[i][!, j])
				elseif rounding == true && errors == true
					param[!, header[j]] = round.(Measurements.value.(meta_data.parameters[i][!, j]); sigdigits=sigdigits)
					param[!, header[j0+jj]] = round.(Measurements.uncertainty.(meta_data.parameters[i][!, j]); sigdigits=sigdigits)
					jj = jj + 1
				elseif rounding == false && errors == true
					param[!, header[j]] = Measurements.value.(meta_data.parameters[i][!, j])
					param[!, header[j0+jj]] = Measurements.uncertainty.(meta_data.parameters[i][!, j])
					jj = jj + 1
				end
			elseif typeof(meta_data.parameters[i][!, j]) == Array{Float64, 1}
				if rounding == true
					param[!, header[j]] = round.(meta_data.parameters[i][!, j]; sigdigits=sigdigits)
				else
					param[!, header[j]] = meta_data.parameters[i][!, j]
				end
			else
				param[!, header[j]] = meta_data.parameters[i][!, j]
			end
		end
		CSV.write(joinpath(meta_data.path[i], new_filename), param)
		#param_df[i] = param
	end
	#return param_df
end

"""
	datafram_of_all(meta_data::DataFrame)

Combine the separate dataframes with the parameter sets of the different entrys of the meta_data dataframe into one big dataframe.
"""
function dataframe_of_all(meta_data)
	Name = String[]
	Phase = String[]
	Source = String[]
	dataset = String[]
	A = Float64[]#Union{Measurement{Float64},Float64}[]#Float64[]
	err_A = Float64[]
	B = Float64[]#Union{Measurement{Float64},Float64}[]#Float64[]
	err_B = Float64[]
	C = Float64[]#Union{Measurement{Float64},Float64}[]#Float64[]
	err_C = Float64[]
	Tchar = Float64[]#Union{Measurement{Float64},Float64}[]#Float64[]
	err_Tchar = Float64[]#
	thetachar = Float64[]#Union{Measurement{Float64},Float64}[]#Float64[]
	err_thetachar = Float64[]
	DeltaCp = Float64[]#Union{Measurement{Float64},Float64}[]#Float64[]
	err_DeltaCp = Float64[]
	DeltaHref = Float64[]#Union{Measurement{Float64},Float64}[]#Float64[]
	err_DeltaHref = Float64[]
	DeltaSref = Float64[]#Union{Measurement{Float64},Float64}[]#Float64[]
	err_DeltaSref = Float64[]
	DeltaHchar = Float64[]#Union{Measurement{Float64},Float64}[]#Float64[]
	err_DeltaHchar = Float64[]
	DeltaSchar = Float64[]#Union{Measurement{Float64},Float64}[]#Float64[]
	err_DeltaSchar = Float64[]
	Tref = Float64[]
	beta0 = Float64[]
	N = Float64[]
	R² = Float64[]
	χ² = Float64[]
	χ̄² = Float64[]
	d = Any[]
	gas = Any[]
	for i=1:length(meta_data.data)
		for j=1:length(meta_data.data[i].Name)
			push!(Name, meta_data.data[i].Name[j])
			push!(Phase, meta_data.phase[i])
			push!(Source, meta_data.source[i])
			push!(dataset, meta_data.filename[i])
			push!(A, meta_data.data[i].A[j])
			if "err_A" in names(meta_data.data[i])
				push!(err_A, meta_data.data[i].err_A[j])
			else push!(err_A, NaN)
			end
			push!(B, meta_data.data[i].B[j])
			if "err_B" in names(meta_data.data[i])
				push!(err_B, meta_data.data[i].err_B[j])
			else push!(err_B, NaN)
			end
			push!(C, meta_data.data[i].C[j])
			if "err_C" in names(meta_data.data[i])
				push!(err_C, meta_data.data[i].err_C[j])
			else push!(err_C, NaN)
			end
			push!(Tchar, meta_data.data[i].Tchar[j])
			if "err_Tchar" in names(meta_data.data[i])
				push!(err_Tchar, meta_data.data[i].err_Tchar[j])
			else push!(err_Tchar, NaN)
			end
			push!(thetachar, meta_data.data[i].thetachar[j])
			if "err_thetachar" in names(meta_data.data[i])
				push!(err_thetachar, meta_data.data[i].err_thetachar[j])
			else push!(err_thetachar, NaN)
			end
			push!(DeltaCp, meta_data.data[i].DeltaCp[j])
			if "err_DeltaCp" in names(meta_data.data[i])
				push!(err_DeltaCp, meta_data.data[i].err_DeltaCp[j])
			else push!(err_DeltaCp, NaN)
			end
			push!(DeltaHref, meta_data.data[i].DeltaHref[j])
			if "err_DeltaHref" in names(meta_data.data[i])
				push!(err_DeltaHref, meta_data.data[i].err_DeltaHref[j])
			else push!(err_DeltaHref, NaN)
			end
			push!(DeltaSref, meta_data.data[i].DeltaSref[j])
			if "err_DeltaSref" in names(meta_data.data[i])
				push!(err_DeltaSref, meta_data.data[i].err_DeltaSref[j])
			else push!(err_DeltaSref, NaN)
			end
			push!(DeltaHchar, meta_data.data[i].DeltaHchar[j])
			if "err_DeltaHchar" in names(meta_data.data[i])
				push!(err_DeltaHchar, meta_data.data[i].err_DeltaHchar[j])
			else push!(err_DeltaHchar, NaN)
			end
			push!(DeltaSchar, meta_data.data[i].DeltaSchar[j])
			if "err_DeltaSchar" in names(meta_data.data[i])
				push!(err_DeltaSchar, meta_data.data[i].err_DeltaSchar[j])
			else push!(err_DeltaSchar, NaN)
			end
			push!(Tref, meta_data.data[i].Tref[j])
			push!(beta0, meta_data.data[i].beta0[j])
			if "n_Kcentric" in names(meta_data.data[i])
				push!(N, meta_data.data[i].n_Kcentric[j])
			else push!(N, NaN)
			end
			if "R²_Kcentric" in names(meta_data.data[i])
				push!(R², meta_data.data[i].R²_Kcentric[j])
			else push!(R², NaN)
			end
			if "χ²_Kcentric" in names(meta_data.data[i])
				push!(χ², meta_data.data[i].χ²_Kcentric[j])
			else push!(χ², NaN)
			end
			if "χ̄²_Kcentric" in names(meta_data.data[i])
				push!(χ̄², meta_data.data[i].χ̄²_Kcentric[j])
			else push!(χ̄², NaN)
			end
			push!(d, meta_data.d[i])
			push!(gas, meta_data.gas[i])
		end
	end
	dfall = DataFrame(Name=Name, Phase=Phase, Source=Source, DataSet=dataset,
						A=A, err_A=err_A, B=B, err_B=err_B, C=C, err_C=err_C,
						Tchar=Tchar, err_Tchar=err_Tchar, thetachar=thetachar, err_thetachar=err_thetachar, DeltaCp=DeltaCp, err_DeltaCp=err_DeltaCp,
						DeltaHchar=DeltaHchar, err_DeltaHchar=err_DeltaHchar, DeltaSchar=DeltaSchar, err_DeltaSchar=err_DeltaSchar,
						DeltaHref=DeltaHref, err_DeltaHref=err_DeltaHref, DeltaSref=DeltaSref, err_DeltaSref=err_DeltaSref, 
						Tref=Tref, beta0=beta0, d=d, gas=gas, N=N, R²=R², χ²=χ², χ̄²=χ̄²)
	# add categories
	cat = collect_categories(meta_data)
	for j=1:size(cat)[2]
		catstring = Any[]
		for i=1:size(cat)[1]
			append!(catstring, cat[i,j])
		end
		dfall[!, "Cat_$(j)"] = catstring
	end	
	return dfall
end


function dataframe_of_all_CAS_flags(meta_data)
	dfall = dataframe_of_all(meta_data)
	# add cas
	CI = RetentionData.substance_identification(dfall)
	dfall[!, "CAS"] = CI.CAS
	# add flags
	dfall[!, "flag"] = RetentionData.flag(dfall)
	return dfall
end

function filter_dataframe_of_all(dfall)
	dfall_f = filter([:CAS, :flag] => (x, y) -> ismissing(x)==false && isempty(y), dfall)
	return dfall_f
end

"""
	collect_categories(meta_data)

Collect the category entrys of the substances in the different datasets of meta_data, if they are available in a multidimensionsal array.
"""
function collect_categories(meta_data)
	# number of categories of the different datasets
	nCat = Array{Int}(undef, length(meta_data.data))
	# indices of the category columns of the different datasets
	iCat = Array{Array{Int,1}}(undef, length(meta_data.data))
	for i=1:length(meta_data.data)
		iCat[i] = findall(occursin.("Cat", names(meta_data.data[i])))
		nCat[i] = length(iCat[i])
	end
	# maximum number of category columns
	maxnCat = maximum(nCat)
	# array of the categories of dataset `i` of category column `j`, filled with an array of the length of the substances of dataset `i` 
	Cat_array = Array{Array{Union{Missing, String},1}}(undef, length(meta_data.data), maxnCat)
	for j=1:maxnCat
		for i=1:length(meta_data.data)
			catstrings = missings(String, length(meta_data.data[i].Name))
			for k=1:length(meta_data.data[i].Name)
				if length(iCat[i])>=j #&& length(iCat[i])!=0
					catstrings[k] = meta_data.data[i][k, iCat[i][j]]
				end
			end
			Cat_array[i,j] = catstrings
		end
	end
	return Cat_array
end

"""
	flag(data)

Create a flag if certain conditions for the parameters are not fullfilled:
	- value of `lambertw_x` is < -1/e or > 0
	- value of `A` > 0
	- value of `B` < 0
	- value of `C` < 0
	- value of `Tchar` < -Tst
	- value of `θchar` < 0
"""
function flag(data)
	flag = Array{Array{String,1}}(undef, length(data.Name))
	for i=1:length(data.Name)
		fl = String[]
		x_lambertw = lambertw_x.(data.A[i], data.B[i], data.C[i], data.beta0[i])
		if x_lambertw < -1/exp(1)
			push!(fl, "lambertw < -1/e")
		end
		if x_lambertw > 0.0
			push!(fl, "lambertw > 0")
		end
		if data.A[i] > 0
			push!(fl, "A > 0")
		end
		if data.B[i] < 0
			push!(fl, "B < 0")
		end
		if data.C[i] < 0
			push!(fl,"C < 0")
		end
		if data.Tchar[i] < -273.15
			push!(fl, "Tchar < -Tst")
		end
		if data.thetachar[i] < 0
			push!(fl, "θchar < 0")
		end
		if data.thetachar[i] > 100
			push!(fl, "θchar > 100 °C")
		end
		flag[i] = fl
	end
	return flag
end

"""
	flagged_data(alldata::DataFrame)

Filter the parameter data for flagged and not-flagged datasets. 

"""
function flagged_data(alldata::DataFrame)
	fl = flag(alldata)
	fl_i = findall(isempty.(fl).==false)
	nofl_i = findall(isempty.(fl).==true)
	flagged = alldata[fl_i,:]
	not_flagged = alldata[nofl_i,:]
	return flagged, not_flagged
end

"""
	load_custom_CI_database(custom_database_url)

Load a custom database for ChemicalIdentifiers.jl from the location `custom_database_url`, if the custom database is not already loaded.	
"""
function load_custom_CI_database(custom_database_url)
	#if !(:custom in keys(ChemicalIdentifiers.DATA_DB))
		ChemicalIdentifiers.load_data!(:custom, url = custom_database_url)
		ChemicalIdentifiers.load_db!(:custom)
	#end
end

"""
	substance_identification(data::DataFrame)

Look up the substance name from the `data` dataframe with ChemicalIdentifiers.jl to find the `CAS`-number, the `formula`, the molecular weight `MW` and the `smiles`-identifier. If the name is not found in the database of ChemicalIdentifiers.jl a list with alternative names (`shortnames.csv`) is used. If there are still no matches, `missing` is used.
"""
function substance_identification(data::DataFrame)
	root = dirname(@__FILE__)
	project = dirname(root)
	shortnames = DataFrame(CSV.File(joinpath(project, "data", "shortnames.csv")))#DataFrame(CSV.File("/Users/janleppert/Documents/GitHub/RetentionData/data/shortnames.csv"))
	missing_subs = DataFrame(CSV.File(joinpath(project, "data", "missing.csv")))#DataFrame(CSV.File("/Users/janleppert/Documents/GitHub/RetentionData/data/missing.csv"))
	load_custom_CI_database(custom_database_url)

	CAS = Array{Union{Missing,AbstractString}}(missing, length(data.Name))
	formula = Array{Union{Missing,AbstractString}}(missing, length(data.Name))
	MW = Array{Union{Missing,Float64}}(missing, length(data.Name))
	smiles = Array{Union{Missing,AbstractString}}(missing, length(data.Name))
	for i=1:length(data.Name)
		if data.Name[i] in shortnames.shortname
			j = findfirst(data.Name[i].==shortnames.shortname)
			ci = try
				search_chemical(string(shortnames.name[j]))
			catch
				missing
			end
		else
			ci = try
				search_chemical(data.Name[i])
			catch
				missing
			end
		end
		if ismissing(ci)
			if data.Name[i] in missing_subs.name
				j = findfirst(data.Name[i].==missing_subs.name)
				CAS[i] = missing_subs.CAS[j]
				formula[i] = missing_subs.formula[j]
				MW[i] = missing_subs.MW[j]
				smiles[i] = missing_subs.smiles[j]
			else
				CAS[i] = missing
				formula[i] = missing
				MW[i] = missing
				smiles[i] = missing
			end
		else
			if length(digits(ci.CAS[2])) == 1
				CAS[i] = string(ci.CAS[1], "-0", ci.CAS[2], "-", ci.CAS[3])
			else
				CAS[i] = string(ci.CAS[1], "-", ci.CAS[2], "-", ci.CAS[3])
			end
			formula[i] = ci.formula
			MW[i] = ci.MW
			smiles[i] = ci.smiles
		end
	end
	id = DataFrame(Name=data.Name, CAS=CAS, formula=formula, MW=MW, smiles=smiles)
	#no_id = filter([:CAS] => x -> ismissing(x), id)
	return id
end

"""
	duplicated_data(alldata)

Find the duplicated data entrys in alldata based on identical CAS-number and identical stationary phase. The dataframe `alldata` must not have `missing` CAS-number entrys.

# Output
- array of dataframe `duplicated_data`: every array element has a dataframe of the duplicated data
- array of Bool `duplicated_entry`: true, if data has a duplicated, fals if not.
"""
function duplicated_data(alldata)
	# duplicate entrys based on CAS and Phase (first nonunique entries not in this list)
	duplicates = alldata[findall(nonunique(alldata, ["CAS", "Phase"]).==true),:]
	# unique duplicates based on CAS and Phase
	unique_duplicates = unique(duplicates, ["CAS", "Phase"])
	# find the indices of the unique duplicates in the original data
	duplicate_entry = falses(length(alldata.CAS))
	all_duplicate_index = Int[]
	duplicate_index = Array{Array{Int,1}}(undef, length(unique_duplicates.CAS))
	duplicate_data = Array{DataFrame}(undef, length(unique_duplicates.CAS))
	for i=1:length(unique_duplicates.CAS)
		duplicate_index[i] = intersect(findall(unique_duplicates.CAS[i].==alldata.CAS),findall(unique_duplicates.Phase[i].==alldata.Phase))
		append!(all_duplicate_index, duplicate_index[i])
		duplicate_data[i] = alldata[duplicate_index[i], :]
	end
	duplicate_entry[all_duplicate_index].=true
	return duplicate_data, duplicate_entry
end

"""
	formula_to_dict(formula)

Translate the formula string of a chemical substance into a dictionary, where the elements contained in the substance are the keys and the number of atoms are the values.

# Example 
```
julia> formula_to_dict("C14H20O")
Dict{String, Int64}("C" => 14, "H" => 20, "O" => 1)
```
"""
function formula_to_dict(formula)
	if ismissing(formula)
		formula_dict = missing
	else
		split_formula = eachmatch(r"[A-Z][a-z]*\d*", formula)
		elements = Array{Tuple{String, Int64}}(undef, length(collect(split_formula)))
		for i=1:length(collect(split_formula))
			formula_parts = collect(split_formula)[i].match
			element_string = match(r"[A-Za-z]+", formula_parts).match
			element_digit = match(r"[0-9]+", formula_parts)
			if isnothing(element_digit)
				elements[i] = (element_string, 1)
			else
				elements[i] = (element_string, parse(Int64, element_digit.match))
			end
		end
		formula_dict = Dict(elements)
	end
	return formula_dict
end

"""
	ring_number(smiles)

Extract the number of rings of a substance defined by its SMILES. The highest digit contained in the SMILES is returned as the number of rings. Only single digit ring numbers are recognized.
"""
function ring_number(smiles)
	if ismissing(smiles)
		rn = missing
	else
		allmatch = eachmatch(r"[0-9]", smiles)
		if isempty(allmatch)
			rn = 0
		else
			rn = maximum(parse.(Int64, [ match.match for match in allmatch]))
			# additional check, all integers from 1 to rn should be in allmatch, e.g. for rn=4 the integers 1, 2, 3, 4 should be in allmatch
		end
	end
	return rn
end

"""
	load_lnkT_data(db_path)

Load the data files (.csv format) with `lnk-T` data from the folder `db_path` including all subfolders.
"""
function load_lnkT_data(db_path)
	all_csv = collect_csv_paths(db_path)
	keyword1 = "log10k-T"
	keyword2 = "lnk-T"
	log10kT_csv = filter(contains(keyword1), all_csv)
	lnkT_csv = filter(contains(keyword2), all_csv)
	meta_data = extract_meta_data([log10kT_csv; lnkT_csv])
	load_csv_data!(meta_data)
	return meta_data
end

"""
	ABC(x, p)

The ABC-model for the relationship lnk(T). 

# Arguments:
- `x`: temperature `T` in K
- `p[1] = A - lnβ`
- `p[2] = B` in K
- `p[3] = C`
"""
@. ABC(x, p) = p[1] + p[2]/x + p[3]*log(x)

"""
	Kcentric(x, p)

The K-centric model for the relationship lnk(T).

# Arguments
- `x`: temperature `T` in K
- `p[1] = Tchar + Tst` in K
- `p[2] = θchar` in °C
- `p[3] = ΔCp/R`
"""
@. Kcentric(x, p) = (p[3] + p[1]/p[2])*(p[1]/x - 1) + p[3]*log(x/p[1])

"""
	coeff_of_determination(fit, y)

Calculate the coefficient of determination R² for LsqFit.jl result `fit` and measured data `y`.
"""
function coeff_of_determination(model, fit, x, y)
	SSres = sum((y .- model(x, fit.param)).^2)
	SStot = sum((y .- mean(y)).^2)
	R² = 1 - SSres/SStot
	return R²
end

#="""
	chi_square(fit)

Calculate chi-square χ² and the adjusted chi-square χ̄² for LsqFit.jl result `fit`.
"""
function chi_square(fit)
	χ² = sum(fit.resid.^2) #-> rss(fit) from LSqFit.jl
	χ̄² = sum(fit.resid.^2)/dof(fit) #-> mse(fit) from LSqFit.jl
	return χ², χ̄²
end=#

"""
	T_column_names_to_Float(data::DataFrame)

Translates the column names of the dataframe `data` containing the values of isothermal temperature to Float64. For the case of identical temperatures, a number is appended, separated by an underscore `_`. If this is the case the string is splited at the `_` and only the first part is used.
"""
function T_column_names_to_Float(data::DataFrame)
	Ts = names(data)[findall(occursin.("Cat", names(data)).==false)[2:end]]
	T = Array{Float64}(undef, length(Ts))
	for i=1:length(Ts)
		if occursin("_", Ts[i])
			T[i] = parse(Float64,split(Ts[i], "_")[1])
		else
			T[i] = parse(Float64, Ts[i])
		end
	end
	return T
end



"""
	plot_lnk_fit(fit, i, j)

Plot the `lnk`-values over `T` of the selected dataset `i` of the selected substance `j`. Also the fit solution for the ABC-model and the K-centric-model are shown over the extended temperature range from 0°C to 400°C.
"""
function plot_lnk_fit(fit, i, j)
	T = 0.0:1.0:800.0
	plnk = scatter(fit[i].T[j], fit[i].lnk[j], label="data", title=fit[i].Name[j], xlabel="T in °C", ylabel="lnk")
	#if !isempty(fit[i].ex_i_ABC[j])
	#	scatter!(plnk, first.(fit[i].ex_i_ABC[j]), last.(fit[i].ex_i_ABC[j]), label="excluded ABC", m=:diamond, mcolor=:grey, msize=2)
	#end
	if fit[i].AcceptCheck[j] == true
		scatter!(plnk, first.(fit[i].ex_i_Kcentric[j]), last.(fit[i].ex_i_Kcentric[j]), label="excluded outliers", m=:cross, mcolor=:orange, msize=2)
	else 
		scatter!(plnk, first.(fit[i].ex_i_Kcentric[j]), last.(fit[i].ex_i_Kcentric[j]), label="included outliers", m=:cross, mcolor=:orange, msize=2)
	end
	#plot!(plnk, T, ABC(T.+Tst, fit[i].fitABC[j].param), label=string("ABC, R²=", round(fit[i].R²_ABC[j]; digits=4)))
	plot!(plnk, T, Kcentric(T.+Tst, fit[i].fitKcentric[j].param), label=string("Kcentric, R²=", round(fit[i].R²_Kcentric[j]; digits=4)))
	return plnk
end



"""
	plot_res_lnk_fit(fit, i, j)

Plot the absolute residuals (not the weighted) of `lnk`-values over `T` of the selected dataset `i` of the selected substance `j` to the fitted models.
"""
function plot_res_lnk_fit(fit, i, j)
	X = fit[i].T[j]
	Y = fit[i].lnk[j]

	Kcentric_ = fit[i].fitKcentric[j]
	
	XOutKcentric = first.(fit[i].ex_i_Kcentric[j])
	YOutKcentric = last.(fit[i].ex_i_Kcentric[j])
	
	YInKcentric = filter(x -> x ∉ last.(fit[i].ex_i_Kcentric[j]), Y)
	XInKcentric = Array{Float64}(undef, length(YInKcentric))
	for ii=1:length(YInKcentric)
		XInKcentric[ii] = X[findfirst(YInKcentric[ii].==Y)]
	end

	resOutKcentric = RetentionData.Kcentric(XOutKcentric .+ 273.15, Kcentric_.param) .- YOutKcentric
	
	if fit[i].AcceptCheck[j] == true
		pRes = scatter(XInKcentric, Kcentric_.resid, label=string("Kcentric, R²=", round(fit[i].R²_Kcentric[j]; digits=4)), xlabel="Temperature in °C", ylabel="residual")
		scatter!(pRes, XOutKcentric, resOutKcentric, label="outliers", c=:orange, m=:rect)
	else
		pRes = scatter(X, Kcentric_.resid, label=string("Kcentric, R²=", round(fit[i].R²_Kcentric[j]; digits=4)), xlabel="Temperature in °C", ylabel="residual")
		scatter!(pRes, XOutKcentric, resOutKcentric, label="potential outliers", c=:orange, m=:rect)
	end
	
	return pRes
end

"""
	fit(model, T, lnk, lb, ub; weighted=false, threshold=NaN)

Old version. Fit the `model`-function to `lnk` over `T` data, with parameter lower boundaries `lb` and upper boundaries `ub`. 
Data points with a residuum above `threshold` are excluded and the fit is recalculated, until all residua are below the threshold or only three data points are left (unless `threshold = NaN`, which is default). 
If `weighted = true` the residuals of an unwheighted fit (OLS) are used as weights for a second fit (``w_i = 1/res_i^2``)
"""
function fit(model, T, lnk, lb, ub; weighted=false, threshold=NaN)

	flagged_index = Int[]
	ok_index = findall(ismissing.(lnk).==false) # indices of `lnk` which are NOT missing
	
	if model == ABC
		# seems to be reliable for all measured data
		p0 = [-100.0, 10000.0, 10.0]
	elseif model == Kcentric
		# in case of weighted fit, a rough estimator for Tchar is needed
		# otherwise the fit can be far off
		TT = T[ok_index]
		Tchar0 = TT[findfirst(minimum(abs.(lnk[ok_index])).==abs.(lnk[ok_index]))] # estimator for Tchar -> Temperature with the smalles lnk-value
		p0 = [Tchar0+Tst, 30.0, 10.0]
	end

	if weighted == false
		fit = curve_fit(model, T[ok_index].+Tst, lnk[ok_index], p0, lower=lb, upper=ub)

	elseif weighted == true
		fit_OLS = curve_fit(model, T[ok_index].+Tst, lnk[ok_index], p0, lower=lb, upper=ub)
		# estimate weights from the residuals of the ordinary least squared
		w = 1.0./fit_OLS.resid.^2
		fit = curve_fit(model, T[ok_index].+Tst, lnk[ok_index], w, p0, lower=lb, upper=ub)
	end

	if isnan(threshold) == false
		if weighted == false
			res = fit.resid
		else
			res = lnk[ok_index] .- model(T[ok_index].+Tst, fit.param)
		end
		# check the residuen
		while maximum(abs.(res)) > threshold
			if length(ok_index) <= 3
				break
			end
			imax = findfirst(abs.(fit.resid).==maximum(abs.(fit.resid))) # exclude this data point
			push!(flagged_index, ok_index[imax])
			ok_index = ok_index[findall(ok_index.!=ok_index[imax])]
			if weighted == false
				fit = curve_fit(model, T[ok_index].+Tst, lnk[ok_index], p0, lower=lb, upper=ub)
				res = fit.resid
			elseif weighted == true
				fit_OLS = curve_fit(model, T[ok_index].+Tst, lnk[ok_index], p0, lower=lb, upper=ub)
				# estimate weights from the residuals of the ordinary least squared
				w = 1.0./fit_OLS.resid.^2
				fit = curve_fit(model, T[ok_index].+Tst, lnk[ok_index], w, p0, lower=lb, upper=ub)
				res = lnk[ok_index] .- model(T[ok_index].+Tst, fit.param)
			end
		end
	end
	return fit, ok_index, flagged_index
end

"""
	fit(model, T, lnk; check=true, ftrusted=0.7)

New version. Fit the `model`-function to `lnk` over `T` data. If `check` is `true` than a robust fit (RAFF.jl, parameter `ftrusted`) is executed and outliers are excluded from
the fit with LsqFit.jl. If `check` is `false` than the outliers found with RAFF.jl are still used for the fit with LsqFit.jl.

# Output
* `fit` - the result from LsqFit.jl
* `robust` - the result from RAFF.jl
* `outlier` - the outliers found with RAFF.jl as a tuple of `(T, lnk)`
"""
function fit(model, T, lnk; check=true, ftrusted=0.7)
	# test if at least 3 points are available
	if length(T) < 3 || length(lnk) < 3
		return throw(ErrorException("not enough points for the fit available. At least 3 data points are needed."))
	else
		# Kcentric model is prefered, using the ABC model the robust fit some times tends toward a nearly linear fit 
		raffmodel(x, p) = if model == RetentionData.ABC
			p[1] + p[2]/x[1] + p[3]*log(x[1])
		elseif model == RetentionData.Kcentric
			(p[3] + p[1]/p[2])*(p[1]/x[1] - 1) + p[3]*real(log(Complex(x[1]/p[1])))
		end
		if model == RetentionData.ABC
			p0 = [-100.0, 10000.0, 10.0]
		elseif model == RetentionData.Kcentric
			Tchar0 = T[findfirst(minimum(abs.(lnk)).==abs.(lnk))] # estimator for Tchar -> Temperature with the smalles lnk-value
			p0 = [Tchar0+273.15, 30.0, 10.0]
		end
		# first robust fitting with RAFF.jl
		robust = raff(raffmodel, [collect(skipmissing(T)).+273.15 collect(skipmissing(lnk))], 3; initguess=p0, ftrusted=ftrusted)
		# second least-square-fit with LsqFit.jl without the outliers

			
		if check==false
			# use all data for lsq-fit
			fit =curve_fit(model, T .+273.15, lnk, p0)
		else	
			# use only non-outlier data for lsq-fit
			fit = curve_fit(model, T[Not(robust.outliers)].+273.15, lnk[Not(robust.outliers)], p0)
		end	
		
		# residual of outliers to the lsq-result:
		#res_outliers = model(T[robust.outliers] .+ 273.15, fit.param) .- lnk[robust.outliers]
		# - if this residual is below a threshold (e.g. the highest residual of the used data), than this outlier is not a outlier anymore -> cleared outlier
		#cleared_outliers = robust.outliers[findall(abs.(res_outliers).<maximum(abs.(fit.resid)))] # perhaps use here a more sufisticated methode -> test if this value belongs to the same distribution as the other values (normal distribution)
		
		#Create a Tuple of outliers
		
		#if !isempty(cleared_outliers)
			# - re-run the lsq-fit now using the cleared outliers
			# index remaining outlier
		#	i_out = findall(!in(T[cleared_outliers]),T[robust.outliers])
			# fit
		#	lsq = curve_fit(model, T[Not(robust.outliers[])].+273.15, lnk[Not(robust.outliers[i_out])], fit.param)
		#	Tuple = Array{Any}(undef, size(robust.outliers[i_out])[1])
		#	for i=1:size(robust.outliers[i_out])[1]
		#		Tuple[i]= (T[robust.outliers[i_out][i]], lnk[robust.outliers[i_out][i]])
		#	end	
		#	return lsq, robust, Tuple
		#else
		outlier = Array{Any}(undef, size(robust.outliers)[1])
		for i=1:size(robust.outliers)[1]
			outlier[i] = (T[robust.outliers[i]],lnk[robust.outliers[i]])
		end	
		return fit, robust, outlier
	end
end	

"""
	AcceptTest(Dataset, Check; ftrusted=0.7)

Make the fit of lnk over T for a all solutes of a `Dataset` with the Kcentric-model. With the boolean variable `Check` a test for outliers, using a robust fit (RAFF.jl), is executed. 

# Output
The fit results and additional statistics are exported as a DataFrame. Categories, which are included in the measured lnk-data are appended to the DataFrame.
"""
function AcceptTest(Dataset, Check; ftrusted=0.7)
	#fitABC = Array{Any}(undef, length(Dataset[!,1]))
	fitKcentric = Array{Any}(undef, length(Dataset[!,1]))
	T = Array{Array{Float64}}(undef, length(Dataset[!,1]))
	lnk = Array{Array{Float64}}(undef, length(Dataset[!,1]))
	name = Array{String}(undef, length(Dataset[!,1]))
	#excludedABC_i = Array{Any}(undef, length(Dataset[!,1]))
	#RobustABC = Array{Any}(undef, length(Dataset[!,1]))
	excludedKcentric_i = Array{Any}(undef, length(Dataset[!,1]))
	RobustKcentric = Array{Any}(undef, length(Dataset[!,1]))
	#R²_ABC = Array{Float64}(undef, length(Dataset[!,1]))
	R²_Kcentric = Array{Float64}(undef, length(Dataset[!,1]))
	#χ²_ABC = Array{Float64}(undef, length(Dataset[!,1]))
	χ²_Kcentric = Array{Float64}(undef, length(Dataset[!,1]))
	#χ̄²_ABC = Array{Float64}(undef, length(Dataset[!,1]))
	χ̄²_Kcentric = Array{Float64}(undef, length(Dataset[!,1]))
	Checkbox=Array{Bool}(undef, length(Dataset[!,1]))
	for j=1:length(Dataset[!,1])

		T_ = RetentionData.T_column_names_to_Float(Dataset)
		Tindex = findall(occursin.("Cat", names(Dataset)).==false)[2:end]
		lnk_ = collect(Union{Missing,Float64}, Dataset[j, Tindex])

		T[j] = T_[findall(ismissing.(lnk_).==false)]
		lnk[j] = lnk_[findall(ismissing.(lnk_).==false)]
		
		#ii = findall(isa.(lnk[j], Float64)) # indices of `lnk` which are NOT missing
		name[j] = Dataset[!, 1][j]

		#fitABC[j], RobustABC[j], excludedABC_i[j] = fit(RetentionData.ABC, T[j], lnk[j], check=Check[j], ftrusted=ftrusted) #fit_outlier_test(m, xx, yy; ftrusted=0.7)

		fitKcentric[j], RobustKcentric[j], excludedKcentric_i[j] = fit(RetentionData.Kcentric, T[j], lnk[j], check=Check[j], ftrusted=ftrusted)
		
		#R²_ABC[j] = RetentionData.coeff_of_determination(RetentionData.ABC, fitABC[j], T[j][Not(RobustABC[j].outliers)].+273.15, lnk[j][Not(RobustABC[j].outliers)])
		R²_Kcentric[j] = RetentionData.coeff_of_determination(RetentionData.Kcentric, fitKcentric[j], T[j][Not(RobustKcentric[j].outliers)].+RetentionData.Tst, lnk[j][Not(RobustKcentric[j].outliers)])
		#χ²_ABC[j] = rss(fitABC[j])
		#χ̄²_ABC[j] = mse(fitABC[j])
		χ²_Kcentric[j] = rss(fitKcentric[j])
		χ̄²_Kcentric[j] = mse(fitKcentric[j])

		Checkbox[j]=Check[j]
	end
	#fits= DataFrame(Name=name, T=T, lnk=lnk, fitABC=fitABC, fitKcentric=fitKcentric, 
	#					RobustABC=RobustABC, RobustKcentric=RobustKcentric, ex_i_ABC=excludedABC_i, ex_i_Kcentric=excludedKcentric_i, 
	#					R²_ABC=R²_ABC, R²_Kcentric=R²_Kcentric,
	#					χ²_ABC=χ²_ABC, χ²_Kcentric=χ²_Kcentric,
	#					χ̄²_ABC=χ̄²_ABC, χ̄²_Kcentric=χ̄²_Kcentric,
	#					AcceptCheck= Checkbox)
	fits= DataFrame(Name=name,
						T=T,
						lnk=lnk,
						fitKcentric=fitKcentric, 
						RobustKcentric=RobustKcentric,
						ex_i_Kcentric=excludedKcentric_i, 
						R²_Kcentric=R²_Kcentric,
						χ²_Kcentric=χ²_Kcentric,
						χ̄²_Kcentric=χ̄²_Kcentric,
						AcceptCheck= Checkbox)
	# add columns with "Cat" in column name
	i_cat = findall(occursin.("Cat", names(Dataset)))
	for j=1:length(i_cat)
		fits[!, "Cat_$(j)"] = Dataset[!, i_cat[j]]
	end
return fits
end

"""
	fit_models(data::Array{DataFrame}, β0::Array{Float64})

New version. Fit the K-centric-model at the lnk(T) data of the `data`-array of dataframes, using LsqFit.jl 
"""
function fit_models(data::Array{DataFrame}, CheckBase; ftrusted=0.7)
	fits = Array{DataFrame}(undef, length(data))
	for i=1:length(data)
		fits[i]=AcceptTest(data[i], CheckBase[i], ftrusted=ftrusted)
	end
	return fits
end

"""	
	fit_models!(meta_data::DataFrame, CheckBase; ftrusted=0.7)

New version. Fit the K-centric-model at the lnk(T) data of the `data`-array of dataframes, using RAFF.jl and LsqFit.jl and add the result in a new column (`fit`) of `meta_data 
"""
function fit_models!(meta_data::DataFrame, CheckBase; ftrusted=0.7)
	fitting = fit_models(meta_data.data, CheckBase, ftrusted=ftrusted)
	meta_data[!, "fitting"] = fitting
	return meta_data
end

"""
	fit_models(data::Array{DataFrame}, β0::Array{Float64})

Old version. Fit the ABC-model and the K-centric-model at the lnk(T) data of the `data`-array of dataframes, using LsqFit.jl 
"""
function fit_models(data::Array{DataFrame}; weighted=false, threshold=NaN, lb_ABC=[-Inf, -Inf, -Inf], ub_ABC=[Inf, Inf, Inf], lb_Kcentric=[-Inf, -Inf, -Inf], ub_Kcentric=[Inf, Inf, Inf])

	fits = Array{DataFrame}(undef, length(data))
	for i=1:length(data)
		fitABC = Array{Any}(undef, length(data[i][!,1]))
		fitKcentric = Array{Any}(undef, length(data[i][!,1]))
		T = Array{Array{Float64}}(undef, length(data[i][!,1]))
		lnk = Array{Any}(undef, length(data[i][!,1]))
		name = Array{String}(undef, length(data[i][!,1]))
		excludedABC_i = Array{Array{Int,1}}(undef, length(data[i][!,1]))
		okABC_i = Array{Array{Int,1}}(undef, length(data[i][!,1]))
		excludedKcentric_i = Array{Array{Int,1}}(undef, length(data[i][!,1]))
		okKcentric_i = Array{Array{Int,1}}(undef, length(data[i][!,1]))
		R²_ABC = Array{Float64}(undef, length(data[i][!,1]))
		R²_Kcentric = Array{Float64}(undef, length(data[i][!,1]))
		χ²_ABC = Array{Float64}(undef, length(data[i][!,1]))
		χ²_Kcentric = Array{Float64}(undef, length(data[i][!,1]))
		χ̄²_ABC = Array{Float64}(undef, length(data[i][!,1]))
		χ̄²_Kcentric = Array{Float64}(undef, length(data[i][!,1]))
		for j=1:length(data[i][!,1])
			T[j] = T_column_names_to_Float(data[i])
			Tindex = findall(occursin.("Cat", names(data[i])).==false)[2:end]
			lnk[j] = collect(Union{Missing,Float64}, data[i][j, Tindex])
			#ii = findall(isa.(lnk[j], Float64)) # indices of `lnk` which are NOT missing
			name[j] = data[i][!, 1][j]

			fitABC[j], okABC_i[j], excludedABC_i[j] = fit(ABC, T[j], lnk[j], lb_ABC, ub_ABC; weighted=weighted, threshold=threshold)

			fitKcentric[j], okKcentric_i[j], excludedKcentric_i[j] = fit(Kcentric, T[j], lnk[j], lb_Kcentric, ub_Kcentric; weighted=weighted, threshold=threshold)

			R²_ABC[j] = coeff_of_determination(ABC, fitABC[j], T[j][okABC_i[j]].+Tst, lnk[j][okABC_i[j]])
			R²_Kcentric[j] = coeff_of_determination(Kcentric, fitKcentric[j], T[j][okKcentric_i[j]].+Tst, lnk[j][okKcentric_i[j]])
			χ²_ABC[j] = rss(fitABC[j])
			χ̄²_ABC[j] = mse(fitABC[j])
			χ²_Kcentric[j] = rss(fitKcentric[j])
			χ̄²_Kcentric[j] = mse(fitKcentric[j])
		end
		fits[i] = DataFrame(Name=name, T=T, lnk=lnk, fitABC=fitABC, fitKcentric=fitKcentric, 
							i_ABC=okABC_i, i_Kcentric=okKcentric_i, ex_i_ABC=excludedABC_i, ex_i_Kcentric=excludedKcentric_i, 
							R²_ABC=R²_ABC, R²_Kcentric=R²_Kcentric,
							χ²_ABC=χ²_ABC, χ²_Kcentric=χ²_Kcentric,
							χ̄²_ABC=χ̄²_ABC, χ̄²_Kcentric=χ̄²_Kcentric)
		# add columns with "Cat" in column name
		i_cat = findall(occursin.("Cat", names(data[i])))
		for j=1:length(i_cat)
			fits[i][!, "Cat_$(j)"] = data[i][!, i_cat[j]]
		end
	end
	return fits
end

"""
	fit_models!(meta_data::DataFrame; weighted=false, threshold=NaN, lb_ABC=[-Inf, 0.0, 0.0], ub_ABC=[0.0, Inf, 50.0], lb_Kcentric=[0.0, 0.0, 0.0], ub_Kcentric=[Inf, Inf, 500.0])

Old version. Fit the ABC-model and the K-centric-model at the lnk(T) data of the `data`-array of dataframes, using LsqFit.jl and add the result in a new column (`fit`) of `meta_data 
"""
function fit_models!(meta_data::DataFrame; weighted=false, threshold=NaN, lb_ABC=[-Inf, 0.0, 0.0], ub_ABC=[0.0, Inf, 50.0], lb_Kcentric=[0.0, 0.0, 0.0], ub_Kcentric=[Inf, Inf, 500.0])
	fitting = fit_models(meta_data.data; weighted=weighted, threshold=threshold, lb_ABC=lb_ABC, ub_ABC=ub_ABC, lb_Kcentric=lb_Kcentric, ub_Kcentric=ub_Kcentric)
	meta_data[!, "fitting"] = fitting
	return meta_data
end



"""
	extract_paramaters_from_fit(fit, β0)

Extract the parameters `A`, `B`, `C`, `Tchar`, `θchar` and `ΔCp` from the fits of lnk over T data with the `ABC`-model and the `Kcentric`-model.
"""
function extract_parameters_from_fit(fit, β0)
	Par = Array{DataFrame}(undef, length(fit))
	for i=1:length(fit)
		A = Array{Measurement{Float64}}(undef, length(fit[i].Name))
		B = Array{Measurement{Float64}}(undef, length(fit[i].Name))
		C = Array{Measurement{Float64}}(undef, length(fit[i].Name))
		Tchar = Array{Measurement{Float64}}(undef, length(fit[i].Name))
		θchar = Array{Measurement{Float64}}(undef, length(fit[i].Name))
		ΔCp = Array{Measurement{Float64}}(undef, length(fit[i].Name))
		ΔHref = Array{Measurement{Float64}}(undef, length(fit[i].Name))
		ΔSref = Array{Measurement{Float64}}(undef, length(fit[i].Name))
		ΔHchar = Array{Measurement{Float64}}(undef, length(fit[i].Name)) # modJL
		ΔSchar = Array{Measurement{Float64}}(undef, length(fit[i].Name)) # modJL
		beta0 = β0[i].*ones(length(fit[i].Name))
		Tref = T0.*ones(length(fit[i].Name))
		#n_ABC = Array{Int}(undef, length(fit[i].Name))
		n_Kcentric = Array{Int}(undef, length(fit[i].Name))
		#approx_equal = Array{Bool}(undef, length(fit[i].Name))
		#WLS = Array{Bool}(undef, length(fit[i].Name))
		for j=1:length(fit[i].Name)
			#A[j] = (fit[i].fitABC[j].param[1] ± stderror(fit[i].fitABC[j])[1]) + log(β0[i])
			#B[j] = fit[i].fitABC[j].param[2] ± stderror(fit[i].fitABC[j])[2]
			#C[j] = fit[i].fitABC[j].param[3] ± stderror(fit[i].fitABC[j])[3]
			Tchar_err = try
				stderror(fit[i].fitKcentric[j])[1]
			catch
				NaN
			end
			θchar_err = try
				stderror(fit[i].fitKcentric[j])[2]
			catch
				NaN
			end
			ΔCp_err = try
				stderror(fit[i].fitKcentric[j])[3]
			catch
				NaN
			end
			Tchar[j] = (fit[i].fitKcentric[j].param[1] ± Tchar_err) - Tst
			θchar[j] = fit[i].fitKcentric[j].param[2] ± θchar_err
			ΔCp[j] = (fit[i].fitKcentric[j].param[3] ± ΔCp_err) * R
			A[j], B[j], C[j] = RetentionData.Kcentric_to_ABC(Tchar[j], θchar[j], ΔCp[j], β0[i])

			TD = RetentionData.ABC_to_TD(A[j], B[j], C[j], T0)
			ΔHref[j] = TD[1]
			ΔSref[j] = TD[2]

			TD_ = RetentionData.ABC_to_TD(A[j], B[j], C[j], Tchar[j]) # modJL
			ΔHchar[j] = TD_[1] # modJL
			ΔSchar[j] = TD_[2] # modJL

			#n_ABC[j] = length(fit[i].fitABC[j].resid)
			n_Kcentric[j] = length(fit[i].fitKcentric[j].resid)
			#if round(fit[i].χ²_ABC[j]; sigdigits=5) == round(fit[i].χ²_Kcentric[j]; sigdigits=5)
			#	approx_equal[j] = true
			#else
			#	approx_equal[j] = false
			#end
			#if length(fit[i].fitABC[j].wt) == 0
			#	WLS[j] = false
			#else
			#	WLS[j] = true
			#end
		end
		#Par[i] = DataFrame(Name=fit[i].Name, A=A, B=B, C=C, Tchar=Tchar, thetachar=θchar, DeltaCp=ΔCp, DeltaHref=ΔHref, DeltaSref=ΔSref,
		#					beta0=beta0, Tref=Tref, 
		#					R²_ABC=fit[i].R²_ABC, R²_Kcentric=fit[i].R²_Kcentric,
		#					χ²_ABC=fit[i].χ²_ABC, χ²_Kcentric=fit[i].χ²_Kcentric,
		#					χ̄²_ABC=fit[i].χ̄²_ABC, χ̄²_Kcentric=fit[i].χ̄²_Kcentric,
		#					n_ABC=n_ABC, n_Kcentric=n_Kcentric,
		#					approx_equal=approx_equal, WLS=WLS)

		#Par[i] = DataFrame(Name=fit[i].Name, A=A, B=B, C=C, Tchar=Tchar, thetachar=θchar, DeltaCp=ΔCp, DeltaHref=ΔHref, DeltaSref=ΔSref,
		#					beta0=beta0, Tref=Tref, 
		#					R²_Kcentric=fit[i].R²_Kcentric,
		#					χ²_Kcentric=fit[i].χ²_Kcentric,
		#					χ̄²_Kcentric=fit[i].χ̄²_Kcentric,
		#					n_Kcentric=n_Kcentric)
		Par[i] = DataFrame(Name=fit[i].Name, A=A, B=B, C=C, Tchar=Tchar, thetachar=θchar, DeltaCp=ΔCp, DeltaHchar=ΔHchar, DeltaSchar=ΔSchar, DeltaHref=ΔHref, DeltaSref=ΔSref,
							Tref=Tref, 
							beta0=beta0, 
							R²_Kcentric=fit[i].R²_Kcentric,
							χ²_Kcentric=fit[i].χ²_Kcentric,
							χ̄²_Kcentric=fit[i].χ̄²_Kcentric,
							n_Kcentric=n_Kcentric)
		# add columns with "Cat" in column name
		i_cat = findall(occursin.("Cat", names(fit[i])))
		for j=1:length(i_cat)
			Par[i][!, "Cat_$(j)"] = fit[i][!, i_cat[j]]
		end
	end
	return Par
end	

function extract_parameters_from_fit!(meta_data)
	par = extract_parameters_from_fit(meta_data.fitting, meta_data.beta0)
	meta_data[!, "parameters"] = par
	return meta_data
end

# some functions for Categories
"""
	align_categories(newdata)

Aligns the entrys for categorys for the same substances (same CAS number).
"""
function align_categories(newdata)
	# find all columns with "Cat" in the name
	iCat = findall(occursin.("Cat", names(newdata)))
	# find identical CAS entrys
	CAS = replace(newdata.CAS, missing => nothing)
	uniqueCAS = unique(CAS)
	#CAS_f = filter(x->!ismissing(x), newdata.CAS)
	i_identicalCAS = Array{Array{Union{Missing,Int64},1}}(undef, length(uniqueCAS))
	union_catstrings = Array{Array{Union{Missing,Any},1}}(undef, length(uniqueCAS))
	for i=1:length(uniqueCAS)
		if !isnothing(uniqueCAS[i])
			i_identicalCAS[i] = findall(CAS.==uniqueCAS[i])
			union_catstrings[i] = unique(Matrix(newdata[i_identicalCAS[i],iCat]))
			filter!(x -> ismissing(x).==false, union_catstrings[i])
		else
			union_catstrings[i] = [missing]
		end
	end
	#i_identicalCAS
	# number of Cat columns needed
	ncat = Array{Int64}(undef, length(union_catstrings))
	for i=1:length(union_catstrings)
		ncat[i] = length(union_catstrings[i])
	end
	maxcat = maximum(ncat)
	# copy data, without old Cat columns
	newnewdata = select(newdata, Not(iCat))
	# add the new Cat Columns
	categories = Array{Union{Missing,String}}(missing, length(newnewdata.CAS), maxcat)
	for i=1:length(newnewdata.CAS)
		ii = findfirst(uniqueCAS.==CAS[i])
		for j=1:length(union_catstrings[ii])
			categories[i,j] = union_catstrings[ii][j]
		end
	end
	categories
	for i=1:maxcat
		newnewdata[!,"Cat_$(i)"] = categories[:,i]
	end
	return newnewdata
end

"""
	add_group_to_Cat!(newdata)

Add categories defined by the file `groups.csv` (group name and a list of CAS numbers)
"""
function add_group_to_Cat!(newdata)
	root = dirname(@__FILE__)
	project = dirname(root)
	groups = DataFrame(CSV.File(joinpath(project, "data", "groups.csv")))#DataFrame(CSV.File("/Users/janleppert/Documents/GitHub/RetentionData/data/groups.csv"))
	CAS = Array{Array{String,1}}(undef, length(groups.CAS))
	for i=1:length(groups.CAS)
		CAS[i] = split(groups.CAS[i],',')
	end
	groups[!,"CAS"]	= CAS

	iCat = findall(occursin.("Cat", names(newdata)))
	for i=1:length(newdata.CAS)
		for j=1:length(groups.CAS)
			if !ismissing(newdata.CAS[i]) && (newdata.CAS[i] in groups.CAS[j])
				if  ismissing(!(groups.Group[j] in newdata[i, iCat])) || !(groups.Group[j] in newdata[i, iCat])# group not allready in Cat
					# find the first Cat column with missing entry
					if isnothing(findfirst(ismissing.(collect(newdata[i,iCat]))))
						ii = iCat[end] + 4 - size(newdata)[2]
						test = Array{Union{Missing,String}}(missing, length(newdata.Name))
						test[i] = groups.Group[j]
						newdata[!,"Cat_$(ii)"] = test
					else
						ii = iCat[findfirst(ismissing.(collect(newdata[i,iCat])))]
						newdata[i,ii] = groups.Group[j]
					end
				end
			end
		end
	end
	return newdata
end

"""
	old_database_format(data)

Export the data into the old database format with the columns:
* Name
* CAS
* Cnumber
* Hnumber
* Onumber
* Nnumber
* Ringnumber
* Molmass
* Phase
* Tchar
* thetachar
* DeltaCp
* phi0
* Annotation
"""
function old_database_format(data) 
	CI = substance_identification(data)
	Cnumber = Array{Int}(undef, length(data.Name))
	Hnumber = Array{Int}(undef, length(data.Name))
	Onumber = Array{Int}(undef, length(data.Name))
	Nnumber = Array{Int}(undef, length(data.Name))
	for i=1:length(data.Name)
		element_numbers = formula_to_dict(CI.formula[i])
		Cnumber[i] = element_numbers["C"]
		Hnumber[i] = element_numbers["H"]
		if haskey(element_numbers, "O")
			Onumber[i] = element_numbers["O"]
		else
			Onumber[i] = 0
		end
		if haskey(element_numbers, "N")
			Nnumber[i] = element_numbers["N"]
		else
			Nnumber[i] = 0
		end
	end
	oldformat = DataFrame(Name=data.Name, 
							CAS=data.CAS,
							Cnumber=Cnumber,
							Hnumber=Hnumber,
							Onumber=Onumber,
							Nnumber=Nnumber,
							Ringnumber=ring_number.(CI.smiles),
							Molmass=CI.MW,
							Phase=data.Phase,
							Tchar=data.Tchar,
							thetachar=data.thetachar,
							DeltaCp=data.DeltaCp,
							phi0=1.0./(4.0.*data.beta0),
							Annotation=data.Source)
	return oldformat
end

"""
	new_database_format(data; ParSet="Kcentric")

Export the data into the new database format with the columns:
* Name
* CAS
* Phase
* Tchar resp. A
* thetachar resp. B
* DeltaCp resp. C
* phi0
* Source
* Cat ... several columns with categories 

With the parameters `ParSet="ABC"` the ABC-parameters are exported, with `ParSet="Kcentric"` (default) the K-centric parameters are exported.
"""
function new_database_format(data; ParSet="Kcentric", filter_flag=true)
	if ParSet=="ABC"
		newformat = DataFrame(Name=data.Name,
								CAS=data.CAS,
								Phase=data.Phase,
								A=data.A,
								err_A=data.err_A,
								B=data.B,
								err_B=data.err_B,
								C=data.C,
								err_C=data.err_C,
								phi0=1.0./(4.0.*data.beta0),
								N=data.N,
								R²=data.R²,
								χ²=data.χ²,
								χ̄²=data.χ̄²,
								Source=data.Source
								
								)
	elseif ParSet=="Kcentric"
		newformat = DataFrame(Name=data.Name,
								CAS=data.CAS,
								Phase=data.Phase,
								Tchar=data.Tchar,
								err_Tchar=data.err_Tchar,
								thetachar=data.thetachar,
								err_thetachar=data.err_thetachar,
								DeltaCp=data.DeltaCp,
								err_DeltaCp=data.err_DeltaCp,
								phi0=1.0./(4.0.*data.beta0),
								N=data.N,
								R²=data.R²,
								χ²=data.χ²,
								χ̄²=data.χ̄²,
								Source=data.Source
								)
	elseif ParSet=="GasChromatographySimulator"
		newformat = DataFrame(Name=data.Name,
								CAS=data.CAS,
								Phase=data.Phase,
								Tchar=data.Tchar,
								thetachar=data.thetachar,
								DeltaCp=data.DeltaCp,
								phi0=1.0./(4.0.*data.beta0),
								Source=data.Source
								)
	elseif ParSet=="TD"
		newformat = DataFrame(Name=data.Name,
								CAS=data.CAS,
								Phase=data.Phase,
								DeltaHref=data.DeltaHref,
								err_DeltaHref=data.err_DeltaHref,
								DeltaSref=data.DeltaSref,
								err_DeltaSref=data.err_DeltaSref,
								DeltaCp=data.DeltaCp,
								err_DeltaCp=data.err_DeltaCp,
								Tref=data.Tref,
								phi0=1.0./(4.0.*data.beta0),
								N=data.N,
								R²=data.R²,
								χ²=data.χ²,
								χ̄²=data.χ̄²,
								Source=data.Source
								
								)
	elseif ParSet=="TDchar"
		newformat = DataFrame(Name=data.Name,
								CAS=data.CAS,
								Phase=data.Phase,
								DeltaHchar=data.DeltaHchar,
								err_DeltaHchar=data.err_DeltaHchar,
								DeltaSchar=data.DeltaSchar,
								err_DeltaSchar=data.err_DeltaSchar,
								DeltaCp=data.DeltaCp,
								err_DeltaCp=data.err_DeltaCp,
								Tchar=data.Tchar,
								err_Tchar=data.err_Tchar,
								phi0=1.0./(4.0.*data.beta0),
								N=data.N,
								R²=data.R²,
								χ²=data.χ²,
								χ̄²=data.χ̄²,
								Source=data.Source
								
								)
	elseif ParSet=="all"
		newformat = DataFrame(Name=data.Name,
								CAS=data.CAS,
								Phase=data.Phase,
								A=data.A,
								err_A=data.err_A,
								B=data.B,
								err_B=data.err_B,
								C=data.C,
								err_C=data.err_C,
								Tchar=data.Tchar,
								err_Tchar=data.err_Tchar,
								thetachar=data.thetachar,
								err_thetachar=data.err_thetachar,
								DeltaCp=data.DeltaCp,
								err_DeltaCp=data.err_DeltaCp,
								DeltaHchar=data.DeltaHchar,
								err_DeltaHchar=data.err_DeltaHchar,
								DeltaSchar=data.DeltaSchar,
								err_DeltaSchar=data.err_DeltaSchar,
								DeltaHref=data.DeltaHref,
								err_DeltaHref=data.err_DeltaHref,
								DeltaSref=data.DeltaSref,
								err_DeltaSref=data.err_DeltaSref,
								Tref=data.Tref,
								phi0=1.0./(4.0.*data.beta0),
								N=data.N,
								R²=data.R²,
								χ²=data.χ²,
								χ̄²=data.χ̄²,
								Source=data.Source
								
								)
	end
	if filter_flag == false
		newformat[!, "flag"] = data.flag
	end
	# add columns with "Cat" in column name
	i_cat = findall(occursin.("Cat", names(data)))
	for j=1:length(i_cat)
		newformat[!, "Cat_$(j)"] = data[!, i_cat[j]]
	end
	return newformat
end

function database(db_path; filter_CAS=true, filter_flag=true, db_format="all")
	#filter_CAS = true
	#filter_flag = true
	#db_format = "Kcentric" # "ABC", "TD", "Kcentric", "all", "old_format"
	data = RetentionData.load_allparameter_data(db_path)
	alldata = unique(RetentionData.dataframe_of_all(data))
	# add flags to alldata
	alldata[!, "flag"] = RetentionData.flag(alldata)
	#fl, nfl = RetentionData.flagged_data(alldata)

	# add CAS number
	CI = RetentionData.substance_identification(alldata)
	alldata[!, "CAS"] = CI.CAS

	# Filter
	if filter_CAS == true 
		alldata = filter!([:CAS] => x -> ismissing(x)==false, alldata)
	end
	if filter_flag == true
		alldata = filter!([:flag] => y -> isempty(y), alldata)
	end
	# add categories
	##if filter_CAS == true
	RetentionData.add_group_to_Cat!(alldata)
		alldata = RetentionData.align_categories(alldata)
		
	##else
	##	alldata_woCAS = filter([:CAS] => x -> ismissing(x)==true, alldata)
	##	alldata_wCAS = filter([:CAS] => x -> ismissing(x)==false, alldata)
	##	alldata_wCAS = RetentionData.align_categories(alldata_wCAS)
	##	RetentionData.add_group_to_Cat!(alldata_wCAS)
		#
	##	alldata = outerjoin(alldata_wCAS, alldata_woCAS, on = intersect(names(alldata_wCAS), names(alldata_woCAS)), matchmissing=:equal)
	##end
	
	# format
	if db_format == "old_format"
		db = RetentionData.old_database_format(alldata)
	else
		db = RetentionData.new_database_format(alldata; ParSet=db_format, filter_flag=filter_flag)
		RetentionData.add_group_to_Cat!(db)
		db = RetentionData.align_categories(db)
	end
	
	return db, alldata
end

function filter_Cat(newdata, cat)
	iCat = findall(occursin.("Cat", names(newdata)))
	i_true = Int[]
	for i=1:length(newdata.CAS)
		for j=1:length(iCat)
			if ismissing(newdata[!, iCat[j]][i]) == false
				if cat == newdata[!, iCat[j]][i]
					push!(i_true, i)
				end
			end
		end
	end
	filtered_data = newdata[i_true,:]
	return filtered_data
end

function filter_Cat(newdata, cat::Array{String,1})
	f_data = DataFrame()
	for i=1:length(cat)
		append!(f_data, filter_Cat(newdata, cat[i]))
	end
	return unique(f_data)
end

end # module