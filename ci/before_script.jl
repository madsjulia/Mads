Pkg = Base.require(Base.PkgId(Base.UUID(0x44cfe95a1eb252eab672e2afdf69b78f), "Pkg"))

try
	@info "Pkg.build(PyCall)"
	ENV["PYTHON"] = ""
	Pkg.build("PyCall")

	import PyCall

	@info "PyCall/deps/build.log:"
	print(read(joinpath(dirname(dirname(pathof(PyCall))), "deps", "build.log"), String))
catch
	@warn "PyCall does not work"
	ENV["MADS_NO_PYTHON"] = ""
end

try
	@info "Pkg.build(Cairo)"
	Pkg.build("Cairo")

	import Cairo

	@info "Cairo/deps/build.log:"
	print(read(joinpath(dirname(dirname(pathof(Cairo))), "deps", "build.log"), String))
catch
	@warn "Cairo does not work"
	ENV["MADS_NO_PYPLOT"] = ""
end

if ENV["MADS_NO_PYPLOT"] != "" && ENV["MADS_NO_PYTHON"] != ""
	try
		@info "Pkg.build(PyPlot)"
		Pkg.build("PyPlot")

		import PyPlot

		@info "PyPlot/deps/build.log:"
		print(read(joinpath(dirname(dirname(pathof(PyPlot))), "deps", "build.log"), String))
	catch
		@warn "PyPlot does not work"
		ENV["MADS_NO_PYPLOT"] = ""
	end
end

# @info "Pkg.add(Pkg.PackageSpec(url=joinpath(pwd(), "..")))"
# Pkg.add(Pkg.PackageSpec(url=joinpath(pwd(), "..")))

# @info "Pkg.build(Mads)"
# Pkg.build("Mads")

import Mads

@info "Mads/deps/build.log:"
print(read(joinpath(dirname(dirname(pathof(Mads))), "deps", "build.log"), String))

@info "Package versions"
show(stdout, "text/plain", Pkg.installed())
println()