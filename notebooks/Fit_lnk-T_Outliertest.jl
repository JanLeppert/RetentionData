### A Pluto.jl notebook ###
# v0.19.14

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ 0b608842-5672-44cc-bd70-c168c537667e
begin
	root = dirname(@__FILE__)
	project = dirname(root)
	db_path = joinpath(project, "Databases")
	
	using CSV, DataFrames, LambertW, Plots, LsqFit, Statistics, ChemicalIdentifiers, Measurements, RAFF
	include(joinpath(project, "src", "RetentionData.jl"))
	using PlutoUI
	TableOfContents()
end

# ╔═╡ 6f0ac0bc-9a3f-11ec-0866-9f56a0d489dd
md"""
# Fit lnk(T) data
Fit the ABC-model and the K-centric model to the lnk(T) data loaded from the folder `db_path` (and its subfolders). Test for Outliers. 
"""

# ╔═╡ c037a761-f192-4a3b-a617-b6024ac6cd61
begin
	data = RetentionData.load_lnkT_data(db_path)
	#RetentionData.fit_models!(data; weighted=false, threshold=NaN, lb_ABC=[-Inf, -Inf, -Inf], ub_ABC=[Inf, Inf, Inf], lb_Kcentric=[-Inf, -Inf, -Inf], ub_Kcentric=[Inf, Inf, Inf])
end

# ╔═╡ 7c800ec4-7194-4cb0-87c8-b3b196deeb16
function fit_outlier_test(model, T, lnk; ftrusted=0.7)
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
	fit = curve_fit(model, T[Not(robust.outliers)].+273.15, lnk[Not(robust.outliers)], p0)
	# residual of outliers to the lsq-result:
	res_outliers = model(T[robust.outliers] .+ 273.15, fit.param) .- lnk[robust.outliers]
	# - if this residual is below a threshold (e.g. the highest residual of the used data), than this outlier is not a outlier anymore -> cleared outlier
	cleared_outliers = robust.outliers[findall(abs.(res_outliers).<maximum(abs.(fit.resid)))] # perhaps use here a more sufisticated methode -> test if this value belongs to the same distribution as the other values (normal distribution)
	if !isempty(cleared_outliers)
		# - re-run the lsq-fit now using the cleared outliers 
		lsq = curve_fit(model, T[Not(robust.outliers[findall(!in(T[cleared_outliers]),T[robust.outliers])])].+273.15, lnk[Not(robust.outliers[findall(!in(T[cleared_outliers]),T[robust.outliers])])], fit.param)
		return fit, robust, res_outliers, cleared_outliers, lsq
	else
		return fit, robust, res_outliers
	end
end

# ╔═╡ 435c5fca-0765-4d2c-b13d-1a67d83cc045
function OutlierCheck(data, select_dataset)	
	
	defaultdata=
	try CSV.File(string("C:\\Users\\Brehmer\\Documents\\GitHub\\RetentionData\\OutlierCheck\\","Check_",data.filename[select_dataset])).OutlierTest
	catch 
	end
	return try 
		PlutoUI.combine() do Child
		
		inputs = [
			md""" $(name): $(
				Child(name, CheckBox(default=defaultdata[findfirst(name.==data.data[select_dataset][!,1])]))
			)"""
			
			for name in data.data[select_dataset][!,1]
		]
		
md""" ## Results of Outlier Test

Dataset: "$(data.filename[select_dataset])"

except outliers and delete from fit?

$(inputs)



"""
		end

	catch 
		PlutoUI.combine() do Child
		
		inputs = [
			md""" $(name): $(
				Child(name, CheckBox(default=true))
			)"""
			
			for name in data.data[select_dataset][!,1]
		]
		
md""" ## Results of Outlier Test

Dataset: "$(data.filename[select_dataset])"

Confirm which Outliers should except

$(inputs)



"""
		end			
	end			
end

# ╔═╡ ae6986cd-33f3-48b1-9f8b-71535670bf27
md"""
## Plot lnk(T) and fit
Select data set: $(@bind select_dataset Slider(1:length(data.filename); show_value=true))
"""

# ╔═╡ 3bac9f60-8749-425b-8e87-ba1d7442ca93
md"""
Select substance: $(@bind select_substance Slider(1:length(data.data[select_dataset][!,1]); show_value=true))
"""

# ╔═╡ b8cb55b5-c40d-4f9b-96fe-580c41cbf3d6
data.filename[select_dataset], data.fitting[select_dataset].Name[select_substance]

# ╔═╡ 67d3b9dc-ae20-4ef8-982c-6be10c96fb5c
begin 
m = RetentionData.Kcentric
X = data.fitting[select_dataset].T[select_substance]
Y = data.fitting[select_dataset].lnk[select_substance]
	
	FIT = data.fitting[select_dataset].fitKcentric[select_substance]
	Robust=data.fitting[select_dataset].i_Kcentric[select_substance]
	collectOutliers= Array{Any}(undef, size(data.fitting[select_dataset].ex_i_Kcentric[select_substance])[1], 2)
	for i=1:size(data.fitting[select_dataset].ex_i_Kcentric[select_substance])[1]
		for j=1:2
			collectOutliers[i,j]=data.fitting[select_dataset].ex_i_Kcentric[select_substance][i][j] 
		end	
	end	

	resOut=m(X[Robust.outliers] .+ 273.15, FIT.param) .- Y[Robust.outliers]
	
	XX = 0.0:1.0:800.0	
	fitP=scatter(X,Y, xlabel="Temperature in °C", ylabel="ln(k)", label="data")
	plot!(XX, m(XX.+273.15, FIT.param), label="lsq")
	scatter!(collectOutliers[:,1], collectOutliers[:,2] , m=:diamond, markersize=5, c=:red, label="outliers")
	plot!(XX, m(XX.+273.15, Robust.solution), label="robust")
	
	pRes = scatter(X[Not(Robust.outliers)], FIT.resid, label="used data", xlabel="Temperature in °C", ylabel="residual", c=5)
	scatter!(pRes, X[Robust.outliers], resOut, label="outliers", c=:red)
	#if length(fit_test) == 5
	#	scatter!(pfit, X[fit_test[4]], yy[fit_test[4]], m=:rect, markersize=2, c=:green, label="cleared outliers")
	#	plot!(pfit, XX, m(XX.+273.15, fit_test[5].param), label="lsq cleared outliers")
	#	scatter!(pres, X[Not(fit_test[2].outliers[findall(!in(X[fit_test[4]]),X[fit_test[2].outliers])])], fit_test[5].resid, label="included cleared outliers", c=:green)
	#end
	plot(fitP, pRes, size=(700,400))
end

# ╔═╡ 3b0c2125-ece5-41d6-92d3-f6cc3e4cfacc
md"""plot without outliers:"""

# ╔═╡ 0a7a4cbc-5d25-44b9-91d1-67808df1626b
begin
	#Plot without Outliers
	#m = RetentionData.Kcentric
	xx = data.fitting[select_dataset].T[select_substance][findall(ismissing.(data.fitting[select_dataset].lnk[select_substance]).==false)]
	yy = data.fitting[select_dataset].lnk[select_substance][findall(ismissing.(data.fitting[select_dataset].lnk[select_substance]).==false)]
	xxx = 0.0:1.0:800.0	

	Outliers=Robust
	
	pFit = scatter(xx[Not(Outliers.outliers)],yy[Not(Outliers.outliers)], xlabel="Temperature in °C", ylabel="ln(k)", label="data")
	
	plot!(pFit, xxx, m(xxx.+273.15, Outliers.solution), label="robust")
	plot!(xxx, m(xxx.+273.15, FIT.param), label="lsq")

	pRes_ = scatter(xx[Not(Outliers.outliers)], FIT.resid, label="used data", xlabel="Temperature in °C", ylabel="residual", c=5)
	#scatter!(pRes_, xx[Outliers.outliers],	Outliers[3], label="outliers", c=:red)
	#if length(Outliers) == 5
	#	scatter!(pfit_, xx[fit_test_[4]], yy[Outliers[4]], m=:rect, markersize=2, c=:green, label="cleared outliers")
	#	plot!(pFit, xxx, m(xxx.+273.15,	Outliers[5].param), label="lsq cleared outliers")
		#scatter!(pRes_, xx[Not(	Outliers[2].outliers[findall(!in(xx[	Outliers[4]]),xx[Outliers[2].outliers])])], Outliers[5].resid, label="included cleared outliers", c=:green)
	#end
	
	plot(pFit, pRes_, size=(700,400))
end

# ╔═╡ 2d8d554b-adf3-4794-8079-5f6848dbc34a
#=begin
	m = RetentionData.Kcentric
	xx = data.fitting[select_dataset].T[select_substance][findall(ismissing.(data.fitting[select_dataset].lnk[select_substance]).==false)]
	yy = data.fitting[select_dataset].lnk[select_substance][findall(ismissing.(data.fitting[select_dataset].lnk[select_substance]).==false)]
	fit_test = fit_outlier_test(m, xx, yy; ftrusted=0.7)#(0.8, 1.0))
	xxx = 0.0:1.0:800.0	
	pfit = scatter(xx,yy, xlabel="Temperature in °C", ylabel="ln(k)", label="data")
	plot!(pfit, xxx, m(xxx.+273.15, fit_test[2].solution), label="robust")
	scatter!(pfit, xx[fit_test[2].outliers], yy[fit_test[2].outliers], m=:diamond, markersize=5, c=:red, label="outliers")
	plot!(pfit, xxx, m(xxx.+273.15, fit_test[1].param), label="lsq")
	pres = scatter(xx[Not(fit_test[2].outliers)], fit_test[1].resid, label="used data", xlabel="Temperature in °C", ylabel="residual", c=5)
	scatter!(pres, xx[fit_test[2].outliers], fit_test[3], label="outliers", c=:red)
	if length(fit_test) == 5
		scatter!(pfit, xx[fit_test[4]], yy[fit_test[4]], m=:rect, markersize=2, c=:green, label="cleared outliers")
		plot!(pfit, xxx, m(xxx.+273.15, fit_test[5].param), label="lsq cleared outliers")
		scatter!(pres, xx[Not(fit_test[2].outliers[findall(!in(xx[fit_test[4]]),xx[fit_test[2].outliers])])], fit_test[5].resid, label="included cleared outliers", c=:green)
	end
	
	plot(pfit, pres, size=(700,400))
end=#

# ╔═╡ 49a1e6d9-b939-4795-8c7f-61e92dc09ee8
@bind Check OutlierCheck(data, select_dataset)

# ╔═╡ bebf0dbc-96de-4e16-90ae-206930a106ee
md"""## Save Data """

# ╔═╡ 64968bac-4878-4564-a16c-06722f215a9b
#resOut=m(X[Robust.outliers] .+ 273.15, FIT.param) .- Y[Robust.outliers]

