import Distributions
import OrderedCollections

"""
Check if a dictionary containing all the Mads model parameters

$(DocumentFunction.documentfunction(isparam;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "dict"=>"dictionary")))

Returns:

- `true` if the dictionary contains all the parameters, `false` otherwise
"""
function isparam(madsdata::AbstractDict, dict::AbstractDict)
	if haskey(madsdata, "Parameters")
		par = getparamkeys(madsdata)
		partype = getparamstype(madsdata)
	else
		par = collect(keys(madsdata))
		partype = "opt"
	end
	flag = true
	for i in par
		if !haskey(dict, i) && partype == "opt"
			@warn("Parameter $(i) is missing!")
			flag = false
			break
		end
	end
	return flag
end

"""
Get keys of all parameters in the MADS problem dictionary

$(DocumentFunction.documentfunction(getparamkeys;
argtext=Dict("madsdata"=>"MADS problem dictionary"),
keytext=Dict("filter"=>"parameter filter")))

Returns:

- array with the keys of all parameters in the MADS problem dictionary
"""
function getparamkeys(madsdata::AbstractDict; filter::AbstractString="")
	if haskey(madsdata, "Parameters")
		return collect(filterkeys(madsdata["Parameters"], filter))
	else
		@warn "No parameters in the MADS problem dictionary!"
		return nothing
	end
end

"""
Get a dictionary with all parameters and their respective initial values

$(DocumentFunction.documentfunction(getparamdict;
argtext=Dict("madsdata"=>"MADS problem dictionary")))

Returns:

- dictionary with all parameters and their respective initial values
"""
function getparamdict(madsdata::AbstractDict)
	if haskey(madsdata, "Parameters")
		paramkeys = Mads.getparamkeys(madsdata)
		paramdict = OrderedCollections.OrderedDict{Union{String,Symbol},Float64}(zip(paramkeys, map(key->madsdata["Parameters"][key]["init"], paramkeys)))
		return paramdict
	else
		@warn("Input Dictionary does not contain parameters!")
		return Dict()
	end
end

"""
Get keys of all source parameters in the MADS problem dictionary

$(DocumentFunction.documentfunction(getsourcekeys;
argtext=Dict("madsdata"=>"MADS problem dictionary")))

Returns:

- array with keys of all source parameters in the MADS problem dictionary
"""
function getsourcekeys(madsdata::AbstractDict)
	sourcekeys = Array{String}(undef, 0)
	if haskey(madsdata, "Sources")
		for i = eachindex(madsdata["Sources"])
			for k = keys(madsdata["Sources"][1])
				sk = collect(String, keys(madsdata["Sources"][i][k]))
				b = fill("Source1_", length(sk))
				s = b .* sk
				sourcekeys = [sourcekeys; s]
			end
		end
	end
	return sourcekeys
end

# Make functions to get MADS parameter variable names"
getparamsnames = ["init", "type", "log", "step", "longname", "plotname"]
getparamstypes = [Float64, Any, Any, Float64, String, String]
getparamsdefault = [0, "opt", false, sqrt(eps(Float32)), "", ""]
getparamslogdefault = [1, "opt", true, sqrt(eps(Float32)), "", ""]
global index = 0
for i = eachindex(getparamsnames)
	global index = i
	paramname = getparamsnames[index]
	paramtype = getparamstypes[index]
	paramdefault = getparamsdefault[index]
	paramlogdefault = getparamslogdefault[index]
	q = quote
		"""
		Get an array with $(getparamsnames[index]) values for parameters defined by `paramkeys`
		"""
		function $(Symbol(string("getparams", paramname)))(madsdata::AbstractDict, paramkeys::AbstractVector) # create a function to get each parameter name with 2 arguments
			paramvalue = Array{$(paramtype)}(undef, length(paramkeys))
			for i = eachindex(paramkeys)
				if haskey(madsdata["Parameters"][paramkeys[i]], $paramname)
					v = madsdata["Parameters"][paramkeys[i]][$paramname]
					v = ( v == "nothing" || v == "null"|| v == "false" || v == "fixed" || v == "none" ) ? nothing : v
					paramvalue[i] = v
				else
					if Mads.islog(madsdata, paramkeys[i])
						paramvalue[i] = $(paramlogdefault)
					else
						paramvalue[i] = $(paramdefault)
					end
				end
			end
			return paramvalue # returns the parameter values
		end
		"""
		Get an array with $(getparamsnames[index]) values for all the MADS model parameters
		"""
		function $(Symbol(string("getparams", paramname)))(madsdata::AbstractDict) # create a function to get each parameter name with 1 argument
			paramkeys = Mads.getparamkeys(madsdata) # get parameter keys
			return $(Symbol(string("getparams", paramname)))(madsdata::AbstractDict, paramkeys) # call the function with 2 arguments
		end
	end
	Core.eval(Mads, q)
