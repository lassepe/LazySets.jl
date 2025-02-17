import Base: rand,
             ∈,
             isempty

export Hyperplane,
       an_element

"""
    Hyperplane{N, VN<:AbstractVector{N}} <: AbstractPolyhedron{N}

Type that represents a hyperplane of the form ``a⋅x = b``.

### Fields

- `a` -- normal direction (non-zero)
- `b` -- constraint

### Examples

The plane ``y = 0``:

```jldoctest
julia> Hyperplane([0, 1.], 0.)
Hyperplane{Float64, Vector{Float64}}([0.0, 1.0], 0.0)
```
"""
struct Hyperplane{N, VN<:AbstractVector{N}} <: AbstractPolyhedron{N}
    a::VN
    b::N

    function Hyperplane(a::VN, b::N) where {N, VN<:AbstractVector{N}}
        @assert !iszero(a) "a hyperplane needs a non-zero normal vector"
        return new{N, VN}(a, b)
    end
end

isoperationtype(::Type{<:Hyperplane}) = false
isconvextype(::Type{<:Hyperplane}) = true

"""
    normalize(H::Hyperplane{N}, p=N(2)) where {N}

Normalize a hyperplane.

### Input

- `H` -- hyperplane
- `p`  -- (optional, default: `2`) norm

### Output

A new hyperplane whose normal direction ``a`` is normalized, i.e., such that
``‖a‖_p = 1`` holds.
"""
function normalize(H::Hyperplane{N}, p=N(2)) where {N}
    a, b = _normalize_halfspace(H, p)
    return Hyperplane(a, b)
end


# --- polyhedron interface functions ---


"""
    constraints_list(hp::Hyperplane)

Return the list of constraints of a hyperplane.

### Input

- `hp` -- hyperplane

### Output

A list containing two half-spaces.
"""
function constraints_list(hp::Hyperplane)
    return _constraints_list_hyperplane(hp.a, hp.b)
end


# --- ConvexSet interface functions ---


"""
    dim(hp::Hyperplane)

Return the dimension of a hyperplane.

### Input

- `hp` -- hyperplane

### Output

The ambient dimension of the hyperplane.
"""
function dim(hp::Hyperplane)
    return length(hp.a)
end

"""
    ρ(d::AbstractVector, hp::Hyperplane)

Evaluate the support function of a hyperplane in a given direction.

### Input

- `d`  -- direction
- `hp` -- hyperplane

### Output

The support function of the hyperplane.
If the set is unbounded in the given direction, the result is `Inf`.
"""
function ρ(d::AbstractVector, hp::Hyperplane)
    v, unbounded = σ_helper(d, hp, error_unbounded=false)
    if unbounded
        N = promote_type(eltype(d), eltype(hp))
        return N(Inf)
    end
    return dot(d, v)
end

"""
    σ(d::AbstractVector, hp::Hyperplane)

Return the support vector of a hyperplane.

### Input

- `d`  -- direction
- `hp` -- hyperplane

### Output

The support vector in the given direction, which is only defined in the
following two cases:
1. The direction has norm zero.
2. The direction is the hyperplane's normal direction or its opposite direction.
In all cases, the result is any point on the hyperplane.
Otherwise this function throws an error.
"""
function σ(d::AbstractVector, hp::Hyperplane)
    v, unbounded = σ_helper(d, hp, error_unbounded=true)
    return v
end

"""
    isbounded(hp::Hyperplane)

Determine whether a hyperplane is bounded.

### Input

- `hp` -- hyperplane

### Output

`true` iff `hp` is one-dimensional.
"""
function isbounded(hp::Hyperplane)
    return dim(hp) == 1
end

"""
    isuniversal(hp::Hyperplane, [witness]::Bool=false)

Check whether a hyperplane is universal.

### Input

- `P`       -- hyperplane
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `false`
* If `witness` option is activated: `(false, v)` where ``v ∉ P``

### Algorithm

A witness is produced by adding the normal vector to an element on the
hyperplane.
"""
function isuniversal(hp::Hyperplane, witness::Bool=false)
    if witness
        v = an_element(hp) + hp.a
        return (false, v)
    else
        return false
    end
end

"""
    an_element(hp::Hyperplane)

Return some element of a hyperplane.

### Input

- `hp` -- hyperplane

### Output

An element on the hyperplane.
"""
function an_element(hp::Hyperplane)
    return an_element_helper(hp)
end

