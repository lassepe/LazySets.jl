export convex_hull

function default_convex_hull_algorithm(points)
    if length(points) != 0 && length(first(points)) == 2
        return "monotone_chain"
    else
        return nothing
    end
end

"""
    convex_hull(X::ConvexSet{N}, Y::ConvexSet{N}; [algorithm]=nothing,
                [backend]=nothing, [solver]=nothing) where {N}

Compute the convex hull of the given convex sets.

### Input

- `X`         -- convex set
- `Y`         -- convex set
- `algorithm` -- (optional, default: `nothing`) the convex-hull algorithm
- `backend`   -- (optional, default: `nothing`) backend for polyhedral
                 computations (used for higher-dimensional sets)
- `solver`    -- (optional, default: `nothing`) the linear-programming solver
                 used in the backend

### Output

If the input sets are one-dimensional, the result is an `Interval`.
If the input sets are two-dimensional, the result is a `VPolygon`.
Otherwise the result is a `VPolytope`.

### Algorithm

One-dimensional sets are resolved by using `overapproximate` with an `Interval`
(which is exact).
For higher-dimensional sets, we compute the vertices of both `X` and `Y` using
`vertices_list` and then compute the convex hull of the union of those vertices.
"""
function convex_hull(X::ConvexSet{N}, Y::ConvexSet{N};
                     algorithm=nothing,
                     backend=nothing,
                     solver=nothing
                    ) where {N}
    n = dim(X)
    @assert n == dim(Y) "the convex hull requires two sets of the same " *
                        "dimension, but the sets had dimension $n and $(dim(Y))"

    chull = convex_hull!([vertices_list(X); vertices_list(Y)];
                         algorithm=algorithm, backend=backend, solver=solver)
    m = length(chull)
    if m == 0
        return EmptySet{N}(n)
    elseif m == 1
            return Singleton(chull[1])
    elseif n == 1
        @assert m == 2
        low = chull[1][1]
        high = chull[2][1]
        if low > high
            tmp = low
            low = high
            high = tmp
        end
        return Interval(low, high)
    elseif n == 2
        return VPolygon(chull)
    end
    return VPolytope(chull)
end

"""
    convex_hull(points::Vector{VN};
                [algorithm]=nothing,
                [backend]=nothing,
                [solver]=nothing
                ) where {N, VN<:AbstractVector{N}}

Compute the convex hull of the given points.

### Input

- `points`    -- list of vectors
- `algorithm` -- (optional, default: `nothing`) the convex-hull algorithm; see
                 below for valid options
- `backend`   -- (optional, default: `nothing`) polyhedral computation backend
                 for higher-dimensional point sets
- `solver`    -- (optional, default: `nothing`) the linear-programming solver
                 used in the backend

### Output

The convex hull as a list of vectors with the coordinates of the points.

### Algorithm

A pre-processing step treats the cases with up to two points for one dimension
and up to four points for two dimensions.
For more points in one resp. two dimensions, we use more general algorithms.

For the one-dimensional case we return the minimum and maximum points, in that order.

The two-dimensional case is handled with a planar convex hull algorithm. The
following algorithms are available:

* `"monotone_chain"`        -- compute the convex hull of points in the plane
                               using Andrew's monotone chain method
* `"monotone_chain_sorted"` -- the same as `"monotone_chain"` but assuming that
                               the points are already sorted in counter-clockwise
                               fashion

See the reference docstring of each of those algorithms for details.

The higher dimensional case is treated using the concrete polyhedra library
`Polyhedra`, that gives access to libraries such as `CDDLib` and `ConvexHull.jl`.
These libraries can be chosen from the `backend` argument.

### Notes

For the in-place version use `convex_hull!` instead of `convex_hull`.

### Examples

Compute the convex hull of a random set of points:

```jldoctest ch_label
julia> points = [randn(2) for i in 1:30]; # 30 random points in 2D

julia> hull = convex_hull(points);

julia> typeof(hull)
Vector{Vector{Float64}} (alias for Array{Array{Float64, 1}, 1})
```
"""
function convex_hull(points::Vector{VN};
                     algorithm=nothing,
                     backend=nothing,
                     solver=nothing
                     ) where {N, VN<:AbstractVector{N}}
    return convex_hull!(copy(points), algorithm=algorithm, backend=backend, solver=solver)
