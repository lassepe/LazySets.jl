import Base: rand,
             ∈

export VPolytope,
       vertices_list,
       linear_map,
       remove_redundant_vertices,
       tohrep,
       tovrep

"""
    VPolytope{N, VN<:AbstractVector{N}} <: AbstractPolytope{N}

Type that represents a convex polytope in V-representation.

### Fields

- `vertices` -- list of vertices

### Examples

A polytope in vertex representation can be constructed by passing the list of
vertices. For example, we can build the tetrahedron:

```jldoctest
julia> P = VPolytope([0 0 0; 1 0 0; 0 1 0; 0 0 1]);

julia> P.vertices
3-element Vector{Vector{Int64}}:
 [0, 1, 0, 0]
 [0, 0, 1, 0]
 [0, 0, 0, 1]
```

Alternatively, a `VPolytope` can be constructed passing a matrix of vertices,
where each *column* represents a vertex:

```jldoctest
julia> M = [0 0 0; 1 0 0; 0 1 0; 0 0 1]'
3×4 adjoint(::Matrix{Int64}) with eltype Int64:
 0  1  0  0
 0  0  1  0
 0  0  0  1

julia> P = VPolytope(M);

julia> P.vertices
4-element Vector{Vector{Int64}}:
 [0, 0, 0]
 [1, 0, 0]
 [0, 1, 0]
 [0, 0, 1]
```
"""
struct VPolytope{N, VN<:AbstractVector{N}} <: AbstractPolytope{N}
    vertices::Vector{VN}
end

isoperationtype(::Type{<:VPolytope}) = false
isconvextype(::Type{<:VPolytope}) = true

# constructor for a VPolytope with empty vertices list
VPolytope{N}() where {N} = VPolytope(Vector{Vector{N}}())

# constructor for a VPolytope with no vertices of type Float64
VPolytope() = VPolytope{Float64}()

# constructor from rectangular matrix
function VPolytope(vertices_matrix::MT) where {N, MT<:AbstractMatrix{N}}
    vertices = [vertices_matrix[:, j] for j in 1:size(vertices_matrix, 2)]
    return VPolytope(vertices)
end

# --- ConvexSet interface functions ---

"""
    dim(P::VPolytope)

Return the dimension of a polytope in V-representation.

### Input

- `P`  -- polytope in V-representation

### Output

The ambient dimension of the polytope in V-representation.
If it is empty, the result is ``-1``.

### Examples

```jldoctest
julia> v = VPolytope();

julia> isempty(v.vertices)
true

julia> dim(v)
-1

julia> v = VPolytope([ones(3)]);

julia> v.vertices
1-element Vector{Vector{Float64}}:
 [1.0, 1.0, 1.0]

julia> dim(v) == 3
true
```
"""
function dim(P::VPolytope)
    return length(P.vertices) == 0 ? -1 : length(P.vertices[1])
end

"""
    σ(d::AbstractVector, P::VPolytope)

Return the support vector of a polytope in V-representation in a given
direction.

### Input

- `d` -- direction
- `P` -- polytope in V-representation

### Output

The support vector in the given direction.

### Algorithm

A support vector maximizes the support function.
For a polytope, the support function is always maximized in some vertex.
Hence it is sufficient to check all vertices.
"""
function σ(d::AbstractVector, P::VPolytope)
    # base cases
    m = length(P.vertices)
    if m == 0
        error("the support function for an empty polytope is undefined")
    elseif m == 1
        return P.vertices[1]
    end

    # evaluate support function in every vertex
    N = promote_type(eltype(d), eltype(P))
    max_ρ = N(-Inf)
    max_idx = 0
    for (i, vi) in enumerate(P.vertices)
        ρ_i = dot(d, vi)
        if ρ_i > max_ρ
            max_ρ = ρ_i
            max_idx = i
        end
    end
    return P.vertices[max_idx]
end