"""
    ∈(x::AbstractVector, hp::Hyperplane)

Check whether a given point is contained in a hyperplane.

### Input

- `x` -- point/vector
- `hp` -- hyperplane

### Output

`true` iff ``x ∈ hp``.

### Algorithm

We just check if ``x`` satisfies ``a⋅x = b``.
"""
function ∈(x::AbstractVector, hp::Hyperplane)
    return _isapprox(dot(hp.a, x), hp.b)
end

"""
    rand(::Type{Hyperplane}; [N]::Type{<:Real}=Float64, [dim]::Int=2,
         [rng]::AbstractRNG=GLOBAL_RNG, [seed]::Union{Int, Nothing}=nothing)

Create a random hyperplane.

### Input

- `Hyperplane` -- type for dispatch
- `N`          -- (optional, default: `Float64`) numeric type
- `dim`        -- (optional, default: 2) dimension
- `rng`        -- (optional, default: `GLOBAL_RNG`) random number generator
- `seed`       -- (optional, default: `nothing`) seed for reseeding

### Output

A random hyperplane.

### Algorithm

All numbers are normally distributed with mean 0 and standard deviation 1.
Additionally, the constraint `a` is nonzero.
"""
function rand(::Type{Hyperplane};
              N::Type{<:Real}=Float64,
              dim::Int=2,
              rng::AbstractRNG=GLOBAL_RNG,
              seed::Union{Int, Nothing}=nothing)
    rng = reseed(rng, seed)
    a = randn(rng, N, dim)
    while iszero(a)
        a = randn(rng, N, dim)
    end
    b = randn(rng, N)
    return Hyperplane(a, b)
end

"""
    isempty(hp::Hyperplane)

Return if a hyperplane is empty or not.

### Input

- `hp` -- hyperplane

### Output

`false`.
"""
function isempty(hp::Hyperplane)
    return false
end

"""
    constrained_dimensions(hp::Hyperplane)

Return the indices in which a hyperplane is constrained.

### Input

- `hp` -- hyperplane

### Output

A vector of ascending indices `i` such that the hyperplane is constrained in
dimension `i`.

### Examples

A 2D hyperplane with constraint ``x1 = 0`` is constrained in dimension 1 only.
"""
function constrained_dimensions(hp::Hyperplane)
    return nonzero_indices(hp.a)
end


# --- Hyperplane functions ---


"""
```
    σ_helper(d::AbstractVector,
             hp::Hyperplane;
             error_unbounded::Bool=true,
             [halfspace]::Bool=false)
```

Return the support vector of a hyperplane.

### Input

- `d`         -- direction
- `hp`        -- hyperplane
- `error_unbounded` -- (optional, default: `true`) `true` if an error should be
                 thrown whenever the set is
                 unbounded in the given direction
- `halfspace` -- (optional, default: `false`) `true` if the support vector
                 should be computed for a half-space

### Output

A pair `(v, b)` where `v` is a vector and `b` is a Boolean flag.

The flag `b` is `false` in one of the following cases:
1. The direction has norm zero.
2. The direction is the hyperplane's normal direction.
3. The direction is the opposite of the hyperplane's normal direction and
`halfspace` is `false`.
In all these cases, `v` is any point on the hyperplane.

Otherwise, the flag `b` is `true`, the set is unbounded in the given direction,
and `v` is any vector.

If `error_unbounded` is `true` and the set is unbounded in the given direction,
this function throws an error instead of returning.

### Notes

For correctness, consider the [weak duality of
LPs](https://en.wikipedia.org/wiki/Linear_programming#Duality):
If the primal is unbounded, then the dual is infeasible.
Since there is only a single constraint, the feasible set of the dual problem is
`hp.a ⋅ y == d`, `y >= 0` (with objective function `hp.b ⋅ y`).
It is easy to see that this problem is infeasible whenever `a` is not parallel
to `d`.
"""
@inline function σ_helper(d::AbstractVector,
                          hp::Hyperplane;
                          error_unbounded::Bool=true,
                          halfspace::Bool=false)
    @assert (length(d) == dim(hp)) "cannot compute the support vector of a " *
        "$(dim(hp))-dimensional " * (halfspace ? "halfspace" : "hyperplane") *
        " along a vector of length $(length(d))"

    first_nonzero_entry_a = -1
    unbounded = false
    if iszero(d)
        # zero vector
        return (an_element(hp), false)
    else
        # not the zero vector, check if it is a normal vector
        N = promote_type(eltype(d), eltype(hp))
        factor = zero(N)
        for i in 1:length(hp.a)
            if hp.a[i] == 0
                if d[i] != 0
                    unbounded = true
                    break
                end
            else
                if d[i] == 0
                    unbounded = true
                    break
                elseif first_nonzero_entry_a == -1
                    factor = hp.a[i] / d[i]
                    first_nonzero_entry_a = i
                    if halfspace && factor < 0
                        unbounded = true
                        break
                    end
                elseif d[i] * factor != hp.a[i]
                    unbounded = true
                    break
                end
            end
        end
        if !unbounded
            return (an_element_helper(hp, first_nonzero_entry_a), false)
        end
        if error_unbounded
            error("the support vector for the " *
                (halfspace ? "halfspace" : "hyperplane") * " with normal " *
                "direction $(hp.a) is not defined along a direction $d")
        end
        # the first return value does not have a meaning here
        return (d, true)
    end
