import Base: isdisjoint

export isdisjoint, is_intersection_empty

# --- disjointness check for general sets ---

"""
    isdisjoint(X::ConvexSet, Y::ConvexSet, witness::Bool=false)

Check whether two sets do not intersect, and otherwise optionally compute a
witness.

### Input

- `X`       -- set
- `Y`       -- another set
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``X ∩ Y = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``X ∩ Y = ∅``
  * `(false, v)` iff ``X ∩ Y ≠ ∅`` and ``v ∈ X ∩ Y``

### Algorithm

This is a fallback implementation that computes the concrete intersection,
`intersection`, of the given sets.

A witness is constructed using the `an_element` implementation of the result.
"""
function isdisjoint(X::ConvexSet, Y::ConvexSet, witness::Bool=false)
    cap = intersection(X, Y)
    empty_intersection = isempty(cap)
    if witness
        if empty_intersection
            N = promote_type(eltype(X), eltype(Y))
            return (true, N[])
        else
            return (false, an_element(cap))
        end
    end
    return empty_intersection
end

# --- alias ---

const is_intersection_empty = isdisjoint

# conversion for IA types
isdisjoint(X::ConvexSet, Y::IA.Interval) = isdisjoint(X, Interval(Y))
isdisjoint(X::IA.Interval, Y::ConvexSet) = isdisjoint(Interval(X), Y)

isdisjoint(X::ConvexSet, Y::IA.IntervalBox) = isdisjoint(X, convert(Hyperrectangle, Y))
isdisjoint(X::IA.IntervalBox, Y::ConvexSet) = isdisjoint(convert(Hyperrectangle, X), Y)

# --- AbstractHyperrectangle ---

"""
    isdisjoint(H1::AbstractHyperrectangle,
                          H2::AbstractHyperrectangle,
                          witness::Bool=false
                         )

Check whether two hyperrectangles do not intersect, and otherwise optionally
compute a witness.

### Input

- `H1` -- first hyperrectangle
- `H2` -- second hyperrectangle
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``H1 ∩ H2 = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``H1 ∩ H2 = ∅``
  * `(false, v)` iff ``H1 ∩ H2 ≠ ∅`` and ``v ∈ H1 ∩ H2``

### Algorithm

``H1 ∩ H2 ≠ ∅`` iff ``|c_2 - c_1| ≤ r_1 + r_2``, where ``≤`` is taken
component-wise.

A witness is computed by starting in one center and moving toward the other
center for as long as the minimum of the radius and the center distance.
In other words, the witness is the point in `H1` that is closest to the center
of `H2`.
"""
function isdisjoint(H1::AbstractHyperrectangle,
                               H2::AbstractHyperrectangle,
                               witness::Bool=false
                              )
    empty_intersection = false
    center_diff = center(H2) - center(H1)
    @inbounds for i in eachindex(center_diff)
        if abs(center_diff[i]) >
                radius_hyperrectangle(H1, i) + radius_hyperrectangle(H2, i)
            empty_intersection = true
            break
        end
    end

    if !witness
        return empty_intersection
    elseif empty_intersection
        N = promote_type(eltype(H1), eltype(H2))
        return (true, N[])
    end

    # compute a witness 'v' in the intersection
    v = copy(center(H1))
    c2 = center(H2)
    @inbounds for i in eachindex(center_diff)
        if v[i] <= c2[i]
            # second center is right of first center
            v[i] += min(radius_hyperrectangle(H1, i), center_diff[i])
        else
            # second center is left of first center
            v[i] -= min(radius_hyperrectangle(H1, i), -center_diff[i])
        end
    end
    return (false, v)
end

# --- disjointness check for 1D intervals ---

"""
    isdisjoint(I1::Interval, I2::Interval, witness::Bool=false)

Check whether two intervals do not intersect, and otherwise optionally
compute a witness.

### Input

- `I1`      -- first interval
- `I2`      -- second interval
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``I1 ∩ I2 = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``I1 ∩ I2 = ∅``
  * `(false, v)` iff ``I1 ∩ I2 ≠ ∅`` and ``v ∈ I1 ∩ I2``

### Algorithm

``I1 ∩ I2 ≠ ∅`` iff there is a gap between the left-most point of the second
interval and the left-most point of the first interval, or vice-versa.

A witness is computed by taking the maximum over the left-most points of each
interval, which is guaranteed to belong to the intersection.
"""
function isdisjoint(I1::Interval, I2::Interval, witness::Bool=false)
    if witness
        return _isdisjoint(I1, I2, Val(true))
    else
        return _isdisjoint(I1, I2, Val(false))
    end
end

function _isdisjoint(I1::Interval, I2::Interval, witness::Val{false})
    return !_leq(min(I2), max(I1)) || !_leq(min(I1), max(I2))
end

function _isdisjoint(I1::Interval, I2::Interval, witness::Val{true})
    check  = _isdisjoint(I1, I2, Val(false))
    return (check, [max(min(I1), min(I2))])
end

# --- AbstractSingleton ---

