import Pkg
!haskey(Pkg.installed(), "OrderedCollections") && Pkg.add("OrderedCollections")
import OrderedCollections

function madsmodelrun_internal_linearmodel(parameters::AbstractDict) # model run
	f(t) = parameters["a"] * t - parameters["b"] # a * t - b
	times = 1:4
	predictions = OrderedCollections.OrderedDict{String, Float64}(zip(map(i -> string("o", i), times), map(f, times)))
	return predictions
end