# ╔═╡ ae5a44de-e350-4340-aa1f-49afe8c51bc5
#=begin
m = RetentionData.Kcentric
	#xx = data.fitting[select_dataset].T[select_substance][findall(ismissing.(data.fitting[select_dataset].lnk[select_substance]).==false)]
	#yy = data.fitting[select_dataset].lnk[select_substance][findall(ismissing.(data.fitting[select_dataset].lnk[select_substance]).==false)]
	fit_test_ = fit_outlier_test(m, xx, yy; ftrusted=(0.8, 1.0))
	#xxx = 0.0:1.0:800.0	
	pfit_ = scatter(xx,yy, xlabel="Temperature in °C", ylabel="ln(k)", label="data")
	plot!(pfit_, xxx, m(xxx.+273.15, fit_test_[2].solution), label="robust")
	scatter!(pfit_, xx[fit_test_[2].outliers], yy[fit_test_[2].outliers], m=:diamond, markersize=5, c=:red, label="outliers")
	plot!(pfit_, xxx, m(xxx.+273.15, fit_test_[1].param), label="lsq")
	pres_ = scatter(xx[Not(fit_test_[2].outliers)], fit_test_[1].resid, label="used data", xlabel="Temperature in °C", ylabel="residual", c=5)
	scatter!(pres_, xx[fit_test_[2].outliers], fit_test_[3], label="outliers", c=:red)
	if length(fit_test_) == 5
		scatter!(pfit_, xx[fit_test_[4]], yy[fit_test_[4]], m=:rect, markersize=2, c=:green, label="cleared outliers")
		plot!(pfit_, xxx, m(xxx.+273.15, fit_test_[5].param), label="lsq cleared outliers")
		scatter!(pres_, xx[Not(fit_test_[2].outliers[findall(!in(xx[fit_test_[4]]),xx[fit_test_[2].outliers])])], fit_test_[5].resid, label="included cleared outliers", c=:green)
	end
	
	plot(pfit_, pres_, size=(700,400))
end=#

# ╔═╡ c6d787a2-4aaa-4155-bae4-4235e8fc7ea1
# include the R2 value of the lsq-fits
# use the solution where R2 is better?
# also add to both plots (lnk(T) and res(T)) the lsq-fit for all points, if outliers are detected

# ╔═╡ fad7761b-84b8-4287-a08a-2ace85b1081e
# put this function (as option) in the fit_models() function

# ╔═╡ cd5d0b6c-6e76-4293-80a0-b07ea94a05d8
begin
	plnk = RetentionData.plot_lnk_fit(data.fitting, select_dataset, select_substance)
	preslnk = RetentionData.plot_res_lnk_fit(data.fitting, select_dataset, select_substance)
	#pl = plot(plnk, preslnk)
	md"""
	$(embed_display(pl))
	### Observation
	For n=3 the results of ABC-model and K-centric model are different (but similar). For n>3 the results of both models are identical.
	"""
end

# ╔═╡ 2d7ed692-9524-428c-92cf-d4ecabe8278e
test = ["name", "60", "70", "Cat", "Cat_b"]

# ╔═╡ faa843f7-ef50-47ab-a5a4-9d32265b7e5a
test[findall(occursin.("Cat", test).==false)[2:end]]

# ╔═╡ dbf47c68-709f-45b5-9ae1-b75fe2e76c5f
Tindex = findall(occursin.("Cat", test).==false)[2:end]

# ╔═╡ 2fd4d728-9068-415c-b006-26f93dddce28
md"""
## Compare parameters
"""

# ╔═╡ f57fc4ec-9522-401f-91de-9495ca50bbb9
#RetentionData.extract_parameters_from_fit!(data);

# ╔═╡ a65c584d-a669-4dfe-8deb-03ce2fd3a0c0
data.parameters[select_dataset]

# ╔═╡ 8a0d3816-b114-42e3-8bef-cda7b63af509
begin
	plotly()
	pABC = scatter(Measurements.value.(data.parameters[1].A), Measurements.value.(data.parameters[1].B), Measurements.value.(data.parameters[1].C), label=1, xlabel="A", ylabel="B", zlabel="C")
	for i=2:length(data.parameters)
		scatter!(pABC, Measurements.value.(data.parameters[i].A), Measurements.value.(data.parameters[i].B), Measurements.value.(data.parameters[i].C), label=i)
	end
	pABC
end

# ╔═╡ baba96bf-b0fb-43a3-8f58-954343b918fd
begin
	plotly()
	pKcentric = scatter(Measurements.value.(data.parameters[1].Tchar), Measurements.value.(data.parameters[1].thetachar), Measurements.value.(data.parameters[1].DeltaCp), label=1, xlabel="Tchar in °C", ylabel="θchar in °C", zlabel="ΔCp in J mol⁻¹ K⁻¹")
	for i=2:length(data.parameters)
		scatter!(pKcentric, Measurements.value.(data.parameters[i].Tchar), Measurements.value.(data.parameters[i].thetachar), Measurements.value.(data.parameters[i].DeltaCp), label=i)
	end
	pKcentric
end

# ╔═╡ 4a2c19cb-0321-4d64-91a5-51127f31ce9d
begin
	plotly()
	pKcentric_ = scatter(Measurements.value.(data.parameters[1].Tchar), Measurements.value.(data.parameters[1].thetachar), Measurements.value.(data.parameters[1].DeltaCp), label=1, xlabel="Tchar in °C", ylabel="θchar in °C", zlabel="ΔCp in J mol⁻¹ K⁻¹")
	for i=2:length(data.parameters)
		if i!=3
			scatter!(pKcentric_, Measurements.value.(data.parameters[i].Tchar), Measurements.value.(data.parameters[i].thetachar), Measurements.value.(data.parameters[i].DeltaCp), label=i)
		end
	end
	pKcentric_
end

# ╔═╡ 4dd4f07a-4654-4fd5-99f1-0fab845a545d
begin
	plotly()
	pEntalpie = scatter(Measurements.value.(data.parameters[1].DeltaHref), Measurements.value.(data.parameters[1].DeltaSref), Measurements.value.(data.parameters[1].DeltaCp), label=1, xlabel="ΔHref in ", ylabel="ΔSref in", zlabel="ΔCp in J mol⁻¹ K⁻¹")
	for i=2:length(data.parameters)
		if i!=3
			scatter!(pEntalpie, Measurements.value.(data.parameters[i].DeltaHref), Measurements.value.(data.parameters[i].DeltaSref), Measurements.value.(data.parameters[i].DeltaCp), label=i)
		end
	end
	pEntalpie
end

# ╔═╡ 8eb557fa-8e94-49fd-8fc5-17f8d42943c6
begin
	p_R2_ABC = scatter(data.parameters[1].R²_ABC, title="R², ABC-model", ylabel="R²", label=1)
	for i=2:length(data.parameters)
		scatter!(p_R2_ABC, data.parameters[i].R²_ABC, label=i)
	end

	p_R2_Kcentric = scatter(data.parameters[1].R²_Kcentric, title="R², Kcentric-model", ylabel="R²", label=1)
	for i=2:length(data.parameters)
		scatter!(p_R2_Kcentric, data.parameters[i].R²_Kcentric, label=i)
	end
	
	p_χ2_ABC = scatter(data.parameters[1].χ²_ABC, title="χ², ABC-model", ylabel="χ²", label=1)
	for i=2:length(data.parameters)
		scatter!(p_χ2_ABC, data.parameters[i].χ²_ABC, label=i)
	end
	
	p_χ2_Kcentric = scatter(data.parameters[1].χ²_Kcentric, title="χ², Kcentric-model", ylabel="χ²", label=1)
	for i=2:length(data.parameters)
		scatter!(p_χ2_Kcentric, data.parameters[i].χ²_Kcentric, label=i)
	end
	plot(p_R2_ABC, p_R2_Kcentric, p_χ2_ABC, p_χ2_Kcentric)
end

# ╔═╡ 448c3252-4e1e-4a9a-a8da-a23ab0959dee
md""" # Fit functions """

# ╔═╡ fcb24959-64f6-423e-9e9e-e6d2e3c25f26
#=begin function fit_(model, T, lnk; weighted=false, threshold=NaN)

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

		fit = curve_fit(model, T[ok_index].+Tst, lnk[ok_index], p0)

	return fit, ok_index, flagged_index
end
	
"""
	fit_models(data::Array{DataFrame}, β0::Array{Float64})

Fit the ABC-model and the K-centric-model at the lnk(T) data of the `data`-array of dataframes, using LsqFit.jl 
"""
function fit_models_old(data::Array{DataFrame}; ftrusted=0.7)

	fits = Array{DataFrame}(undef, length(data))
	for i=1:length(data)
		fitABC = Array{Any}(undef, length(data[i][!,1]))
		fitKcentric = Array{Any}(undef, length(data[i][!,1]))
		T = Array{Array{Float64}}(undef, length(data[i][!,1]))
		lnk = Array{Array{Float64}}(undef, length(data[i][!,1]))
		name = Array{String}(undef, length(data[i][!,1]))
		excludedABC_i = Array{Any}(undef, length(data[i][!,1]))
		okABC_i = Array{Any}(undef, length(data[i][!,1]))
		excludedKcentric_i = Array{Any}(undef, length(data[i][!,1]))
		okKcentric_i = Array{Any}(undef, length(data[i][!,1]))
		R²_ABC = Array{Float64}(undef, length(data[i][!,1]))
		R²_Kcentric = Array{Float64}(undef, length(data[i][!,1]))
		χ²_ABC = Array{Float64}(undef, length(data[i][!,1]))
		χ²_Kcentric = Array{Float64}(undef, length(data[i][!,1]))
		χ̄²_ABC = Array{Float64}(undef, length(data[i][!,1]))
		χ̄²_Kcentric = Array{Float64}(undef, length(data[i][!,1]))
		for j=1:length(data[i][!,1])
		
			T_ = RetentionData.T_column_names_to_Float(data[i])
			Tindex = findall(occursin.("Cat", names(data[i])).==false)[2:end]
			lnk_ = collect(Union{Missing,Float64}, data[i][j, Tindex])

			T[j] = T_[findall(ismissing.(lnk_).==false)]
			lnk[j] = lnk_[findall(ismissing.(lnk_).==false)]
			
			#ii = findall(isa.(lnk[j], Float64)) # indices of `lnk` which are NOT missing
			name[j] = data[i][!, 1][j]

			fitABC[j], okABC_i[j], excludedABC_i[j] = fit(RetentionData.ABC, T[j], lnk[j], ftrusted=ftrusted) #fit_outlier_test(m, xx, yy; ftrusted=0.7)

			fitKcentric[j], okKcentric_i[j], excludedKcentric_i[j] = fit(RetentionData.Kcentric, T[j], lnk[j], ftrusted=ftrusted)

			Not(okKcentric_i[j].outliers)

			R²_ABC[j] = RetentionData.coeff_of_determination(RetentionData.ABC, fitABC[j], T[j][Not(okABC_i[j].outliers)].+273.15, lnk[j][Not(okABC_i[j].outliers)])
			R²_Kcentric[j] = RetentionData.coeff_of_determination(RetentionData.Kcentric, fitKcentric[j], T[j][Not(okKcentric_i[j].outliers)].+RetentionData.Tst, lnk[j][Not(okKcentric_i[j].outliers)])
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