"""
    ∈(x::AbstractVector{N}, P::VPolytope{N};
      solver=default_lp_solver(N)) where {N}

Check whether a given point is contained in a polytope in vertex representation.

### Input

- `x`      -- point/vector
- `P`      -- polytope in vertex representation
- `solver` -- (optional, default: `default_lp_solver(N)`) the backend used to
              solve the linear program

### Output

`true` iff ``x ∈ P``.

### Algorithm

We check, using linear programming, the definition of a convex polytope that a
point is in the set if and only if it is a convex combination of the vertices.

Let ``\\{v_j\\}`` be the ``m`` vertices of `P`.
Then we solve the following ``m``-dimensional linear program.

```math
\\max 0 \\text{ s.t. }
\\bigwedge_{i=1}^n \\sum_{j=1}^m λ_j v_j[i] = x[i]
∧ \\sum_{j=1}^m λ_j = 1
∧ \\bigwedge_{j=1}^m λ_j ≥ 0
```
"""
function ∈(x::AbstractVector{N}, P::VPolytope{N};
           solver=default_lp_solver(N)) where {N}
    vertices = P.vertices
    m = length(vertices)

    # special cases: 0 or 1 vertex
    if m == 0
        return false
    elseif m == 1
        return x == vertices[1]
    end

    n = length(x)
    @assert n == dim(P) "a vector of length $(length(x)) cannot be " *
        "contained in a polytope of dimension $(dim(P))"

    A = Matrix{N}(undef, n+1, m)
    for j in 1:m
        v_j = vertices[j]
        # ⋀_i Σ_j λ_j v_j[i] = x[i]
        for i in 1:n
            A[i, j] = v_j[i]
        end
        # Σ_j λ_j = 1
        A[n+1, j] = one(N)
    end
    b = [x; one(N)]
    lbounds = zero(N)
    ubounds = N(Inf)
    sense = '='
    obj = zeros(N, m)
    lp = linprog(obj, A, sense, b, lbounds, ubounds, solver)
    if is_lp_optimal(lp.status)
        return true
    elseif is_lp_infeasible(lp.status)
        return false
    end
    @assert false "LP returned status $(lp.status) unexpectedly"
end

"""
    rand(::Type{VPolytope}; [N]::Type{<:Real}=Float64, [dim]::Int=2,
         [rng]::AbstractRNG=GLOBAL_RNG, [seed]::Union{Int, Nothing}=nothing,
         [num_vertices]::Int=-1)

Create a random polytope in vertex representation.

### Input

- `VPolytope`    -- type for dispatch
- `N`            -- (optional, default: `Float64`) numeric type
- `dim`          -- (optional, default: 2) dimension
- `rng`          -- (optional, default: `GLOBAL_RNG`) random number generator
- `seed`         -- (optional, default: `nothing`) seed for reseeding
- `num_vertices` -- (optional, default: `-1`) upper bound on the number of
                    vertices of the polytope (see comment below)

### Output

A random polytope in vertex representation.

### Algorithm

All numbers are normally distributed with mean 0 and standard deviation 1.

The number of vertices can be controlled with the argument `num_vertices`.
For a negative value we choose a random number in the range `dim:5*dim` (except
if `dim == 1`, in which case we choose in the range `1:2`).
Note that we do not guarantee that the vertices are not redundant.
"""
function rand(::Type{VPolytope};
              N::Type{<:Real}=Float64,
              dim::Int=2,
              rng::AbstractRNG=GLOBAL_RNG,
              seed::Union{Int, Nothing}=nothing,
              num_vertices::Int=-1)
    rng = reseed(rng, seed)
    if num_vertices < 0
        num_vertices = (dim == 1) ? rand(1:2) : rand(dim:5*dim)
    end
    vertices = [randn(rng, N, dim) for i in 1:num_vertices]
    return VPolytope(vertices)
end

"""
    linear_map(M::AbstractMatrix, P::VPolytope; [apply_convex_hull]::Bool=false)

Concrete linear map of a polytope in vertex representation.

### Input

- `M` -- matrix
- `P` -- polytope in vertex representation
- `apply_convex_hull` -- (optional, default: `false`) flag for applying a convex
                         hull to eliminate redundant vertices

### Output

A polytope in vertex representation.

### Algorithm

The linear map ``M`` is applied to each vertex of the given set ``P``, obtaining
a polytope in V-representation. The output type is again a `VPolytope`.
"""
function linear_map(M::AbstractMatrix, P::VPolytope; apply_convex_hull::Bool=false)
    @assert dim(P) == size(M, 2) "a linear map of size $(size(M)) cannot be " *
        "applied to a set of dimension $(dim(P))"

    return _linear_map_vrep(M, P; apply_convex_hull=apply_convex_hull)