# common code for singletons
@inline function isdisjoint_helper_singleton(
        S::AbstractSingleton, X::ConvexSet, witness::Bool=false)
    empty_intersection = element(S) ∉ X
    if witness
        N = promote_type(eltype(S), eltype(X))
        return (empty_intersection, empty_intersection ? N[] : element(S))
    else
        return empty_intersection
    end
end

"""
    isdisjoint(X::ConvexSet, S::AbstractSingleton, witness::Bool=false)

Check whether a convex set and a singleton do not intersect, and otherwise
optionally compute a witness.

### Input

- `X`       -- convex set
- `S`       -- singleton
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``S ∩ X = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``S ∩ X = ∅``
  * `(false, v)` iff ``S ∩ X ≠ ∅`` and
    `v` = `element(S)` ``∈ S ∩ X``

### Algorithm

``S ∩ X = ∅`` iff `element(S)` ``∉ X``.
"""
@commutative function isdisjoint(X::ConvexSet, S::AbstractSingleton,
                                            witness::Bool=false)
    return isdisjoint_helper_singleton(S, X, witness)
end

"""
    isdisjoint(S1::AbstractSingleton,
                          S2::AbstractSingleton,
                          witness::Bool=false
                         )

Check whether two singletons do not intersect, and otherwise optionally compute
a witness.

### Input

- `S1` -- first singleton
- `S2` -- second singleton
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``S1 ∩ S2 = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``S1 ∩ S2 = ∅``
  * `(false, v)` iff ``S1 ∩ S2 ≠ ∅`` and `v` = `element(S1)` ``∈ S1 ∩ S2``

### Algorithm

``S1 ∩ S2 = ∅`` iff ``S1 ≠ S2``.
"""
function isdisjoint(S1::AbstractSingleton,
                               S2::AbstractSingleton,
                               witness::Bool=false
                              )
    empty_intersection = element(S1) != element(S2)
    if witness
        N = promote_type(eltype(S1), eltype(S2))
        return (empty_intersection, empty_intersection ? N[] : element(S1))
    else
        return empty_intersection
    end
end

"""
    isdisjoint(H::AbstractHyperrectangle,
                          S::AbstractSingleton,
                          witness::Bool=false
                         )

Check whether a hyperrectangle and a singleton do not intersect, and otherwise
optionally compute a witness.

### Input

- `H` -- hyperrectangle
- `S` -- singleton
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``H ∩ S = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``H ∩ S = ∅``
  * `(false, v)` iff ``H ∩ S ≠ ∅`` and `v` = `element(S)` ``∈ H ∩ S``

### Algorithm

``H ∩ S = ∅`` iff `element(S)` ``∉ H``.
"""
@commutative function isdisjoint(H::AbstractHyperrectangle,
                                            S::AbstractSingleton,
                                            witness::Bool=false)
    return isdisjoint_helper_singleton(S, H, witness)
end


# --- Ball2 ---


"""
    isdisjoint(B1::Ball2, B2::Ball2, witness::Bool=false)

Check whether two balls in the 2-norm do not intersect, and otherwise optionally
compute a witness.

### Input

- `B1` -- first ball in the 2-norm
- `B2` -- second ball in the 2-norm
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``B1 ∩ B2 = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``B1 ∩ B2 = ∅``
  * `(false, v)` iff ``B1 ∩ B2 ≠ ∅`` and ``v ∈ B1 ∩ B2``

### Algorithm

``B1 ∩ B2 = ∅`` iff ``‖ c_2 - c_1 ‖_2 > r_1 + r_2``.

A witness is computed depending on the smaller/bigger ball (to break ties,
choose `B1` for the smaller ball) as follows.
- If the smaller ball's center is contained in the bigger ball, we return it.
- Otherwise start in the smaller ball's center and move toward the other center
  until hitting the smaller ball's border.
  In other words, the witness is the point in the smaller ball that is closest
  to the center of the bigger ball.
"""
function isdisjoint(B1::Ball2, B2::Ball2, witness::Bool=false)
    center_diff_normed = norm(center(B2) - center(B1), 2)
    empty_intersection = center_diff_normed > B1.radius + B2.radius

    if !witness
        return empty_intersection
    elseif empty_intersection
        N = promote_type(eltype(B1), eltype(B2))
        return (true, N[])
    end

    # compute a witness 'v' in the intersection
    if B1.radius <= B2.radius
        smaller = B1
        bigger = B2
    else
        smaller = B2
        bigger = B1
    end
    if center_diff_normed <= bigger.radius
        # smaller ball's center is contained in bigger ball
        v = smaller.center
    else
        # scale center difference with smaller ball's radius
        direction = (bigger.center - smaller.center)
        v = smaller.center + direction / center_diff_normed * smaller.radius
    end
    return (false, v)
end


# --- Zonotope ---


