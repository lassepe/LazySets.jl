import Base: rand,
             ∈

export ZeroSet,
       linear_map

"""
    ZeroSet{N} <: AbstractSingleton{N}

Type that represents the zero set, i.e., the set that only contains the origin.

### Fields

- `dim` -- the ambient dimension of this zero set
"""
struct ZeroSet{N} <: AbstractSingleton{N}
    dim::Int
end

isoperationtype(::Type{<:ZeroSet}) = false
isconvextype(::Type{<:ZeroSet}) = true

# default constructor of type Float64
ZeroSet(dim::Int) = ZeroSet{Float64}(dim)


# --- AbstractSingleton interface functions ---


"""
    element(S::ZeroSet{N}) where {N}

Return the element of a zero set.

### Input

- `S` -- zero set

### Output

The element of the zero set, i.e., a zero vector.
"""
function element(S::ZeroSet{N}) where {N}
    return zeros(N, S.dim)
end

"""
    element(S::ZeroSet{N}, ::Int) where {N}

Return the i-th entry of the element of a zero set.

### Input

- `S` -- zero set
- `i` -- dimension

### Output

The i-th entry of the element of the zero set, i.e., 0.
"""
function element(S::ZeroSet{N}, ::Int) where {N}
    return zero(N)
end


# --- ConvexSet interface functions ---


"""
    dim(Z::ZeroSet)

Return the ambient dimension of this zero set.

### Input

- `Z` -- a zero set, i.e., a set that only contains the origin

### Output

The ambient dimension of the zero set.
"""
function dim(Z::ZeroSet)
    return Z.dim
end

"""
    σ(d::AbstractVector, Z::ZeroSet)

Return the support vector of a zero set.

### Input

- `d` -- direction
- `Z` -- a zero set, i.e., a set that only contains the origin

### Output

The returned value is the origin since it is the only point that belongs to this
set.
"""
function σ(d::AbstractVector, Z::ZeroSet)
    @assert length(d) == dim(Z) "the direction has the wrong dimension"
    return element(Z)
end

"""
    ρ(d::AbstractVector, Z::ZeroSet)

Evaluate the support function of a zero set in a given direction.

### Input

- `d` -- direction
- `Z` -- a zero set, i.e., a set that only contains the origin

### Output

`0`.
"""
function ρ(d::AbstractVector, Z::ZeroSet)
    @assert length(d) == dim(Z) "the direction has the wrong dimension"
    N = promote_type(eltype(d), eltype(Z))
    return zero(N)
end

"""
    ∈(x::AbstractVector, Z::ZeroSet)

Check whether a given point is contained in a zero set.

### Input

- `x` -- point/vector
- `Z` -- zero set

### Output

`true` iff ``x ∈ Z``.

### Examples

```jldoctest
julia> Z = ZeroSet(2);

julia> [1.0, 0.0] ∈ Z
false
julia> [0.0, 0.0] ∈ Z
true
```
"""
function ∈(x::AbstractVector, Z::ZeroSet)
    @assert length(x) == dim(Z)

    N = promote_type(eltype(x), eltype(Z))
    return all(==(zero(N)), x)
end

"""
    rand(::Type{ZeroSet}; [N]::Type{<:Real}=Float64, [dim]::Int=2,
         [rng]::AbstractRNG=GLOBAL_RNG, [seed]::Union{Int, Nothing}=nothing)

Create a zero set (note that there is nothing to randomize).

### Input

- `ZeroSet` -- type for dispatch
- `N`       -- (optional, default: `Float64`) numeric type
- `dim`     -- (optional, default: 2) dimension
- `rng`     -- (optional, default: `GLOBAL_RNG`) random number generator
- `seed`    -- (optional, default: `nothing`) seed for reseeding

### Output

The (only) zero set of the given numeric type and dimension.
"""
function rand(::Type{ZeroSet};
              N::Type{<:Real}=Float64,
              dim::Int=2,
              rng::AbstractRNG=GLOBAL_RNG,
              seed::Union{Int, Nothing}=nothing)
    rng = reseed(rng, seed)
    return ZeroSet{N}(dim)
end

"""
    linear_map(M::AbstractMatrix, Z::ZeroSet)

Concrete linear map of a zero set.

### Input

- `M` -- matrix
- `Z` -- zero set

### Output

The zero set whose dimension matches the output dimension of the given matrix.
"""
function linear_map(M::AbstractMatrix, Z::ZeroSet)
    @assert dim(Z) == size(M, 2) "a linear map of size $(size(M)) cannot be " *
                                 "applied to a set of dimension $(dim(Z))"

    return ZeroSet(size(M, 1))
end

"""
    translate(Z::ZeroSet, v::AbstractVector)

Translate (i.e., shift) a zero set by a given vector.

### Input

- `Z` -- zero set
- `v` -- translation vector

### Output

A singleton containing the vector `v`.
"""
function translate(Z::ZeroSet, v::AbstractVector)
    @assert length(v) == dim(Z) "cannot translate a $(dim(Z))-dimensional " *
                                "set by a $(length(v))-dimensional vector"
    return Singleton(v)
end


# --- AbstractCentrallySymmetric interface functions ---


"""
    center(Z::ZeroSet{N}, i::Int) where {N}

Return the center along a given dimension of a zero set.

### Input

- `Z` -- zero set
- `i` -- dimension of interest

### Output

The center along a given dimension of the zero set.
"""
@inline function center(Z::ZeroSet{N}, i::Int) where {N}
    @boundscheck _check_bounds(Z, i)
    return zero(N)
end

"""
    rectify(Z::ZeroSet)

Concrete rectification of a zero set.

### Input

- `Z` -- zero set

### Output

The same set.
"""
function rectify(Z::ZeroSet)
    return Z
end