Fit the ABC-model and the K-centric-model at the lnk(T) data of the `data`-array of dataframes, using LsqFit.jl and add the result in a new column (`fit`) of `meta_data 
"""
function fit_models!(meta_data::DataFrame;Check=true, ftrusted=0.7)
	fitting = fit_models(meta_data.data, Check, ftrusted=ftrusted)
	meta_data[!, "fitting"] = fitting
	return meta_data
end
end=#

# ╔═╡ c1fbe870-ffd5-423b-8d59-0d06e56c9e07
begin 
	function fit(model, T, lnk; check=true, ftrusted=0.7)
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
		fit =curve_fit(model, T .+273.15, lnk, p0)
	else	
		fit = curve_fit(model, T[Not(robust.outliers)].+273.15, lnk[Not(robust.outliers)], p0)
	end	
	
	# residual of outliers to the lsq-result:
	res_outliers = model(T[robust.outliers] .+ 273.15, fit.param) .- lnk[robust.outliers]
	# - if this residual is below a threshold (e.g. the highest residual of the used data), than this outlier is not a outlier anymore -> cleared outlier
	cleared_outliers = robust.outliers[findall(abs.(res_outliers).<maximum(abs.(fit.resid)))] # perhaps use here a more sufisticated methode -> test if this value belongs to the same distribution as the other values (normal distribution)
	#Create a Tuple of outliers
	
	Tuple=Array{Any}(undef, size(robust.outliers)[1])
		for i=1:size(robust.outliers)[1]
			Tuple[i]=(T[robust.outliers[i]],lnk[robust.outliers[i]])
		end	
	if !isempty(cleared_outliers)
		# - re-run the lsq-fit now using the cleared outliers 
		lsq = curve_fit(model, T[Not(robust.outliers[findall(!in(T[cleared_outliers]),T[robust.outliers])])].+273.15, lnk[Not(robust.outliers[findall(!in(T[cleared_outliers]),T[robust.outliers])])], fit.param)
		Tuple2=Array{Any}(undef, size(robust.outliers[findall(!in(T[cleared_outliers]),T[robust.outliers])])[1])
			for i=1:size(robust.outliers[findall(!in(T[cleared_outliers]),T[robust.outliers])])[1]
				Tuple2[i]= (T[robust.outliers[findall(!in(T[cleared_outliers]),T[robust.outliers])][i]], lnk[robust.outliers[findall(!in(T[cleared_outliers]),T[robust.outliers])][i]])
			end	
		return lsq, robust, Tuple2
	else
		return fit, robust, Tuple
	end
	end	
	
end		

# ╔═╡ 2a906f58-cdad-4944-b190-a5019cb1396f
function AcceptTest(Dataset, Check; ftrusted=0.7)
		fitABC = Array{Any}(undef, length(Dataset[!,1]))
		fitKcentric = Array{Any}(undef, length(Dataset[!,1]))
		T = Array{Array{Float64}}(undef, length(Dataset[!,1]))
		lnk = Array{Array{Float64}}(undef, length(Dataset[!,1]))
		name = Array{String}(undef, length(Dataset[!,1]))
		excludedABC_i = Array{Any}(undef, length(Dataset[!,1]))
		okABC_i = Array{Any}(undef, length(Dataset[!,1]))
		excludedKcentric_i = Array{Any}(undef, length(Dataset[!,1]))
		okKcentric_i = Array{Any}(undef, length(Dataset[!,1]))
		R²_ABC = Array{Float64}(undef, length(Dataset[!,1]))
		R²_Kcentric = Array{Float64}(undef, length(Dataset[!,1]))
		χ²_ABC = Array{Float64}(undef, length(Dataset[!,1]))
		χ²_Kcentric = Array{Float64}(undef, length(Dataset[!,1]))
		χ̄²_ABC = Array{Float64}(undef, length(Dataset[!,1]))
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

			fitABC[j], okABC_i[j], excludedABC_i[j] = fit(RetentionData.ABC, T[j], lnk[j], check=Check[j], ftrusted=ftrusted) #fit_outlier_test(m, xx, yy; ftrusted=0.7)

			fitKcentric[j], okKcentric_i[j], excludedKcentric_i[j] = fit(RetentionData.Kcentric, T[j], lnk[j], check=Check[j], ftrusted=ftrusted)

			Not(okKcentric_i[j].outliers)

			R²_ABC[j] = RetentionData.coeff_of_determination(RetentionData.ABC, fitABC[j], T[j][Not(okABC_i[j].outliers)].+273.15, lnk[j][Not(okABC_i[j].outliers)])
			R²_Kcentric[j] = RetentionData.coeff_of_determination(RetentionData.Kcentric, fitKcentric[j], T[j][Not(okKcentric_i[j].outliers)].+RetentionData.Tst, lnk[j][Not(okKcentric_i[j].outliers)])
			χ²_ABC[j] = rss(fitABC[j])
			χ̄²_ABC[j] = mse(fitABC[j])
			χ²_Kcentric[j] = rss(fitKcentric[j])
			χ̄²_Kcentric[j] = mse(fitKcentric[j])

			Checkbox[j]=Check[j]
		end
		fits= DataFrame(Name=name, T=T, lnk=lnk, fitABC=fitABC, fitKcentric=fitKcentric, 
							i_ABC=okABC_i, i_Kcentric=okKcentric_i, ex_i_ABC=excludedABC_i, ex_i_Kcentric=excludedKcentric_i, 
							R²_ABC=R²_ABC, R²_Kcentric=R²_Kcentric,
							χ²_ABC=χ²_ABC, χ²_Kcentric=χ²_Kcentric,
							χ̄²_ABC=χ̄²_ABC, χ̄²_Kcentric=χ̄²_Kcentric,
							AcceptCheck= Checkbox)
		# add columns with "Cat" in column name
		i_cat = findall(occursin.("Cat", names(Dataset)))
		for j=1:length(i_cat)
			fits[!, "Cat_$(j)"] = Dataset[!, i_cat[j]]
		end
	return fits
end

# ╔═╡ 1ec53761-5a43-42a5-a5dc-ee94accf0650
begin

md""" Save results from Outlier check"""
	
CSV.write(string("C:\\Users\\Brehmer\\Documents\\GitHub\\RetentionData\\OutlierCheck\\","Check_",data.filename[select_dataset]), DataFrame(Name=data.data[select_dataset][!,1], OutlierTest=AcceptTest(data.data[select_dataset], Check).AcceptCheck))

CheckBase=Array{Any}(undef, size(data.filename)[1])
	for i=1:size(data.filename)[1]
		try
			CheckBase[i]=CSV.File(string("C:\\Users\\Brehmer\\Documents\\GitHub\\RetentionData\\OutlierCheck\\","Check_",data.filename[i])).OutlierTest
		catch 
			CheckBase[i]=Array{Any}(undef, size(data.data[i])[1])
				 		for j=1:size(data.data[i])[1]
							CheckBase[i][j]= true
						end		
		end	
		end	
CheckBase	
RetentionData.extract_parameters_from_fit!(data);
end;

# ╔═╡ 437bc369-4ad4-4641-b9b2-d64cce55736e
 fit(m, X, Y, check=CheckBase[select_dataset][select_substance]; ftrusted=0.7)

# ╔═╡ 1f5ae6f9-eb0e-49cf-aad6-f0b65442c1a8
CheckBase

# ╔═╡ d1152703-304f-4a2a-bc8f-36456c63100a
begin function fit_models(data::Array{DataFrame}, CheckBase; ftrusted=0.7)

	fits = Array{DataFrame}(undef, length(data))
	for i=1:length(data)

		fits[i]=AcceptTest(data[i], CheckBase[i], ftrusted=ftrusted)
	end
	return fits

	end

"""	
	fit_models!(meta_data::DataFrame; weighted=false, threshold=NaN, lb_ABC=[-Inf, 0.0, 0.0], ub_ABC=[0.0, Inf, 50.0], lb_Kcentric=[0.0, 0.0, 0.0], ub_Kcentric=[Inf, Inf, 500.0])

Fit the ABC-model and the K-centric-model at the lnk(T) data of the `data`-array of dataframes, using LsqFit.jl and add the result in a new column (`fit`) of `meta_data 
"""
function fit_models!(meta_data::DataFrame,CheckBase; ftrusted=0.7)
	fitting = fit_models(meta_data.data,CheckBase, ftrusted=ftrusted)
	meta_data[!, "fitting"] = fitting
	return meta_data
end
	
end

# ╔═╡ 3c8e66f6-fa6f-430b-816c-c3a1bfbe76af
begin
fit_models!(data, CheckBase).fitting[select_dataset]
RetentionData.extract_parameters_from_fit(data.fitting, data.beta0);
	A = data.parameters[select_dataset].A[select_substance];
	B = data.parameters[select_dataset].B[select_substance];
	C = data.parameters[select_dataset].C[select_substance];
	Tchar = data.parameters[select_dataset].Tchar[select_substance];
	θchar = data.parameters[select_dataset].thetachar[select_substance];
	ΔCp = data.parameters[select_dataset].DeltaCp[select_substance];
end;	

# ╔═╡ 8587abf6-b962-4e9c-a8b4-2d9ba5a25e51
Tchar

# ╔═╡ ca984e5b-2e1f-40ce-ad65-453171b402dc
θchar

# ╔═╡ 6493101e-d266-4cff-a72b-7e2829d158ce
ΔCp

# ╔═╡ d1ef794d-dd55-4cf4-8fde-f0a03ea2e2cd
mini_Kcentric = Tchar + (Tchar+273.15)^2/(θchar*ΔCp/8.31446261815324)

# ╔═╡ 6c250c7e-c95a-4bc1-a523-299b96e43584
mini_lnk_Kcentric = (ΔCp/8.31446261815324+(Tchar+273.15)/θchar)*((Tchar+273.15)/(mini_Kcentric+273.15)-1)+ΔCp/8.31446261815324*log((mini_Kcentric+273.15)/(Tchar+273.15))

# ╔═╡ d7a5f461-33e1-4602-b803-0223ef9a4484
maxi_μ_Kcentric = 1/(1+exp(mini_lnk_Kcentric))

# ╔═╡ 5a84d979-f8ff-466f-946e-7c2d0917eebc
A

# ╔═╡ 388801a7-2ebb-44cf-8154-320e514ceb2d
B

# ╔═╡ cd26abc7-244c-4535-9db9-8530053471dd
C

# ╔═╡ 9ba32dff-3be6-493a-b9b4-abe025bb1dad
mini_ABC = B/C - 273.15

# ╔═╡ fc3b5738-f63f-41b3-808a-8086bce5aefc
fit_models!(data, CheckBase);

# ╔═╡ 325478fb-6b22-4f33-a455-a7fd1dfa8ec7
fit_models!(data, CheckBase).fitting;

# ╔═╡ d57b2b89-9763-4998-8434-465de994ce54
#RetentionData.save_all_parameter_data(data)

# ╔═╡ 91c46525-43f9-4ef2-98f4-35fb3974d64f
md"""
# End
"""

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
CSV = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
ChemicalIdentifiers = "fa4ea961-1416-484e-bda2-883ee1634ba5"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
LambertW = "984bce1d-4616-540c-a9ee-88d1112d94c9"
LsqFit = "2fda8390-95c7-5789-9bda-21331edee243"
Measurements = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
Plots = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
PlutoUI = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
RAFF = "4aa82a78-ed18-41f9-aee6-9d73ba3a0b42"
Statistics = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[compat]
CSV = "~0.10.2"
ChemicalIdentifiers = "~0.1.5"
DataFrames = "~1.3.2"
LambertW = "~0.4.5"
LsqFit = "~0.12.1"
Measurements = "~2.7.1"
Plots = "~1.26.0"
PlutoUI = "~0.7.35"
RAFF = "~0.6.4"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.2"
manifest_format = "2.0"

[[deps.AbstractPlutoDingetjes]]
deps = ["Pkg"]
git-tree-sha1 = "8eaf9f1b4921132a4cff3f36a1d9ba923b14a481"
uuid = "6e696c72-6542-2067-7265-42206c756150"
version = "1.1.4"

[[deps.Adapt]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "195c5505521008abea5aee4f96930717958eac6f"
uuid = "79e6a3ab-5dfb-504d-930d-738a2a938a0e"
version = "3.4.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.ArrayInterfaceCore]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "14c3f84a763848906ac681f94cf469a851601d92"
uuid = "30b0a656-2188-435a-8636-2ec0e6a096e2"
version = "0.1.28"

[[deps.Arrow]]
deps = ["ArrowTypes", "BitIntegers", "CodecLz4", "CodecZstd", "DataAPI", "Dates", "LoggingExtras", "Mmap", "PooledArrays", "SentinelArrays", "Tables", "TimeZones", "UUIDs", "WorkerUtilities"]
git-tree-sha1 = "e97bdb5e241bb57f628968fd56efd9590078ada4"
uuid = "69666777-d1a9-59fb-9406-91d4454c9d45"
version = "2.4.2"

[[deps.ArrowTypes]]
deps = ["UUIDs"]
git-tree-sha1 = "563d60f89fcb730668bd568ba3e752ee71dde023"
uuid = "31f734f8-188a-4ce0-8406-c8a06bd891cd"
version = "2.0.2"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.BitIntegers]]
deps = ["Random"]
git-tree-sha1 = "fc54d5837033a170f3bad307f993e156eefc345f"
uuid = "c3b6d118-76ef-56ca-8cc7-ebb389d030a1"
version = "0.2.7"

[[deps.Bzip2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "19a35467a82e236ff51bc17a3a44b69ef35185a2"
uuid = "6e34b625-4abd-537c-b88f-471c36dfa7a0"
version = "1.0.8+0"

[[deps.CEnum]]
git-tree-sha1 = "eb4cb44a499229b3b8426dcfb5dd85333951ff90"
uuid = "fa961155-64e5-5f13-b03f-caf6b980ea82"
version = "0.4.2"

[[deps.CSV]]
deps = ["CodecZlib", "Dates", "FilePathsBase", "InlineStrings", "Mmap", "Parsers", "PooledArrays", "SentinelArrays", "SnoopPrecompile", "Tables", "Unicode", "WeakRefStrings", "WorkerUtilities"]
git-tree-sha1 = "c700cce799b51c9045473de751e9319bdd1c6e94"
uuid = "336ed68f-0bac-5ca0-87d4-7b16caf5d00b"
version = "0.10.9"

[[deps.Cairo_jll]]
deps = ["Artifacts", "Bzip2_jll", "CompilerSupportLibraries_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "JLLWrappers", "LZO_jll", "Libdl", "Pixman_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "4b859a208b2397a7a623a03449e4636bdb17bcf2"
uuid = "83423d85-b0ee-5818-9007-b63ccbeb887a"
version = "1.16.1+1"

[[deps.Calculus]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f641eb0a4f00c343bbc32346e1217b86f3ce9dad"
uuid = "49dc2e85-a5d0-5ad3-a950-438e2897f1b9"
version = "0.5.1"

[[deps.ChainRulesCore]]
deps = ["Compat", "LinearAlgebra", "SparseArrays"]
git-tree-sha1 = "c6d890a52d2c4d55d326439580c3b8d0875a77d9"
uuid = "d360d2e6-b24c-11e9-a2a3-2a2ae2dbcce4"
version = "1.15.7"

[[deps.ChangesOfVariables]]
deps = ["ChainRulesCore", "LinearAlgebra", "Test"]
git-tree-sha1 = "38f7a08f19d8810338d4f5085211c7dfa5d5bdd8"
uuid = "9e997f8a-9a97-42d5-a9f1-ce6bfc15e2c0"
version = "0.1.4"

[[deps.ChemicalIdentifiers]]
deps = ["Arrow", "Downloads", "Preferences", "Scratch", "UUIDs", "Unicode"]
git-tree-sha1 = "f55715e75fb14cbe72808d43b75c4d66e5200daf"
uuid = "fa4ea961-1416-484e-bda2-883ee1634ba5"
version = "0.1.7"

[[deps.CodecLz4]]
deps = ["Lz4_jll", "TranscodingStreams"]
git-tree-sha1 = "59fe0cb37784288d6b9f1baebddbf75457395d40"
uuid = "5ba52731-8f18-5e0d-9241-30f10d1ec561"
version = "0.4.0"

[[deps.CodecZlib]]
deps = ["TranscodingStreams", "Zlib_jll"]
git-tree-sha1 = "ded953804d019afa9a3f98981d99b33e3db7b6da"
uuid = "944b1d66-785c-5afd-91f1-9de20f533193"
version = "0.7.0"

[[deps.CodecZstd]]
deps = ["CEnum", "TranscodingStreams", "Zstd_jll"]
git-tree-sha1 = "849470b337d0fa8449c21061de922386f32949d9"
uuid = "6b39b394-51ab-5f42-8807-6242bab2b4c2"
version = "0.7.2"

[[deps.ColorSchemes]]
deps = ["ColorTypes", "ColorVectorSpace", "Colors", "FixedPointNumbers", "Random", "SnoopPrecompile"]
git-tree-sha1 = "aa3edc8f8dea6cbfa176ee12f7c2fc82f0608ed3"
uuid = "35d6a980-a343-548e-a6ea-1d62b119f2f4"
version = "3.20.0"

[[deps.ColorTypes]]
deps = ["FixedPointNumbers", "Random"]
git-tree-sha1 = "eb7f0f8307f71fac7c606984ea5fb2817275d6e4"
uuid = "3da002f7-5984-5a60-b8a6-cbb66c0b333f"
version = "0.11.4"

[[deps.ColorVectorSpace]]
deps = ["ColorTypes", "FixedPointNumbers", "LinearAlgebra", "SpecialFunctions", "Statistics", "TensorCore"]
git-tree-sha1 = "600cc5508d66b78aae350f7accdb58763ac18589"
uuid = "c3611d14-8923-5661-9e6a-0046d554d3a4"
version = "0.9.10"

[[deps.Colors]]
deps = ["ColorTypes", "FixedPointNumbers", "Reexport"]
git-tree-sha1 = "fc08e5930ee9a4e03f84bfb5211cb54e7769758a"
uuid = "5ae59095-9a9b-59fe-a467-6f913c188581"
version = "0.12.10"

[[deps.CommonSubexpressions]]
deps = ["MacroTools", "Test"]
git-tree-sha1 = "7b8a93dba8af7e3b42fecabf646260105ac373f7"
uuid = "bbf7d656-a473-5ed7-a52c-81e309532950"
version = "0.3.0"

[[deps.Compat]]
deps = ["Dates", "LinearAlgebra", "UUIDs"]
git-tree-sha1 = "00a2cccc7f098ff3b66806862d275ca3db9e6e5a"
uuid = "34da2185-b29b-5c13-b0c7-acf172513d20"
version = "4.5.0"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.ConstructionBase]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "fb21ddd70a051d882a1686a5a550990bbe371a95"
uuid = "187b0558-2788-49d3-abe0-74a17ed4e7c9"
version = "1.4.1"

[[deps.Contour]]
deps = ["StaticArrays"]
git-tree-sha1 = "9f02045d934dc030edad45944ea80dbd1f0ebea7"
uuid = "d38c429a-6771-53c6-b99e-75d170b6e991"
version = "0.5.7"

[[deps.Crayons]]
git-tree-sha1 = "249fe38abf76d48563e2f4556bebd215aa317e15"
uuid = "a8cc5b0e-0ffa-5ad4-8c14-923d3ee1735f"
version = "4.1.1"

[[deps.DataAPI]]
git-tree-sha1 = "e8119c1a33d267e16108be441a287a6981ba1630"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.14.0"

[[deps.DataFrames]]
deps = ["Compat", "DataAPI", "Future", "InvertedIndices", "IteratorInterfaceExtensions", "LinearAlgebra", "Markdown", "Missings", "PooledArrays", "PrettyTables", "Printf", "REPL", "Reexport", "SortingAlgorithms", "Statistics", "TableTraits", "Tables", "Unicode"]
git-tree-sha1 = "db2a9cb664fcea7836da4b414c3278d71dd602d2"
uuid = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
version = "1.3.6"

[[deps.DataStructures]]
deps = ["Compat", "InteractiveUtils", "OrderedCollections"]
git-tree-sha1 = "d1fff3a548102f48987a52a2e0d114fa97d730f0"
uuid = "864edb3b-99cc-5e75-8d2d-829cb0a9cfe8"
version = "0.18.13"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.DelimitedFiles]]
deps = ["Mmap"]
uuid = "8bb1440f-4735-579b-a4ab-409b98df4dab"

[[deps.DensityInterface]]
deps = ["InverseFunctions", "Test"]
git-tree-sha1 = "80c3e8639e3353e5d2912fb3a1916b8455e2494b"
uuid = "b429d917-457f-4dbc-8f4c-0cc954292b1d"
version = "0.4.0"

[[deps.DiffResults]]
deps = ["StaticArraysCore"]
git-tree-sha1 = "782dd5f4561f5d267313f23853baaaa4c52ea621"
uuid = "163ba53b-c6d8-5494-b064-1a9d43ac40c5"
version = "1.1.0"

[[deps.DiffRules]]
deps = ["IrrationalConstants", "LogExpFunctions", "NaNMath", "Random", "SpecialFunctions"]
git-tree-sha1 = "c5b6685d53f933c11404a3ae9822afe30d522494"
uuid = "b552c78f-8df3-52c6-915a-8e097449b14b"
version = "1.12.2"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Distributions]]
deps = ["ChainRulesCore", "DensityInterface", "FillArrays", "LinearAlgebra", "PDMats", "Printf", "QuadGK", "Random", "SparseArrays", "SpecialFunctions", "Statistics", "StatsBase", "StatsFuns", "Test"]
git-tree-sha1 = "74911ad88921455c6afcad1eefa12bd7b1724631"
uuid = "31c24e10-a181-5473-b8eb-7969acd0382f"
version = "0.25.80"

[[deps.DocStringExtensions]]
deps = ["LibGit2"]
git-tree-sha1 = "2fb1e02f2b635d0845df5d7c167fec4dd739b00d"
uuid = "ffbed154-4ef7-542d-bbb7-c09d3a79fcae"
version = "0.9.3"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.DualNumbers]]
deps = ["Calculus", "NaNMath", "SpecialFunctions"]
git-tree-sha1 = "5837a837389fccf076445fce071c8ddaea35a566"
uuid = "fa6b7ba4-c1ee-5f82-b5fc-ecf0adba8f74"
version = "0.6.8"

[[deps.EarCut_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e3290f2d49e661fbd94046d7e3726ffcb2d41053"
uuid = "5ae413db-bbd1-5e63-b57d-d24a61df00f5"
version = "2.2.4+0"

[[deps.Expat_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bad72f730e9e91c08d9427d5e8db95478a3c323d"
uuid = "2e619515-83b5-522b-bb60-26c02a35a201"
version = "2.4.8+0"

[[deps.ExprTools]]
git-tree-sha1 = "56559bbef6ca5ea0c0818fa5c90320398a6fbf8d"
uuid = "e2ba6199-217a-4e67-a87a-7c52f15ade04"
version = "0.1.8"

[[deps.Extents]]
git-tree-sha1 = "5e1e4c53fa39afe63a7d356e30452249365fba99"
uuid = "411431e0-e8b7-467b-b5e0-f676ba4f2910"
version = "0.1.1"

[[deps.FFMPEG]]
deps = ["FFMPEG_jll"]
git-tree-sha1 = "b57e3acbe22f8484b4b5ff66a7499717fe1a9cc8"
uuid = "c87230d0-a227-11e9-1b43-d7ebe4e7570a"
version = "0.4.1"

[[deps.FFMPEG_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "JLLWrappers", "LAME_jll", "Libdl", "Ogg_jll", "OpenSSL_jll", "Opus_jll", "PCRE2_jll", "Pkg", "Zlib_jll", "libaom_jll", "libass_jll", "libfdk_aac_jll", "libvorbis_jll", "x264_jll", "x265_jll"]
git-tree-sha1 = "74faea50c1d007c85837327f6775bea60b5492dd"
uuid = "b22a6f82-2f65-5046-a5b2-351ab43fb4e5"
version = "4.4.2+2"

[[deps.FilePathsBase]]
deps = ["Compat", "Dates", "Mmap", "Printf", "Test", "UUIDs"]
git-tree-sha1 = "e27c4ebe80e8699540f2d6c805cc12203b614f12"
uuid = "48062228-2e41-5def-b9a4-89aafe57970f"
version = "0.9.20"

[[deps.FillArrays]]
deps = ["LinearAlgebra", "Random", "SparseArrays", "Statistics"]
git-tree-sha1 = "9a0472ec2f5409db243160a8b030f94c380167a3"
uuid = "1a297f60-69ca-5386-bcde-b61e274b549b"
version = "0.13.6"

[[deps.FiniteDiff]]
deps = ["ArrayInterfaceCore", "LinearAlgebra", "Requires", "Setfield", "SparseArrays", "StaticArrays"]
git-tree-sha1 = "04ed1f0029b6b3af88343e439b995141cb0d0b8d"
uuid = "6a86dc24-6348-571c-b903-95158fe2bd41"
version = "2.17.0"

[[deps.FixedPointNumbers]]
deps = ["Statistics"]
git-tree-sha1 = "335bfdceacc84c5cdf16aadc768aa5ddfc5383cc"
uuid = "53c48c17-4a7d-5ca2-90c5-79b7896eea93"
version = "0.8.4"

[[deps.Fontconfig_jll]]
deps = ["Artifacts", "Bzip2_jll", "Expat_jll", "FreeType2_jll", "JLLWrappers", "Libdl", "Libuuid_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "21efd19106a55620a188615da6d3d06cd7f6ee03"
uuid = "a3f928ae-7b40-5064-980b-68af3947d34b"
version = "2.13.93+0"

[[deps.Formatting]]
deps = ["Printf"]
git-tree-sha1 = "8339d61043228fdd3eb658d86c926cb282ae72a8"
uuid = "59287772-0a20-5a39-b81b-1366585eb4c0"
version = "0.4.2"

[[deps.ForwardDiff]]
deps = ["CommonSubexpressions", "DiffResults", "DiffRules", "LinearAlgebra", "LogExpFunctions", "NaNMath", "Preferences", "Printf", "Random", "SpecialFunctions", "StaticArrays"]
git-tree-sha1 = "a69dd6db8a809f78846ff259298678f0d6212180"
uuid = "f6369f11-7733-5829-9624-2563aa707210"
version = "0.10.34"

[[deps.FreeType2_jll]]
deps = ["Artifacts", "Bzip2_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "87eb71354d8ec1a96d4a7636bd57a7347dde3ef9"
uuid = "d7e528f0-a631-5988-bf34-fe36492bcfd7"
version = "2.10.4+0"

[[deps.FriBidi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "aa31987c2ba8704e23c6c8ba8a4f769d5d7e4f91"
uuid = "559328eb-81f9-559d-9380-de523a88c83c"
version = "1.0.10+0"

[[deps.Future]]
deps = ["Random"]
uuid = "9fa8497b-333b-5362-9e8d-4d0656e87820"

[[deps.GLFW_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libglvnd_jll", "Pkg", "Xorg_libXcursor_jll", "Xorg_libXi_jll", "Xorg_libXinerama_jll", "Xorg_libXrandr_jll"]
git-tree-sha1 = "d972031d28c8c8d9d7b41a536ad7bb0c2579caca"
uuid = "0656b61e-2033-5cc2-a64a-77c0f6c09b89"
version = "3.3.8+0"

[[deps.GPUArraysCore]]
deps = ["Adapt"]
git-tree-sha1 = "57f7cde02d7a53c9d1d28443b9f11ac5fbe7ebc9"
uuid = "46192b85-c4d5-4398-a991-12ede77f4527"
version = "0.1.3"

[[deps.GR]]
deps = ["Base64", "DelimitedFiles", "GR_jll", "HTTP", "JSON", "Libdl", "LinearAlgebra", "Pkg", "Printf", "Random", "RelocatableFolders", "Serialization", "Sockets", "Test", "UUIDs"]
git-tree-sha1 = "c98aea696662d09e215ef7cda5296024a9646c75"
uuid = "28b8d3ca-fb5f-59d9-8090-bfdbd6d07a71"
version = "0.64.4"

[[deps.GR_jll]]
deps = ["Artifacts", "Bzip2_jll", "Cairo_jll", "FFMPEG_jll", "Fontconfig_jll", "GLFW_jll", "JLLWrappers", "JpegTurbo_jll", "Libdl", "Libtiff_jll", "Pixman_jll", "Pkg", "Qt5Base_jll", "Zlib_jll", "libpng_jll"]
git-tree-sha1 = "bc9f7725571ddb4ab2c4bc74fa397c1c5ad08943"
uuid = "d2c73de3-f751-5644-a686-071e5b155ba9"
version = "0.69.1+0"

[[deps.GeoInterface]]
deps = ["Extents"]
git-tree-sha1 = "e315c4f9d43575cf6b4e511259433803c15ebaa2"
uuid = "cf35fbd7-0cd7-5166-be24-54bfbe79505f"
version = "1.1.0"

[[deps.GeometryBasics]]
deps = ["EarCut_jll", "GeoInterface", "IterTools", "LinearAlgebra", "StaticArrays", "StructArrays", "Tables"]
git-tree-sha1 = "fe9aea4ed3ec6afdfbeb5a4f39a2208909b162a6"
uuid = "5c1252a2-5f33-56bf-86c9-59e7332b4326"
version = "0.4.5"

[[deps.Gettext_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "9b02998aba7bf074d14de89f9d37ca24a1a0b046"
uuid = "78b55507-aeef-58d4-861c-77aaff3498b1"
version = "0.21.0+0"

[[deps.Glib_jll]]
deps = ["Artifacts", "Gettext_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Libiconv_jll", "Libmount_jll", "PCRE2_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "d3b3624125c1474292d0d8ed0f65554ac37ddb23"
uuid = "7746bdde-850d-59dc-9ae8-88ece973131d"
version = "2.74.0+2"

[[deps.Graphite2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "344bf40dcab1073aca04aa0df4fb092f920e4011"
uuid = "3b182d85-2403-5c21-9c21-1e1f0cc25472"
version = "1.3.14+0"

[[deps.Grisu]]
git-tree-sha1 = "53bb909d1151e57e2484c3d1b53e19552b887fb2"
uuid = "42e2da0e-8278-4e71-bc24-59509adca0fe"
version = "1.0.2"

[[deps.HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[deps.HarfBuzz_jll]]
deps = ["Artifacts", "Cairo_jll", "Fontconfig_jll", "FreeType2_jll", "Glib_jll", "Graphite2_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg"]
git-tree-sha1 = "129acf094d168394e80ee1dc4bc06ec835e510a3"
uuid = "2e76f6c2-a576-52d4-95c1-20adfe4de566"
version = "2.8.1+1"

[[deps.HypergeometricFunctions]]
deps = ["DualNumbers", "LinearAlgebra", "OpenLibm_jll", "SpecialFunctions", "Test"]
git-tree-sha1 = "709d864e3ed6e3545230601f94e11ebc65994641"
uuid = "34004b35-14d8-5ef3-9330-4cdb6864b03a"
version = "0.3.11"

[[deps.Hyperscript]]
deps = ["Test"]
git-tree-sha1 = "8d511d5b81240fc8e6802386302675bdf47737b9"
uuid = "47d2ed2b-36de-50cf-bf87-49c2cf4b8b91"
version = "0.0.4"

[[deps.HypertextLiteral]]
deps = ["Tricks"]
git-tree-sha1 = "c47c5fa4c5308f27ccaac35504858d8914e102f9"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.4"

[[deps.IOCapture]]
deps = ["Logging", "Random"]
git-tree-sha1 = "f7be53659ab06ddc986428d3a9dcc95f6fa6705a"
uuid = "b5f81e59-6552-4d32-b1f0-c071b021bf89"
version = "0.2.2"

[[deps.IniFile]]
git-tree-sha1 = "f550e6e32074c939295eb5ea6de31849ac2c9625"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.1"

[[deps.InlineStrings]]
deps = ["Parsers"]
git-tree-sha1 = "0cf92ec945125946352f3d46c96976ab972bde6f"
uuid = "842dd82b-1e85-43dc-bf29-5d0ee9dffc48"
version = "1.3.2"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.InverseFunctions]]
deps = ["Test"]
git-tree-sha1 = "49510dfcb407e572524ba94aeae2fced1f3feb0f"
uuid = "3587e190-3f89-42d0-90ee-14403ec27112"
version = "0.1.8"

[[deps.InvertedIndices]]
git-tree-sha1 = "82aec7a3dd64f4d9584659dc0b62ef7db2ef3e19"
uuid = "41ab1584-1d38-5bbf-9106-f11c6c58b48f"
version = "1.2.0"

[[deps.IrrationalConstants]]
git-tree-sha1 = "7fd44fd4ff43fc60815f8e764c0f352b83c49151"
uuid = "92d709cd-6900-40b7-9082-c6be49f344b6"
version = "0.1.1"

[[deps.IterTools]]
git-tree-sha1 = "fa6287a4469f5e048d763df38279ee729fbd44e5"
uuid = "c8e1da08-722c-5040-9ed9-7db0dc04731e"
version = "1.4.0"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JLLWrappers]]
deps = ["Preferences"]
git-tree-sha1 = "abc9885a7ca2052a736a600f7fa66209f96506e1"
uuid = "692b3bcd-3c85-4b1f-b108-f13ce0eb3210"
version = "1.4.1"

[[deps.JSON]]
deps = ["Dates", "Mmap", "Parsers", "Unicode"]
git-tree-sha1 = "3c837543ddb02250ef42f4738347454f95079d4e"
uuid = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
version = "0.21.3"

[[deps.JpegTurbo_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b53380851c6e6664204efb2e62cd24fa5c47e4ba"
uuid = "aacddb02-875f-59d6-b918-886e6ef4fbf8"
version = "2.1.2+0"

[[deps.LAME_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6250b16881adf048549549fba48b1161acdac8c"
uuid = "c1c5ebd0-6772-5130-a774-d5fcae4a789d"
version = "3.100.1+0"

[[deps.LERC_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "bf36f528eec6634efc60d7ec062008f171071434"
uuid = "88015f11-f218-50d7-93a8-a6af411a945d"
version = "3.0.0+1"

[[deps.LZO_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e5b909bcf985c5e2605737d2ce278ed791b89be6"
uuid = "dd4b983a-f0e5-5f8d-a1b7-129d4a5fb1ac"
version = "2.10.1+0"

[[deps.LaTeXStrings]]
git-tree-sha1 = "f2355693d6778a178ade15952b7ac47a4ff97996"
uuid = "b964fa9f-0449-5b57-a5c2-d3ea65f4040f"
version = "1.3.0"

[[deps.LambertW]]
git-tree-sha1 = "2d9f4009c486ef676646bca06419ac02061c088e"
uuid = "984bce1d-4616-540c-a9ee-88d1112d94c9"
version = "0.4.5"

[[deps.Latexify]]
deps = ["Formatting", "InteractiveUtils", "LaTeXStrings", "MacroTools", "Markdown", "OrderedCollections", "Printf", "Requires"]
git-tree-sha1 = "2422f47b34d4b127720a18f86fa7b1aa2e141f29"
uuid = "23fbe1c1-3f47-55db-b15f-69d7ec21a316"
version = "0.15.18"

[[deps.LazyArtifacts]]
deps = ["Artifacts", "Pkg"]
uuid = "4af54fe1-eca0-43a8-85a7-787d91b784e3"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.Libffi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "0b4a5d71f3e5200a7dff793393e09dfc2d874290"
uuid = "e9f186c6-92d2-5b65-8a66-fee21dc1b490"
version = "3.2.2+1"

[[deps.Libgcrypt_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgpg_error_jll", "Pkg"]
git-tree-sha1 = "64613c82a59c120435c067c2b809fc61cf5166ae"
uuid = "d4300ac3-e22c-5743-9152-c294e39db1e4"
version = "1.8.7+0"

[[deps.Libglvnd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll", "Xorg_libXext_jll"]
git-tree-sha1 = "6f73d1dd803986947b2c750138528a999a6c7733"
uuid = "7e76a0d4-f3c7-5321-8279-8d96eeed0f29"
version = "1.6.0+0"

[[deps.Libgpg_error_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c333716e46366857753e273ce6a69ee0945a6db9"
uuid = "7add5ba3-2f88-524e-9cd5-f83b8a55f7b8"
version = "1.42.0+0"

[[deps.Libiconv_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "c7cb1f5d892775ba13767a87c7ada0b980ea0a71"
uuid = "94ce4f54-9a6c-5748-9c1c-f9c7231a4531"
version = "1.16.1+2"

[[deps.Libmount_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "9c30530bf0effd46e15e0fdcf2b8636e78cbbd73"
uuid = "4b2f31a3-9ecc-558c-b454-b3730dcb73e9"
version = "2.35.0+0"

[[deps.Libtiff_jll]]
deps = ["Artifacts", "JLLWrappers", "JpegTurbo_jll", "LERC_jll", "Libdl", "Pkg", "Zlib_jll", "Zstd_jll"]
git-tree-sha1 = "3eb79b0ca5764d4799c06699573fd8f533259713"
uuid = "89763e89-9b03-5906-acba-b20f662cd828"
version = "4.4.0+0"

[[deps.Libuuid_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "7f3efec06033682db852f8b3bc3c1d2b0a0ab066"
uuid = "38a345b3-de98-5d2b-a5d3-14cd9215e700"
version = "2.36.0+0"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.LogExpFunctions]]
deps = ["ChainRulesCore", "ChangesOfVariables", "DocStringExtensions", "InverseFunctions", "IrrationalConstants", "LinearAlgebra"]
git-tree-sha1 = "946607f84feb96220f480e0422d3484c49c00239"
uuid = "2ab3a3ac-af41-5b50-aa03-7779005ae688"
version = "0.3.19"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoggingExtras]]
deps = ["Dates", "Logging"]
git-tree-sha1 = "cedb76b37bc5a6c702ade66be44f831fa23c681e"
uuid = "e6f89c97-d47a-5376-807f-9c37f3926c36"
version = "1.0.0"

[[deps.LsqFit]]
deps = ["Distributions", "ForwardDiff", "LinearAlgebra", "NLSolversBase", "OptimBase", "Random", "StatsBase"]
git-tree-sha1 = "91aa1442e63a77f101aff01dec5a821a17f43922"
uuid = "2fda8390-95c7-5789-9bda-21331edee243"
version = "0.12.1"

[[deps.Lz4_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "5d494bc6e85c4c9b626ee0cab05daa4085486ab1"
uuid = "5ced341a-0733-55b8-9ab6-a4889d929147"
version = "1.9.3+0"

[[deps.MIMEs]]
git-tree-sha1 = "65f28ad4b594aebe22157d6fac869786a255b7eb"
uuid = "6c6e2e6c-3030-632d-7369-2d6c69616d65"
version = "0.1.4"

[[deps.MacroTools]]
deps = ["Markdown", "Random"]
git-tree-sha1 = "42324d08725e200c23d4dfb549e0d5d89dede2d2"
uuid = "1914dd2f-81c6-5fcd-8719-6d5c9610ff09"
version = "0.5.10"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "MozillaCACerts_jll", "Random", "Sockets"]
git-tree-sha1 = "03a9b9718f5682ecb107ac9f7308991db4ce395b"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.1.7"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.Measurements]]
deps = ["Calculus", "LinearAlgebra", "Printf", "RecipesBase", "Requires"]
git-tree-sha1 = "dd8b9e6d7be9731fdaecc813acc5c3083496a251"
uuid = "eff96d63-e80a-5855-80a2-b1b0885c5ab7"
version = "2.7.2"

[[deps.Measures]]
git-tree-sha1 = "c13304c81eec1ed3af7fc20e75fb6b26092a1102"
uuid = "442fdcdd-2543-5da2-b0f3-8c86c306513e"
version = "0.3.2"

[[deps.Missings]]
deps = ["DataAPI"]
git-tree-sha1 = "f66bdc5de519e8f8ae43bdc598782d35a25b1272"
uuid = "e1d29d7a-bbdc-5cf2-9ac0-f12de2c33e28"
version = "1.1.0"

[[deps.Mmap]]
uuid = "a63ad114-7e13-5084-954f-fe012c677804"

[[deps.Mocking]]
deps = ["Compat", "ExprTools"]
git-tree-sha1 = "c272302b22479a24d1cf48c114ad702933414f80"
uuid = "78c3b35d-d492-501b-9361-3d52fe80e533"
version = "0.7.5"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.NLSolversBase]]
deps = ["DiffResults", "Distributed", "FiniteDiff", "ForwardDiff"]
git-tree-sha1 = "a0b464d183da839699f4c79e7606d9d186ec172c"
uuid = "d41bc354-129a-5804-8e4c-c37616107c6c"
version = "7.8.3"

[[deps.NaNMath]]
deps = ["OpenLibm_jll"]
git-tree-sha1 = "a7c3d1da1189a1c2fe843a3bfa04d18d20eb3211"
uuid = "77ba4419-2d1f-58cd-9bb1-8ffee604a2e3"
version = "1.0.1"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.Ogg_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "887579a3eb005446d514ab7aeac5d1d027658b8f"
uuid = "e7412a2a-1a6e-54c0-be00-318e2571c051"
version = "1.3.5+1"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OpenLibm_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "05823500-19ac-5b8b-9628-191a04bc5112"

[[deps.OpenSSL_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "f6e9dba33f9f2c44e08a020b0caf6903be540004"
uuid = "458c3c95-2e84-50aa-8efc-19380b2a3a95"
version = "1.1.19+0"

[[deps.OpenSpecFun_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "13652491f6856acfd2db29360e1bbcd4565d04f1"
uuid = "efe28fd5-8261-553b-a9e1-b2916fc3738e"
version = "0.5.5+0"

[[deps.OptimBase]]
deps = ["NLSolversBase", "Printf", "Reexport"]
git-tree-sha1 = "9cb1fee807b599b5f803809e85c81b582d2009d6"
uuid = "87e2bd06-a317-5318-96d9-3ecbac512eee"
version = "2.0.2"

[[deps.Opus_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "51a08fb14ec28da2ec7a927c4337e4332c2a4720"
uuid = "91d4177d-7536-5919-b921-800302f37372"
version = "1.3.2+0"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.PCRE2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "efcefdf7-47ab-520b-bdef-62a2eaa19f15"

[[deps.PDMats]]
deps = ["LinearAlgebra", "SparseArrays", "SuiteSparse"]
git-tree-sha1 = "cf494dca75a69712a72b80bc48f59dcf3dea63ec"
uuid = "90014a1f-27ba-587c-ab20-58faa44d9150"
version = "0.11.16"

[[deps.Parsers]]
deps = ["Dates", "SnoopPrecompile"]
git-tree-sha1 = "8175fc2b118a3755113c8e68084dc1a9e63c61ee"
uuid = "69de0a69-1ddd-5017-9359-2bf0b02dc9f0"
version = "2.5.3"

[[deps.Pixman_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "b4f5d02549a10e20780a24fce72bea96b6329e29"
uuid = "30392449-352a-5448-841d-b1acce4e97dc"
version = "0.40.1+0"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.PlotThemes]]
deps = ["PlotUtils", "Requires", "Statistics"]
git-tree-sha1 = "a3a964ce9dc7898193536002a6dd892b1b5a6f1d"
uuid = "ccf2f8ad-2431-5c83-bf29-c5338b663b6a"
version = "2.0.1"

[[deps.PlotUtils]]
deps = ["ColorSchemes", "Colors", "Dates", "Printf", "Random", "Reexport", "SnoopPrecompile", "Statistics"]
git-tree-sha1 = "5b7690dd212e026bbab1860016a6601cb077ab66"
uuid = "995b91a9-d308-5afd-9ec6-746e21dbc043"
version = "1.3.2"

[[deps.Plots]]
deps = ["Base64", "Contour", "Dates", "Downloads", "FFMPEG", "FixedPointNumbers", "GR", "GeometryBasics", "JSON", "Latexify", "LinearAlgebra", "Measures", "NaNMath", "Pkg", "PlotThemes", "PlotUtils", "Printf", "REPL", "Random", "RecipesBase", "RecipesPipeline", "Reexport", "Requires", "Scratch", "Showoff", "SparseArrays", "Statistics", "StatsBase", "UUIDs", "UnicodeFun", "Unzip"]
git-tree-sha1 = "2f041202ab4e47f4a3465e3993929538ea71bd48"
uuid = "91a5bcdd-55d7-5caf-9e0b-520d859cae80"
version = "1.26.1"

[[deps.PlutoUI]]
deps = ["AbstractPlutoDingetjes", "Base64", "ColorTypes", "Dates", "FixedPointNumbers", "Hyperscript", "HypertextLiteral", "IOCapture", "InteractiveUtils", "JSON", "Logging", "MIMEs", "Markdown", "Random", "Reexport", "URIs", "UUIDs"]
git-tree-sha1 = "eadad7b14cf046de6eb41f13c9275e5aa2711ab6"
uuid = "7f904dfe-b85e-4ff6-b463-dae2292396a8"
version = "0.7.49"

[[deps.PooledArrays]]
deps = ["DataAPI", "Future"]
git-tree-sha1 = "a6062fe4063cdafe78f4a0a81cfffb89721b30e7"
uuid = "2dfb63ee-cc39-5dd5-95bd-886bf059d720"
version = "1.4.2"

[[deps.Preferences]]
deps = ["TOML"]
git-tree-sha1 = "47e5f437cc0e7ef2ce8406ce1e7e24d44915f88d"
uuid = "21216c6a-2e73-6563-6e65-726566657250"
version = "1.3.0"

[[deps.PrettyTables]]
deps = ["Crayons", "Formatting", "Markdown", "Reexport", "Tables"]
git-tree-sha1 = "dfb54c4e414caa595a1f2ed759b160f5a3ddcba5"
uuid = "08abe8d2-0d0c-5749-adfa-8a2ac140af0d"
version = "1.3.1"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.Qt5Base_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Fontconfig_jll", "Glib_jll", "JLLWrappers", "Libdl", "Libglvnd_jll", "OpenSSL_jll", "Pkg", "Xorg_libXext_jll", "Xorg_libxcb_jll", "Xorg_xcb_util_image_jll", "Xorg_xcb_util_keysyms_jll", "Xorg_xcb_util_renderutil_jll", "Xorg_xcb_util_wm_jll", "Zlib_jll", "xkbcommon_jll"]
git-tree-sha1 = "0c03844e2231e12fda4d0086fd7cbe4098ee8dc5"
uuid = "ea2cea3b-5b76-57ae-a6ef-0a8af62496e1"
version = "5.15.3+2"

[[deps.QuadGK]]
deps = ["DataStructures", "LinearAlgebra"]
git-tree-sha1 = "de191bc385072cc6c7ed3ffdc1caeed3f22c74d4"
uuid = "1fd47b50-473d-5c70-9696-f719f8f3bcdc"
version = "2.7.0"

[[deps.RAFF]]
deps = ["DelimitedFiles", "Distributed", "ForwardDiff", "LinearAlgebra", "Logging", "Printf", "Random", "SharedArrays", "Statistics", "Test"]
git-tree-sha1 = "e716c75b85568625f4bd09aae9174e6f43aca981"
uuid = "4aa82a78-ed18-41f9-aee6-9d73ba3a0b42"
version = "0.6.4"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RecipesBase]]
deps = ["SnoopPrecompile"]
git-tree-sha1 = "261dddd3b862bd2c940cf6ca4d1c8fe593e457c8"
uuid = "3cdcf5f2-1ef4-517c-9805-6587b60abb01"
version = "1.3.3"

[[deps.RecipesPipeline]]
deps = ["Dates", "NaNMath", "PlotUtils", "RecipesBase"]
git-tree-sha1 = "dc1e451e15d90347a7decc4221842a022b011714"
uuid = "01d81517-befc-4cb6-b9ec-a95719d0359c"
version = "0.5.2"

[[deps.Reexport]]
git-tree-sha1 = "45e428421666073eab6f2da5c9d310d99bb12f9b"
uuid = "189a3867-3050-52da-a836-e630ba90ab69"
version = "1.2.2"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "cdbd3b1338c72ce29d9584fdbe9e9b70eeb5adca"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "0.1.3"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Rmath]]
deps = ["Random", "Rmath_jll"]
git-tree-sha1 = "bf3188feca147ce108c76ad82c2792c57abe7b1f"
uuid = "79098fc4-a85e-5d69-aa6a-4863f24498fa"
version = "0.7.0"

[[deps.Rmath_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "68db32dff12bb6127bac73c209881191bf0efbb7"
uuid = "f50d1b31-88e8-58de-be2c-1cc44531875f"
version = "0.3.0+0"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "f94f779c94e58bf9ea243e77a37e16d9de9126bd"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.1"

[[deps.SentinelArrays]]
deps = ["Dates", "Random"]
git-tree-sha1 = "c02bd3c9c3fc8463d3591a62a378f90d2d8ab0f3"
uuid = "91c51154-3ec4-41a3-a24f-3f23e20d615c"
version = "1.3.17"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Setfield]]
deps = ["ConstructionBase", "Future", "MacroTools", "StaticArraysCore"]
git-tree-sha1 = "e2cc6d8c88613c05e1defb55170bf5ff211fbeac"
uuid = "efcf1570-3423-57d1-acb7-fd33fddbac46"
version = "1.1.1"

[[deps.SharedArrays]]
deps = ["Distributed", "Mmap", "Random", "Serialization"]
uuid = "1a1011a3-84de-559e-8e89-a11a2f7dc383"

[[deps.Showoff]]
deps = ["Dates", "Grisu"]
git-tree-sha1 = "91eddf657aca81df9ae6ceb20b959ae5653ad1de"
uuid = "992d4aef-0814-514b-bc4d-f2e9a6c4116f"
version = "1.0.3"

[[deps.SnoopPrecompile]]
deps = ["Preferences"]
git-tree-sha1 = "e760a70afdcd461cf01a575947738d359234665c"
uuid = "66db9d55-30c0-4569-8b51-7e840670fc0c"
version = "1.0.3"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.SortingAlgorithms]]
deps = ["DataStructures"]
git-tree-sha1 = "a4ada03f999bd01b3a25dcaa30b2d929fe537e00"
uuid = "a2af1166-a08f-5f64-846c-94a0d3cef48c"
version = "1.1.0"

[[deps.SparseArrays]]
deps = ["LinearAlgebra", "Random"]
uuid = "2f01184e-e22b-5df5-ae63-d93ebab69eaf"

[[deps.SpecialFunctions]]
deps = ["ChainRulesCore", "IrrationalConstants", "LogExpFunctions", "OpenLibm_jll", "OpenSpecFun_jll"]
git-tree-sha1 = "d75bda01f8c31ebb72df80a46c88b25d1c79c56d"
uuid = "276daf66-3868-5448-9aa4-cd146d93841b"
version = "2.1.7"

[[deps.StaticArrays]]
deps = ["LinearAlgebra", "Random", "StaticArraysCore", "Statistics"]
git-tree-sha1 = "6954a456979f23d05085727adb17c4551c19ecd1"
uuid = "90137ffa-7385-5640-81b9-e52037218182"
version = "1.5.12"

[[deps.StaticArraysCore]]
git-tree-sha1 = "6b7ba252635a5eff6a0b0664a41ee140a1c9e72a"
uuid = "1e83bf80-4336-4d27-bf5d-d5a4f845583c"
version = "1.4.0"

[[deps.Statistics]]
deps = ["LinearAlgebra", "SparseArrays"]
uuid = "10745b16-79ce-11e8-11f9-7d13ad32a3b2"

[[deps.StatsAPI]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "f9af7f195fb13589dd2e2d57fdb401717d2eb1f6"
uuid = "82ae8749-77ed-4fe6-ae5f-f523153014b0"
version = "1.5.0"

[[deps.StatsBase]]
deps = ["DataAPI", "DataStructures", "LinearAlgebra", "LogExpFunctions", "Missings", "Printf", "Random", "SortingAlgorithms", "SparseArrays", "Statistics", "StatsAPI"]
git-tree-sha1 = "d1bf48bfcc554a3761a133fe3a9bb01488e06916"
uuid = "2913bbd2-ae8a-5f71-8c99-4fb6c76f3a91"
version = "0.33.21"

[[deps.StatsFuns]]
deps = ["ChainRulesCore", "HypergeometricFunctions", "InverseFunctions", "IrrationalConstants", "LogExpFunctions", "Reexport", "Rmath", "SpecialFunctions"]
git-tree-sha1 = "ab6083f09b3e617e34a956b43e9d51b824206932"
uuid = "4c63d2b9-4356-54db-8cca-17b64c39e42c"
version = "1.1.1"

[[deps.StructArrays]]
deps = ["Adapt", "DataAPI", "GPUArraysCore", "StaticArraysCore", "Tables"]
git-tree-sha1 = "b03a3b745aa49b566f128977a7dd1be8711c5e71"
uuid = "09ab397b-f2b6-538f-b94a-2f83cf4a842a"
version = "0.6.14"

[[deps.SuiteSparse]]
deps = ["Libdl", "LinearAlgebra", "Serialization", "SparseArrays"]
uuid = "4607b0f0-06f3-5cda-b6b1-a6196a1729e9"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "c79322d36826aa2f4fd8ecfa96ddb47b174ac78d"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.10.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.TensorCore]]
deps = ["LinearAlgebra"]
git-tree-sha1 = "1feb45f88d133a655e001435632f019a9a1bcdb6"
uuid = "62fd8b95-f654-4bbd-a8a5-9c27f68ccd50"
version = "0.1.1"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.TimeZones]]
deps = ["Dates", "Downloads", "InlineStrings", "LazyArtifacts", "Mocking", "Printf", "RecipesBase", "Scratch", "Unicode"]
git-tree-sha1 = "a92ec4466fc6e3dd704e2668b5e7f24add36d242"
uuid = "f269a46b-ccf7-5d73-abea-4c690281aa53"
version = "1.9.1"

[[deps.TranscodingStreams]]
deps = ["Random", "Test"]
git-tree-sha1 = "94f38103c984f89cf77c402f2a68dbd870f8165f"
uuid = "3bb67fe8-82b1-5028-8e26-92a6c54297fa"
version = "0.9.11"

[[deps.Tricks]]
git-tree-sha1 = "6bac775f2d42a611cdfcd1fb217ee719630c4175"
uuid = "410a4b4d-49e4-4fbc-ab6d-cb71b17b3775"
version = "0.1.6"

[[deps.URIs]]
git-tree-sha1 = "ac00576f90d8a259f2c9d823e91d1de3fd44d348"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.4.1"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.UnicodeFun]]
deps = ["REPL"]
git-tree-sha1 = "53915e50200959667e78a92a418594b428dffddf"
uuid = "1cfade01-22cf-5700-b092-accc4b62d6e1"
version = "0.4.1"

[[deps.Unzip]]
git-tree-sha1 = "34db80951901073501137bdbc3d5a8e7bbd06670"
uuid = "41fe7b60-77ed-43a1-b4f0-825fd5a5650d"
version = "0.1.2"

[[deps.Wayland_jll]]
deps = ["Artifacts", "Expat_jll", "JLLWrappers", "Libdl", "Libffi_jll", "Pkg", "XML2_jll"]
git-tree-sha1 = "ed8d92d9774b077c53e1da50fd81a36af3744c1c"
uuid = "a2964d1f-97da-50d4-b82a-358c7fce9d89"
version = "1.21.0+0"

[[deps.Wayland_protocols_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4528479aa01ee1b3b4cd0e6faef0e04cf16466da"
uuid = "2381bf8a-dfd0-557d-9999-79630e7b1b91"
version = "1.25.0+0"

[[deps.WeakRefStrings]]
deps = ["DataAPI", "InlineStrings", "Parsers"]
git-tree-sha1 = "b1be2855ed9ed8eac54e5caff2afcdb442d52c23"
uuid = "ea10d353-3f73-51f8-a26c-33c1cb351aa5"
version = "1.4.2"

[[deps.WorkerUtilities]]
git-tree-sha1 = "cd1659ba0d57b71a464a29e64dbc67cfe83d54e7"
uuid = "76eceee3-57b5-4d4a-8e66-0e911cebbf60"
version = "1.6.1"

[[deps.XML2_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libiconv_jll", "Pkg", "Zlib_jll"]
git-tree-sha1 = "93c41695bc1c08c46c5899f4fe06d6ead504bb73"
uuid = "02c8fc9c-b97f-50b9-bbe4-9be30ff0a78a"
version = "2.10.3+0"

[[deps.XSLT_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Libgcrypt_jll", "Libgpg_error_jll", "Libiconv_jll", "Pkg", "XML2_jll", "Zlib_jll"]
git-tree-sha1 = "91844873c4085240b95e795f692c4cec4d805f8a"
uuid = "aed1982a-8fda-507f-9586-7b0439959a61"
version = "1.1.34+0"

[[deps.Xorg_libX11_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll", "Xorg_xtrans_jll"]
git-tree-sha1 = "5be649d550f3f4b95308bf0183b82e2582876527"
uuid = "4f6342f7-b3d2-589e-9d20-edeb45f2b2bc"
version = "1.6.9+4"

[[deps.Xorg_libXau_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4e490d5c960c314f33885790ed410ff3a94ce67e"
uuid = "0c0b7dd1-d40b-584c-a123-a41640f87eec"
version = "1.0.9+4"

[[deps.Xorg_libXcursor_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXfixes_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "12e0eb3bc634fa2080c1c37fccf56f7c22989afd"
uuid = "935fb764-8cf2-53bf-bb30-45bb1f8bf724"
version = "1.2.0+4"

[[deps.Xorg_libXdmcp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fe47bd2247248125c428978740e18a681372dd4"
uuid = "a3789734-cfe1-5b06-b2d0-1dd0d9d62d05"
version = "1.1.3+4"

[[deps.Xorg_libXext_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "b7c0aa8c376b31e4852b360222848637f481f8c3"
uuid = "1082639a-0dae-5f34-9b06-72781eeb8cb3"
version = "1.3.4+4"

[[deps.Xorg_libXfixes_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "0e0dc7431e7a0587559f9294aeec269471c991a4"
uuid = "d091e8ba-531a-589c-9de9-94069b037ed8"
version = "5.0.3+4"

[[deps.Xorg_libXi_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXfixes_jll"]
git-tree-sha1 = "89b52bc2160aadc84d707093930ef0bffa641246"
uuid = "a51aa0fd-4e3c-5386-b890-e753decda492"
version = "1.7.10+4"

[[deps.Xorg_libXinerama_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll"]
git-tree-sha1 = "26be8b1c342929259317d8b9f7b53bf2bb73b123"
uuid = "d1454406-59df-5ea1-beac-c340f2130bc3"
version = "1.1.4+4"

[[deps.Xorg_libXrandr_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libXext_jll", "Xorg_libXrender_jll"]
git-tree-sha1 = "34cea83cb726fb58f325887bf0612c6b3fb17631"
uuid = "ec84b674-ba8e-5d96-8ba1-2a689ba10484"
version = "1.5.2+4"

[[deps.Xorg_libXrender_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "19560f30fd49f4d4efbe7002a1037f8c43d43b96"
uuid = "ea2f1a96-1ddc-540d-b46f-429655e07cfa"
version = "0.9.10+4"

[[deps.Xorg_libpthread_stubs_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "6783737e45d3c59a4a4c4091f5f88cdcf0908cbb"
uuid = "14d82f49-176c-5ed1-bb49-ad3f5cbd8c74"
version = "0.1.0+3"

[[deps.Xorg_libxcb_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "XSLT_jll", "Xorg_libXau_jll", "Xorg_libXdmcp_jll", "Xorg_libpthread_stubs_jll"]
git-tree-sha1 = "daf17f441228e7a3833846cd048892861cff16d6"
uuid = "c7cfdc94-dc32-55de-ac96-5a1b8d977c5b"
version = "1.13.0+3"

[[deps.Xorg_libxkbfile_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libX11_jll"]
git-tree-sha1 = "926af861744212db0eb001d9e40b5d16292080b2"
uuid = "cc61e674-0454-545c-8b26-ed2c68acab7a"
version = "1.1.0+4"

[[deps.Xorg_xcb_util_image_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "0fab0a40349ba1cba2c1da699243396ff8e94b97"
uuid = "12413925-8142-5f55-bb0e-6d7ca50bb09b"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxcb_jll"]
git-tree-sha1 = "e7fd7b2881fa2eaa72717420894d3938177862d1"
uuid = "2def613f-5ad1-5310-b15b-b15d46f528f5"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_keysyms_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "d1151e2c45a544f32441a567d1690e701ec89b00"
uuid = "975044d2-76e6-5fbe-bf08-97ce7c6574c7"
version = "0.4.0+1"

[[deps.Xorg_xcb_util_renderutil_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "dfd7a8f38d4613b6a575253b3174dd991ca6183e"
uuid = "0d47668e-0667-5a69-a72c-f761630bfb7e"
version = "0.3.9+1"

[[deps.Xorg_xcb_util_wm_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xcb_util_jll"]
git-tree-sha1 = "e78d10aab01a4a154142c5006ed44fd9e8e31b67"
uuid = "c22f9ab0-d5fe-5066-847c-f4bb1cd4e361"
version = "0.4.1+1"

[[deps.Xorg_xkbcomp_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_libxkbfile_jll"]
git-tree-sha1 = "4bcbf660f6c2e714f87e960a171b119d06ee163b"
uuid = "35661453-b289-5fab-8a00-3d9160c6a3a4"
version = "1.4.2+4"

[[deps.Xorg_xkeyboard_config_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Xorg_xkbcomp_jll"]
git-tree-sha1 = "5c8424f8a67c3f2209646d4425f3d415fee5931d"
uuid = "33bec58e-1273-512f-9401-5d533626f822"
version = "2.27.0+4"

[[deps.Xorg_xtrans_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "79c31e7844f6ecf779705fbc12146eb190b7d845"
uuid = "c5fb5394-a638-5e4d-96e5-b29de1b5cf10"
version = "1.4.0+3"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.Zstd_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "e45044cd873ded54b6a5bac0eb5c971392cf1927"
uuid = "3161d3a3-bdf6-5164-811a-617609db77b4"
version = "1.5.2+0"

[[deps.libaom_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "3a2ea60308f0996d26f1e5354e10c24e9ef905d4"
uuid = "a4ae2306-e953-59d6-aa16-d00cac43593b"
version = "3.4.0+0"

[[deps.libass_jll]]
deps = ["Artifacts", "Bzip2_jll", "FreeType2_jll", "FriBidi_jll", "HarfBuzz_jll", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "5982a94fcba20f02f42ace44b9894ee2b140fe47"
uuid = "0ac62f75-1d6f-5e53-bd7c-93b484bb37c0"
version = "0.15.1+0"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.libfdk_aac_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "daacc84a041563f965be61859a36e17c4e4fcd55"
uuid = "f638f0a6-7fb0-5443-88ba-1cc74229b280"
version = "2.0.2+0"

[[deps.libpng_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Zlib_jll"]
git-tree-sha1 = "94d180a6d2b5e55e447e2d27a29ed04fe79eb30c"
uuid = "b53b4c65-9356-5827-b1ea-8c7a1a84506f"
version = "1.6.38+0"

[[deps.libvorbis_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Ogg_jll", "Pkg"]
git-tree-sha1 = "b910cb81ef3fe6e78bf6acee440bda86fd6ae00c"
uuid = "f27f6e37-5d2b-51aa-960f-b287f2bc3b7a"
version = "1.3.7+1"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"

[[deps.x264_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "4fea590b89e6ec504593146bf8b988b2c00922b2"
uuid = "1270edf5-f2f9-52d2-97e9-ab00b5d0237a"
version = "2021.5.5+0"

[[deps.x265_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg"]
git-tree-sha1 = "ee567a171cce03570d77ad3a43e90218e38937a9"
uuid = "dfaa095f-4041-5dcd-9319-2fabd8486b76"
version = "3.5.0+0"

[[deps.xkbcommon_jll]]
deps = ["Artifacts", "JLLWrappers", "Libdl", "Pkg", "Wayland_jll", "Wayland_protocols_jll", "Xorg_libxcb_jll", "Xorg_xkeyboard_config_jll"]
git-tree-sha1 = "9ebfc140cc56e8c2156a15ceac2f0302e327ac0a"
uuid = "d8fb68d0-12a3-5cfd-a85a-d49703b185fd"
version = "1.4.1+0"
"""

