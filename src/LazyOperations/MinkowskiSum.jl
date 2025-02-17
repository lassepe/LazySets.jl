import Base: +, getindex, isempty

export MinkowskiSum, ⊕,
       MinkowskiSum!,
       swap

"""
    MinkowskiSum{N, S1<:ConvexSet{N}, S2<:ConvexSet{N}} <: ConvexSet{N}

Type that represents the Minkowski sum of two sets, i.e., the set

```math
X \\oplus Y = \\{x + y : x \\in X, y \\in Y\\}.
```

### Fields

- `X` -- first set
- `Y` -- second set

### Notes

The `ZeroSet` is the neutral element and the `EmptySet` is the absorbing element
for `MinkowskiSum`.

The Minkowski sum preserves convexity: if the set arguments are convex, then
their Minkowski sum is convex as well.
"""
struct MinkowskiSum{N, S1<:ConvexSet{N}, S2<:ConvexSet{N}} <: ConvexSet{N}
    X::S1
    Y::S2

    # default constructor with dimension check
    function MinkowskiSum(X::ConvexSet{N}, Y::ConvexSet{N}) where {N}
        @assert dim(X) == dim(Y) "sets in a Minkowski sum must have the same dimension"
        return new{N, typeof(X), typeof(Y)}(X, Y)
    end
end

isoperationtype(::Type{<:MinkowskiSum}) = true
isconvextype(::Type{MinkowskiSum{N, S1, S2}}) where {N, S1, S2} = isconvextype(S1) && isconvextype(S2)
is_polyhedral(ms::MinkowskiSum) = is_polyhedral(ms.X) && is_polyhedral(ms.Y)

# ZeroSet is the neutral element for MinkowskiSum
@neutral(MinkowskiSum, ZeroSet)

# EmptySet and Universe are the absorbing elements for MinkowskiSum
@absorbing(MinkowskiSum, EmptySet)
# @absorbing(MinkowskiSum, Universe)  # TODO problematic

"""
    X + Y

Convenience constructor for Minkowski sum.

### Input

- `X` -- a set
- `Y` -- another set

### Output

The symbolic Minkowski sum of ``X`` and ``Y``.
"""
+(X::ConvexSet, Y::ConvexSet) = MinkowskiSum(X, Y)

"""
    ⊕(X::ConvexSet, Y::ConvexSet)

Unicode alias constructor ⊕ (`oplus`) for the lazy Minkowski sum operator.

### Notes

Write `\\oplus[TAB]` to enter this symbol.
"""
⊕(X::ConvexSet, Y::ConvexSet) = MinkowskiSum(X, Y)

"""
    swap(ms::MinkowskiSum)

Return a new `MinkowskiSum` object with the arguments swapped.

### Input

- `ms` -- Minkowski sum of two sets

### Output

A new `MinkowskiSum` object with the arguments swapped.
"""
function swap(ms::MinkowskiSum)
    return MinkowskiSum(ms.Y, ms.X)
end

"""
    dim(ms::MinkowskiSum)

Return the dimension of a Minkowski sum.

### Input

- `ms` -- Minkowski sum

### Output

The ambient dimension of the Minkowski sum.
"""
function dim(ms::MinkowskiSum)
    return dim(ms.X)
end

"""
    σ(d::AbstractVector, ms::MinkowskiSum)

Return the support vector of a Minkowski sum.

### Input

- `d`  -- direction
- `ms` -- Minkowski sum

### Output

The support vector in the given direction.
If the direction has norm zero, the result depends on the summand sets.

### Algorithm

The support vector in direction ``d`` of the Minkowski sum of two sets ``X``
and ``Y`` is the sum of the support vectors of ``X`` and ``Y`` in direction
``d``.
"""
function σ(d::AbstractVector, ms::MinkowskiSum)
    return σ(d, ms.X) + σ(d, ms.Y)
end

