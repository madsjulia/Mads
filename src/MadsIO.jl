import DataStructures

"""
Load MADS input file defining a MADS problem dictionary

- `Mads.loadmadsfile(filename)`
- `Mads.loadmadsfile(filename; julia=false)`
- `Mads.loadmadsfile(filename; julia=true)`

Arguments:

- `filename` : input file name (e.g. `input_file_name.mads`)
- `julia` : if `true`, force using `julia` parsing functions; if `false` (default), use `python` parsing functions [boolean]

Returns:

- `madsdata` : Mads problem dictionary

Example: `md = loadmadsfile("input_file_name.mads")`
"""
function loadmadsfile(filename::String; julia::Bool=false, format::String="yaml")
	if format == "yaml"
		madsdata = loadyamlfile(filename; julia=julia) # this is not OrderedDict()
	elseif format == "json"
		madsdata = loadjsonfile(filename)
	end
	parsemadsdata!(madsdata)
	madsdata["Filename"] = filename
	if haskey(madsdata, "Observations")
		t = getobstarget(madsdata)
		isn = isnan(t)
		if any(isn)
			l = length(isn[isn.==true])
			if l == 1
				warn("There is 1 observation with a missing target!")
			else
				warn("There are $(l) observations with missing targets!")
			end
		end
	end
	return madsdata
end

"""
Parse loaded Mads problem dictionary

Arguments:

- `madsdata` : Mads problem dictionary
"""
function parsemadsdata!(madsdata::Associative)
	if haskey(madsdata, "Parameters")
		parameters = DataStructures.OrderedDict()
		for dict in madsdata["Parameters"]
			for key in keys(dict)
				if !haskey(dict[key], "exp") # it is a real parameter, not an expression
					parameters[key] = dict[key]
				else
					if !haskey(madsdata, "Expressions")
						madsdata["Expressions"] = DataStructures.OrderedDict()
					end
					madsdata["Expressions"][key] = dict[key]
				end
			end
		end
		madsdata["Parameters"] = parameters
	end
	addsourceparameters!(madsdata)
	if haskey(madsdata, "Parameters")
		parameters = madsdata["Parameters"]
		for key in keys(parameters)
			if !haskey(parameters[key], "init") && !haskey(parameters[key], "exp")
				Mads.madserror("""Parameter `$key` does not have initial value; add "init" value!""")
			end
			for v in ["init", "init_max", "init_min", "max", "min", "step"]
				if haskey(parameters[key], v)
					parameters[key][v] = float(parameters[key][v])
				end
			end
			if haskey(parameters[key], "log")
				flag = parameters[key]["log"]
				if flag == "yes" || flag == true
					parameters[key]["log"] = true
					for v in ["init", "init_max", "init_min", "max", "min", "step"]
						if haskey(parameters[key], v)
							if parameters[key][v] < 0
								Mads.madserror("""The value $v for Parameter $key cannot be log-transformed; it is negative!""")
							end
						end
					end
				else
					parameters[key]["log"] = false
				end
			end
		end
	end
	checkparameterranges(madsdata)
	if haskey(madsdata, "Wells")
		wells = DataStructures.OrderedDict()
		for dict in madsdata["Wells"]
			for key in keys(dict)
				wells[key] = dict[key]
				wells[key]["on"] = true
				for i = 1:length(wells[key]["obs"])
					for keys in keys(wells[key]["obs"][i])
						wells[key]["obs"][i] = wells[key]["obs"][i][keys]
					end
				end
			end
		end
		madsdata["Wells"] = wells
		Mads.wells2observations!(madsdata)
	elseif haskey(madsdata, "Observations") # TODO drop zero weight observations
		observations = DataStructures.OrderedDict()
		for dict in madsdata["Observations"]
			for key in keys(dict)
				observations[key] = dict[key]
			end
		end
		madsdata["Observations"] = observations
	end
	if haskey(madsdata, "Templates")
		templates = Array(Dict, length(madsdata["Templates"]))
		i = 1
		for dict in madsdata["Templates"]
			for key in keys(dict) # this should only iterate once
				templates[i] = dict[key]
			end
			i += 1
		end
		madsdata["Templates"] = templates
	end
	if haskey(madsdata, "Instructions")
		instructions = Array(Dict, length(madsdata["Instructions"]))
		i = 1
		for dict in madsdata["Instructions"]
			for key in keys(dict) # this should only iterate once
				instructions[i] = dict[key]
			end
			i += 1
		end
		madsdata["Instructions"] = instructions
	end
