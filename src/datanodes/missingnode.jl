struct MissingNode{D}
	data::D
	present::Vector{Bool}
end

MissingNode(d) = MissingNode(d, fill(true, nobs(d)))

Base.ndims(x::MissingNode) = Colon()
LearnBase.nobs(a::MissingNode) = length(a.present)
LearnBase.nobs(a::MissingNode, ::Type{ObsDim.Last}) = nobs(a.present)

function Base.reduce(::typeof(Mill.catobs), as::Vector{T}) where {T<:MissingNode}
    data = reduce(Mill.catobs, [x.data for x in as])
    present = reduce(vcat, [x.present for x in as])
    MissingNode(data, present)
end

get_true_index(present, i::Int) = sum(view(present, 1:i))
get_true_index(present, ii::Vector{Int}) = map(i -> get_true_index(present, i), ii)

function Base.getindex(x::MissingNode, i::VecOrRange)
	p = x.present[i]
	!any(p) && return(MissingNode(x.data[1:0], p))
	ii = get_true_index(x.present, i[p])
	@show typeof(p)
	MissingNode(x.data[ii], p)
end