"""
    isdisjoint(Z::AbstractZonotope, H::Union{Hyperplane, Line2D}, witness::Bool=false)

Check whether a zonotope and a hyperplane do not intersect, and otherwise
optionally compute a witness.

### Input

- `Z`       -- zonotope
- `H`       -- hyperplane
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``Z ∩ H = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``Z ∩ H = ∅``
  * `(false, v)` iff ``Z ∩ H ≠ ∅`` and ``v ∈ Z ∩ H``

### Algorithm

``Z ∩ H = ∅`` iff ``(b - a⋅c) ∉ \\left[ ± ∑_{i=1}^p |a⋅g_i| \\right]``,
where ``a``, ``b`` are the hyperplane coefficients, ``c`` is the zonotope's
center, and ``g_i`` are the zonotope's generators.

For witness production we fall back to a less efficient implementation for
general sets as the first argument.
"""
@commutative function isdisjoint(Z::AbstractZonotope,
                                            H::Union{Hyperplane, Line2D},
                                            witness::Bool=false)
    if witness
        return _isdisjoint(Z, H, Val(true))
    else
        return _isdisjoint(Z, H, Val(false))
    end
end

function _isdisjoint(Z::AbstractZonotope, H::Union{Hyperplane, Line2D}, ::Val{false})
    c, G = center(Z), genmat(Z)
    v = H.b - dot(H.a, c)

    n, p = size(G)
    p == 0 && return !isapproxzero(v)
    asum = abs_sum(H.a, G)
    return !_geq(v, -asum) || !_leq(v, asum)
end

function _isdisjoint(Z::AbstractZonotope, H::Union{Hyperplane, Line2D}, ::Val{true})
    isdisjoint_helper_hyperplane(H, Z, true)
end

"""
    isdisjoint(Z1::AbstractZonotope, Z2::AbstractZonotope,
                          witness::Bool=false)

Check whether two zonotopes do not intersect, and otherwise optionally compute a
witness.

### Input

- `Z1`      -- zonotope
- `Z2`      -- zonotope
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``Z1 ∩ Z2 = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``Z1 ∩ Z2 = ∅``
  * `(false, v)` iff ``Z1 ∩ Z2 ≠ ∅`` and ``v ∈ Z1 ∩ Z2``

### Algorithm

``Z1 ∩ Z2 = ∅`` iff ``c_1 - c_2 ∉ Z(0, (g_1, g_2))`` where ``c_i`` and ``g_i``
are the center and generators of zonotope `Zi` and ``Z(c, g)`` represents the
zonotope with center ``c`` and generators ``g``.
"""
function isdisjoint(Z1::AbstractZonotope, Z2::AbstractZonotope,
                               witness::Bool=false)
    n = dim(Z1)
    @assert n == dim(Z2) "zonotopes need to have the same dimensions"
    N = promote_type(eltype(Z1), eltype(Z2))
    Z = Zonotope(zeros(N, n), hcat(genmat(Z1), genmat(Z2)))
    result = (center(Z1) - center(Z2)) ∉ Z
    if result
        return witness ? (true, N[]) : true
    elseif witness
        error("witness production is not supported yet")
    else
        return false
    end
end

# TODO refactor to Arrays module
@inline function _cross(ls1::AbstractVector, ls2::AbstractVector)
    @inbounds ls1[1] * ls2[2] - ls1[2] * ls2[1]
end

# disambiguation
@commutative function isdisjoint(Z::AbstractZonotope,
                                            S::AbstractSingleton,
                                            witness::Bool=false)
    return isdisjoint_helper_singleton(S, Z, witness)
end

"""
    isdisjoint(ls1::LineSegment,
                          ls2::LineSegment,
                          witness::Bool=false
                         )

Check whether two line segments do not intersect, and otherwise optionally
compute a witness.

### Input

- `ls1` -- first line segment
- `ls2` -- second line segment
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``ls1 ∩ ls2 = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``ls1 ∩ ls2 = ∅``
  * `(false, v)` iff ``ls1 ∩ ls2 ≠ ∅`` and ``v ∈ ls1 ∩ ls2``

### Algorithm

The algorithm is inspired from [here](https://stackoverflow.com/a/565282), which
again is the special 2D case of a 3D algorithm by Ronald Goldman's article on the
*Intersection of two lines in three-space* in Graphics Gems, Andrew S. (ed.), 1990.

We first check if the two line segments are parallel, and if so, if they are
collinear.
In the latter case, we check containment of any of the end points in the other
line segment.
Otherwise the lines are not parallel, so we can solve an equation of the
intersection point, if it exists.
"""
function isdisjoint(ls1::LineSegment,
                               ls2::LineSegment,
                               witness::Bool=false
                              )
    r = ls1.q - ls1.p
    N = promote_type(eltype(ls1), eltype(ls2))
    # TODO change iszero to isapproxzero etc
    if iszero(r)
        # first line segment is a point
        empty_intersection = ls1.q ∉ ls2
        if witness
            return (empty_intersection, empty_intersection ? N[] : ls1.q)
        else
            return empty_intersection
        end
    end

    s = ls2.q - ls2.p
    if iszero(s)
        # second line segment is a point
        empty_intersection = ls2.q ∉ ls1
        if witness
            return (empty_intersection, empty_intersection ? N[] : ls2.q)
        else
            return empty_intersection
        end
    end

    p1p2 = ls2.p - ls1.p
    u_numerator = _cross(p1p2, r)
    u_denominator = _cross(r, s)

    if u_denominator == 0
        # line segments are parallel
        if u_numerator == 0
            # line segments are collinear
            if ls1.p ∈ ls2
                empty_intersection = false
                if witness
                    v = ls1.p
                end
            elseif ls1.q ∈ ls2
                empty_intersection = false
                if witness
                    v = ls1.q
                end
            else
                empty_intersection = true
            end
        else
            # line segments are parallel and not collinear
            empty_intersection = true
        end
    else
        # line segments are not parallel
        u = u_numerator / u_denominator
        if u < 0 || u > 1
            empty_intersection = true
        else
            t = _cross(p1p2, s) / u_denominator
            empty_intersection = t < 0 || t > 1
            if witness
                v = ls1.p + t * r
            end
        end
    end

    if witness
        return (empty_intersection, empty_intersection ? N[] : v)
    else
        return empty_intersection
    end