end

"""
Save MADS problem dictionary `madsdata` in MADS input file `filename`

- `Mads.savemadsfile(madsdata)`
- `Mads.savemadsfile(madsdata, "test.mads")`
- `Mads.savemadsfile(madsdata, parameters, "test.mads")`
- `Mads.savemadsfile(madsdata, parameters, "test.mads", explicit=true)`

Arguments:

- `madsdata` : Mads problem dictionary
- `parameters` : Dictinary with parameters (optional)
- `filename` : input file name (e.g. `input_file_name.mads`)
- `julia` : if `true` use Julia JSON module to save
- `explicit` : if `true` ignores MADS YAML file modifications and rereads the original input file
"""
function savemadsfile(madsdata::Associative, filename::String=""; julia::Bool=false, explicit::Bool=false)
	if filename == ""
		filename = setnewmadsfilename(madsdata)
	end
	dumpyamlmadsfile(madsdata, filename, julia=julia)
end

function savemadsfile(madsdata::Associative, parameters::Associative, filename::String=""; julia::Bool=false, explicit::Bool=false)
	if filename == ""
		filename = setnewmadsfilename(madsdata)
	end
	if explicit
		madsdata2 = loadyamlfile(madsdata["Filename"])
		for i = 1:length(madsdata2["Parameters"])
			pdict = madsdata2["Parameters"][i]
			paramname = collect(keys(pdict))[1]
			realparam = pdict[paramname]
			if haskey(realparam, "type") && realparam["type"] == "opt"
				oldinit = realparam["init"]
				realparam["init"] = parameters[paramname]
				newinit = realparam["init"]
			end
		end
		dumpyamlfile(filename, madsdata2, julia=julia)
	else
		madsdata2 = deepcopy(madsdata)
		setparamsinit!(madsdata2, parameters)
		dumpyamlmadsfile(madsdata2, filename, julia=julia)
	end
end

"Save calibration results"
function savecalibrationresults(madsdata::Associative, results)
	#TODO map estimated parameters on a new madsdata structure
	#TODO save madsdata in yaml file using dumpyamlmadsfile
	#TODO save residuals, predictions, observations (yaml?)
end

"""
Set a default MADS input file

`Mads.setmadsinputfile(filename)`

Arguments:

- `filename` : input file name (e.g. `input_file_name.mads`)
"""
function setmadsinputfile(filename::String)
	global madsinputfile = filename
end

"""
Get the default MADS input file set as a MADS global variable using `setmadsinputfile(filename)`

`Mads.getmadsinputfile()`

Arguments: `none`

Returns:

- `filename` : input file name (e.g. `input_file_name.mads`)
"""
function getmadsinputfile()
	return madsinputfile
end

"""
Get the MADS problem root name

`madsrootname = Mads.getmadsrootname(madsdata)`
"""
function getmadsrootname(madsdata::Associative; first=true, version=false)
	return getrootname(madsdata["Filename"]; first=first, version=version)
end

"""
Get the directory where the Mads data file is located

`Mads.getmadsproblemdir(madsdata)`

Example:

```
madsdata = Mads.loadmadsproblem("../../a.mads")
madsproblemdir = Mads.getmadsproblemdir(madsdata)
```

where `madsproblemdir` = `"../../"`
"""
function getmadsproblemdir(madsdata::Associative)
	dirname(madsdata["Filename"])
end

"""
Get the directory where the Mads data file is located

`Mads.getmadsproblemdirtail(madsdata)`

Example:

```
madsdata = Mads.loadmadsproblem("../example/a.mads")
madsproblemdirtail = Mads.getmadsproblemdirtail(madsdata)
```

where `madsproblemdirtail` = `"example"`
"""
function getmadsproblemdirtail(madsdata::Associative)
	splitdir(dirname(madsdata["Filename"]))[2]
end

"""
Get the directory where currently Mads is running

`problemdir = Mads.getmadsdir()`
"""
function getmadsdir()
	source_path = Base.source_path()
	if typeof(source_path) == Void
		problemdir = ""
	else
		problemdir = string((dirname(source_path)))
		madsinfo("Problem directory: $(problemdir)")
	end
	return problemdir
end