"""
    ρ(d::AbstractVector, ms::MinkowskiSum)

Return the support function of a Minkowski sum.

### Input

- `d`  -- direction
- `ms` -- Minkowski sum

### Output

The support function in the given direction.

### Algorithm

The support function in direction ``d`` of the Minkowski sum of two sets ``X``
and ``Y`` is the sum of the support functions of ``X`` and ``Y`` in direction
``d``.
"""
function ρ(d::AbstractVector, ms::MinkowskiSum)
    return ρ(d, ms.X) + ρ(d, ms.Y)
end

"""
    isbounded(ms::MinkowskiSum)

Determine whether a Minkowski sum is bounded.

### Input

- `ms` -- Minkowski sum

### Output

`true` iff both wrapped sets are bounded.
"""
function isbounded(ms::MinkowskiSum)
    return isbounded(ms.X) && isbounded(ms.Y)
end

function isboundedtype(::Type{MinkowskiSum{N, S1, S2}}) where {N, S1, S2}
    return isboundedtype(S1) && isboundedtype(S2)
end

"""
    isempty(ms::MinkowskiSum)

Return if a Minkowski sum is empty or not.

### Input

- `ms` -- Minkowski sum

### Output

`true` iff any of the wrapped sets are empty.
"""
function isempty(ms::MinkowskiSum)
    return isempty(ms.X) || isempty(ms.Y)
end

"""
    center(ms::MinkowskiSum)

Return the center of a Minkowski sum of centrally-symmetric sets.

### Input

- `ms` -- Minkowski sum of centrally-symmetric sets

### Output

The center of the Minkowski sum.
"""
function center(ms::MinkowskiSum)
    center(ms.X) + center(ms.Y)
end

"""
    constraints_list(ms::MinkowskiSum)

Return the list of constraints of a lazy Minkowski sum of two polyhedral sets.

### Input

- `ms` -- Minkowski sum of two polyhedral sets

### Output

The list of constraints of the Minkowski sum.

### Algorithm

We compute a concrete set representation via `minkowski_sum` and call
`constraints_list` on the result.
"""
function constraints_list(ms::MinkowskiSum)
    return constraints_list(minkowski_sum(ms.X, ms.Y))
end

"""
    ∈(x::AbstractVector, ms::MinkowskiSum{N, S1, S2}) where {N, S1<:AbstractSingleton, S2<:ConvexSet}

Check whether a given point is contained in the Minkowski sum of a singleton
and a set.

### Input

- `x`  -- point
- `ms` -- lazy Minkowski sum of a singleton and a set

### Output

`true` iff ``x ∈ ms``.

### Algorithm

Note that ``x ∈ (S ⊕ P)``, where ``S`` is a singleton set, ``S = \\{s\\}`` and
``P`` is a set, if and only if ``(x-s) ∈ P``.
"""
function ∈(x::AbstractVector, ms::MinkowskiSum{N, S1, S2}) where {N, S1<:AbstractSingleton, S2<:ConvexSet}
    return _in_singleton_msum(x, ms.X, ms.Y)
end

# symmetric method
function ∈(x::AbstractVector, ms::MinkowskiSum{N, <:ConvexSet, <:AbstractSingleton}) where {N}
    return _in_singleton_msum(x, ms.Y, ms.X)
end

# disambiguation
function ∈(x::AbstractVector, ms::MinkowskiSum{N, <:AbstractSingleton, <:AbstractSingleton}) where {N}
    return _in_singleton_msum(x, ms.X, ms.Y)
end

@inline _in_singleton_msum(x, X, Y) = (x - element(X)) ∈ Y

function concretize(ms::MinkowskiSum)
    return minkowski_sum(concretize(ms.X), concretize(ms.Y))
end

"""
    vertices_list(ms::MinkowskiSum)

Return the list of vertices for the Minkowski sum of two sets.

### Input

- `ms` -- Minkowski sum of two sets

### Output

The list of vertices of the Minkowski sum of two sets.

### Algorithm

We compute the concrete Minkowski sum (via `minkowski_sum`) and call
`vertices_list` on the result.
"""
function vertices_list(ms::MinkowskiSum)
    return vertices_list(minkowski_sum(ms.X, ms.Y))
end