end

function getparamlabels(madsdata::AbstractDict, paramkeys::AbstractVector=getparamkeys(madsdata))
	plotlabels = getparamsplotname(madsdata, paramkeys)
	if plotlabels[1] == ""
		plotlabels = getparamslongname(madsdata, paramkeys)
		if plotlabels[1] == ""
			plotlabels = String.(paramkeys)
		end
	end
	return plotlabels
end

"""
Get an array with `min` values for parameters defined by `paramkeys`

$(DocumentFunction.documentfunction(getparamsmin;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "paramkeys"=>"parameter keys")))

Returns:

- the parameter values
"""
function getparamsmin(madsdata::AbstractDict, paramkeys::AbstractVector=getparamkeys(madsdata))
	paramvalue = Array{Float64}(undef, length(paramkeys))
	for i = eachindex(paramkeys)
		p = madsdata["Parameters"][paramkeys[i]]
		if haskey(p, "min")
			paramvalue[i] = p["min"]
			continue
		elseif haskey(p, "dist")
			distribution = Mads.getdistribution(p["dist"], "parameter")
			if typeof(distribution) <: Distributions.Uniform
				paramvalue[i] = distribution.a
				continue
			end
		end
		if Mads.islog(madsdata, paramkeys[i])
			paramvalue[i] = eps(Float64)
		else
			paramvalue[i] = -Inf
		end
	end
	return paramvalue
end

"""
Get an array with `max` values for parameters defined by `paramkeys`

$(DocumentFunction.documentfunction(getparamsmax;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "paramkeys"=>"parameter keys")))

Returns:

- returns the parameter values
"""
function getparamsmax(madsdata::AbstractDict, paramkeys::AbstractVector=getparamkeys(madsdata))
	paramvalue = Array{Float64}(undef, length(paramkeys))
	for i = eachindex(paramkeys)
		p = madsdata["Parameters"][paramkeys[i]]
		if haskey(p, "max")
			paramvalue[i] = p["max"]
			continue
		elseif haskey(p, "dist")
			distribution = Mads.getdistribution(p["dist"], "parameter")
			if typeof(distribution) <: Distributions.Uniform
				paramvalue[i] = distribution.b
				continue
			end
		end
		if Mads.islog(madsdata, paramkeys[i])
			paramvalue[i] = Inf
		else
			paramvalue[i] = Inf
		end
	end
	return paramvalue
end

"""
Get an array with `init_min` values for parameters

$(DocumentFunction.documentfunction(getparamsinit_min;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "paramkeys"=>"parameter keys")))

Returns:

- the parameter values
"""
function getparamsinit_min(madsdata::AbstractDict, paramkeys::AbstractVector=getparamkeys(madsdata))
	paramvalue = Array{Float64}(undef, length(paramkeys))
	for i = eachindex(paramkeys)
		p = madsdata["Parameters"][paramkeys[i]]
		if haskey(p, "init_min")
			paramvalue[i] = p["init_min"]
			continue
		end
		if haskey(p, "init_dist")
			distribution = Mads.getdistribution(p["init_dist"], "parameter")
			if typeof(distribution) <: Distributions.Uniform
				paramvalue[i] = distribution.a
				continue
			end
		end
		if haskey(p, "min")
			paramvalue[i] = p["min"]
			continue
		end
		if haskey(p, "dist")
			distribution = Mads.getdistribution(p["dist"], "parameter")
			if typeof(distribution) <: Distributions.Uniform
				paramvalue[i] = distribution.a
				continue
			end
		end
		if Mads.islog(madsdata, paramkeys[i])
			paramvalue[i] = eps(Float64)
		else
			paramvalue[i] = -Inf16
		end
	end
	return paramvalue # returns the parameter values
end