"""
Get file name root

Example:

```
r = Mads.getrootname("a.rnd.dat") # r = "a"
r = Mads.getrootname("a.rnd.dat", first=false) # r = "a.rnd"
```
"""
function getrootname(filename::String; first=true, version=false)
	d = splitdir(filename)
	s = split(d[2], ".")
	if !first && length(s) > 1
		r = join(s[1:end-1], ".")
	else
		r = s[1]
	end
	if version && ismatch(r"-v[0-9].$", r)
		rm = match(r"-v[0-9].$", r)
		r = r[1:rm.offset-1]
	end
	if length(d) > 1
		r = joinpath(d[1], r)
	end
	return r
end

"""
Get file name extension

Example:

```
ext = Mads.getextension("a.mads") # ext = "mads"
```
"""
function getextension(filename)
	d = splitdir(filename)
	s = split(d[2], ".")
	if length(s) > 1
		return s[end]
	else
		return ""
	end
end

"""
Get directory

Example:

```
d = Mads.getdir("a.mads") # d = "."
d = Mads.getdir("test/a.mads") # d = "test"
```
"""
function getdir(filename)
	d = splitdir(filename)[1]
	if d == ""
		d = "."
	end
	return d
end

"Get the directories where model outputs should be saved for MADS"
function getmodeloutputdirs(madsdata::Associative)
	directories = Array(String, 0)
	if haskey(madsdata, "Instructions") # Templates/Instructions
		for instruction in madsdata["Instructions"]
			filename = instruction["read"]
			push!(directories, getdir(filename))
		end
	end
	if haskey(madsdata, "JLDPredictions") # JLD
		for filename in vcat(madsdata["JLDPredictions"])
			push!(directories, getdir(filename))
		end
	end
	if haskey(madsdata, "JSONPredictions") # JSON
		for filename in vcat(madsdata["JSONPredictions"])
			push!(directories, getdir(filename))
		end
	end
	if haskey(madsdata, "YAMLPredictions") # YAML
		for filename in vcat(madsdata["YAMLPredictions"])
			push!(directories, getdir(filename))
		end
	end
	if haskey(madsdata, "ASCIIPredictions") # ASCII
		for filename in vcat(madsdata["ASCIIPredictions"])
			push!(directories, getdir(filename))
		end
	end
	directories = unique(directories)
	if length(directories) == 0
		directories = ["."]
	end
	return directories
end

