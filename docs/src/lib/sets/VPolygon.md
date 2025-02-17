```@meta
CurrentModule = LazySets
```

# [Polygon in vertex representation (VPolygon)](@id def_VPolygon)

```@docs
VPolygon
σ(::AbstractVector, ::VPolygon)
∈(::AbstractVector, ::VPolygon)
an_element(::VPolygon)
rand(::Type{VPolygon})
vertices_list(::VPolygon)
tohrep(::VPolygon{N}, ::Type{HPOLYGON}=HPolygon) where {N, HPOLYGON<:AbstractHPolygon}
tovrep(::VPolygon)
constraints_list(::VPolygon)
translate(::VPolygon, ::AbstractVector)
translate!(::VPolygon, ::AbstractVector)
remove_redundant_vertices(::VPolygon; ::String="monotone_chain")
remove_redundant_vertices!(::VPolygon; ::String="monotone_chain")
```
Inherited from [`ConvexSet`](@ref):
* [`norm`](@ref norm(::ConvexSet, ::Real))
* [`radius`](@ref radius(::ConvexSet, ::Real))
* [`diameter`](@ref diameter(::ConvexSet, ::Real))
* [`singleton_list`](@ref singleton_list(::ConvexSet))

Inherited from [`AbstractPolyhedron`](@ref):
* [`linear_map`](@ref linear_map(::AbstractMatrix{NM}, ::AbstractPolyhedron{NP}) where {NM, NP})

Inherited from [`AbstractPolytope`](@ref):
* [`isbounded`](@ref isbounded(::AbstractPolytope))
* [`isempty`](@ref isempty(::AbstractPolytope))
* [`isuniversal`](@ref isuniversal(::AbstractPolytope{N}, ::Bool=false) where {N})
* [`volume`](@ref volume(::AbstractPolytope))

Inherited from [`AbstractPolygon`](@ref):
* [`dim`](@ref dim(::AbstractPolygon))