end

function convex_hull!(points::Vector{VN};
                      algorithm=nothing,
                      backend=nothing,
                      solver=nothing) where {N, VN<:AbstractVector{N}}

    m = length(points)

    # =====================
    # Treat special cases
    # =====================

    # zero or one point
    if m == 0 || m == 1
        return points
    end

    n = length(first(points))

    if n == 1 # dimensional check
        if m == 2
            # two points case in 1d
            return _two_points_1d!(points)
        else
             # general case in 1d
            return _convex_hull_1d!(points)
        end
    elseif n == 2
        return _convex_hull_2d_preprocess!(points, m; algorithm=algorithm)
    else
        # general case in nd
        return _convex_hull_nd!(points, backend=backend, solver=solver)
    end
end

function _convex_hull_2d_preprocess!(points, m=length(points); algorithm=nothing)
    if m == 2
        # two points case in 2d
        return _two_points_2d!(points)
    elseif m == 3
        # three points case in 2d
        return _three_points_2d!(points)
    elseif m == 4
        # four points case in 2d
        return _four_points_2d!(points)
    else
        # general case in 2d
        return _convex_hull_2d!(points, algorithm=algorithm)
    end
end

function _two_points_1d!(points)
    p1, p2 = points[1], points[2]
    if  _isapprox(p1[1], p2[1]) # check for redundancy
        pop!(points)
    end
    return points
end

function _two_points_2d!(points)
    p1, p2 = points[1], points[2]
    if _isapprox(p1[1], p2[1]) && _isapprox(p1[2], p2[2]) # check for redundancy
        pop!(points)
    end
    return points
end

function _three_points_2d!(points::AbstractVector{<:AbstractVector{N}}) where {N}
    # Algorithm: the function takes three points and uses the formula
    #            from here: https://stackoverflow.com/questions/2122305/convex-hull-of-4-points/2122620#2122620
    #            to decide if the points are ordered in a counter-clockwise fashion or not, the result is saved
    #            in the 'turn' boolean, then returns the points in ccw fashion acting according to 'turn'. For the
    #            cases where the points are collinear we pass the points with the minimum and maximum first
    #            component to the function for two points in 2d(_two_points_2d), if those are equal, we do the same
    #            but with the second component.
    A, B, C = points[1], points[2], points[3]
    turn = right_turn(A, B, C)

    if isapproxzero(turn)
        # ABC are collinear
        if isapprox(A[1], B[1]) && isapprox(B[1], C[1]) && isapprox(C[1], A[1])
            # points are approximately equal in their first component
            if isapprox(A[2], B[2]) && isapprox(B[2], C[2]) && isapprox(C[2], A[2])
                # all points are approximately equal
                pop!(points)
                pop!(points)
                return points
            else
                points[1], points[2] = points[argmin([A[2], B[2], C[2]])], points[argmax([A[2], B[2], C[2]])]
            end
        else
            points[1], points[2] = points[argmin([A[1], B[1], C[1]])], points[argmax([A[1], B[1], C[1]])]
        end
        pop!(points)
        _two_points_2d!(points)
    elseif turn < zero(N)
        # ABC is CW
        points[1], points[2], points[3] = C, B, A
    end
    # else ABC is CCW => nothing to do
    return points
end

# given an index i in {1, 2, 3} return the element among (A, B, C) in the i-th position
@inline function _get_i(i, A, B, C)
    return i == 1 ? A : i == 2 ? B : C
end

