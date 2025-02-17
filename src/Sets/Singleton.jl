import Base.rand

export Singleton

"""
    Singleton{N, VN<:AbstractVector{N}} <: AbstractSingleton{N}

Type that represents a singleton, that is, a set with a unique element.

### Fields

- `element` -- the only element of the set

### Examples

```jldoctest
julia> Singleton([1.0, 2.0])
Singleton{Float64, Vector{Float64}}([1.0, 2.0])

julia> Singleton(1.0, 2.0)  # convenience constructor from numbers
Singleton{Float64, Vector{Float64}}([1.0, 2.0])
```
"""
struct Singleton{N, VN<:AbstractVector{N}} <: AbstractSingleton{N}
    element::VN
end

function Singleton(args::Real...)
    return Singleton(collect(args))
end

isoperationtype(::Type{<:Singleton}) = false
isconvextype(::Type{<:Singleton}) = true

# --- AbstractSingleton interface functions ---


"""
    element(S::Singleton)

Return the element of a singleton.

### Input

- `S` -- singleton

### Output

The element of the singleton.
"""
function element(S::Singleton)
    return S.element
end

"""
    element(S::Singleton, i::Int)

Return the i-th entry of the element of a singleton.

### Input

- `S` -- singleton
- `i` -- dimension

### Output

The i-th entry of the element of the singleton.
"""
function element(S::Singleton, i::Int)
    return S.element[i]
end


# --- ConvexSet interface functions ---


"""
    rand(::Type{Singleton}; [N]::Type{<:Real}=Float64, [dim]::Int=2,
         [rng]::AbstractRNG=GLOBAL_RNG, [seed]::Union{Int, Nothing}=nothing)

Create a random singleton.

### Input

- `Singleton` -- type for dispatch
- `N`         -- (optional, default: `Float64`) numeric type
- `dim`       -- (optional, default: 2) dimension
- `rng`       -- (optional, default: `GLOBAL_RNG`) random number generator
- `seed`      -- (optional, default: `nothing`) seed for reseeding

### Output

A random singleton.

### Algorithm

The element is a normally distributed vector with entries of mean 0 and standard
deviation 1.
"""
function rand(::Type{Singleton};
              N::Type{<:Real}=Float64,
              dim::Int=2,
              rng::AbstractRNG=GLOBAL_RNG,
              seed::Union{Int, Nothing}=nothing)
    rng = reseed(rng, seed)
    element = randn(rng, N, dim)
    return Singleton(element)
end

"""
    translate(S::Singleton, v::AbstractVector)

Translate (i.e., shift) a singleton by a given vector.

### Input

- `S` -- singleton
- `v` -- translation vector

### Output

A translated singleton.

### Algorithm

We add the vector to the point in the singleton.

### Notes

See also [`translate!(::Singleton, ::AbstractVector)`](@ref) for the in-place version.
"""
function translate(S::Singleton, v::AbstractVector)
    return translate!(copy(S), v)
end

"""
    translate!(S::Singleton, v::AbstractVector)

Translate (i.e., shift) a singleton by a given vector, in-place.

### Input

- `S` -- singleton
- `v` -- translation vector

### Output

The singleton `S` translated by `v`.

### Algorithm

We add the vector to the point in the singleton.

### Notes

See also [`translate(::Singleton, ::AbstractVector)`](@ref) for the out-of-place version.
"""
function translate!(S::Singleton, v::AbstractVector)
    @assert length(v) == dim(S) "cannot translate a $(dim(S))-dimensional " *
                                "set by a $(length(v))-dimensional vector"
    e = element(S)
    e .+= v
    return S
end

"""
    rectify(S::Singleton)

Concrete rectification of a singleton.

### Input

- `S` -- singleton

### Output

The `Singleton` that corresponds to the rectification of `S`.
"""
function rectify(S::Singleton)
    return Singleton(rectify(element(S)))
end

"""
    project(S::Singleton, block::AbstractVector{Int}; kwargs...)

Concrete projection of a singleton.

### Input

- `S`     -- singleton
- `block` -- block structure, a vector with the dimensions of interest

### Output

A set representing the projection of the singleton `S` on the dimensions
specified by `block`.
"""
function project(S::Singleton, block::AbstractVector{Int}; kwargs...)
    return Singleton(element(S)[block])
end

function permute(S::Singleton, p::AbstractVector{Int})
    e = element(S)[p]
    return Singleton(e)
end