"""
Get an array with `init_max` values for parameters defined by `paramkeys`

$(DocumentFunction.documentfunction(getparamsinit_max;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "paramkeys"=>"parameter keys")))

Returns:

- the parameter values
"""
function getparamsinit_max(madsdata::AbstractDict, paramkeys::AbstractVector=getparamkeys(madsdata))
	paramvalue = Array{Float64}(undef, length(paramkeys))
	for i = eachindex(paramkeys)
		p = madsdata["Parameters"][paramkeys[i]]
		if haskey(p, "init_max")
			paramvalue[i] = p["init_max"]
			continue
		end
		if haskey(p, "init_dist")
			distribution = Mads.getdistribution(p["init_dist"], "parameter")
			if typeof(distribution) <: Distributions.Uniform
				paramvalue[i] = distribution.b
				continue
			end
		end
		if haskey(p, "max")
			paramvalue[i] = p["max"]
			continue
		end
		if haskey(p, "dist")
			distribution = Mads.getdistribution(p["dist"], "parameter")
			if typeof(distribution) <: Distributions.Uniform
				paramvalue[i] = distribution.b
				continue
			end
		end
		if Mads.islog(madsdata, paramkeys[i])
			paramvalue[i] = Inf
		else
			paramvalue[i] = Inf
		end
	end
	return paramvalue # returns the parameter values
end

"""
Set initial optimized parameter guesses in the MADS problem dictionary

$(DocumentFunction.documentfunction(setparamsinit!;
argtext=Dict("madsdata"=>"MADS problem dictionary",
             "paramdict"=>"dictionary with initial model parameter values",
            "paramdictarray"=>"dictionary of arrays with initial model parameter values",
            "idx"=>"index of the dictionary of arrays with initial model parameter values")))
"""
function setparamsinit!(madsdata::AbstractDict, paramdict::AbstractDict, idx::Integer=1)
	paramkeys = getparamkeys(madsdata)
	for k in paramkeys
		if haskey(paramdict, k)
			if typeof(paramdict[k]) <: Number
				madsdata["Parameters"][k]["init"] = paramdict[k]
			else
				madsdata["Parameters"][k]["init"] = paramdict[k][idx]
			end
		end
	end
	setsourceinit!(madsdata, paramdict, idx)
end

"""
Set initial optimized parameter guesses in the MADS problem dictionary for the Source class

$(DocumentFunction.documentfunction(setparamsinit!;
argtext=Dict("madsdata"=>"MADS problem dictionary",
             "paramdict"=>"dictionary with initial model parameter values",
            "paramdictarray"=>"dictionary of arrays with initial model parameter values",
            "idx"=>"index of the dictionary of arrays with initial model parameter values")))
"""
function setsourceinit!(madsdata::AbstractDict, paramdict::AbstractDict, idx::Integer=1)
	if haskey(madsdata, "Sources")
		ns = length(madsdata["Sources"])
		paramkeys = getparamkeys(madsdata)
		for k in paramkeys
			if haskey(paramdict, k) && occursin(r"source[1-9]*_(.*)", k)
				m = match(r"source([1-9])*_(.*)", k)
				sn = Meta.parse(m.captures[1])
				pk = m.captures[2]
				if sn > 0 && sn < ns
					sk = collect(keys(madsdata["Sources"][sn]))[1]
					if typeof(paramdict[k]) <: Number
						madsdata["Sources"][sn][sk][pk]["init"] = paramdict[k]
					else
						madsdata["Sources"][sn][sk][pk]["init"] = paramdict[k][idx]
					end
				end
			end
		end
	end
end

function getoptparams(madsdata::AbstractDict, parameterarray::AbstractArray=getparamsinit(madsdata), optparameterkey::AbstractArray=getoptparamkeys(madsdata))
	if length(optparameterkey) == 0
		optparameterkey = getoptparamkeys(madsdata)
	end
	parameterkey = getparamkeys(madsdata)
	nP = length(parameterkey)
	nP2 = length(parameterarray)
	nPo = length(optparameterkey)
	if nP2 == nPo
		return parameterarray
	elseif nP > nPo
		@assert nP2 == nP
		parameterarraynew = Array{Float64}(undef, nPo)
		j = 1
		for i in 1:nP
			if optparameterkey[j] == parameterkey[i]
				parameterarraynew[j] = parameterarray[i]
				j += 1
				if j > nPo
					break
				end
			end
		end
		return parameterarraynew
	else
		return parameterarray
	end
