"""
    ProductNode{T, C} <: AbstractProductNode

Data node representing a Cartesian product of several spaces each represented by subtree stored in iterable of type `T`. May store metadata of type `C`.

See also: [`AbstractProductNode`](@ref), [`AbstractMillNode`](@ref), [`ProductModel`](@ref).
"""
struct ProductNode{T, C} <: AbstractProductNode
    data::T
    metadata::C

    function ProductNode(data::Union{Tuple,NamedTuple,AbstractVector}, metadata=nothing)
        @assert length(data) ≥ 1 "Provide at least one subtree!"
        data = map(_arraynode, data)
        l = nobs(data[1])
        @assert all(n -> nobs(n) == l, data) "All subtrees must have an equal amount of instances!"
        new{typeof(data), typeof(metadata)}(data, metadata)
    end
end

"""
    ProductNode(dss, m=nothing)
    ProductNode(m=nothing; dss...)

Construct a new [`ProductNode`](@ref) with data `dss`, and metadata `m`.

`dss` should be a `Tuple` or `NamedTuple` and all its elements must contain
the same number of observations.

If any element of `dss` is not an [`AbstractMillNode`](@ref) it is first wrapped in
an [`ArrayNode`](@ref).

# Examples
```jldoctest
julia> ProductNode((ArrayNode(zeros(2, 2)), ArrayNode(Flux.onehotbatch([1, 2], 1:2))))
ProductNode 	# 2 obs, 16 bytes
  ├── ArrayNode(2×2 Array with Float64 elements) 	# 2 obs, 80 bytes
  └── ArrayNode(2×2 OneHotArray with Bool elements) 	# 2 obs, 64 bytes

julia> ProductNode(x1 = ArrayNode(NGramMatrix(["Hello", "world"])),
                   x2 = BagNode(ArrayNode([1 2; 3 4]), [1:3, 4:4]))
ProductNode 	# 2 obs, 48 bytes
  ├── x1: ArrayNode(2053×2 NGramMatrix with Int64 elements) 	# 2 obs, 146 bytes
  └── x2: BagNode 	# 2 obs, 96 bytes
            └── ArrayNode(2×2 Array with Int64 elements) 	# 2 obs, 80 bytes

julia> ProductNode([1 2 3])
ProductNode 	# 3 obs, 8 bytes
  └── ArrayNode(1×3 Array with Int64 elements) 	# 3 obs, 72 bytes

julia> ProductNode((ArrayNode([1 2; 3 4]), ArrayNode([1; 3])))
ERROR: AssertionError: All subtrees must have an equal amount of instances!
[...]
```

See also: [`AbstractProductNode`](@ref), [`AbstractMillNode`](@ref), [`ProductModel`](@ref).
"""
ProductNode(ds, args...) = ProductNode(tuple(ds), args...)
ProductNode(args...; ns...) = ProductNode(NamedTuple(ns), args...)

Flux.@functor ProductNode
mapdata(f, x::ProductNode) = ProductNode(map(i -> mapdata(f, i), x.data), x.metadata)

dropmeta(x::ProductNode) = ProductNode(map(dropmeta, x.data))

Base.getindex(x::ProductNode, i::Symbol) = x.data[i]
Base.keys(x::ProductNode) = keys(x.data)
Base.haskey(x::ProductNode{<:NamedTuple}, k::Symbol) = haskey(x.data, k)

_check_idxs(as::Vector{<:Union{Vector, Tuple}}) = all(isequal(length(as[1])), (length(a) for a in as))
_check_idxs(as::Vector{<:NamedTuple{K}}) where K = true
_check_idxs(as) = false

_cattrees(as::Vector{<:Vector}) = [reduce(catobs, [a[i] for a in as]) for i in eachindex(as[1])]
_cattrees(as::Vector{T}) where T <: Tuple = T(reduce(catobs, [a[i] for a in as]) for i in eachindex(as[1]))
_cattrees(as::Vector{T}) where T <: NamedTuple = T(reduce(catobs, [a[i] for a in as]) for i in keys(as[1]))
@generated function _cattrees(xs::Vector{NamedTuple{K, T}}) where {K, T}
    chs = map(K, T.parameters) do k, t
        :(reduce(catobs, $t[x.$k for x in xs]))
    end
    quote
        NamedTuple{$K}(tuple($(chs...)))
    end
end

function reduce(::typeof(catobs), as::Vector{<:ProductNode})
    ds = data.(as)
    if !_check_idxs(ds)
        ArgumentError("Trying to `catobs` `ProductNode`s with different subtrees") |> throw
    end
    ProductNode(_cattrees(ds), reduce(catobs, metadata.(as)))
end

Base.getindex(x::ProductNode, i::VecOrRange{<:Int}) = ProductNode(subset(data(x), i), subset(metadata(x), i))
Base.getindex(x::ProductNode{<:Vector}, i::VecOrRange{<:Int}) = ProductNode(map(x -> getindex(x, i), data(x)), subset(metadata(x), i))

Base.hash(e::ProductNode, h::UInt) = hash((e.data, e.metadata), h)
(e1::ProductNode == e2::ProductNode) = e1.data == e2.data && e1.metadata == e2.metadata
Base.isequal(e1::ProductNode, e2::ProductNode) = isequal(e1.data, e2.data) && isequal(e1.metadata, e2.metadata)