end


# --- Hyperplane ---


@inline function isdisjoint_helper_hyperplane(
        hp::Union{Hyperplane, Line2D},
        X::ConvexSet,
        witness::Bool=false
       )
    normal_hp = hp.a
    sv_left = σ(-normal_hp, X)
    if -dot(sv_left, -normal_hp) <= hp.b
        sv_right = σ(normal_hp, X)
        empty_intersection = (hp.b > dot(sv_right, normal_hp))
    else
        empty_intersection = true
    end
    if witness
        if empty_intersection
            N = promote_type(eltype(hp), eltype(X))
            v = N[]
        else
            point_hp = an_element(hp)
            point_line = sv_left
            dir_line = sv_right - sv_left
            d = dot((point_hp - point_line), normal_hp) /
                dot(dir_line, normal_hp)
            v = d * dir_line + point_line
        end
        return (empty_intersection, v)
    else
        return empty_intersection
    end
end


"""
    isdisjoint(X::ConvexSet,
                          hp::Union{Hyperplane, Line2D},
                          [witness]::Bool=false
                         )

Check whether a compact set an a hyperplane do not intersect, and otherwise
optionally compute a witness.

### Input

- `X`       -- compact set
- `hp`      -- hyperplane
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``X ∩ hp = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``X ∩ hp = ∅``
  * `(false, v)` iff ``X ∩ hp ≠ ∅`` and ``v ∈ X ∩ hp``

### Notes

We assume that `X` is compact.
Otherwise, the support vector queries may fail.

### Algorithm

A compact convex set intersects with a hyperplane iff the support function in
the negative resp. positive direction of the hyperplane's normal vector ``a`` is
to the left resp. right of the hyperplane's constraint ``b``:

```math
-ρ(-a) ≤ b ≤ ρ(a)
```

For witness generation, we compute a line connecting the support vectors to the
left and right, and then take the intersection of the line with the hyperplane.
We follow
[this algorithm](https://en.wikipedia.org/wiki/Line%E2%80%93plane_intersection#Algebraic_form)
for the line-hyperplane intersection.
"""
@commutative function isdisjoint(X::ConvexSet,
                                            hp::Union{Hyperplane, Line2D},
                                            witness::Bool=false)
    return isdisjoint_helper_hyperplane(hp, X, witness)
end

function isdisjoint(hp1::Union{Hyperplane, Line2D},
                               hp2::Union{Hyperplane, Line2D},
                               witness::Bool=false;
                               kwargs...
                              )
    if isequivalent(hp1, hp2)
        res = false
        if witness
            w = an_element(hp1)
        end
    else
        cap = intersection(hp1, hp2)
        res = cap isa EmptySet
        if !res && witness
            w = an_element(cap)
        end
    end
    if witness
        if res
            N = promote_type(eltype(hp1), eltype(hp2))
            return (true, N[])
        else
            return (false, w)
        end
    else
        return res
    end
end

# disambiguation
@commutative function isdisjoint(hp::Union{Hyperplane, Line2D},
                                            S::AbstractSingleton,
                                            witness::Bool=false)
    return isdisjoint_helper_singleton(S, hp, witness)
end


# --- HalfSpace ---


@inline function isdisjoint_helper_halfspace(
        hs::HalfSpace,
        X::ConvexSet,
        witness::Bool=false
       )
    if !witness
        return !_leq(-ρ(-hs.a, X), hs.b)
    end

    # for witness production, we compute the support vector instead
    svec = σ(-hs.a, X)
    empty_intersection = svec ∉ hs
    N = promote_type(eltype(hs), eltype(X))
    v = empty_intersection ? N[] : svec
    return (empty_intersection, v)
end