function _collinear_case!(points, A, B, C, D)
    # A, B and C collinear, D is the extra point
    if isapprox(A[1], B[1]) && isapprox(B[1], C[1]) && isapprox(C[1], A[1])
        # points are approximately equal in their first component
        if isapprox(A[2], B[2]) && isapprox(B[2], C[2]) && isapprox(C[2], A[2])
            # the three points are approximately equal
            points[1], points[2] = A, D
            pop!(points)
            pop!(points)
            return _two_points_2d!(points)
        else
            # assign the points with max and min value in their second component to the
            # firsts points and the extra point to the third place, then pop the point that was in the middle
            min_y, max_y = arg_minmax(A[2], B[2], C[2])
            points[1] = _get_i(min_y, A, B, C)
            points[2] = _get_i(max_y, A, B, C)
            points[3] = D
            pop!(points)
        end
    else
        # assign the points with max and min value in their first component to the
        # firsts points and the extra point to the third place, then pop the point that was in the middle
        min_x, max_x = arg_minmax(A[1], B[1], C[1])
        points[1] = _get_i(min_x, A, B, C)
        points[2] = _get_i(max_x, A, B, C)
        points[3] = D
        pop!(points)
    end
    return _three_points_2d!(points)
end

function _four_points_2d!(points::AbstractVector{<:AbstractVector{N}}) where {N}
    A, B, C, D = points[1], points[2], points[3], points[4]
    tri_ABC = right_turn(A, B, C)
    tri_ABD = right_turn(A, B, D)
    tri_BCD = right_turn(B, C, D)
    tri_CAD = right_turn(C, A, D)
    key = 0
    if tri_ABC > zero(N)
        key = key + 1000
    end
    if tri_ABD > zero(N)
        key = key + 100
    end
    if tri_BCD > zero(N)
        key = key + 10
    end
    if tri_CAD > zero(N)
        key = key + 1
    end

    if isapproxzero(tri_ABC)
        return _collinear_case!(points, A, B, C, D)
    elseif isapproxzero(tri_ABD)
        return _collinear_case!(points, A, B, D, C)
    elseif isapproxzero(tri_BCD)
        return _collinear_case!(points, B, C, D, A)
    elseif isapproxzero(tri_CAD)
        return _collinear_case!(points, C, A, D, B)
    end

    # ABC  ABD  BCD  CAD  hull
    # ------------------------
    #  +    +    +    +   ABC
    #  +    +    +    -   ABCD
    #  +    +    -    +   ABDC
    #  +    +    -    -   ABD
    #  +    -    +    +   ADBC
    #  +    -    +    -   BCD
    #  +    -    -    +   CAD
    #  +    -    -    -   [should not happen]
    #  -    +    +    +   [should not happen]
    #  -    +    +    -   ACD
    #  -    +    -    +   DCB
    #  -    +    -    -   DACB
    #  -    -    +    +   ADB
    #  -    -    +    -   ACDB
    #  -    -    -    +   ADCB
    #  -    -    -    -   ACB
    if key == 1111
        points[1], points[2], points[3] = A, B, C # +    +    +    +   ABC
        pop!(points)
    elseif key == 1110
        points[1], points[2], points[3], points[4] = A, B, C, D # +    +    +    -   ABCD
    elseif key == 1101
        points[1], points[2], points[3], points[4] = A, B, D, C #  +    +    -    +   ABDC
    elseif key == 1100
        points[1], points[2], points[3] = A, B, D #  +    +    -    -   ABD
        pop!(points)
    elseif key == 1011
        points[1], points[2], points[3], points[4] = A, D, B, C #  +    -    +    +   ADBC
    elseif key == 1010
        points[1], points[2], points[3] = B, C, D #  +    -    +    -   BCD
        pop!(points)
    elseif key == 1001
        points[1], points[2], points[3] = C, A, D #  +    -    -    +    CAD
        pop!(points)
    elseif key == 0110
        points[1], points[2], points[3] = A, C, D #  -    +    +    -   ACD
        pop!(points)
    elseif key == 0101
        points[1], points[2], points[3] = D, C, B #  -    +    -    +   DCB
        pop!(points)
    elseif key == 0100
        points[1], points[2], points[3], points[4] = D, A, C, B #  -    +    -    -   DACB
    elseif key == 0011
        points[1], points[2], points[3] = A, D, B #  -    -    +    +   ADB
        pop!(points)
    elseif key == 0010
        points[1], points[2], points[3], points[4] = A, C, D, B #  -    -    +    -   ACDB
    elseif key == 0001
        points[1], points[2], points[3], points[4] = A, D, C, B #  -    -    -    +   ADCB
    elseif key == 0000
        points[1], points[2], points[3] = A, C, B #  -    -    -    -   ACB
        pop!(points)
    else
        @assert false "unexpected case in convex_hull"
    end
    return points