end
@doc """
Get optimizable parameters

$(DocumentFunction.documentfunction(getoptparams;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "parameterarray"=>"parameter array",
            "optparameterkey"=>"optimizable parameter keys")))

Returns:

- parameter array
""" getoptparams

"""
Is a parameter with key `parameterkey` optimizable?

$(DocumentFunction.documentfunction(isopt;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "parameterkey"=>"parameter key")))

Returns:

- `true` if optimizable, `false` if not
"""
function isopt(madsdata::AbstractDict, parameterkey::Union{Symbol,AbstractString})
	if haskey(madsdata, "Parameters") && haskey(madsdata["Parameters"], parameterkey) &&
		(!haskey(madsdata["Parameters"][parameterkey], "type") || haskey(madsdata["Parameters"][parameterkey], "type") && madsdata["Parameters"][parameterkey]["type"] == "opt")
		return true
	else
		return false
	end
end

"""
Is parameter with key `parameterkey` log-transformed?

$(DocumentFunction.documentfunction(islog;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "parameterkey"=>"parameter key")))

Returns:

- `true` if log-transformed, `false` otherwise
"""
function islog(madsdata::AbstractDict, parameterkey::Union{Symbol,AbstractString})
	if haskey(madsdata["Parameters"][parameterkey], "log") && madsdata["Parameters"][parameterkey]["log"] == true
		return true
	else
		return false
	end
end

"""
Set all parameters ON

$(DocumentFunction.documentfunction(setallparamson!;
argtext=Dict("madsdata"=>"MADS problem dictionary"),
keytext=Dict("filter"=>"parameter filter")))
"""
function setallparamson!(madsdata::AbstractDict; filter::AbstractString="")
	paramkeys = getparamkeys(madsdata; filter=filter)
	for k in paramkeys
		madsdata["Parameters"][k]["type"] = "opt"
	end
end

"""
Set all parameters OFF

$(DocumentFunction.documentfunction(setallparamsoff!;
argtext=Dict("madsdata"=>"MADS problem dictionary"),
keytext=Dict("filter"=>"parameter filter")))
"""
function setallparamsoff!(madsdata::AbstractDict; filter::AbstractString="")
	paramkeys = getparamkeys(madsdata; filter=filter)
	for k in paramkeys
		madsdata["Parameters"][k]["type"] = nothing
	end
end

"""
Set a specific parameter with a key `parameterkey` ON

$(DocumentFunction.documentfunction(setparamon!;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "parameterkey"=>"parameter key")))
"""
function setparamon!(madsdata::AbstractDict, parameterkey::Union{Symbol,AbstractString})
	madsdata["Parameters"][parameterkey]["type"] = "opt";
end

"""
Set a specific parameter with a key `parameterkey` OFF

$(DocumentFunction.documentfunction(setparamoff!;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "parameterkey"=>"parameter key")))
"""
function setparamoff!(madsdata::AbstractDict, parameterkey::Union{Symbol,AbstractString})
	madsdata["Parameters"][parameterkey]["type"] = nothing
end

"""
Set normal parameter distributions for all the model parameters in the MADS problem dictionary

$(DocumentFunction.documentfunction(setparamsdistnormal!;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "mean"=>"array with the mean values",
            "stddev"=>"array with the standard deviation values")))
"""
function setparamsdistnormal!(madsdata::AbstractDict, mean::AbstractVector, stddev::AbstractVector)
	paramkeys = getparamkeys(madsdata)
	for i = eachindex(paramkeys)
		madsdata["Parameters"][paramkeys[i]]["dist"] = "Normal($(mean[i]),$(stddev[i]))"
	end
end

"""
Set uniform parameter distributions for all the model parameters in the MADS problem dictionary

$(DocumentFunction.documentfunction(setparamsdistuniform!;
argtext=Dict("madsdata"=>"MADS problem dictionary",
            "min"=>"array with the minimum values",
            "max"=>"array with the maximum values")))
"""
function setparamsdistuniform!(madsdata::AbstractDict, min::AbstractVector, max::AbstractVector)
	paramkeys = getparamkeys(madsdata)
	for i = eachindex(paramkeys)
		madsdata["Parameters"][paramkeys[i]]["dist"] = "Uniform($(min[i]),$(max[i]))"
	end
end

