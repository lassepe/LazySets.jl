import Base: rand,
             ∈,
             isempty

export EmptySet, ∅,
       an_element,
       linear_map

"""
    EmptySet{N} <: ConvexSet{N}

Type that represents the empty set, i.e., the set with no elements.
"""
struct EmptySet{N} <: ConvexSet{N}
    dim::Int
end

isoperationtype(::Type{<:EmptySet}) = false
isconvextype(::Type{<:EmptySet}) = true

# default constructor of type Float64
EmptySet(dim::Int) = EmptySet{Float64}(dim)

"""
    ∅

Alias for `EmptySet{Float64}`.
"""
const ∅ = EmptySet{Float64}


# --- ConvexSet interface functions ---


"""
    dim(∅::EmptySet)

Return the dimension of an empty set.

### Input

- `∅` -- an empty set

### Output

The dimension of the empty set.
"""
function dim(∅::EmptySet)
    return ∅.dim
end

"""
    σ(d::AbstractVector, ∅::EmptySet)

Return the support vector of an empty set.

### Input

- `d` -- direction
- `∅` -- empty set

### Output

An error.
"""
function σ(d::AbstractVector, ∅::EmptySet)
    error("the support vector of an empty set does not exist")
end

"""
    ρ(d::AbstractVector, ∅::EmptySet)

Evaluate the support function of an empty set in a given direction.

### Input

- `d` -- direction
- `∅` -- empty set

### Output

An error.
"""
function ρ(d::AbstractVector, ∅::EmptySet)
    error("the support function of an empty set does not exist")
end

function isboundedtype(::Type{<:EmptySet})
    return true
end

"""
    isbounded(∅::EmptySet)

Determine whether an empty set is bounded.

### Input

- `∅` -- empty set

### Output

`true`.
"""
function isbounded(::EmptySet)
    return true
end

"""
    isuniversal(∅::EmptySet{N}, [witness]::Bool=false) where {N}

Check whether an empty is universal.

### Input

- `∅`       -- empty set
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `false`
* If `witness` option is activated: `(false, v)` where ``v ∉ S``, although
  we currently throw an error
"""
function isuniversal(∅::EmptySet{N}, witness::Bool=false) where {N}
    if witness
        return (false, zeros(N, dim(∅)))
    else
        return false
    end
end

"""
    ∈(x::AbstractVector, ∅::EmptySet)

Check whether a given point is contained in an empty set.

### Input

- `x` -- point/vector
- `∅` -- empty set

### Output

The output is always `false`.

### Examples

```jldoctest
julia> [1.0, 0.0] ∈ ∅(2)
false
```
"""
function ∈(x::AbstractVector, ∅::EmptySet)
    return false
end

"""
    an_element(∅::EmptySet)

Return some element of an empty set.

### Input

- `∅` -- empty set

### Output

An error.
"""
function an_element(∅::EmptySet)
    error("an empty set does not have any element")
end

"""
    rand(::Type{EmptySet}; [N]::Type{<:Real}=Float64, [dim]::Int=0,
         [rng]::AbstractRNG=GLOBAL_RNG, [seed]::Union{Int, Nothing}=nothing)

Create an empty set (note that there is nothing to randomize).

### Input

- `EmptySet` -- type for dispatch
- `N`        -- (optional, default: `Float64`) numeric type
- `dim`      -- (optional, default: 2) dimension
- `rng`      -- (optional, default: `GLOBAL_RNG`) random number generator
- `seed`     -- (optional, default: `nothing`) seed for reseeding

### Output

The (only) empty set of the given numeric type and dimension.
"""
function rand(::Type{EmptySet};
              N::Type{<:Real}=Float64,
              dim::Int=2,
              rng::AbstractRNG=GLOBAL_RNG,
              seed::Union{Int, Nothing}=nothing)
    rng = reseed(rng, seed)
    return EmptySet{N}(dim)
end

