import JSON

if VERSION >= v"0.7"
	using OrderedCollections
else
	using DataStructures
end

parameters = JSON.parsefile("parameters.json"; dicttype=OrderedDict)

f(t) = parameters["a"] * t - parameters["b"] # a * t - b; linear model
times = 1:4
predictions = OrderedDict(zip(map(i -> string("o", i), times), map(f, times)))

jo = open("predictions.json", "w")
JSON.print(jo, predictions)
close(jo)