# Make functions to get parameter keys for specific MADS parameters (optimized and log-transformed)
getfunction = [getparamstype, getparamslog]
keywordname = ["opt", "log"]
keywordvalsNOT = [nothing, false]
functiondescription = ["optimized", "log-transformed"]
global index = 0
for i = eachindex(getfunction)
	global index = i
	q = quote
		"""
		Get the keys in the MADS problem dictionary for parameters that are $(functiondescription[index]) (`$(keywordname[index])`)
		"""
		function $(Symbol(string("get", keywordname[index], "paramkeys")))(madsdata::AbstractDict, paramkeys::AbstractVector) # create functions getoptparamkeys / getlogparamkeys
			paramtypes = $(getfunction[index])(madsdata, paramkeys)
			return paramkeys[paramtypes .!= $(keywordvalsNOT[index])]
		end
		function $(Symbol(string("get", keywordname[index], "paramkeys")))(madsdata::AbstractDict)
			paramkeys = getparamkeys(madsdata)
			return $(Symbol(string("get", keywordname[index], "paramkeys")))(madsdata, paramkeys::AbstractVector)
		end
		"""
		Get the keys in the MADS problem dictionary for parameters that are NOT $(functiondescription[index]) (`$(keywordname[index])`)
		"""
		function $(Symbol(string("getnon", keywordname[index], "paramkeys")))(madsdata::AbstractDict, paramkeys::AbstractVector) # create functions getnonoptparamkeys / getnonlogparamkeys
			paramtypes = $(getfunction[index])(madsdata, paramkeys)
			return paramkeys[paramtypes .== $(keywordvalsNOT[index])]
		end
		function $(Symbol(string("getnon", keywordname[index], "paramkeys")))(madsdata::AbstractDict)
			paramkeys = getparamkeys(madsdata)
			return $(Symbol(string("getnon", keywordname[index], "paramkeys")))(madsdata, paramkeys)
		end
	end
	Core.eval(Mads, q)
end

function showparameters(madsdata::AbstractDict, result::AbstractDict; kw...)
	md = deepcopy(madsdata)
	map(i->(md["Parameters"][i]["init"]=result[i]), Mads.getoptparamkeys(md))
	showparameters(md; kw...)
end
function showparameters(madsdata::AbstractDict, parkeys::AbstractVector=Mads.getoptparamkeys(madsdata); all::Bool=false, rescale::Bool=true)
	if all
		parkeys = Mads.getparamkeys(madsdata)
	end
	printparameters(madsdata, parkeys; showtype=false, rescale=rescale)
	if parkeys == Mads.getoptparamkeys(madsdata)
		println("Number of optimizable parameters: $(length(parkeys))")
	else
		println("Number of parameters: $(length(parkeys))")
	end
end
@doc """
Show parameters in the MADS problem dictionary

$(DocumentFunction.documentfunction(showparameters;
argtext=Dict("madsdata"=>"MADS problem dictionary")))
""" showparameters

function showallparameters(madsdata::AbstractDict, parkeys::AbstractVector=Mads.getparamkeys(madsdata); rescale::Bool=true)
	printparameters(madsdata, parkeys; showtype=true, rescale=rescale)
	println("Number of parameters: $(length(parkeys))")
end
function showallparameters(madsdata::AbstractDict, result::AbstractDict; kw...)
	md = deepcopy(madsdata)
	map(i->(md["Parameters"][i]["init"]=result[i]), collect(keys(result)))
	showallparameters(md; kw...)
end
@doc """
Show all parameters in the MADS problem dictionary

$(DocumentFunction.documentfunction(showallparameters;
argtext=Dict("madsdata"=>"MADS problem dictionary")))
""" showallparameters

showparameterestimates = showparameters

function scale_up(v::Number, vmin::Number, vmax::Number, vlog::Bool=false)
	if vlog
		vminl = log10(vmin)
		vmaxl = log10(vmax)
		vl = 10 ^ (v * (vmaxl - vminl) + vminl)
	else
		vl = v * (vmax - vmin) + vmin
	end
	return vl
end

function scale_down(v::Number, vmin::Number, vmax::Number, vlog::Bool=false)
	if vlog
		vminl = log10(vmin)
		vmaxl = log10(vmax)
		vl = (log10(v) - vminl) / (vmaxl - vminl)
	else
		vl = (v - vmin) / (vmax - vmin)
	end
	return vl