"""
    isdisjoint(X::ConvexSet, hs::HalfSpace, [witness]::Bool=false)

Check whether a compact set an a half-space do not intersect, and otherwise
optionally compute a witness.

### Input

- `X`       -- compact set
- `hs`      -- half-space
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``X ∩ hs = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``X ∩ hs = ∅``
  * `(false, v)` iff ``X ∩ hs ≠ ∅`` and ``v ∈ X ∩ hs``

### Notes

We assume that `X` is compact.
Otherwise, the support vector queries may fail.

### Algorithm

A compact convex set intersects with a half-space iff the support vector in
the negative direction of the half-space's normal vector ``a`` is contained in
the half-space: ``σ(-a) ∈ hs``.
The support vector is thus also a witness.

Optional keyword arguments can be passed to the `ρ` function. In particular, if
`X` is a lazy intersection, options can be passed to the line search algorithm.
"""
@commutative function isdisjoint(X::ConvexSet, hs::HalfSpace,
                                            witness::Bool=false)
    return isdisjoint_helper_halfspace(hs, X, witness)
end

"""
    isdisjoint(hs1::HalfSpace, hs2::HalfSpace, [witness]::Bool=false)

Check whether two half-spaces do not intersect, and otherwise optionally compute
a witness.

### Input

- `hs1`     -- half-space
- `hs2`     -- half-space
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``hs1 ∩ hs2 = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``hs1 ∩ hs2 = ∅``
  * `(false, v)` iff ``hs1 ∩ hs2 ≠ ∅`` and ``v ∈ hs1 ∩ hs2``

### Algorithm

Two half-spaces do not intersect if and only if their normal vectors point in
the opposite direction and there is a gap between the two defining hyperplanes.

The latter can be checked as follows:
Let ``hs_1 : a_1⋅x = b_1`` and ``hs2 : a_2⋅x = b_2``.
Then we already know that ``a_2 = -k⋅a_1`` for some positive scaling factor
``k``.
Let ``x_1`` be a point on the defining hyperplane of ``hs_1``.
We construct a line segment from ``x_1`` to the point ``x_2`` on the defining
hyperplane of ``hs_2`` by shooting a ray from ``x_1`` with direction ``a_1``.
Thus we look for a factor ``s`` such that ``(x_1 + s⋅a_1)⋅a_2 = b_2``.
This gives us ``s = (b_2 - x_1⋅a_2) / (-k a_1⋅a_1)``.
The gap exists if and only if ``s`` is positive.

If the normal vectors do not point in opposite directions, then the defining
hyperplanes intersect and we can produce a witness as follows.
All points ``x`` in this intersection satisfy ``a_1⋅x = b_1`` and ``a_2⋅x = b_2``.
Thus we have ``(a_1 + a_2)⋅x = b_1+b_2``.
We now find a dimension where ``a_1 + a_2`` is non-zero, say, ``i``.
Then the result is a vector with one non-zero entry in dimension ``i``, defined
as ``[0, …, 0, (b_1 + b_2)/(a_1[i] + a_2[i]), 0, …, 0]``.
Such a dimension ``i`` always exists.
"""
function isdisjoint(hs1::HalfSpace,
                               hs2::HalfSpace,
                               witness::Bool=false
                              )
    a1 = hs1.a
    a2 = hs2.a
    N = promote_type(eltype(hs1), eltype(hs2))
    issamedir, k = samedir(a1, -a2)
    if issamedir
        x1 = an_element(Hyperplane(a1, hs1.b))
        b2 = hs2.b
        s = (b2 - dot(x1, a2)) / (-k * dot(a1, a1))
        empty_intersection = s > 0
        if witness
            if empty_intersection
                v = N[]
            else
                # both defining hyperplanes are contained in each half-space
                v = x1
            end
        end
    else
        empty_intersection = false
        if witness
            v = zeros(N, length(a1))
            for i in 1:length(a1)
                a_sum_i = a1[i] + a2[i]
                if a_sum[i] != 0
                    v[i] = (hs1.b + hs2.b) / a_sum_i
                    break
                end
            end
        end
    end

    if !witness
        return empty_intersection
    else
        return (empty_intersection, v)
    end
end

# disambiguation
@commutative function isdisjoint(H::HalfSpace, S::AbstractSingleton,
                                            witness::Bool=false)
    return isdisjoint_helper_singleton(S, H, witness)
end

@commutative function isdisjoint(hp::Union{Hyperplane, Line2D},
                                            hs::HalfSpace, witness::Bool=false)
    return isdisjoint_helper_halfspace(hs, hp, witness)
end


# --- polyhedra ---


