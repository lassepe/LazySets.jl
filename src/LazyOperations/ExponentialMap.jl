import Base: *, size, ∈

export SparseMatrixExp,
       ExponentialMap,
       size,
       ProjectionSparseMatrixExp,
       ExponentialProjectionMap,
       get_row,
       get_rows,
       get_column,
       get_columns

# --- SparseMatrixExp & ExponentialMap ---

"""
    SparseMatrixExp{N}

Type that represents the matrix exponential, ``\\exp(M)``, of a sparse matrix.

### Fields

- `M` -- sparse matrix; it should be square

### Examples

Take for example a random sparse matrix of dimensions ``100 × 100`` and with
occupation probability ``0.1``:

```jldoctest SparseMatrixExp_constructor
julia> using SparseArrays

julia> A = sprandn(100, 100, 0.1);

julia> using ExponentialUtilities

julia> E = SparseMatrixExp(A);

julia> size(E)
(100, 100)
```

Here `E` is a lazy representation of ``\\exp(A)``. To compute with `E`, use
`get_row` and `get_column` resp. `get_rows` and `get_columns`. These functions
return row and column vectors (or matrices). For example:

```jldoctest SparseMatrixExp_constructor
julia> get_row(E, 10); # compute E[10, :]

julia> get_column(E, 10); # compute E[:, 10]

julia> get_rows(E, [10]); # same as get_row(E, 10) but a 1x100 matrix is returned

julia> get_columns(E, [10]); # same as get_column(E, 10) but a 100x1 matrix is returned
```

### Notes

This type is provided for use with very large and very sparse matrices.
The evaluation of the exponential matrix action over vectors relies on external
packages such as
[ExponentialUtilities](https://github.com/SciML/ExponentialUtilities.jl) or
[Expokit](https://github.com/acroy/Expokit.jl).
Hence, you will have to install and load such an optional dependency to have
access to the functionality of `SparseMatrixExp`.
"""
struct SparseMatrixExp{N, MN<:AbstractSparseMatrix{N}} <: AbstractMatrix{N}
    M::MN
    function SparseMatrixExp(M::MN) where {N, MN<:AbstractSparseMatrix{N}}
        @assert size(M, 1) == size(M, 2) "the lazy matrix exponential `SparseMatrixExp` " *
            "requires the given matrix to be square, but it has size $(size(M))"
        return new{N, MN}(M)
    end
end

SparseMatrixExp(M::Matrix) =
        error("only sparse matrices can be used to create a `SparseMatrixExp`")

Base.IndexStyle(::Type{<:SparseMatrixExp}) = IndexCartesian()
Base.getindex(spmexp::SparseMatrixExp, I::Vararg{Int, 2}) = get_column(spmexp, I[2])[I[1]]

function size(spmexp::SparseMatrixExp)
    return size(spmexp.M)
end

function size(spmexp::SparseMatrixExp, ax::Int)
    return size(spmexp.M, ax)
end

function get_column(spmexp::SparseMatrixExp{N}, j::Int;
                    backend=get_exponential_backend()) where {N}
    n = size(spmexp, 1)
    aux = zeros(N, n)
    aux[j] = one(N)
    return _expmv(backend, one(N), spmexp.M, aux)
end

function get_columns(spmexp::SparseMatrixExp{N}, J::AbstractArray;
                     backend=get_exponential_backend()) where {N}
    n = size(spmexp, 1)
    aux = zeros(N, n)
    res = zeros(N, n, length(J))
    @inbounds for (k, j) in enumerate(J)
        aux[j] = one(N)
        res[:, k] = _expmv(backend, one(N), spmexp.M, aux)
        aux[j] = zero(N)
    end
    return res
end

"""
    get_row(spmexp::SparseMatrixExp{N}, i::Int;
            [backend]=get_exponential_backend()) where {N}

Return a single row of a sparse matrix exponential.

### Input

- `spmexp`  -- sparse matrix exponential
- `i`       -- row index
- `backend` -- (optional; default: `get_exponential_backend()`) exponentiation
               backend

### Output

A row vector corresponding to the `i`th row of the matrix exponential.

### Notes

This function uses Julia's `transpose` function to create the result.
The result is of type `Transpose`; in Julia versions older than v0.7, the result
was of type `RowVector`.
"""
function get_row(spmexp::SparseMatrixExp{N}, i::Int;
                 backend=get_exponential_backend()) where {N}
    n = size(spmexp, 1)
    aux = zeros(N, n)
    aux[i] = one(N)
    return transpose(_expmv(backend, one(N), transpose(spmexp.M), aux))