end

function scale_up(v::AbstractVector, vmin::AbstractVector, vmax::AbstractVector,  vlog::AbstractVector=falses(legnth(v)))
	vv = similar(v)
	for i = eachindex(v)
		if v[i] < 0
			vl = 0
		elseif v[i] > 1
			vl = 1
		else
			vl = v[i]
		end
		if vlog[i]
			vminl = log10(vmin[i])
			vmaxl = log10(vmax[i])
			vl = 10 ^ (vl * (vmaxl - vminl) + vminl)
		else
			vl = vl * (vmax[i] - vmin[i]) + vmin[i]
		end
		vv[i] = vl
	end
	if any(isnan.(vv))
		@show v
		@show vv
		@warn("NaN values in scaled vector!")
		throw()
	end
	return vv
end

function scale_down(v::AbstractVector, vmin::AbstractVector, vmax::AbstractVector, vlog::AbstractVector=falses(legnth(v)))
	vv = similar(v)
	for i = eachindex(v)
		if vlog[i]
			vminl = log10(vmin[i])
			vmaxl = log10(vmax[i])
			dx = (vmaxl - vminl)
			vl = dx == 0 ? 1 : (log10(v[i]) - vminl) / dx
		else
			dx = (vmax[i] - vmin[i])
			vl = dx == 0 ? 1 : (v[i] - vmin[i]) / dx
		end
		if vl < 0
			vl = 0
		elseif vl > 1
			vl = 1
		end
		vv[i] = vl
	end
	if any(isnan.(vv))
		@show v
		@show vv
		@warn("NaN values in scaled vector!")
		throw()
	end
	return vv
end

function scale_up(madsdata::AbstractDict, v::AbstractVector)
	vmin = getparamskey(madsdata, "minorig")
	vmax = getparamskey(madsdata, "maxorig")
	vlog = Bool.(getparamskey(madsdata, "logorig"))
	return scale_up(v, vmin, vmax, vlog)
end

function scale_down(madsdata::AbstractDict, v::AbstractVector)
	vmin = getparamskey(madsdata, "minorig")
	vmax = getparamskey(madsdata, "maxorig")
	vlog = Bool.(getparamskey(madsdata, "logorig"))
	return scale_down(v, vmin, vmax, vlog)
end

function getparamskey(madsdata::AbstractDict, paramkey::Union{Symbol,AbstractString}="init")
	paramkeys = getparamkeys(madsdata)
	paramvalue = Array{Float64}(undef, length(paramkeys))
	for i = eachindex(paramkeys)
		paramvalue[i] = madsdata["Parameters"][paramkeys[i]][paramkey]
	end
	return paramvalue
end