"""
    isdisjoint(P::AbstractPolyhedron,
                          X::ConvexSet,
                          witness::Bool=false;
                          solver=nothing
                         )

Check whether two polyhedra do not intersect.

### Input

- `P`         -- polyhedron
- `X`         -- another set (see the Notes section below)
- `witness`   -- (optional, default: `false`) compute a witness if activated
- `solver`    -- (optional, default: `nothing`) the backend used to solve the
                 linear program
- `algorithm` -- (optional, default: `"exact"`) algorithm keyword, one of:
                 * `"exact" (exact, uses a feasibility LP)
                 * `"sufficient" (sufficient, uses half-space checks)

### Output

* If `witness` option is deactivated: `true` iff ``P ∩ X = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``P ∩ X = ∅``
  * `(false, v)` iff ``P ∩ X ≠ ∅`` and ``v ∈ P ∩ X``

### Notes

For `algorithm == "exact"`, we assume that `constraints_list(X)` is defined.
For `algorithm == "sufficient"`, witness production is not supported.

For `solver == nothing` we fall back to `default_lp_solver(N)`.

### Algorithm

For `algorithm == "exact"`, see [`isempty(P::HPoly, ::Bool)`](@ref).

For `algorithm == "sufficient"`, we rely on the intersection check between the
set `X` and each constraint in `P`.
This means one support function evaluation of `X` for each constraint of `P`.
With the sufficiency algorithm, this function may return `false` even in the case
where the intersection is empty. On the other hand, if the algorithm returns
`true`, then it is guaranteed that the intersection is empty.
"""
@commutative function isdisjoint(P::AbstractPolyhedron, X::ConvexSet,
                                            witness::Bool=false;
                                            solver=nothing, algorithm="exact")
    return _isdisjoint_polyhedron(P, X, witness;
                                             solver=solver, algorithm=algorithm)
end

function _isdisjoint_polyhedron(P::AbstractPolyhedron,
                                           X::ConvexSet,
                                           witness::Bool=false;
                                           solver=nothing,
                                           algorithm="exact"
                                          )

    N = promote_type(eltype(P), eltype(X))
    if algorithm == "sufficient"
        # sufficient check for empty intersection using half-space checks
        for Hi in constraints_list(P)
            if isdisjoint(X, Hi)
                if witness
                    return (true, N[])
                end
                return true
            end
        end
        if witness
            error("witness production is not supported yet")
        end
        return false
    elseif algorithm == "exact"
        # exact check for empty intersection using a feasibility LP
        clist_P = _normal_Vector(P) # TODO
        clist_X =_normal_Vector(X) # TODO
        if solver == nothing
            solver = default_lp_solver(N)
        end
        return isempty(HPolyhedron([clist_P; clist_X]), witness; solver=solver)
    else
        error("algorithm $algorithm unknown")
    end
end

# disambiguation
function isdisjoint(P::AbstractPolyhedron,
                               Q::AbstractPolyhedron,
                               witness::Bool=false;
                               solver=nothing,
                               algorithm="exact"
                              )
    return _isdisjoint_polyhedron(P, Q, witness;
                                             solver=solver, algorithm=algorithm)
end

@commutative function isdisjoint(P::AbstractPolyhedron,
                                            hs::HalfSpace, witness::Bool=false)
    return isdisjoint_helper_halfspace(hs, P, witness)
end

@commutative function isdisjoint(P::AbstractPolyhedron,
                                            S::AbstractSingleton,
                                            witness::Bool=false)
    return isdisjoint_helper_singleton(S, P, witness)
end

@commutative function isdisjoint(P::AbstractPolyhedron,
                                            hp::Union{Hyperplane, Line2D},
                                            witness::Bool=false;
                                            solver=nothing,
                                            algorithm="exact")
    return _isdisjoint_polyhedron(P, hp, witness;
                                             solver=solver, algorithm=algorithm)
end


# --- union ---


"""
    isdisjoint(cup::UnionSet, X::ConvexSet, [witness]::Bool=false)

Check whether a union of two convex sets and another set do not intersect.

### Input

- `cup` -- union of two convex sets
- `X`   -- another set

### Output

`true` iff ``\\text{cup} ∩ X = ∅``.
"""
@commutative function isdisjoint(cup::UnionSet, X::ConvexSet,
                                            witness::Bool=false)
    return isdisjoint(UnionSetArray([cup.X, cup.Y]), X, witness)
end

# disambiguation
function isdisjoint(cup1::UnionSet, cup2::UnionSet,
                               witness::Bool=false)
    return isdisjoint(UnionSetArray([cup1.X, cup1.Y]),
                                 UnionSetArray([cup2.X, cup2.Y]), witness)
end

"""
    isdisjoint(cup::UnionSetArray, X::ConvexSet, [witness]::Bool=false)

Check whether a union of a finite number of convex sets and another set do not
intersect.

### Input

- `cup` -- union of a finite number of convex sets
- `X`   -- another set

### Output

`true` iff ``\\text{cup} ∩ X = ∅``.
"""
@commutative function isdisjoint(cup::UnionSetArray, X::ConvexSet,
                                            witness::Bool=false)
    result = true
    N = promote_type(eltype(cup), eltype(X))
    w = N[]
    for Y in array(cup)
        if witness
            result, w = isdisjoint(Y, X, witness)
        else
            result = isdisjoint(Y, X, witness)
        end
        if !result
            break
        end
    end
    return witness ? (result, w) : result
end

# disambiguation
@commutative function isdisjoint(cup1::UnionSet, cup2::UnionSetArray,
                               witness::Bool=false)
    return isdisjoint(UnionSetArray([cup1.X, cup1.Y]), cup2, witness)
end

