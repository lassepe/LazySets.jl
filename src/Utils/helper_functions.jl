"""
    sign_cadlag(x::N) where {N<:Real}

This function works like the sign function but is ``1`` for input ``0``.

### Input

- `x` -- real scalar

### Output

``1`` if ``x ≥ 0``, ``-1`` otherwise.

### Notes

This is the sign function right-continuous at zero (see
[càdlàg function](https://en.wikipedia.org/wiki/C%C3%A0dl%C3%A0g)).
It can be used with vector-valued arguments via the dot operator.

### Examples

```jldoctest
julia> LazySets.sign_cadlag.([-0.6, 1.3, 0.0])
3-element Vector{Float64}:
 -1.0
  1.0
  1.0
```
"""
function sign_cadlag(x::N) where {N<:Real}
    return x < zero(x) ? -one(x) : one(x)
end

"""
    implementing_sets(op::Function;
                      signature::Tuple{Vector{Type}, Int}=(Type[], 1),
                      type_args=Float64, binary::Bool=false)

Compute a dictionary containing information about availability of (unary or
binary) concrete set operations.

### Input

- `op`        -- set operation (respectively its `Function` object)
- `signature` -- (optional, default: `Type[]`) the type signature of the
                 function without the `ConvexSet` type(s) (see also the `index`
                 option and the `Examples` section below)
- `index`     -- (optional, default: `1`) index of the set type in the signature
                 in the unary case (see the `binary` option)
- `type_args` -- (optional, default: `Float64`) type arguments added to the
                 `ConvexSet`(s) when searching for available methods; valid
                 inputs are a type or `nothing`, and in the unary case (see the
                 `binary` option) it can also be a list of types
- `binary`    -- (optional, default: `false`) flag indicating whether `op` is a
                 binary function (`true`) or a unary function (`false`)

### Output

A dictionary with three keys each mapping to a list:
- `"available"` -- This list contains all set types such that there exists an
                   implementation of `op`.
- `"missing"`   -- This list contains all set types such that there does not
                   exist an implementation of `op`. Note that this is the
                   complement of the `"available"` list.
- `"specific"`  -- This list contains all set types such that there exists a
                   type-specific implementation. Note that those set types also
                   occur in the `"available"` list.

In the unary case, the lists contain set types.
In the binary case, the lists contain pairs of set types.

### Examples

```jldoctests
julia> using LazySets: implementing_sets

julia> dict = implementing_sets(tovrep);

julia> dict["available"]  # tovrep is only available for polyhedral set types
6-element Vector{Type}:
 HPolygon
 HPolygonOpt
 HPolyhedron
 HPolytope
 VPolygon
 VPolytope

julia> dict = implementing_sets(σ; signature=Type[AbstractVector{Float64}], index=2);

julia> isempty(dict["missing"])  # every set type implements function σ
true

julia> N = Rational{Int};  # restriction of the number type

julia> dict = implementing_sets(σ; signature=Type[AbstractVector{N}], index=2, type_args=N);

julia> dict["missing"]  # some set types are not available with number type N
3-element Vector{Type}:
 Ball2
 Ballp
 Ellipsoid

julia> dict = LazySets.implementing_sets(convex_hull; binary=true);  # binary case

julia> (HPolytope, HPolytope) ∈ dict["available"]  # dict contains pairs now
true
```
"""
function implementing_sets(op::Function;
                           signature::Vector{Type}=Type[],
                           index::Int=1,
                           type_args=Float64,
                           binary::Bool=false)
    function get_unary_dict()
        return Dict{String, Vector{Type}}("available" => Vector{Type}(),
                                          "missing" => Vector{Type}(),
                                          "specific" => Vector{Type}())
    end

    if !binary
        # unary case
        dict = get_unary_dict()
        _implementing_sets_unary!(dict, op, signature, index, type_args)
        return dict
    end

    # binary case by considering all set types as second argument
    binary_dict = Dict{String, Vector{Tuple{Type, Type}}}(
        "available" => Vector{Tuple{Type, Type}}(),
        "missing" => Vector{Tuple{Type, Type}}(),
        "specific" => Vector{Tuple{Type, Type}}())
    signature_copy = copy(signature)
    insert!(signature_copy, 1, ConvexSet)  # insert a dummy type
    for set_type in subtypes(ConvexSet, true)
        augmented_set_type = set_type
        try
            if type_args isa Type
                augmented_set_type = set_type{type_args}
            else
                @assert type_args == nothing "for binary functions, " *
                    "`type_args` must not be a list"
            end
        catch e
            # type combination not available
            push!(binary_dict["missing"], (set_type, ConvexSet))
            continue
        end
        signature_copy[1] = augmented_set_type  # replace dummy type
        unary_dict = get_unary_dict()
        _implementing_sets_unary!(unary_dict, op, signature_copy, 1, type_args)

        # create pairs
        for key in ["available", "missing", "specific"]
            i = 1
            for other_set_type in unary_dict[key]
                push!(binary_dict[key], (set_type, other_set_type))
                i += 1
            end
        end
    end
    return binary_dict