function printparameters(madsdata::AbstractDict, parkeys::AbstractVector=Mads.getoptparamkeys(madsdata); parset::AbstractDict=Dict(), showtype::Bool=true, rescale::Bool=true)
	pardict = madsdata["Parameters"]
	maxl = 0
	maxk = 0
	for parkey in parkeys
		l = length(String(parkey))
		maxk = (maxk > l) ? maxk : l
		if haskey(pardict[parkey], "longname")
			l = length(String(pardict[parkey]["longname"]))
			maxl = (maxl > l) ? maxl : l
		end
	end
	p = Array{String}(undef, 0)
	for parkey in parkeys
		sparkey = String(parkey)
		if haskey(pardict[parkey], "longname") && String(pardict[parkey]["longname"]) != sparkey
			s = Mads.sprintf("%-$(maxl)s : ", String(pardict[parkey]["longname"]))
		else
			s = ""
		end
		s *= Mads.sprintf("%-$(maxk)s = ", sparkey)
		if haskey(parset, parkey)
			v = parset[parkey]
		elseif haskey(pardict[parkey], "init")
			v = pardict[parkey]["init"]
		else
			@warn("No initial value or expression for parameter $(sparkey)")
			continue
		end
		logorig = haskey(pardict[parkey], "logorig") ? pardict[parkey]["logorig"] : false
		if rescale && haskey(pardict[parkey], "minorig") && haskey(pardict[parkey], "maxorig")
			minorig = pardict[parkey]["minorig"]
			maxorig = pardict[parkey]["maxorig"]
			v = scale_up(v, minorig, maxorig, logorig)
			if haskey(pardict[parkey], "min")
				vmin = scale_up(pardict[parkey]["min"], minorig, maxorig, logorig)
			end
			if haskey(pardict[parkey], "max")
				vmax = scale_up(pardict[parkey]["max"], minorig, maxorig, logorig)
			end
		else
			if haskey(pardict[parkey], "min")
				vmin = pardict[parkey]["min"]
			end
			if haskey(pardict[parkey], "max")
				vmax = pardict[parkey]["max"]
			end
		end
		s *= Mads.sprintf("%15g ", v)
		if showtype
			if haskey(pardict[parkey], "type")
				if pardict[parkey]["type"] == "opt"
					s *= "$(Base.text_colors[:yellow])<- optimizable $(Base.text_colors[:normal])"
				else
					s *= "$(Base.text_colors[:blue])<- fixed       $(Base.text_colors[:normal])"
				end
			else
				s *= "$(Base.text_colors[:yellow])<- optimizable $(Base.text_colors[:normal])"
			end
		end
		if haskey(pardict[parkey], "min")
			s *= @Printf.sprintf "min = %15g " vmin
		end
		if haskey(pardict[parkey], "max")
			s *= @Printf.sprintf "max = %15g " vmax
		end
		if haskey(pardict[parkey], "dist")
			s *= @Printf.sprintf "distribution = %s " pardict[parkey]["dist"]
		end
		if haskey(pardict[parkey], "minorig") && haskey(pardict[parkey], "maxorig")
			if rescale
				s *= "$(Base.text_colors[:magenta]) <- rescaled $(Base.text_colors[:normal])"
			else
				s *= @Printf.sprintf "minorig = %15g " pardict[parkey]["minorig"]
				s *= @Printf.sprintf "maxorig = %15g " pardict[parkey]["maxorig"]
			end
		end
		if haskey(pardict[parkey], "log" ) && pardict[parkey]["log"] == true
			s *= "$(Base.text_colors[:red]) <- log-transformed $(Base.text_colors[:normal])"
		end
		if rescale && haskey(pardict[parkey], "minorig") && haskey(pardict[parkey], "maxorig") && logorig
			s *= "$(Base.text_colors[:red]) <- scale log-transformed $(Base.text_colors[:normal])"
		end
		s *= "\n"
		push!(p, s)
	end
	if haskey(madsdata, "Expressions")
		expdict = madsdata["Expressions"]
		params = Mads.evaluatemadsexpressions(madsdata)
		for expkey in keys(expdict)
			s = Mads.sprintf("%-$(maxk)s = %s\n", expkey, expdict[expkey]["exp"])
			push!(p, s)
		end
	end
	print(p...)
end

"""
Get probabilistic distributions of all parameters in the MADS problem dictionary

Note:

Probabilistic distribution of parameters can be defined only if `dist` or `min`/`max` model parameter fields are specified in the MADS problem dictionary `madsdata`.

$(DocumentFunction.documentfunction(getparamdistributions;
argtext=Dict("madsdata"=>"MADS problem dictionary"),
keytext=Dict("init_dist"=>"if `true` use the distribution defined for initialization in the MADS problem dictionary (defined using `init_dist` parameter field); else use the regular distribution defined in the MADS problem dictionary (defined using `dist` parameter field [default=`false`]")))

Returns:

- probabilistic distributions
"""
function getparamdistributions(madsdata::AbstractDict; init_dist::Bool=false)
	paramkeys = getoptparamkeys(madsdata)
	distributions = OrderedCollections.OrderedDict()
	for i = eachindex(paramkeys)
		p = madsdata["Parameters"][paramkeys[i]]
		if init_dist
			if haskey(p, "init_dist")
				distributions[paramkeys[i]] = Mads.getdistribution(p["init_dist"], "parameter")
				continue
			elseif haskey(p, "dist")
				distributions[paramkeys[i]] = Mads.getdistribution(p["dist"], "parameter")
				continue
			else
				minkey = haskey(p, "init_min") ? "init_dist" : "min"
				maxkey = haskey(p, "init_max") ? "init_dist" : "max"
			end
		else
			if haskey(p, "dist")
				distributions[paramkeys[i]] = Mads.getdistribution(p["dist"], "parameter")
				continue
			else
				minkey = "min"
				maxkey = "max"
			end
		end
		if haskey(p, minkey ) && haskey(p, maxkey )
			min = p[minkey]
			max = p[maxkey]
			if(min > max)
				madserror("Min/max for parameter `$(string(paramkeys[i]))` are messed up (min = $min; max = $max)!")
			end
			distributions[paramkeys[i]] = Distributions.Uniform(min, max)
		else
			madserror("""Probabilistic distribution of parameter `$(string(paramkeys[i]))` is not defined; "dist" or "min"/"max" are missing!""")
		end
	end
	return distributions
