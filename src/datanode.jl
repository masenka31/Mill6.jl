using LearnBase
using DataFrames

abstract type AbstractNode{C} end
abstract type AbstractBagNode{T <: AbstractNode, C} <: AbstractNode{C} end
abstract type AbstractTreeNode{N, C} <: AbstractNode{C} end

mutable struct ArrayNode{C} <: AbstractNode{C}
	data::AbstractArray
	metadata::C
end

mutable struct BagNode{T, C} <: AbstractBagNode{T, C}
	data::T
	bags::Bags
	metadata::C
end

mutable struct WeightedBagNode{W, T, C} <: AbstractBagNode{T, C}
	data::T
	bags::Bags
	weights::Vector{W}
	metadata::C
end

mutable struct TreeNode{N, C} <: AbstractTreeNode{N, C}
	data::NTuple{N, AbstractNode}
	metadata::C
	function TreeNode{N, C}(data::NTuple{N, AbstractNode}, metadata::C) where {N, C}
		assert(length(data) >= 1 && all(x -> nobs(x) == nobs(data[1]), data))
		new(data, metadata)
	end
end

ArrayNode(data::AbstractArray) = ArrayNode(data, nothing)
BagNode(data::AbstractNode, b) = BagNode(data, bag(b), nothing)
WeightedBagNode(data::AbstractNode, b, weights::Vector) = WeightedBagNode(data, bag(b), weights, nothing)
TreeNode(data::NTuple{N, AbstractNode}, metadata::C) where {N, C} = TreeNode{N, C}(data, metadata)
TreeNode(data) = TreeNode(data, nothing)

################################################################################

mapdata(f, x::ArrayNode) = ArrayNode(f(x.data), x.metadata)
mapdata(f, x::BagNode) = BagNode(mapdata(f, x.data), x.bags, x.metadata)
mapdata(f, x::WeightedBagNode) = WeightedBagNode(mapdata(f, x.data), x.bags, x.weights, x.metadata)
mapdata(f, x::TreeNode) = TreeNode(map(i -> mapdata(f, i), x.data), x.metadata)

################################################################################

LearnBase.nobs(a::ArrayNode) = size(a.data,2)
LearnBase.nobs(a::ArrayNode, ::Type{ObsDim.Last}) = nobs(a)
LearnBase.nobs(a::AbstractBagNode) = length(a.bags)
LearnBase.nobs(a::AbstractBagNode, ::Type{ObsDim.Last}) = nobs(a)
LearnBase.nobs(a::AbstractTreeNode) = nobs(a.data[1],ObsDim.Last)
LearnBase.nobs(a::AbstractTreeNode, ::Type{ObsDim.Last}) = nobs(a)

################################################################################

function Base.cat(a::T...) where T <: AbstractNode
	data = lastcat(map(d -> d.data, a)...)
	metadata = lastcat(Iterators.filter(i -> i!= nothing,map(d -> d.metadata,a))...)
	return T(data, metadata)
end

function Base.cat(a::BagNode...)
	data = lastcat(map(d -> d.data, a)...)
	metadata = lastcat(Iterators.filter(i -> i!= nothing,map(d -> d.metadata,a))...)
	bags = catbags(map(d -> d.bags, a)...)
	return BagNode(data, bags, metadata)
end

function Base.cat(a::WeightedBagNode...)
	data = lastcat(map(d -> d.data, a)...)
	metadata = lastcat(Iterators.filter(i -> i!= nothing,map(d -> d.metadata,a))...)
	bags = catbags(map(d -> d.bags, a)...)
	weights = lastcat(map(d -> d.weights, a)...)
	return WeightedBagNode(data, bags, weights, metadata)
end

function Base.cat(a::TreeNode...)
	data = lastcat(map(d -> d.data, a)...)
	metadata = lastcat(Iterators.filter(i -> i!= nothing,map(d -> d.metadata,a))...)
	return TreeNode(data, metadata)
end

lastcat(a::AbstractArray...) = hcat(a...)
lastcat(a::Vector...) = vcat(a...)
lastcat(a::DataFrame...) = vcat(a...)
lastcat(a::AbstractNode...) = cat(a...)
lastcat(a::Void...) = nothing
# enforces both the same length of the tuples and their structure
lastcat(a::NTuple{N, AbstractNode}...) where N = ((cat(d...) for d in zip(a...))...)
lastcat() = nothing

################################################################################

Base.getindex(x::T, i::VecOrRange) where T <: AbstractNode = T(subset(x.data, i), subset(x.metadata, i))

function Base.getindex(x::BagNode, i::VecOrRange)
	nb, ii = remapbag(x.bags, i)
	BagNode(subset(x.data,ii), nb, subset(x.metadata, ii))
end

function Base.getindex(x::WeightedBagNode, i::VecOrRange)
	nb, ii = remapbag(x.bags, i)
	WeightedBagNode(subset(x.data,ii), nb, subset(x.weights, ii), subset(x.metadata, ii))
end

Base.getindex(x::AbstractNode, i::Int) = x[i:i]
MLDataPattern.getobs(x::AbstractNode, i) = x[i]
MLDataPattern.getobs(x::AbstractNode, i, ::LearnBase.ObsDim.Undefined) = x[i]
MLDataPattern.getobs(x::AbstractNode, i, ::LearnBase.ObsDim.Last) = x[i]

subset(x::AbstractArray, i) = x[:, i]
subset(x::Vector, i) = x[i]
subset(x::AbstractNode, i) = x[i]
subset(x::DataFrame, i) = x[i, :]
subset(x::Void, i) = nothing
subset(xs::Tuple, i) = tuple(map(x -> x[i], xs)...)

################################################################################

Base.show(io::IO, n::AbstractNode) = ds_print(io, n)

ds_print(io::IO, n::ArrayNode; offset::Int=0) =
	paddedprint(io, "ArrayNode$(size(n.data))\n", offset=offset)

function ds_print(io::IO, n::BagNode{ArrayNode}; offset::Int=0)
	paddedprint(io,"BagNode$(size(n.data)) with $(length(n.bags)) bag(s)\n", offset=offset)
	ds_print(io, n.data, offset=offset + 2)
end

function ds_print(io::IO, n::BagNode; offset::Int=0)
	c = rand(1:256)
	paddedprint(io,"BagNode with $(length(n.bags)) bag(s)\n", offset=offset, color=c)
	ds_print(io, n.data, offset=offset + 2)
end

function ds_print(io::IO, n::WeightedBagNode{ArrayNode}; offset::Int=0)
	paddedprint(io, "WeightedNode$(size(n.data)) with $(length(n.bags)) bag(s) and weights Σw = $(sum(n.weights))\n", offset=offset)
end

function ds_print(io::IO, n::WeightedBagNode; offset::Int=0)
	c = rand(1:256)
	paddedprint(io, "WeightedNode with $(length(n.bags)) bag(s) and weights Σw = $(sum(n.weights))\n", offset=offset, color=c)
	ds_print(io, n.data, offset=offset + 2)
end

function ds_print(io::IO, n::AbstractTreeNode{N}; offset::Int=0) where {N}
	c = rand(1:256)
	paddedprint(io, "TreeNode{$N}(\n", offset=offset, color=c)
	foreach(m -> ds_print(io, m, offset=offset + 2), n.data)
	paddedprint(io, "           )\n", offset=offset, color=c)
end