function isdisjoint(cup1::UnionSetArray,
                               cup2::UnionSetArray,
                               witness::Bool=false)
    result = true
    N = promote_type(eltype(cup1), eltype(cup2))
    w = N[]
    for X in array(cup1)
        for Y in array(cup2)
            if witness
                result, w = isdisjoint(Y, X, witness)
            else
                result = isdisjoint(Y, X, witness)
            end
            if !result
                break
            end
        end
    end
    return witness ? (result, w) : result
end


# --- Universe ---


"""
    isdisjoint(U::Universe, X::ConvexSet, [witness]::Bool=false)

Check whether a universe and another set do not intersect.

### Input

- `U` -- universe
- `X` -- another set

### Output

`true` iff ``X ≠ ∅``.
"""
@commutative function isdisjoint(U::Universe, X::ConvexSet,
                                            witness::Bool=false)
    return _isdisjoint_universe(X, U, witness)
end

function _isdisjoint_universe(X, U::Universe{N}, witness) where {N}
    @assert dim(X) == dim(U) "the dimensions of the given sets should match " *
                             "but they are $(dim(X)) and $(dim(U)) respectively"
    result = isempty(X)
    if result
        return witness ? (result, N[]) : result
    else
        return witness ? (result, an_element(X)) : result
    end
end

# disambiguation
function isdisjoint(U::Universe, ::Universe, witness::Bool=false)
    return witness ? (false, an_element(U)) : false
end

@commutative function isdisjoint(P::AbstractPolyhedron, U::Universe,
                                            witness::Bool=false)
    return invoke(isdisjoint,
                  Tuple{Universe, ConvexSet, Bool},
                  U, P, witness)
end

@commutative function isdisjoint(S::AbstractSingleton, U::Universe,
                                            witness::Bool=false)
    return invoke(isdisjoint,
                  Tuple{Universe, ConvexSet, Bool},
                  U, S, witness)
end

@commutative function isdisjoint(hs::HalfSpace, U::Universe,
                                            witness::Bool=false)
    return invoke(isdisjoint,
                  Tuple{Universe, ConvexSet, Bool},
                  U, hs, witness)
end

@commutative function isdisjoint(U::Universe,
                                            hp::Union{Hyperplane, Line2D},
                                            witness::Bool=false)
    return invoke(isdisjoint,
                  Tuple{Universe, ConvexSet, Bool},
                  U, hp, witness)
end


# --- Complement ---


"""
    isdisjoint(C::Complement, X::ConvexSet, [witness]::Bool=false)

Check whether the complement of a convex set and another set do not intersect.

### Input

- `C` -- complement of a convex set
- `X` -- convex set

### Output

* If `witness` option is deactivated: `true` iff ``X ∩ C = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``X ∩ C = ∅``
  * `(false, v)` iff ``X ∩ C ≠ ∅`` and ``v ∈ X ∩ C``

### Algorithm

We fall back to `X ⊆ C.X`, which can be justified as follows:

```math
    X ∩ Y^C = ∅ ⟺ X ⊆ Y
```
"""
@commutative function isdisjoint(C::Complement, X::ConvexSet,
                                            witness::Bool=false)
    return ⊆(X, C.X, witness)
end

"""
    isdisjoint(cpa::CartesianProductArray, P::AbstractPolyhedron)

Check whether a polytopic Cartesian product array intersects with a polyhedron.

### Input

- `cpa` -- Cartesian product array of polytopes
- `P`   -- polyhedron

### Output

`true` iff ``\\text{cpa} ∩ Y = ∅ ``.

### Algorithm

We first identify the blocks of `cpa` in which `P` is constrained.
Then we project `cpa` to those blocks and convert the result to an `HPolytope`
`Q`.
Finally we determine whether `Q` and the projected `P` intersect.
"""
@commutative function isdisjoint(cpa::CartesianProductArray,
                                            P::AbstractPolyhedron)
    return _isdisjoint_cpa_polyhedron(cpa, P)
end

function _isdisjoint_cpa_polyhedron(cpa::CartesianProductArray, P)
    cpa_low_dim, vars, _block_structure = get_constrained_lowdimset(cpa, P)
    hpoly_low_dim = HPolytope(constraints_list(cpa_low_dim))
    return isdisjoint(hpoly_low_dim, project(P, vars))
end

# disambiguation
@commutative function isdisjoint(cpa::CartesianProductArray,
                                            hs::HalfSpace)
    return isdisjoint_helper_halfspace(hs, cpa)
end

@commutative function isdisjoint(cpa::CartesianProductArray,
                                            S::AbstractSingleton,
                                            witness::Bool=false)
    return isdisjoint_helper_singleton(S, cpa, witness)
end

@commutative function isdisjoint(cpa::CartesianProductArray,
                                            U::Universe, witness::Bool=false)
    return _isdisjoint_universe(cpa, U, witness)
end

@commutative function isdisjoint(cpa::CartesianProductArray,
                                            hp::Union{Hyperplane, Line2D},
                                            witness::Bool=false)
    return return _isdisjoint_cpa_polyhedron(cpa, hp)
end