end

"""
Check parameter ranges for model parameters

$(DocumentFunction.documentfunction(checkparameterranges;
argtext=Dict("madsdata"=>"MADS problem dictionary")))
"""
function checkparameterranges(madsdata::AbstractDict)
	if !haskey(madsdata, "Parameters")
		madsinfo("No parameters in the provided dictionary!")
		return
	end
	paramkeys = Mads.getparamkeys(madsdata)
	optparamkeys = Mads.getoptparamkeys(madsdata)
	init = Mads.getparamsinit(madsdata)
	min = Mads.getparamsmin(madsdata)
	max = Mads.getparamsmax(madsdata)
	init_min = Mads.getparamsinit_min(madsdata)
	init_max = Mads.getparamsinit_max(madsdata)
	flag_error = false
	d = init - min .< 0
	if any(d)
		for i in findall(d)
			madswarn("Parameter `$(string(paramkeys[i]))` initial value is less than the minimum (init = $(init[i]); min = $(min[i]))!")
			if findfirst(optparamkeys, paramkeys[i]) > 0
				flag_error = true
			end
		end
	end
	d = max - init .< 0
	if any(d)
		for i in findall(d)
			madswarn("Parameter `$(string(paramkeys[i]))` initial value is greater than the maximum (init = $(init[i]); max = $(max[i]))!")
			if findfirst(optparamkeys, paramkeys[i]) > 0
				flag_error = true
			end
		end
	end
	d = max - min .< 0
	if any(d)
		for i in findall(d)
			madswarn("Parameter `$(string(paramkeys[i]))` maximum is less than the minimum (max = $(max[i]); min = $(min[i]))!")
			if findfirst(optparamkeys, paramkeys[i]) > 0
				flag_error = true
			end
		end
	end
	d = init_max - init_min .< 0
	if any(d)
		for i in findall(d)
			madswarn("Parameter `$(string(paramkeys[i]))` initialization maximum is less than the initialization minimum (init_max = $(init_max[i]); init_min = $(init_min[i]))!")
		end
	end
	d = init_min - min .< 0
	if any(d)
		for i in findall(d)
			madswarn("Parameter `$(string(paramkeys[i]))` initialization minimum is less than the minimum (init_min = $(init_min[i]); min = $(min[i]))!")
		end
	end
	d = max - init_max .< 0
	if any(d)
		for i in findall(d)
			madswarn("Parameter `$(string(paramkeys[i]))` initialization maximum is greater than the maximum (init_max = $(init_max[i]); max = $(min[i]))!")
		end
	end
	if flag_error
		madserror("Parameter ranges are incorrect!")
	end
	return nothing
end

function boundparameters!(madsdata::AbstractDict, parvec::AbstractVector)
	if !haskey(madsdata, "Parameters")
		return
	end
	parmin = Mads.getparamsmin(madsdata)
	parmax = Mads.getparamsmax(madsdata)
	i = parvec .> parmax
	parvec[i] .= parmax[i]
	i = parvec .< parmin
	parvec[i] .= parmin[i]
	return nothing
end
function boundparameters!(madsdata::AbstractDict, pardict::AbstractDict)
	if !haskey(madsdata, "Parameters")
		return
	end
	parkeys = getparamkeys(madsdata)
	parmin = Mads.getparamsmin(madsdata, parkeys)
	parmax = Mads.getparamsmax(madsdata, parkeys)
	for (i, k) in enumerate(parkeys)
		if pardict[k] > parmax[i]
			pardict[k] = parmax[i]
		elseif pardict[k] < parmin[i]
			pardict[k] = parmin[i]
		end
	end
	return nothing
end
@doc """
Bound model parameters based on their ranges

$(DocumentFunction.documentfunction(boundparameters!;
argtext=Dict("madsdata"=>"MADS problem dictionary","parvec"=>"Parameter vector","pardict"=>"Parameter dictionary")))
""" boundparameters!