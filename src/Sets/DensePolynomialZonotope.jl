export DensePolynomialZonotope,
       dim,
       σ,
       polynomial_order,
       order,
       linear_map,
       scale

"""
    DensePolynomialZonotope{N, VT, VMT, MT} <: AbstractPolynomialZonotope{N}

Type that represents a polynomial zonotope.

### Fields

- `c`  -- starting point
- `E`  -- matrix of multi-indexed generators such that *all* indices have the same value
- `F`  -- matrix of multi-indexed generators such that *not all* indices have the same value
- `G`  -- matrix of single-indexed generators

### Notes

Polynomial zonotopes were introduced by M. Althoff in [1] and have been applied
as a non-convex set representation in the reachability problem of nonlinear ODEs.

Mathematically, a polynomial zonotope is defined as the tuple ``(c, E, F, G)``,
where:

- ``c ∈ \\mathbb{R}^n`` is the starting point (in some particular cases it corresponds
  to the center of a usual zonotope),

- ``E = [E^{[1]} ⋯ E^{[η]}]`` is an ``n × p × η(η+1)/2`` matrix with column-blocks

```math
E^{[i]} = [f^{([i], 1, 1, …, 1)} ⋯ f^{([i], p, p, …, p)}], \\qquad i = 1,…, η
```
called the matrix of *multi-indexed generators with equal indices*, where each
``f^{([i], k_1, k_2, …, k_i)}`` is an ``n``-vector,

- ``F = [F^{[2]} ⋯ F^{[η]}]`` is a matrix with column-blocks

```math
F^{[i]} = [f^{([i], 1, 1, …, 1, 2)} f^{([i], 1, 1, …, 1, 3)} ⋯ f^{([i], 1, 1, …, 1, p)} \\\\
f^{([i], 1, 1, …, 2, 2)} f^{([i], 1, 1, …, 2, 3)} ⋯ f^{([i], 1, 1, …, 2, p)} \\\\
f^{([i], 1, 1, …, 3, 3)} ⋯], \\qquad i = 1,…, η
```
called the matrix of *multi-indexed generators with unequal indices* (or, more accurately,
not-all-equal indices), where each ``f^{([i], k_1, k_2, …, k_i)}`` is an ``n``-vector,

- ``G = [G^{[1]} ⋯ G^{[q]}]`` is an ``n × q`` matrix with columns

```math
G^{[i]} = g^{(i)}, \\qquad i = 1,…, q
```
called the matrix of *single-indexed generators*, where each ``g^{(i)}`` is an
``n``-vector.

The polynomial zonotope ``(c, E, F, G)`` defines the set:

```math
\\mathcal{PZ} = \\left\\{ c + ∑_{j=1}^p β_j f^{([1], j)} + ∑_{j=1}^p ∑_{k=j}^p β_j β_k f^{([2], j, k)} + \\\\
+ … + ∑_{j=1}^p ∑_{k=j}^p ⋯ ∑_{m=ℓ}^p β_j β_k ⋯ β_m f^{([η], j, k, …, m)} + \\\\
+ ∑_{i=1}^q γ_i g^{(i)}, \\qquad β_i, γ_i ∈ [-1, 1] \\right\\},
```
where the number of factors in the final product, ``β_j β_k ⋯ β_m``, corresponds to
the polynomial order ``η``.

[1] M. Althoff in *Reachability analysis of nonlinear systems using conservative
    polynomialization and non-convex sets*, Hybrid Systems: Computation and
    Control, 2013, pp. 173–182.
"""
struct DensePolynomialZonotope{N, VT, VMT, MT} <: AbstractPolynomialZonotope{N}
    c::VT
    E::VMT
    F::VMT
    G::MT

    # default constructor with dimension check
    function DensePolynomialZonotope(c::VT, E::VMT, F::VMT, G::MT) where {VT, VMT, MT}
        # check polynomial order
        @assert length(E) == 1 + length(F)
        N = typeof(c[1])

        return new{N, VT, VMT, MT}(c, E, F, G)
    end
end

isoperationtype(::Type{<:DensePolynomialZonotope}) = false
isconvextype(::Type{<:DensePolynomialZonotope}) = false

"""
    dim(pz::DensePolynomialZonotope)

Return the ambient dimension of a polynomial zonotope.

### Input

- `pz` -- polynomial zonotope

### Output

An integer representing the ambient dimension of the polynomial zonotope.
"""
dim(pz::DensePolynomialZonotope) = length(pz.c)

"""
    σ(d::AbstractVector, pz::DensePolynomialZonotope)

Return the support vector of a polynomial zonotope along direction `d`.

### Input

- `d`  -- direction
- `pz` -- polynomial zonotope

### Output

Vector representing the support vector.
"""
function σ(d::AbstractVector, pz::DensePolynomialZonotope)
    error("this function is not yet implemented")
end

"""
    ρ(d::AbstractVector, pz::DensePolynomialZonotope)

Return the support function of a polynomial zonotope along direction `d`.

### Input

- `d`  -- direction
- `pz` -- polynomial zonotope

### Output

Value of the support function.
"""
function ρ(d::AbstractVector, pz::DensePolynomialZonotope)
    error("this function is not yet implemented")
end

"""
    polynomial_order(pz::DensePolynomialZonotope)

Polynomial order of a polynomial zonotope.

### Input

- `pz` -- polynomial zonotope

## Output

The polynomial order, defined as the maximal power of the scale factors ``β_i``.
Usually denoted ``η``.
"""
polynomial_order(pz::DensePolynomialZonotope) = length(pz.E)

"""
    order(pz::DensePolynomialZonotope)

Order of a polynomial zonotope.

### Input

- `pz` -- polynomial zonotope

## Output

The order, a rational number defined as the total number of generators divided
by the ambient dimension.
"""
function order(pz::DensePolynomialZonotope)
    η = polynomial_order(pz)  # polynomial order
    p = size(pz.E[1], 2)  # number of dependent factors
    q = size(pz.G, 2)  # number of independent factors
    ξ = sum(i -> binomial(p+i-1, i), 1:η) + q
    n = dim(pz)
    return ξ//n
end

"""
    linear_map(M::Matrix, pz::DensePolynomialZonotope)

Return the linear map of a polynomial zonotope.

### Input

- `M`  -- matrix
- `pz` -- polynomial zonotope

## Output

Polynomial zonotope such that its starting point and generators are those of `pz`
multiplied by the matrix `M`.
"""
function linear_map(M::Matrix, pz::DensePolynomialZonotope)
    c = M * pz.c
    E = [M*Ei for Ei in pz.E]
    F = [M*Fi for Fi in pz.F]
    G = M * pz.G
    return DensePolynomialZonotope(c, E, F, G)
end

"""
    scale(α::Number, pz::DensePolynomialZonotope)

Return a polynomial zonotope modified by a scale factor.

### Input

- `α`  -- polynomial zonotope
- `pz` -- polynomial zonotope

## Output

Polynomial zonotope such that its center and generators are multiples of those
of `pz` by a factor ``α``.
"""
function scale(α::Number, pz::DensePolynomialZonotope)
    c = α * pz.c
    E = [α*Ei for Ei in pz.E]
    F = [α*Fi for Fi in pz.F]
    G = α * pz.G
    return DensePolynomialZonotope(c, E, F, G)
end