end

@inline function _linear_map_vrep(M::AbstractMatrix, P::VPolytope,
                                  algo::LinearMapVRep=LinearMapVRep(nothing);
                                  apply_convex_hull::Bool=false)
    vlist = broadcast(v -> M * v, vertices_list(P))
    if apply_convex_hull
        convex_hull!(vlist)
    end
    return VPolytope(vlist)
end

"""
    translate(P::VPolytope, v::AbstractVector)

Translate (i.e., shift) a polytope in vertex representation by a given vector.

### Input

- `P` -- polytope in vertex representation
- `v` -- translation vector

### Output

A translated polytope in vertex representation.

### Algorithm

We add the vector to each vertex of the polytope.

### Notes

See also [`translate!(::VPolytope, AbstractVector)`](@ref) for the in-place version.
"""
function translate(P::VPolytope, v::AbstractVector)
    return translate!(deepcopy(P), v)
end

"""
    translate!(P::VPolytope, v::AbstractVector)

Translate (i.e., shift) a polytope in vertex representation by a given vector, in-place.

### Input

- `P` -- polytope in vertex representation
- `v` -- translation vector

### Output

The polytope `P` translated by `v`.

### Notes

See also [`translate(::VPolytope, AbstractVector)`](@ref) for the out-of-place version.
"""
function translate!(P::VPolytope, v::AbstractVector)
    @assert length(v) == dim(P) "cannot translate a $(dim(P))-dimensional " *
                                "set by a $(length(v))-dimensional vector"
    for x in P.vertices
        x .+= v
    end
    return P
end

# --- AbstractPolytope interface functions ---

"""
    vertices_list(P::VPolytope)

Return the list of vertices of a polytope in V-representation.

### Input

- `P` -- polytope in vertex representation

### Output

List of vertices.
"""
function vertices_list(P::VPolytope)
    return P.vertices
end

"""
    constraints_list(P::VPolytope)

Return the list of constraints defining a polytope in V-representation.

### Input

- `P` -- polytope in V-representation

### Output

The list of constraints of the polytope.

### Algorithm

First the H-representation of ``P`` is computed, then its list of constraints
is returned.
"""
function constraints_list(P::VPolytope)
    return constraints_list(tohrep(P))
end

"""
    remove_redundant_vertices(P::VPolytope{N};
                              [backend]=nothing,
                              [solver]=nothing) where {N}

Return the polytope obtained by removing the redundant vertices of the given polytope.

### Input

- `P`       -- polytope in vertex representation
- `backend` -- (optional, default: `nothing`) the backend for polyhedral
               computations; see `default_polyhedra_backend(P)` or
               [Polyhedra's documentation](https://juliapolyhedra.github.io/)
               for further information
- `solver`  -- (optional, default: `nothing`) the linear programming
               solver used in the backend, if needed; see
               `default_lp_solver_polyhedra(N)`

### Output

A new polytope such that its vertices are the convex hull of the given polytope.

### Notes

The optimization problem associated to removing redundant vertices is handled
by `Polyhedra`.
If the polyhedral computations backend requires an LP solver but it has not been
set, we use `default_lp_solver_polyhedra(N)` to define such solver.
Otherwise, the redundancy removal function of the polyhedral backend is used.
"""
function remove_redundant_vertices(P::VPolytope{N};
                                   backend=nothing,
                                   solver=nothing) where {N}
    require(:Polyhedra; fun_name="remove_redundant_vertices")
    if backend == nothing
        backend = default_polyhedra_backend(P)
    end
    Q = polyhedron(P; backend=backend)
    if Polyhedra.supportssolver(typeof(Q))
        if solver == nothing
            solver = default_lp_solver_polyhedra(N)
        end
        vQ = Polyhedra.vrep(Q)
        Polyhedra.setvrep!(Q, Polyhedra.removevredundancy(vQ, solver))
    else
        Polyhedra.removevredundancy!(Q; ztol=_ztol(N))
    end
    return VPolytope(Q)
end