# ╔═╡ Cell order:
# ╟─6f0ac0bc-9a3f-11ec-0866-9f56a0d489dd
# ╟─0b608842-5672-44cc-bd70-c168c537667e
# ╟─c037a761-f192-4a3b-a617-b6024ac6cd61
# ╟─3c8e66f6-fa6f-430b-816c-c3a1bfbe76af
# ╟─7c800ec4-7194-4cb0-87c8-b3b196deeb16
# ╟─435c5fca-0765-4d2c-b13d-1a67d83cc045
# ╟─ae6986cd-33f3-48b1-9f8b-71535670bf27
# ╟─3bac9f60-8749-425b-8e87-ba1d7442ca93
# ╟─b8cb55b5-c40d-4f9b-96fe-580c41cbf3d6
# ╟─67d3b9dc-ae20-4ef8-982c-6be10c96fb5c
# ╟─3b0c2125-ece5-41d6-92d3-f6cc3e4cfacc
# ╟─0a7a4cbc-5d25-44b9-91d1-67808df1626b
# ╟─2d8d554b-adf3-4794-8079-5f6848dbc34a
# ╟─437bc369-4ad4-4641-b9b2-d64cce55736e
# ╟─49a1e6d9-b939-4795-8c7f-61e92dc09ee8
# ╠═8587abf6-b962-4e9c-a8b4-2d9ba5a25e51
# ╠═ca984e5b-2e1f-40ce-ad65-453171b402dc
# ╠═6493101e-d266-4cff-a72b-7e2829d158ce
# ╟─d1ef794d-dd55-4cf4-8fde-f0a03ea2e2cd
# ╟─d7a5f461-33e1-4602-b803-0223ef9a4484
# ╟─6c250c7e-c95a-4bc1-a523-299b96e43584
# ╠═5a84d979-f8ff-466f-946e-7c2d0917eebc
# ╠═388801a7-2ebb-44cf-8154-320e514ceb2d
# ╠═cd26abc7-244c-4535-9db9-8530053471dd
# ╟─9ba32dff-3be6-493a-b9b4-abe025bb1dad
# ╟─bebf0dbc-96de-4e16-90ae-206930a106ee
# ╟─1f5ae6f9-eb0e-49cf-aad6-f0b65442c1a8
# ╠═1ec53761-5a43-42a5-a5dc-ee94accf0650
# ╟─fc3b5738-f63f-41b3-808a-8086bce5aefc
# ╟─64968bac-4878-4564-a16c-06722f215a9b
# ╟─ae5a44de-e350-4340-aa1f-49afe8c51bc5
# ╟─c6d787a2-4aaa-4155-bae4-4235e8fc7ea1
# ╟─fad7761b-84b8-4287-a08a-2ace85b1081e
# ╠═cd5d0b6c-6e76-4293-80a0-b07ea94a05d8
# ╠═2d7ed692-9524-428c-92cf-d4ecabe8278e
# ╠═faa843f7-ef50-47ab-a5a4-9d32265b7e5a
# ╠═dbf47c68-709f-45b5-9ae1-b75fe2e76c5f
# ╟─2fd4d728-9068-415c-b006-26f93dddce28
# ╟─f57fc4ec-9522-401f-91de-9495ca50bbb9
# ╟─a65c584d-a669-4dfe-8deb-03ce2fd3a0c0
# ╟─8a0d3816-b114-42e3-8bef-cda7b63af509
# ╟─baba96bf-b0fb-43a3-8f58-954343b918fd
# ╟─4a2c19cb-0321-4d64-91a5-51127f31ce9d
# ╟─4dd4f07a-4654-4fd5-99f1-0fab845a545d
# ╟─8eb557fa-8e94-49fd-8fc5-17f8d42943c6
# ╟─448c3252-4e1e-4a9a-a8da-a23ab0959dee
# ╟─325478fb-6b22-4f33-a455-a7fd1dfa8ec7
# ╟─fcb24959-64f6-423e-9e9e-e6d2e3c25f26
# ╟─d1152703-304f-4a2a-bc8f-36456c63100a
# ╟─2a906f58-cdad-4944-b190-a5019cb1396f
# ╟─c1fbe870-ffd5-423b-8d59-0d06e56c9e07
# ╠═d57b2b89-9763-4998-8434-465de994ce54
# ╟─91c46525-43f9-4ef2-98f4-35fb3974d64f
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
