import Distributed

#!/usr/bin/env julia -q --color=yes

function madsjl_help()
	println("Usage:    madsjl.jl {mads_dictionary_file}.mads commands ...")
	println("Examples: madsjl.jl my_mads_yaml_file.mads forward efast")
	println("          madsjl.jl diff my_mads_yaml_file1.mads my_mads_yaml_file2.mads")
	println("          madsjl.jl help")
end

function write_cmdline_hist()
	f = open("madsjl.cmdline_hist", "a+")
	write(f, join(["$(Dates.now()) :"; "madsjl.jl"; ARGS; "\n"], " ") )
	close(f)
end

if length(ARGS) < 1
	@warn("Command line error!")
	madsjl_help()
	quit()
end

if haskey(ENV, "SLURM_NODELIST")
	include(joinpath(Mads.dir, "src-interactive", "MadsParallel.jl"))
	setprocs()
end

madscommand = ARGS[1]
madsscript = joinpath(Mads.dir, "scripts", string(madscommand, ".jl"))
if isfile(madsscript)
	@info("Executing Mads script $(madsscript) ...")
	include(madsscript)
	@info("done.")
	write_cmdline_hist()
	quit()
elseif isfile(string(madscommand, ".jl"))
	madsscript = string(madscommand, ".jl")
	@info("Executing Mads script $(madsscript) ...")
	include(madsscript)
	@info("done.")
	write_cmdline_hist()
	quit()
end

@Distributed.everywhere import Mads
@Distributed.everywhere import JLD2

madsfile = ARGS[1]
if isfile(madsfile)
	@info("Reading $madsfile ...")
	@Distributed.everywhere md = Mads.loadmadsfile(madsfile)
	@Distributed.everywhere dir = Mads.getmadsproblemdir(md)
	@Distributed.everywhere root = Mads.getmadsrootname(md)
elseif ARGS[1] == "help"
	madsjl_help()
	quit()
elseif ARGS[1] == "testing"
	madsjl_help()
else
	@warn("Expecting Mads input file or Mads script as a first argument!")
	madsjl_help()
	quit()
end
for i = eachindex(ARGS)[begin+1:end]
	madscommand = ARGS[i]
	madsscript = joinpath(Mads.dir, "scripts", string(madscommand, ".jl"))
	if isfile(madsscript)
		@info("Executing Mads script $(madsscript) ...")
		include(madsscript)
	elseif isfile(string(madscommand, ".jl"))
		madsscript = string(madscommand, ".jl")
		@info("Executing Mads script $(madsscript) ...")
		include(madsscript)
	else
		@info("Executing Mads command $madscommand (Mads.$madscommand) ...")
		result = Core.eval(Mads, Meta.parse("Mads.$(madscommand)(md)"))
		f = "$(dir)/$(root)_$(madscommand)_results.jld2"
		JLD2.savef(f, result)
		Base.display(result)
		println("")
		@info("Results are saved in $(f)!")
	end
	@info("done.")
end
write_cmdline_hist()