end

"""
    an_element_helper(hp::Hyperplane{N},
                      [nonzero_entry_a]::Int) where {N}

Helper function that computes an element on a hyperplane's hyperplane.

### Input

- `hp` -- hyperplane
- `nonzero_entry_a` -- (optional, default: computes the first index) index `i`
                       such that `hp.a[i]` is different from 0

### Output

An element on a hyperplane.

### Algorithm

We compute the point on the hyperplane as follows:
- We already found a nonzero entry of ``a`` in dimension, say, ``i``.
- We set ``x[i] = b / a[i]``.
- We set ``x[j] = 0`` for all ``j ≠ i``.
"""
@inline function an_element_helper(hp::Hyperplane{N},
                                   nonzero_entry_a::Int=findnext(x -> x!=zero(N), hp.a, 1)
                                  ) where {N}
    @assert nonzero_entry_a in 1:length(hp.a) "invalid index " *
        "$nonzero_entry_a for hyperplane"
    x = zeros(N, dim(hp))
    x[nonzero_entry_a] = hp.b / hp.a[nonzero_entry_a]
    return x
end

# internal helper function
function _constraints_list_hyperplane(a::AbstractVector, b)
    return [HalfSpace(a, b), HalfSpace(-a, -b)]
end

function _linear_map_hrep_helper(M::AbstractMatrix{N}, P::Hyperplane{N},
                                 algo::AbstractLinearMapAlgorithm) where {N}
    constraints = _linear_map_hrep(M, P, algo)
    if length(constraints) == 2
        # assuming these constraints define a hyperplane
        c = first(constraints)
        return Hyperplane(c.a, c.b)
    elseif isempty(constraints)
        return Universe{N}(size(M, 1))
    else
        error("unexpected number of $(length(constraints)) constraints")
    end
end

"""
    translate(hp::Hyperplane, v::AbstractVector; share::Bool=false)

Translate (i.e., shift) a hyperplane by a given vector.

### Input

- `hp`    -- hyperplane
- `v`     -- translation vector
- `share` -- (optional, default: `false`) flag for sharing unmodified parts of
             the original set representation

### Output

A translated hyperplane.

### Notes

The normal vectors of the hyperplane (vector `a` in `a⋅x = b`) is shared with
the original hyperplane if `share == true`.

### Algorithm

A hyperplane ``a⋅x = b`` is transformed to the hyperplane ``a⋅x = b + a⋅v``.
In other words, we add the dot product ``a⋅v`` to ``b``.
"""
function translate(hp::Hyperplane, v::AbstractVector; share::Bool=false)
    @assert length(v) == dim(hp) "cannot translate a $(dim(hp))-dimensional " *
                                 "set by a $(length(v))-dimensional vector"
    a = share ? hp.a : copy(hp.a)
    b = hp.b + dot(hp.a, v)
    return Hyperplane(a, b)
end

function project(hp::Hyperplane{N}, block::AbstractVector{Int}; kwargs...) where {N}
    if constrained_dimensions(hp) ⊆ block
        return Hyperplane(hp.a[block], hp.b)
    else
        return Universe{N}(length(block))
    end
end

"""
    project(x::AbstractVector, hp::Hyperplane)

Project a point onto a hyperplane.

### Input

- `x`  -- point
- `hp` -- hyperplane

### Output

The projection of `x` onto `hp`.

### Algorithm

The projection of ``x`` onto the hyperplane of the form ``a⋅x = b`` is

```math
    x - \\dfrac{a (a⋅x - b)}{‖a‖²}
```
"""
function project(x::AbstractVector, hp::Hyperplane)
    return x - hp.a * (dot(hp.a, x) - hp.b) / norm(hp.a, 2)^2
end

function is_hyperplanar(::Hyperplane)
    return true
end

# ============================================
# Functionality that requires Symbolics
# ============================================
function load_symbolics_hyperplane()
return quote

