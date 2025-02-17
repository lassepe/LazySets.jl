# Conversion between set representations

This section of the manual lists the conversion functions between set
representations.

```@contents
Pages = ["conversion.md"]
Depth = 3
```

```@meta
CurrentModule = LazySets
```

```@docs
convert(::Type{HPOLYGON}, ::VPolygon) where {HPOLYGON<:AbstractHPolygon}
convert(::Type{Hyperrectangle}, ::AbstractHyperrectangle)
convert(::Type{Interval}, ::AbstractHyperrectangle)
convert(::Type{Interval}, ::ConvexSet{N}) where {N<:Real}
convert(::Type{Hyperrectangle}, cpa::CartesianProductArray{N, HN}) where {N<:Real, HN<:AbstractHyperrectangle{N}}
convert(::Type{Hyperrectangle}, cpa::CartesianProductArray{N, Interval{N}}) where {N<:Real}
convert(::Type{HPOLYGON}, ::AbstractHyperrectangle) where {HPOLYGON<:AbstractHPolygon}
convert(::Type{HPOLYGON}, ::HPolytope{N, VN}) where {N<:Real, VN<:AbstractVector{N}, HPOLYGON<:AbstractHPolygon}
convert(::Type{HPOLYGON}, ::AbstractSingleton{N}) where {N<:Real, HPOLYGON<:AbstractHPolygon}
convert(::Type{HPOLYGON}, ::LineSegment{N}) where {N<:Real, HPOLYGON<:AbstractHPolygon}
convert(::Type{HPOLYGON}, ::ConvexSet) where {HPOLYGON<:AbstractHPolygon}
convert(::Type{HPolyhedron}, ::AbstractPolytope)
convert(::Type{HPolytope}, ::AbstractHPolygon)
convert(::Type{HPolytope}, ::AbstractHyperrectangle)
convert(::Type{HPolytope}, ::AbstractPolytope)
convert(::Type{HPolytope}, ::VPolytope)
convert(::Type{VPolygon}, ::AbstractHPolygon)
convert(::Type{VPolytope}, ::ConvexSet)
convert(::Type{VPolytope}, ::AbstractPolytope)
convert(::Type{VPolytope}, ::HPolytope)
convert(::Type{Zonotope}, ::AbstractZonotope)
convert(::Type{IntervalArithmetic.IntervalBox}, ::AbstractHyperrectangle)
convert(::Type{Hyperrectangle}, ::IntervalArithmetic.IntervalBox)
convert(::Type{Zonotope}, ::CartesianProduct{N, ZN1, ZN2}) where {N<:Real, ZN1<:AbstractZonotope{N}, ZN2<:AbstractZonotope{N}}
convert(::Type{Hyperrectangle}, ::CartesianProduct{N, HN1, HN2}) where {N<:Real, HN1<:AbstractHyperrectangle{N}, HN2<:AbstractHyperrectangle{N}}
convert(::Type{Zonotope}, ::CartesianProduct{N, HN1, HN2}) where {N<:Real, HN1<:AbstractHyperrectangle{N}, HN2<:AbstractHyperrectangle{N}}
convert(::Type{Zonotope}, ::CartesianProductArray{N, HN}) where {N<:Real, HN<:AbstractHyperrectangle{N}}
convert(::Type{Zonotope}, ::LinearMap{N, ZN}) where {N, ZN<:AbstractZonotope{N}}
convert(::Type{Zonotope}, ::LinearMap{N, CartesianProduct{N, HN1, HN2}}) where {N, HN1<:AbstractHyperrectangle{N}, HN2<:AbstractHyperrectangle{N}}
convert(::Type{Zonotope}, ::LinearMap{N, CartesianProductArray{N, HN}}) where {N, HN<:AbstractHyperrectangle{N}}
convert(::Type{CartesianProduct{N, Interval{N}, Interval{N}}}, ::AbstractHyperrectangle{N}) where {N<:Real}
convert(::Type{CartesianProductArray{N, Interval{N}}}, ::AbstractHyperrectangle{N}) where {N<:Real}
convert(::Type{Hyperrectangle}, ::Rectification{N, AH}) where {N<:Real, AH<:AbstractHyperrectangle{N}}
convert(::Type{Interval}, ::Rectification{N, IN}) where {N<:Real, IN<:Interval{N}}
convert(::Type{IntervalArithmetic.Interval}, ::ConvexSet)
convert(::Type{Interval}, ::IntervalArithmetic.Interval)
convert(::Type{VPolytope}, ::ConvexHullArray{N, Singleton{N, VT}}) where {N, VT}
convert(::Type{VPolygon}, ::ConvexSet)
convert(::Type{MinkowskiSumArray}, ::MinkowskiSum{N, ST, MinkowskiSumArray{N, ST}}) where {N, ST}
convert(::Type{Interval}, ::MinkowskiSum{N, IT, IT}) where {N, IT<:Interval{N}}
convert(::Type{HParallelotope}, Z::AbstractZonotope{N}) where {N}
convert(::Type{Zonotope}, ::CartesianProduct{N, AZ1, AZ2}) where {N, AZ1<:AbstractZonotope{N}, AZ2<:AbstractZonotope{N}}
convert(::Type{Zonotope}, ::CartesianProductArray{N, AZ}) where {N, AZ<:AbstractZonotope{N}}
convert(::Type{STAR}, ::AbstractPolyhedron{N}) where {N}
convert(::Type{STAR}, ::Star)
convert(::Type{Star}, ::AbstractPolyhedron{N}) where {N}
convert(::Type{SimpleSparsePolynomialZonotope}, ::AbstractZonotope)
convert(::Type{SimpleSparsePolynomialZonotope}, ::SparsePolynomialZonotope)
convert(::Type{SparsePolynomialZonotope}, ::AbstractZonotope{N}) where {N}
convert(::Type{SparsePolynomialZonotope}, ::SimpleSparsePolynomialZonotope{N}) where {N}
```