end

function get_rows(spmexp::SparseMatrixExp{N}, I::AbstractArray{Int};
                  backend=get_exponential_backend()) where {N}
    n = size(spmexp, 1)
    aux = zeros(N, n)
    res = zeros(N, length(I), n)
    Mtranspose = transpose(spmexp.M)
    @inbounds for (k, i) in enumerate(I)
        aux[i] = one(N)
        res[k, :] = _expmv(backend, one(N), Mtranspose, aux)
        aux[i] = zero(N)
    end
    return res
end

"""
    ExponentialMap{N, S<:ConvexSet{N}} <: AbstractAffineMap{N, S}

Type that represents the action of an exponential map on a set.

### Fields

- `spmexp` -- sparse matrix exponential
- `X`      -- set

### Notes

The exponential map preserves convexity: if `X` is convex, then any exponential
map of `X` is convex as well.

### Examples

The `ExponentialMap` type is overloaded to the usual times `*` operator when the
linear map is a lazy matrix exponential. For instance,

```jldoctest constructors
julia> using SparseArrays

julia> A = sprandn(100, 100, 0.1);

julia> E = SparseMatrixExp(A);

julia> B = BallInf(zeros(100), 1.);

julia> M = E * B; # represents the image set: exp(A) * B

julia> M isa ExponentialMap
true

julia> dim(M)
100
```

The application of an `ExponentialMap` to a `ZeroSet` or an `EmptySet` is
simplified automatically.

```jldoctest constructors
julia> E * ZeroSet(100)
ZeroSet{Float64}(100)

julia> E * EmptySet(2)
∅(2)
```
"""
struct ExponentialMap{N, S<:ConvexSet{N}} <: AbstractAffineMap{N, S}
    spmexp::SparseMatrixExp{N}
    X::S
end

# ZeroSet is "almost absorbing" for ExponentialMap (only the dimension changes)
function ExponentialMap(spmexp::SparseMatrixExp, Z::ZeroSet)
    N = promote_type(eltype(spmexp), eltype(Z))
    @assert dim(Z) == size(spmexp, 2) "an exponential map of size " *
            "$(size(spmexp)) cannot be applied to a set of dimension $(dim(Z))"
    return ZeroSet{N}(size(spmexp, 1))
end

isoperationtype(::Type{<:ExponentialMap}) = true
isconvextype(::Type{ExponentialMap{N, S}}) where {N, S} = isconvextype(S)

# EmptySet is absorbing for ExponentialMap
function ExponentialMap(spmexp::SparseMatrixExp, ∅::EmptySet)
    return ∅
end

"""
```
    *(spmexp::SparseMatrixExp, X::ConvexSet)
```

Return the exponential map of a set from a sparse matrix exponential.

### Input

- `spmexp` -- sparse matrix exponential
- `X`      -- set

### Output

The exponential map of the set.
"""
function *(spmexp::SparseMatrixExp, X::ConvexSet)
    return ExponentialMap(spmexp, X)
end


# --- AbstractAffineMap interface functions ---


function matrix(em::ExponentialMap)
    return em.spmexp
end

function vector(em::ExponentialMap{N}) where {N}
    return spzeros(N, dim(em))
end

function set(em::ExponentialMap)
    return em.X
end


# --- ConvexSet interface functions ---


"""
    dim(em::ExponentialMap)

Return the dimension of an exponential map.

### Input

- `em` -- an ExponentialMap

### Output

The ambient dimension of the exponential map.
"""
function dim(em::ExponentialMap)
    return size(em.spmexp, 1)
end

"""
    σ(d::AbstractVector, em::ExponentialMap; [backend]=get_exponential_backend())

Return the support vector of the exponential map.

### Input

- `d`       -- direction
- `em`      -- exponential map
- `backend` -- (optional; default: `get_exponential_backend()`) exponentiation
               backend

### Output

The support vector in the given direction.
If the direction has norm zero, the result depends on the wrapped set.

### Notes

If ``E = \\exp(M)⋅S``, where ``M`` is a matrix and ``S`` is a set, it
follows that ``σ(d, E) = \\exp(M)⋅σ(\\exp(M)^T d, S)`` for any direction ``d``.
"""
function σ(d::AbstractVector, em::ExponentialMap;
           backend=get_exponential_backend())
    N = promote_type(eltype(d), eltype(em))
    v = _expmv(backend, one(N), transpose(em.spmexp.M), d)  # v   <- exp(M^T) * d
    return _expmv(backend, one(N), em.spmexp.M, σ(v, em.X)) # res <- exp(M) * σ(v, S)