end

function _convex_hull_1d!(points::Vector{VN}) where {N, VN<:AbstractVector{N}}
    points[1:2] = [minimum(points), maximum(points)]
    return resize!(points, 2)
end

function _convex_hull_nd!(points::Vector{VN};
                          backend=nothing,
                          solver=nothing
                          ) where {N, VN<:AbstractVector{N}}
    V = VPolytope(points)
    Vch = remove_redundant_vertices(V, backend=backend, solver=solver)
    m = length(Vch.vertices)
    points[1:m] = Vch.vertices
    return resize!(points, m)
end

function _convex_hull_2d!(points::Vector{VN};
                          algorithm="monotone_chain"
                         ) where {N, VN<:AbstractVector{N}}
    if algorithm == nothing
        algorithm = default_convex_hull_algorithm(points)
    end
    if algorithm == "monotone_chain"
        return monotone_chain!(points)
    elseif algorithm == "monotone_chain_sorted"
        return monotone_chain!(points, sort=false)
    else
        error("the convex hull algorithm $algorithm is unknown")
    end
end

"""
    monotone_chain!(points::Vector{VN}; sort::Bool=true
                   ) where {N, VN<:AbstractVector{N}}

Compute the convex hull of points in the plane using Andrew's monotone chain
method.

### Input

- `points` -- list of 2D vectors; is sorted in-place inside this function
- `sort`   -- (optional, default: `true`) flag for sorting the vertices
              lexicographically; sortedness is required for correctness

### Output

List of vectors containing the 2D coordinates of the corner points of the
convex hull.

### Notes

For large sets of points, it is convenient to use static vectors to get
maximum performance. For information on how to convert usual vectors
into static vectors, see the type `SVector` provided by the
[StaticArrays](http://juliaarrays.github.io/StaticArrays.jl/stable/)
package.

### Algorithm

This function implements Andrew's monotone chain convex hull algorithm to
construct the convex hull of a set of ``n`` points in the plane in
``O(n \\log n)`` time.
For further details see
[Monotone chain](https://en.wikibooks.org/wiki/Algorithm_Implementation/Geometry/Convex_hull/Monotone_chain)
"""
function monotone_chain!(points::Vector{VN}; sort::Bool=true
                        ) where {N, VN<:AbstractVector{N}}

    @inline function build_hull!(semihull, iterator, points)
        @inbounds for i in iterator
            while length(semihull) >= 2 &&
                    (right_turn(semihull[end-1], semihull[end], points[i])
                         <= zero(N))
                pop!(semihull)
            end
            push!(semihull, points[i])
        end
    end

    if sort
        # sort the points lexicographically
        sort!(points, by=x->(x[1], x[2]))
    end

    # build lower hull
    lower = Vector{VN}()
    iterator = 1:length(points)
    build_hull!(lower, iterator, points)

    # build upper hull
    upper = Vector{VN}()
    iterator = length(points):-1:1
    build_hull!(upper, iterator, points)

    # remove the last point of each segment because they are repeated
    copyto!(points, @view(lower[1:end-1]))
    copyto!(points, length(lower), @view(upper[1:end-1]))
    m = length(lower) + length(upper) - 2
    if m == 2 && _isapprox(points[1], points[2])
        # upper and lower chain consist of a single, identical point
        m = 1
    end
    return resize!(points, m)
end

"""
    convex_hull(U::UnionSetArray{N, PT}; kwargs...) where {N, PT<:AbstractPolytope{N}}

Compute the convex hull of a union of a finite number of polytopes.

### Input

- `U` -- UnionSetArray of polytopes

### Output

A list of the vertices of the convex hull.
"""
function convex_hull(U::UnionSetArray{N, PT}; kwargs...) where {N, PT<:AbstractPolytope{N}}
    vlist = mapreduce(vertices_list, vcat, U.array)
    return convex_hull(vlist; kwargs...)
end