"""
    isdisjoint(X::CartesianProductArray, Y::CartesianProductArray)

Check whether two Cartesian products of a finite number of convex sets do not
intersect.

### Input

- `X` -- Cartesian product array of convex sets
- `Y` -- Cartesian product array of convex sets

### Output

`true` iff ``X ∩ Y = ∅``.
"""
function isdisjoint(X::CartesianProductArray,
                               Y::CartesianProductArray)
    @assert same_block_structure(array(X), array(Y)) "block structure has to " *
        "be the same"

    for i in 1:length(X.array)
        if isdisjoint(X.array[i], Y.array[i])
            return true
        end
    end
    return false
end

"""
    isdisjoint(cpa::CartesianProductArray,
                          H::AbstractHyperrectangle,
                          [witness]::Bool=false)

Check whether a Cartesian product of a finite number of convex sets and a
hyperrectangular set do not intersect, and otherwise optionally compute a
witness.

### Input

- `cpa`     -- Cartesian product of a finite number of convex sets
- `H`       -- hyperrectangular set
- `witness` -- (optional, default: `false`) compute a witness if activated

### Output

* If `witness` option is deactivated: `true` iff ``cpa ∩ H = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``cpa ∩ H = ∅``
  * `(false, v)` iff ``cpa ∩ H ≠ ∅`` and ``v ∈ cpa ∩ H``

### Algorithm

The sets `cpa` and `H` are disjoint if and only if at least one block of `cpa`
and the corresponding projection of `H` are disjoint.
We perform these checks sequentially.
"""
@commutative function isdisjoint(cpa::CartesianProductArray,
                                            H::AbstractHyperrectangle,
                                            witness::Bool=false)
    N = promote_type(eltype(cpa), eltype(H))
    if witness
        w = zeros(N, dim(H))
    end
    n = dim(H)
    block_start = 1
    for bi in array(cpa)
        ni = dim(bi)
        block = block_start:(block_start + ni - 1)
        Hi = project(H, block, Hyperrectangle, n)
        res = isdisjoint(bi, Hi, witness)
        if witness
            if res[1]
                return (true, N[])
            else
                w[block] = res[2]
            end
        elseif res
            return true
        end
        block_start += ni
    end
    return witness ? (false, w) : false
end

@commutative function isdisjoint(::EmptySet, ::ConvexSet)
    return true
end

@commutative function isdisjoint(::EmptySet, ::AbstractPolyhedron)
    return true
end

@commutative function isdisjoint(::EmptySet, ::AbstractSingleton)
    return true
end

@commutative function isdisjoint(::EmptySet, ::Universe)
    return true
end

@commutative function isdisjoint(::EmptySet, ::HalfSpace)
    return true
end

@commutative function isdisjoint(::EmptySet, ::Union{Hyperplane, Line2D})
    return true
end

function isdisjoint(::EmptySet, ::EmptySet)
    return true
end

# =================================================================
# Disjointness methods for two-dimensional lines and line segments
# =================================================================

"""
    isdisjoint(L1::Line2D, L2::Line2D, witness::Bool=false)

Check whether two two-dimensional lines do not intersect.

### Input

- `L1` -- line
- `L2` -- line

### Output

* If `witness` option is deactivated: `true` iff ``L1 ∩ L2 = ∅``
* If `witness` option is activated:
  * `(true, [])` iff ``L1 ∩ L2 = ∅``
  * `(false, v)` iff ``L1 ∩ L2 ≠ ∅`` and ``v ∈ L1 ∩ L2``
"""
function isdisjoint(L1::Line2D, L2::Line2D, witness::Bool=false)
    disjoint = _isdisjoint(L1, L2)
    if !witness
        return disjoint
    else
        if disjoint
            N = promote_type(eltype(L1), eltype(L2))
            return (true, N[])
        else
            return (false, an_element(intersection(L1, L2)))
        end
    end
end

# the lines do not intersect <=> det is zero and they are not identical
function _isdisjoint(L1::Line2D, L2::Line2D)
    det = _det(L1, L2)
    disjoint = isapproxzero(det) && !isapprox(L1.b, L2.b)
    return disjoint
end

@inline function _det(L1::Line2D, L2::Line2D)
    @inbounds det = L1.a[1] * L2.a[2] - L1.a[2] * L2.a[1]
end

for ST in (AbstractZonotope, AbstractSingleton)
    @eval @commutative function isdisjoint(C::CartesianProduct{N, <:ConvexSet, <:Universe}, Z::$(ST)) where N
        X = C.X
        Zp = project(Z, 1:dim(X))
        return isdisjoint(X, Zp)
    end

    @eval @commutative function isdisjoint(C::CartesianProduct{N, <:Universe, <:ConvexSet}, Z::$(ST)) where N
        Y = C.Y
        Zp = project(Z, dim(C.X)+1:dim(C))
        return isdisjoint(Y, Zp)
    end

    # disambiguation
    @eval @commutative function isdisjoint(C::CartesianProduct{N, <:Universe, <:Universe}, Z::$(ST)) where N
        return false
    end
end