end

"""
    ρ(d::AbstractVector, em::ExponentialMap; [backend]=get_exponential_backend())

Return the support function of the exponential map.

### Input

- `d`       -- direction
- `em`      -- exponential map
- `backend` -- (optional; default: `get_exponential_backend()`) exponentiation
               backend

### Output

The support function in the given direction.

### Notes

If ``E = \\exp(M)⋅S``, where ``M`` is a matrix and ``S`` is a set, it
follows that ``ρ(d, E) = ρ(\\exp(M)^T d, S)`` for any direction ``d``.
"""
function ρ(d::AbstractVector, em::ExponentialMap;
           backend=get_exponential_backend())
    N = promote_type(eltype(d), eltype(em))
    v = _expmv(backend, one(N), transpose(em.spmexp.M), d) # v <- exp(M^T) * d
    return ρ(v, em.X)
end

function concretize(em::ExponentialMap)
    return exponential_map(Matrix(em.spmexp.M), concretize(em.X))
end

"""
    ∈(x::AbstractVector, em::ExponentialMap; [backend]=get_exponential_backend())

Check whether a given point is contained in an exponential map of a set.

### Input

- `x`       -- point/vector
- `em`      -- exponential map of a set
- `backend` -- (optional; default: `get_exponential_backend()`) exponentiation
               backend

### Output

`true` iff ``x ∈ em``.

### Algorithm

This implementation exploits that ``x ∈ \\exp(M)⋅S`` iff ``\\exp(-M)⋅x ∈ S``.
This follows from ``\\exp(-M)⋅\\exp(M) = I`` for any ``M``.

### Examples

```jldoctest
julia> using SparseArrays

julia> em = ExponentialMap(
        SparseMatrixExp(sparse([1, 2], [1, 2], [2.0, 1.0], 2, 2)),
        BallInf([1., 1.], 1.));

julia> [-1.0, 1.0] ∈ em
false
julia> [1.0, 1.0] ∈ em
true
```
"""
function ∈(x::AbstractVector, em::ExponentialMap;
           backend=get_exponential_backend())
    @assert length(x) == dim(em) "a vector of length $(length(x)) is " *
        "incompatible with a set of dimension $(dim(em))"
    N = promote_type(eltype(x), eltype(em))
    y = _expmv(backend, -one(N), em.spmexp.M, x)
    return y ∈ em.X
end

"""
    vertices_list(em::ExponentialMap{N};
                  [backend]=get_exponential_backend()) where {N}

Return the list of vertices of a (polytopic) exponential map.

### Input

- `em`      -- exponential map
- `backend` -- (optional; default: `get_exponential_backend()`) exponentiation
               backend

### Output

A list of vertices.

### Algorithm

We assume that the underlying set `X` is polytopic.
Then the result is just the exponential map applied to the vertices of `X`.
"""
function vertices_list(em::ExponentialMap{N};
                       backend=get_exponential_backend()) where {N}
    # collect low-dimensional vertices lists
    vlist_X = vertices_list(em.X)

    # create resulting vertices list
    vlist = Vector{Vector{N}}(undef, length(vlist_X))
    @inbounds for (i, v) in enumerate(vlist_X)
        vlist[i] = _expmv(backend, one(N), em.spmexp.M, v)
    end

    return vlist
end

"""
    isbounded(em::ExponentialMap)

Determine whether an exponential map is bounded.

### Input

- `em` -- exponential map

### Output

`true` iff the exponential map is bounded.
"""
function isbounded(em::ExponentialMap)
    return isbounded(em.X)
end

function isboundedtype(::Type{<:ExponentialMap{N, S}}) where {N, S}
    return isboundedtype(S)
end

# --- ProjectionSparseMatrixExp & ExponentialProjectionMap ---

"""
    ProjectionSparseMatrixExp{N, MN1<:AbstractSparseMatrix{N},
                                 MN2<:AbstractSparseMatrix{N},
                                 MN3<:AbstractSparseMatrix{N}}

Type that represents the projection of a sparse matrix exponential, i.e.,
``L⋅\\exp(M)⋅R`` for a given sparse matrix ``M``.

### Fields

- `L` -- left multiplication matrix
- `E` -- sparse matrix exponential
- `R` -- right multiplication matrix
"""
struct ProjectionSparseMatrixExp{N, MN1<:AbstractSparseMatrix{N},
                                 MN2<:AbstractSparseMatrix{N},
                                 MN3<:AbstractSparseMatrix{N}}
    L::MN1
    spmexp::SparseMatrixExp{N, MN2}
    R::MN3