"""
    isempty(∅::EmptySet)

Return if the empty set is empty or not.

### Input

- `∅` -- empty set

### Output

`true`.
"""
function isempty(∅::EmptySet)
    return true
end

"""
    norm(S::EmptySet, [p]::Real=Inf)

Return the norm of an empty set.
It is the norm of the enclosing ball (of the given ``p``-norm) of minimal volume
that is centered in the origin.

### Input

- `S` -- empty set
- `p` -- (optional, default: `Inf`) norm

### Output

An error.
"""
function norm(S::EmptySet, p::Real=Inf)
    error("an empty set does not have a norm")
end

"""
    radius(S::EmptySet, [p]::Real=Inf)

Return the radius of an empty set.
It is the radius of the enclosing ball (of the given ``p``-norm) of minimal
volume with the same center.

### Input

- `S` -- empty set
- `p` -- (optional, default: `Inf`) norm

### Output

An error.
"""
function radius(S::EmptySet, p::Real=Inf)
    error("an empty set does not have a radius")
end

"""
    diameter(S::EmptySet, [p]::Real=Inf)

Return the diameter of an empty set.
It is the maximum distance between any two elements of the set, or,
equivalently, the diameter of the enclosing ball (of the given ``p``-norm) of
minimal volume with the same center.

### Input

- `S` -- empty set
- `p` -- (optional, default: `Inf`) norm

### Output

An error.
"""
function diameter(S::EmptySet, p::Real=Inf)
    error("an empty set does not have a diameter")
end

"""
    vertices(∅::EmptySet{N}) where {N}

Construct an iterator over the vertices of an empty set.

### Input

- `∅` -- empty set

### Output

The empty iterator, as the empty set does not contain any vertices.
"""
function vertices(∅::EmptySet{N}) where {N}
    return EmptyIterator{Vector{N}}()
end

"""
    vertices_list(∅::EmptySet{N}) where {N}

Return the list of vertices of an empty set.

### Input

- `∅` -- empty set

### Output

The empty list of vertices, as the empty set does not contain any vertices.
"""
function vertices_list(∅::EmptySet{N}) where {N}
    return Vector{Vector{N}}()
end

"""
    linear_map(M::AbstractMatrix{N}, ∅::EmptySet{N}) where {N}

Return the linear map of an empty set.

### Input

- `M` -- matrix
- `∅` -- empty set

### Output

The empty set.
"""
linear_map(M::AbstractMatrix{N}, ∅::EmptySet{N}) where {N} = ∅

"""
    translate(∅::EmptySet, v::AbstractVector)

Translate (i.e., shift) an empty set by a given vector.

### Input

- `∅` -- empty set
- `v` -- translation vector

### Output

The empty set.
"""
function translate(∅::EmptySet, v::AbstractVector)
    return translate!(∅, v)
end

function translate!(∅::EmptySet, v::AbstractVector)
    @assert length(v) == dim(∅) "cannot translate a $(dim(∅))-dimensional " *
                                "set by a $(length(v))-dimensional vector"
    return ∅
end

"""
    plot_recipe(∅::EmptySet{N}, [ε]=zero(N)) where {N}

Convert an empty set to a sequence of points for plotting.
In the special case of an empty set, we define the sequence as `nothing`.

### Input

- `∅` -- empty set
- `ε` -- (optional, default: `0`) ignored, used for dispatch

### Output

`nothing`.
"""
function plot_recipe(∅::EmptySet{N}, ε=zero(N)) where {N}
    return []
end

"""
    area(∅::EmptySet{N}) where {N}

Return the area of an empty set.

### Input

- `∅` -- empty set

### Output

The zero element of type `N`.
"""
function area(∅::EmptySet{N}) where {N}
    return zero(N)
end

function project(∅::EmptySet{N}, block::AbstractVector{Int}; kwargs...) where {N}
    return EmptySet{N}(length(block))
end

function volume(∅::EmptySet{N}) where {N}
    return zero(N)
end