"Set model input files; delete files where model output should be saved for MADS"
function setmodelinputs(madsdata::Associative, parameters::Associative; path::String=".")
	if haskey(madsdata, "Instructions") # Templates/Instructions
		for instruction in madsdata["Instructions"]
			filename = instruction["read"]
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
	end
	if haskey(madsdata, "Templates") # Templates/Instructions
		for template in madsdata["Templates"]
			filename = template["write"]
			Mads.rmfile(filename) # delete the parameter file links
		end
		writeparameters(madsdata, parameters)
	end
	#TODO move the writing into the "writeparameters" function
	if haskey(madsdata, "JLDParameters") # JLD
		for filename in vcat(madsdata["JLDParameters"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
		JLD.save("$(madsdata["JLDParameters"])", parameters) # create parameter files
	end
	if haskey(madsdata, "JLDPredictions") # JLD
		for filename in vcat(madsdata["JLDPredictions"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
	end
	if haskey(madsdata, "JSONParameters") # JSON
		for filename in vcat(madsdata["JSONParameters"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
		dumpjsonfile(madsdata["JSONParameters"], parameters) # create parameter files
	end
	if haskey(madsdata, "JSONPredictions") # JSON
		for filename in vcat(madsdata["JSONPredictions"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
	end
	if haskey(madsdata, "YAMLParameters") # YAML
		for filename in vcat(madsdata["YAMLParameters"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
		dumpyamlfile(joinpath(path, madsdata["YAMLParameters"]), parameters) # create parameter files
	end
	if haskey(madsdata, "YAMLPredictions") # YAML
		for filename in vcat(madsdata["YAMLPredictions"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
	end
	if haskey(madsdata, "ASCIIParameters") # ASCII
		filename = madsdata["ASCIIParameters"]
		Mads.rmfile(filename, path=path) # delete the parameter file links
		#TODO this does NOT work; `parameters` are not required to be Ordered Dictionary
		dumpasciifile(joinpath(path, madsdata["ASCIIParameters"]), values(parameters)) # create an ASCII parameter file
	end
	if haskey(madsdata, "ASCIIPredictions") # ASCII
		for filename in vcat(madsdata["ASCIIPredictions"])
			Mads.rmfile(filename, path=path) # delete the parameter file links
		end
	end
end

"Read model outputs saved for MADS"
function readmodeloutput(madsdata::Associative; obskeys::Vector=getobskeys(madsdata), path::String="")
	results = DataStructures.OrderedDict()
	if haskey(madsdata, "Instructions") # Templates/Instructions
		results = readobservations(madsdata, obskeys)
	end
	if haskey(madsdata, "JLDPredictions") # JLD
		for filename in vcat(madsdata["JLDPredictions"])
			results = merge(results, JLD.load(filename))
		end
	end
	if haskey(madsdata, "JSONPredictions") # JSON
		for filename in vcat(madsdata["JSONPredictions"])
			results = merge(results, loadjsonfile(filename))
		end
	end
	if haskey(madsdata, "YAMLPredictions") # YAML
		for filename in vcat(madsdata["YAMLPredictions"])
			results = merge(results, loadyamlfile(filename))
		end
	end
	if haskey(madsdata, "ASCIIPredictions") # ASCII
		predictions = loadasciifile(madsdata["ASCIIPredictions"])
		obsid=[convert(String,k) for k in obskeys]
		@assert length(obskeys) == length(predictions)
		results = merge(results, DataStructures.OrderedDict{String, Float64}(zip(obsid, predictions)))
	end
	return results
end

"""
Set new mads file name
"""
function setnewmadsfilename(madsdata::Associative)
	dir = getmadsproblemdir(madsdata)
	root = splitdir(getmadsrootname(madsdata))[2]
	if ismatch(r"-v[0-9].$", root)
		rm = match(r"-v([0-9]).$", root)
		l = rm.captures[1]
		s = split(rm.match, "v")
		v = parse(Int, s[2]) + 1
		l = length(s[2])
		f = "%0" * string(l) * "d"
		filename = "$(root[1:rm.offset-1])-v$(sprintf(f, v)).mads"
	else
		filename = "$(root)-rerun.mads"
	end
	return joinpath(dir, filename)
end

"""
Get files in the current directory or in a directory defined by `path` matching pattern `key` which can be a string or regular expression

- `Mads.searchdir("a")`
- `Mads.searchdir(r"[A-B]"; path = ".")`
- `Mads.searchdir(r".*\.cov"; path = ".")`

Arguments:

- `key` : matching pattern for Mads input files (string or regular expression accepted)
- `path` : search directory for the mads input files

Returns:

- `filename` : an array with file names matching the pattern in the specified directory
"""
searchdir(key::Regex; path::String = ".") = filter(x->ismatch(key, x), readdir(path))
searchdir(key::String; path::String = ".") = filter(x->contains(x, key), readdir(path))

"Filter dictionary keys based on a string or regular expression"
filterkeys(dict::Associative, key::Regex) = key == r"" ? collect(keys(dict)) : filter(x->ismatch(key, x), collect(keys(dict)))
filterkeys(dict::Associative, key::String = "") = key == "" ? collect(keys(dict)) : filter(x->contains(x, key), collect(keys(dict)))

"Find indexes for dictionary keys based on a string or regular expression"
indexkeys(dict::Associative, key::Regex) = key == r"" ? find(collect(keys(dict))) : find(x->ismatch(key, x), collect(keys(dict)))
indexkeys(dict::Associative, key::String = "") = key == "" ? find(collect(keys(dict))) : find(x->contains(x, key), collect(keys(dict)))

"Get dictionary values for keys based on a string or regular expression"
getdictvalues(dict::Associative, key::Regex) = map(y->(y, dict[y]), filterkeys(dict, key))
getdictvalues(dict::Associative, key::String = "") = map(y->(y, dict[y]), filterkeys(dict, key))

"Write `parameters` via MADS template (`templatefilename`) to an output file (`outputfilename`)"
function writeparametersviatemplate(parameters, templatefilename, outputfilename)
	tplfile = open(templatefilename) # open template file
	line = readline(tplfile) # read the first line that says "template $separator\n"
	if length(line) >= 10 && line[1:9] == "template "
		separator = line[10] # template separator
		lines = readlines(tplfile)
	else
		#it doesn't specify the separator -- assume it is '#'
		separator = '#'
		lines = [line; readlines(tplfile)]
	end
	close(tplfile)
	outfile = open(outputfilename, "w")
	for line in lines
		splitline = split(line, separator) # two separators are needed for each parameter
		if rem(length(splitline), 2) != 1
			error("The number of separators (\"$separator\") is not even in template file $templatefilename on line:\n$line")
		end
		for i = 1:div(length(splitline)-1, 2)
			write(outfile, splitline[2 * i - 1]) # write the text before the parameter separator
			Mads.madsinfo("Replacing " * strip(splitline[2 * i]) * " -> " * string(parameters[strip(splitline[2 * i])]), 1)
			write(outfile, string(parameters[strip(splitline[2 * i])])) # splitline[2 * i] in this case is parameter ID
		end
		write(outfile, splitline[end]) # write the rest of the line after the last separator
	end
	close(outfile)
end

"Write initial parameters"
function writeparameters(madsdata::Associative)
	paramsinit = getparamsinit(madsdata)
	paramkeys = getparamkeys(madsdata)
	writeparameters(madsdata, Dict(zip(paramkeys, paramsinit)))
end

"Write parameters"
function writeparameters(madsdata::Associative, parameters)
	expressions = evaluatemadsexpressions(madsdata, parameters)
	paramsandexps = merge(parameters, expressions)
	for template in madsdata["Templates"]
		writeparametersviatemplate(paramsandexps, template["tpl"], template["write"])
	end
end

"Convert an instruction line in the Mads instruction file into regular expressions"
function instline2regexs(instline::String)
	floatregex = r"\h*[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?"
	regex = r"@[^@]*@|w|![^!]*!"
	offset = 1
	regexs = Regex[]
	obsnames = String[]
	getparamhere = Bool[]
	while offset <= length(instline) && ismatch(regex, instline, offset - 1)#this may be a julia bug -- offset for ismatch and match seem to be based on zero vs. one indexing
		m = match(regex, instline, offset)
		if m == nothing
			Mads.madserror("match not found for instruction line:\n$instline\nnear \"$(instline[offset:end])\"")
		end
		offset = m.offset + length(m.match)
		if m.match[1] == '@'
			if isspace(m.match[end - 1])
				push!(regexs, Regex(string("\\h*", m.match[2:end - 1])))
			else
				push!(regexs, Regex(string("\\h*", m.match[2:end - 1], "[^\\s]*")))
			end
			push!(getparamhere, false)
		elseif m.match[1] == '!'
			push!(regexs, floatregex)
			if m.match[2:end - 1] != "dum"
				push!(obsnames, m.match[2:end - 1])
				push!(getparamhere, true)
			else
				push!(getparamhere, false)
			end
		elseif m.match == "w"
			push!(regexs, r"\h+")
			push!(getparamhere, false)
		else
			Mads.madserror("Unknown instruction file instruction: $(m.match)")
		end
	end
	return regexs, obsnames, getparamhere
end

"Match an instruction line in the Mads instruction file with model input file"
function obslineismatch(obsline::String, regexs::Array{Regex, 1})
	bigregex = Regex(string(map(x->x.pattern, regexs)...))
	return ismatch(bigregex, obsline)
end

"Get observations for a set of regular expressions"
function regexs2obs(obsline, regexs, obsnames, getparamhere)
	offset = 1
	obsnameindex = 1
	obsdict = Dict{String, Float64}()
	for i = 1:length(regexs)
		m = match(regexs[i], obsline, offset)
		if m == nothing
			Mads.madserror("match not found for $(regexs[i]) in observation line: $(strip(obsline)) (\"$(strip(obsline[offset:end]))\")")
		else
			if getparamhere[i]
				obsdict[obsnames[obsnameindex]] = parse(Float64, m.match)
				obsnameindex += 1
			end
		end
		offset = m.offset + length(m.match)
	end
	return obsdict
end

"Apply Mads instruction file `instructionfilename` to read model input file `inputfilename`"
function ins_obs(instructionfilename::String, inputfilename::String)
	instfile = open(instructionfilename, "r")
	obsfile = open(inputfilename, "r")
	obslineitr = eachline(obsfile)
	state = start(obslineitr)
	obsdict = Dict{String, Float64}()
	for instline in eachline(instfile)
		regexs, obsnames, getparamhere = instline2regexs(instline)
		gotmatch = false
		while !gotmatch && !done(obslineitr, state)
			obsline, state = next(obslineitr, state)
			if obslineismatch(obsline, regexs)
				merge!(obsdict, regexs2obs(obsline, regexs, obsnames, getparamhere))
				gotmatch = true
			end
		end
		if !gotmatch
			Mads.madserror("Did not get a match for instruction file ($instructionfilename) line:\n$instline")
		end
	end
	close(instfile)
	close(obsfile)
	return obsdict
end

"Read observations"
function readobservations(madsdata::Associative, obskeys::Vector=getobskeys(madsdata))
	observations = Dict()
	obscount = Dict(zip(obskeys, zeros(Int, length(obskeys))))
	for instruction in madsdata["Instructions"]
		obs = ins_obs(instruction["ins"], instruction["read"])
		for k in keys(obs)
			obscount[k] += 1
			observations[k] = obscount[k] > 1 ? observations[k] + obs[k] : obs[k]
		end
	end
	missing = 0
	c = 0
	for k in keys(obscount)
		c += 1
		if obscount[k] == 0
			missing += 1
			madsinfo("Observation $k is missing!", 1)
		elseif obscount[k] > 1
			observations[k] /= obscount[k]
			madsinfo("Observation $k detected $(obscount[k]) times; an average is computed")
		end
	end
	if missing > 0
		madswarn("Observations (total count = $(missing)) are missing!")
	end
	return observations
end

"Dump well data from MADS problem dictionary into a ASCII file"
function dumpwelldata(madsdata::Associative, filename::String)
	if haskey(madsdata, "Wells")
		outfile = open(filename, "w")
		write(outfile, "well_name, x_coord [m], x_coord [m], z_coord [m], time [years], concentration [ppb]\n")
		for n in keys(madsdata["Wells"])
			x = madsdata["Wells"]["$n"]["x"]
			y = madsdata["Wells"]["$n"]["y"]
			z0 = madsdata["Wells"]["$n"]["z0"]
			z1 = madsdata["Wells"]["$n"]["z1"]
			o = madsdata["Wells"]["$n"]["obs"]
			for i in 1:length(o)
				c = o[i]["c"]
				t = o[i]["t"]
				write(outfile, "$n, $x, $y, $z0, $t, $c\n")
			end
		end
		close(outfile)
	end
end

"Create a symbolic link of all the files in a directory `dirsource` in a directory `dirtarget`"
function symlinkdirfiles(dirsource::String, dirtarget::String)
	for f in readdir(dirsource)
		symlinkdir(f, dirtarget)
	end
end

"Create a symbolic link of a file `filename` in a directory `dirtarget`"
function symlinkdir(filename::String, dirtarget::String)
	filenametarget = joinpath(dirtarget, filename)
	if !islink(filenametarget) && !isdir(filenametarget) && !isfile(filenametarget)
		symlink(abspath(filename), filenametarget)
	end
end

"Remove directory"
function rmdir(dir::String; path::String="")
	if path != "" && path != "."
		dir = joinpath(path, dir)
	end
	if isdir(dir)
		rm(dir, recursive=true)
	end
end

"Remove file"
function rmfile(filename::String; path::String="")
	if path != "" && path != "."
		filename = joinpath(path, filename)
	end
	if isfile(filename)
		rm(filename)
	end
end

"Remove files with extension `ext`"
function rmfiles_ext(ext::String; path::String=".")
	for f in searchdir(Regex(string(".*\\.", ext)); path=path)
		rm(joinpath(path, f))
	end
end

"Remove files with root `root`"
function rmfiles_root(root::String; path::String=".")
	s = splitdir(root)
	if s[1] != ""
		path = s[1]
		root = s[2]
	end
	for f in searchdir(Regex(string(root, "\\..*")); path=path)
		rm(joinpath(path, f))
	end
end

"Create temporary directory"
function createtempdir(tempdirname::String)
	attempt = 0
	trying = true
	while trying
		try
			attempt += 1
			if !isdir(tempdirname)
				mkdir(tempdirname)
			end
			Mads.madsinfo("Created temporary directory: $(tempdirname)", 1)
			trying = false
		catch e
			sleep(attempt * 0.5)
			if attempt > 3
				madscritical("$(e)\nTemporary directory $tempdirname cannot be created!")
				trying = false
			end
		end
	end
end

"Link files in a temporary directory"
function linktempdir(madsproblemdir::String, tempdirname::String)
	attempt = 0
	trying = true
	while trying
		try
			attempt += 1
			Mads.symlinkdirfiles(madsproblemdir, tempdirname)
			Mads.madsinfo("Links created in temporary directory: $(tempdirname)", 1)
			trying = false
		catch e
			Mads.rmdir(tempdirname)
			sleep(attempt * 1)
			Mads.createtempdir(tempdirname)
			if attempt > 4
				madscritical("$(e)\nLinks cannot be created in temporary directory $tempdirname cannot be created!")
				trying = false
			end
		end
	end
end