end

"""
    ExponentialProjectionMap{N, S<:ConvexSet{N}} <: AbstractAffineMap{N, S}

Type that represents the application of a projection of a sparse matrix
exponential to a set.

### Fields

- `spmexp` -- projection of a sparse matrix exponential
- `X`      -- set

### Notes

The exponential projection preserves convexity: if `X` is convex, then any
exponential projection of `X` is convex as well.
"""
struct ExponentialProjectionMap{N, S<:ConvexSet{N}} <: AbstractAffineMap{N, S}
    projspmexp::ProjectionSparseMatrixExp
    X::S
end

isoperationtype(::Type{<:ExponentialProjectionMap}) = true
isconvextype(::Type{ExponentialProjectionMap{N, S}}) where {N, S} = isconvextype(S)

"""
```
    *(projspmexp::ProjectionSparseMatrixExp, X::ConvexSet)
```

Return the application of a projection of a sparse matrix exponential to a set.

### Input

- `projspmexp` -- projection of a sparse matrix exponential
- `X`          -- set

### Output

The application of the projection of a sparse matrix exponential to the set.
"""
function *(projspmexp::ProjectionSparseMatrixExp, X::ConvexSet)
    return ExponentialProjectionMap(projspmexp, X)
end


# --- AbstractAffineMap interface functions ---


function matrix(epm::ExponentialProjectionMap)
    projspmexp = epm.projspmexp
    return projspmexp.L * projspmexp.spmexp * projspmexp.R
end

function vector(epm::ExponentialProjectionMap{N}) where {N<:Real}
    return spzeros(N, dim(epm))
end

function set(epm::ExponentialProjectionMap)
    return epm.X
end


# --- ConvexSet interface functions ---


"""
    dim(eprojmap::ExponentialProjectionMap)

Return the dimension of a projection of an exponential map.

### Input

- `eprojmap` -- projection of an exponential map

### Output

The ambient dimension of the projection of an exponential map.
"""
function dim(eprojmap::ExponentialProjectionMap)
    return size(eprojmap.projspmexp.L, 1)
end

"""
    σ(d::AbstractVector, eprojmap::ExponentialProjectionMap;
      [backend]=get_exponential_backend())

Return the support vector of a projection of an exponential map.

### Input

- `d`        -- direction
- `eprojmap` -- projection of an exponential map
- `backend`  -- (optional; default: `get_exponential_backend()`) exponentiation
                backend

### Output

The support vector in the given direction.
If the direction has norm zero, the result depends on the wrapped set.

### Notes

If ``S = (L⋅M⋅R)⋅X``, where ``L`` and ``R`` are matrices, ``M`` is a matrix
exponential, and ``X`` is a set, it follows that
``σ(d, S) = L⋅M⋅R⋅σ(R^T⋅M^T⋅L^T⋅d, X)`` for any direction ``d``.
"""
function σ(d::AbstractVector, eprojmap::ExponentialProjectionMap;
           backend=get_exponential_backend())
    daux = transpose(eprojmap.projspmexp.L) * d
    N = promote_type(eltype(d), eltype(eprojmap))
    aux1 = _expmv(backend, one(N), transpose(eprojmap.projspmexp.spmexp.M), daux)
    daux = At_mul_B(eprojmap.projspmexp.R, aux1)
    svec = σ(daux, eprojmap.X)

    aux2 = eprojmap.projspmexp.R * svec
    daux = _expmv(backend, one(N), eprojmap.projspmexp.spmexp.M, aux2)
    return eprojmap.projspmexp.L * daux
end

"""
    isbounded(eprojmap::ExponentialProjectionMap)

Determine whether an exponential projection map is bounded.

### Input

- `eprojmap` -- exponential projection map

### Output

`true` iff the exponential projection map is bounded.

### Algorithm

We first check if the left or right projection matrix is zero or the wrapped set
is bounded.
Otherwise, we check boundedness via [`LazySets._isbounded_unit_dimensions`](@ref).
"""
function isbounded(eprojmap::ExponentialProjectionMap)
    if iszero(eprojmap.projspmexp.L) || iszero(eprojmap.projspmexp.R) || isbounded(eprojmap.X)
        return true
    end
    return _isbounded_unit_dimensions(eprojmap)
end