"""
    convex_hull(P::VPolygon, Q::VPolygon; [algorithm]::String="monotone_chain")

Return the convex hull of two polygons in vertex representation.

### Input

- `P`         -- polygon in vertex representation
- `Q`         -- another polygon in vertex representation
- `algorithm` -- (optional, default: "monotone_chain") the algorithm used to
                 compute the convex hull

### Output

A new polygon such that its vertices are the convex hull of the given two polygons.

### Algorithm

A convex hull algorithm is used to compute the convex hull of the vertices of the
given input polygons `P` and `Q`; see `?convex_hull` for details on the available
algorithms. The vertices of the output polygon are sorted in counter-clockwise
fashion.
"""
function convex_hull(P::VPolygon, Q::VPolygon;
                     algorithm::String="monotone_chain")
    vunion = [P.vertices; Q.vertices]
    convex_hull!(vunion; algorithm=algorithm)
    return VPolygon(vunion, apply_convex_hull=false)
end

"""
    convex_hull(P1::VPolytope, P2::VPolytope; [backend]=nothing)

Compute the convex hull of the set union of two polytopes in V-representation.

### Input

- `P1`         -- polytope
- `P2`         -- another polytope
- `backend`    -- (optional, default: `nothing`) the polyhedral
                  computations backend

### Output

The `VPolytope` obtained by the concrete convex hull of `P1` and `P2`.

### Notes

This function takes the union of the vertices of each polytope and then relies
on a concrete convex hull algorithm.
For low dimensions, a specialized implementation for polygons is used.
For higher dimensions, `convex_hull` relies on the polyhedral backend that can
be specified using the `backend` keyword argument.

For performance reasons, it is suggested to use the `CDDLib.Library()` backend.
"""
function convex_hull(P1::VPolytope, P2::VPolytope; backend=nothing)
    vunion = [P1.vertices; P2.vertices]
    convex_hull!(vunion; backend=backend)
    return VPolytope(vunion)
end

"""
    convex_hull(P1::HPoly, P2::HPoly;
               [backend]=default_polyhedra_backend(P1))

Compute the convex hull of the set union of two polyhedra in H-representation.

### Input

- `P1`         -- polyhedron
- `P2`         -- another polyhedron
- `backend`    -- (optional, default: `default_polyhedra_backend(P1)`)
                  the polyhedral computations backend

### Output

The `HPolyhedron` (resp. `HPolytope`) obtained by the concrete convex hull of
`P1` and `P2`.

### Notes

For performance reasons, it is suggested to use the `CDDLib.Library()` backend
for the `convex_hull`.

For further information on the supported backends see
[Polyhedra's documentation](https://juliapolyhedra.github.io/).
"""
function convex_hull(P1::HPoly, P2::HPoly;
                     backend=default_polyhedra_backend(P1))
    require(:Polyhedra; fun_name="convex_hull")
    Pch = Polyhedra.convexhull(polyhedron(P1; backend=backend),
                               polyhedron(P2; backend=backend))
    removehredundancy!(Pch)
    return convert(basetype(P1), Pch)
end

function convex_hull(X::UnionSet)
    return convex_hull(X.X, X.Y)
end

convex_hull(X::ConvexSet, ::EmptySet) = X
convex_hull(::EmptySet, X::ConvexSet) = X
convex_hull(∅::EmptySet, ::EmptySet) = ∅

"""
    convex_hull(P1::SimpleSparsePolynomialZonotope, P2::SimpleSparsePolynomialZonotope)

Computes the convex hull of the simple sparse polynomial zonotopes `P1` and `P2`.

### Input

- `P1` : simple sparse polynomial zonotopes
- `P2` : simple sparse polynomial zonotopes

### Output

Tightest convex simple sparse polynomial zonotope containing `P1` and `P2`.
"""
function convex_hull(P1::SimpleSparsePolynomialZonotope, P2::SimpleSparsePolynomialZonotope)
    return linear_combination(linear_combination(P1, P1), linear_combination(P2, P2))
end

"""
    convex_hull(P::SimpleSparsePolynomialZonotope)

Computes the convex hull of the simple sparse polynomial zonotope `P`.

### Input

- `P` -- simple sparse polynomial zonotopes

### Output

Tightest convex simple sparse polynomial zonotope containing `P`.
"""
function convex_hull(P::SimpleSparsePolynomialZonotope)
    return linear_combination(P, P)
end