end

function _implementing_sets_unary!(dict, op, signature, index, type_args)
    function create_type_tuple(given_type)
        if isempty(signature)
            return Tuple{given_type}
        end
        # create dynamic tuple
        new_signature = copy(signature)
        insert!(new_signature, index, given_type)
        return Tuple{new_signature...}
    end

    for set_type in subtypes(ConvexSet, true)
        augmented_set_type = set_type
        try
            if type_args isa Type
                augmented_set_type = set_type{type_args}
            elseif type_args != nothing
                augmented_set_type = set_type{type_args...}
            end
        catch e
            # type combination not available
            push!(dict["missing"], set_type)
            continue
        end
        tuple_set_type = create_type_tuple(augmented_set_type)
        if !hasmethod(op, tuple_set_type)
            # implementation not available
            push!(dict["missing"], set_type)
            continue
        end
        # implementation available
        push!(dict["available"], set_type)

        # check if there is a type-specific method
        super_type = supertype(augmented_set_type)
        tuple_super_type = create_type_tuple(super_type)
        if !hasmethod(op, tuple_super_type)
            continue
        end
        method_set_type = which(op, tuple_set_type)
        method_super_type = which(op, tuple_super_type)
        if method_set_type != method_super_type
            push!(dict["specific"], set_type)
        end
    end
end

# check that the given coordinate i can be used to index an arbitrary element in the set X
@inline function _check_bounds(X, i)
    1 <= i <= dim(X) || throw(ArgumentError("there is no index at coordinate $i, since the set is of dimension $(dim(X))"))
end

"""
    read_gen(filename::String)

Read a sequence of polygons stored in vertex representation (gen format).

### Input

- `filename` -- path of the file containing the polygons

### Output

A list of polygons in vertex representation.

### Notes

The `x` and `y` coordinates of each vertex should be separated by an empty space,
and polygons are separated by empty lines (even the last polygon). For example:

```julia
1.01 1.01
0.99 1.01
0.99 0.99
1.01 0.99

0.908463 1.31047
0.873089 1.31047
0.873089 1.28452
0.908463 1.28452


```
This is parsed as

```julia
2-element Array{VPolygon{Float64, Vector{Float64}},1}:
 VPolygon{Float64, Vector{Float64}}([[1.01, 1.01], [0.99, 1.01], [0.99, 0.99], [1.01, 0.99]])
 VPolygon{Float64, Vector{Float64}}([[0.908463, 1.31047], [0.873089, 1.31047], [0.873089, 1.28452], [0.908463, 1.28452]])
```
"""
function read_gen(filename::String)
    Mi = Vector{Vector{Float64}}()
    P = Vector{VPolygon{Float64, Vector{Float64}}}()

    # detects when we finished reading a new polygon, needed because polygons
    # may be separated by more than one end-of-line
    new_polygon = true
    open(filename) do f
        for line in eachline(f)
            if !isempty(line)
                push!(Mi, map(x -> parse(Float64, x), split(line)))
                new_polygon = true
             elseif isempty(line) && new_polygon
                push!(P, VPolygon(Mi))
                Mi = Vector{Vector{Float64}}()
                new_polygon = false
             end
        end
    end
    return P
end

"""
    minmax(A, B, C)

Compute the minimum and maximum of three numbers A, B, C.

### Input

- `A` -- first number
- `B` -- second number
- `C` -- third number

### Output

The minimum and maximum of three given numbers.

### Examples

```jldoctest
julia> LazySets.minmax(1.4, 52.4, -5.2)
(-5.2, 52.4)
```
"""
function minmax(A, B, C)
    if A > B
        min, max = B, A
    else
        min, max = A, B
    end
    if C > max
        max = C
    elseif C < min
        min = C
    end
    return min, max
end

"""
    arg_minmax(A, B, C)

Compute the index (1, 2, 3) of the minimum and maximum of three numbers A, B, C.

### Input

- `A` -- first number
- `B` -- second number
- `C` -- third number

### Output

The index of the minimum and maximum of the three given numbers.

### Examples

```jldoctest
julia> LazySets.arg_minmax(1.4, 52.4, -5.2)
(3, 2)
```
"""
function arg_minmax(A, B, C)
    if A > B
        min, max = B, A
        imin, imax = 2, 1
    else
        min, max = A, B
        imin, imax = 1, 2
    end
    if C > max
        imax = 3
    elseif C < min
        imin = 3
    end
    return imin, imax
end
