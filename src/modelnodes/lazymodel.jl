struct LazyModel{Name,T} <: AbstractMillModel
    m::T
end

const LazyModel{Name} = LazyModel{Name, T} where {T}
LazyModel{Name}(m::M) where {Name, M} = LazyModel{Name,M}(m)

Flux.@functor LazyModel

function (m::LazyModel{Name})(x::LazyNode{Name}) where {Name}
    ds = unpack2mill(x)
    m.m(ds)
end

function HiddenLayerModel(m::LazyModel{N}, ds::LazyNode{N}, n) where {N}
    hm, o = HiddenLayerModel(m.m, unpack2mill(ds), n)
    return(LazyModel{N}(hm), o )
end

function mapactivations(hm::LazyModel{N}, x::LazyNode{N}, m::LazyModel{N}) where {N}
    ho, o = mapactivations(hm.m, unpack2mill(x), m.m)
end

function unpack2mill end

# Base.hash(m::LazyModel{T}, h::UInt) where {T} = hash((T, m.m), h)
# (m1::LazyModel{T} == m2::LazyModel{T}) where {T} = m1.m == m2.m