"""
    tohrep(P::VPolytope{N};
           [backend]=default_polyhedra_backend(P)) where {N}

Transform a polytope in V-representation to a polytope in H-representation.

### Input

- `P`       -- polytope in vertex representation
- `backend` -- (optional, default: `default_polyhedra_backend(P)`) the
               backend for polyhedral computations; see [Polyhedra's
               documentation](https://juliapolyhedra.github.io/) for further
               information

### Output

The `HPolytope` which is the constraint representation of the given polytope
in vertex representation.

### Notes

The conversion may not preserve the numeric type (e.g., with `N == Float32`)
depending on the backend.
"""
function tohrep(P::VPolytope{N};
                backend=default_polyhedra_backend(P)) where {N}
    vl = P.vertices
    if isempty(vl)
        return EmptySet{N}(dim(P))
    end
    require(:Polyhedra; fun_name="tohrep")
    return convert(HPolytope, polyhedron(P; backend=backend))
end

"""
    tovrep(P::VPolytope)

Return a vertex representation of the given polytope in vertex
representation (no-op).

### Input

- `P` -- polytope in vertex representation

### Output

The same polytope instance.
"""
function tovrep(P::VPolytope)
    return P
end

# ==========================================
# Lower level methods that use Polyhedra.jl
# ==========================================

function load_polyhedra_vpolytope() # function to be loaded by Requires
return quote
# see the interface file AbstractPolytope.jl for the imports

# VPolytope from a VRep
function VPolytope(P::VRep{N}) where {N}
    # TODO: use point type of the VRep #2010
    vertices = Vector{Vector{N}}()
    for vi in Polyhedra.points(P)
        push!(vertices, vi)
    end
    return VPolytope(vertices)
end

"""
    polyhedron(P::VPolytope;
               [backend]=default_polyhedra_backend(P),
               [relative_dimension]=nothing)

Return an `VRep` polyhedron from `Polyhedra.jl` given a polytope in V-representation.

### Input

- `P`       -- polytope
- `backend` -- (optional, default: `default_polyhedra_backend(P)`) the
               backend for polyhedral computations; see [Polyhedra's
               documentation](https://juliapolyhedra.github.io/) for further
               information
- `relative_dimension` -- (default, optional: `nothing`) an integer representing
                          the (relative) dimension of the polytope; this
                          argument is mandatory if the polytope is empty

### Output

A `VRep` polyhedron.

### Notes

The *relative dimension* (or just *dimension*) refers to the dimension of the set
relative to itself, independently of the ambient dimension. For example, a point
has (relative) dimension zero, and a line segment has (relative) dimension one.

In this library, `LazySets.dim` always returns the ambient dimension of the set,
such that a line segment in two dimensions has dimension two. However,
`Polyhedra.dim` will assign a dimension equal to one to a line segment
because it uses a different convention.
"""
function polyhedron(P::VPolytope;
                    backend=default_polyhedra_backend(P),
                    relative_dimension=nothing)
    if isempty(P)
        if relative_dimension == nothing
            error("the conversion to a `Polyhedra.polyhedron` requires the (relative) dimension " *
                  "of the `VPolytope` to be known, but it cannot be inferred from an empty set; " *
                  "try passing it in the keyword argument `relative_dimension`")
        end
        return polyhedron(Polyhedra.vrep(P.vertices, d=relative_dimension), backend)
    end
    return polyhedron(Polyhedra.vrep(P.vertices), backend)
end

end # quote
end # function load_polyhedra_vpolytope()

function project(V::VPolytope, block::AbstractVector{Int}; kwargs...)
    return _project_vrep(vertices_list(V), dim(V), block)
end

function _project_vrep(vlist::AbstractVector{VN}, n, block) where {N, VN<:AbstractVector{N}}
    M = projection_matrix(block, n, VN)
    πvertices = broadcast(v -> M * v, vlist)

    m = size(M, 1)
    if m == 1
        # convex_hull in 1d returns the minimum and maximum points, in that order
        aux = convex_hull(πvertices)
        a = first(aux[1])
        b = length(aux) == 1 ? a : first(aux[2])
        return Interval(a, b)
    elseif m == 2
        return VPolygon(πvertices; apply_convex_hull=true)
    else
        return VPolytope(πvertices)
    end
end

function permute(P::VPolytope, p::AbstractVector{Int})
    vlist = [v[p] for v in vertices_list(P)]
    return VPolytope(vlist)
end