# returns `(true, sexpr)` if expr represents a hyperplane,
# where sexpr is the simplified expression sexpr := LHS - RHS == 0
# otherwise, returns `(false, expr)`
function _is_hyperplane(expr::Symbolic)
    got_hyperplane = operation(expr) == ==
    if got_hyperplane
        # simplify to the form a*x + b == 0
        a, b = arguments(expr)
        sexpr = simplify(a - b)
    end
    return got_hyperplane ? (true, sexpr) : (false, expr)
end

"""
    Hyperplane(expr::Num, vars=_get_variables(expr); [N]::Type{<:Real}=Float64)

Return the hyperplane given by a symbolic expression.

### Input

- `expr` -- symbolic expression that describes a hyperplane
- `vars` -- (optional, default: `_get_variables(expr)`), if an array of variables is given,
            use those as the ambient variables in the set with respect to which derivations
            take place; otherwise, use only the variables which appear in the given
            expression (but be careful because the order may be incorrect;
            it is advised to always `vars` explicitly)
- `N`    -- (optional, default: `Float64`) the numeric type of the returned hyperplane

### Output

A `Hyperplane`.

### Examples

```jldoctest
julia> using Symbolics

julia> vars = @variables x y
2-element Vector{Num}:
 x
 y

julia> Hyperplane(x - y == 2)
Hyperplane{Float64, Vector{Float64}}([1.0, -1.0], 2.0)

julia> Hyperplane(x == y)
Hyperplane{Float64, Vector{Float64}}([1.0, -1.0], -0.0)

julia> vars = @variables x[1:4]
1-element Vector{Symbolics.Arr{Num, 1}}:
 x[1:4]

julia> Hyperplane(x[1] == x[2], x)
Hyperplane{Float64, Vector{Float64}}([1.0, -1.0, 0.0, 0.0], -0.0)
```

### Algorithm

It is assumed that the expression is of the form
`EXPR0: α*x1 + ⋯ + α*xn + γ == β*x1 + ⋯ + β*xn + δ`.
This expression is transformed, by rearrangement and substitution, into the
canonical form `EXPR1 : a1 * x1 + ⋯ + an * xn == b`. The method used to identify
the coefficients is to take derivatives with respect to the ambient variables `vars`.
Therefore, the order in which the variables appear in `vars` affects the final result.
Finally, the returned set is the hyperplane with normal vector `[a1, …, an]` and
displacement `b`.
"""
function Hyperplane(expr::Num, vars::AbstractVector{Num}; N::Type{<:Real}=Float64)
    valid, sexpr = _is_hyperplane(Symbolics.value(expr))
    if !valid
        throw(ArgumentError("expected an expression of the form `ax == b`, got $expr"))
    end

    # compute the linear coefficients by taking first order derivatives
    coeffs = [N(α.val) for α in gradient(sexpr, collect(vars))]

    # get the constant term by expression substitution
    zeroed_vars = Dict(v => zero(N) for v in vars)
    β = -N(Symbolics.substitute(sexpr, zeroed_vars))

    return Hyperplane(coeffs, β)
end

Hyperplane(expr::Num; N::Type{<:Real}=Float64) = Hyperplane(expr, _get_variables(expr); N=N)
Hyperplane(expr::Num, vars; N::Type{<:Real}=Float64) = Hyperplane(expr, _vec(vars), N=N)

end end  # quote / load_symbolics_hyperplane()

"""
    distance(x::AbstractVector, H::Hyperplane{N}) where {N}

Compute the distance between point `x` and hyperplane `H` with respect to the
Euclidean norm.

### Input

- `x` -- vector
- `H` -- hyperplane

### Output

A scalar representing the distance between point `x` and hyperplane `H`.
"""
function distance(x::AbstractVector, H::Hyperplane{N}) where {N}
    a, b = _normalize_halfspace(H, N(2))
    return abs(dot(x, a) - b)
end

distance(H::Hyperplane, x::AbstractVector) = distance(x, H)

"""
    reflect(x::AbstractVector, H::Hyperplane)

Reflect (mirror) a vector in a hyperplane.

### Input

- `x` -- vector
- `H` -- hyperplane

### Output

The reflection of `x` in `H`.

### Algorithm

The reflection of a point ``p`` in the hyperplane ``a ⋅ x = b`` is

```math
    p − 2 \frac{p ⋅ a − c}{a ⋅ a} a
```

where ``x · y`` denotes the dot product.
"""
function reflect(x::AbstractVector, H::Hyperplane)
    return _reflect_point_hyperplane(x, H.a, H.b)
end

function _reflect_point_hyperplane(x, a, b)
    return x - 2 * (dot(x, a) - b) / dot(a, a) * a
end
