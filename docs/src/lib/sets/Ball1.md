```@meta
CurrentModule = LazySets
```

# [Manhattan-norm ball (Ball1)](@id def_Ball1)

```@docs
Ball1
σ(::AbstractVector, ::Ball1)
∈(::AbstractVector, ::Ball1, ::Bool=false)
vertices_list(::Ball1{N, VN}) where {N, VN<:AbstractVector}
center(::Ball1)
rand(::Type{Ball1})
constraints_list(::Ball1{N}) where {N}
translate(::Ball1, ::AbstractVector)
translate!(::Ball1, ::AbstractVector)
```

Inherited from [`ConvexSet`](@ref):
* [`norm`](@ref norm(::ConvexSet, ::Real))
* [`radius`](@ref radius(::ConvexSet, ::Real))
* [`diameter`](@ref diameter(::ConvexSet, ::Real))
* [`singleton_list`](@ref singleton_list(::ConvexSet))

Inherited from [`AbstractPolytope`](@ref):
* [`isbounded`](@ref isbounded(::AbstractPolytope))
* [`isuniversal`](@ref isuniversal(::AbstractPolytope{N}, ::Bool=false) where {N})
* [`volume`](@ref volume(::AbstractPolytope))

Inherited from [`AbstractCentrallySymmetricPolytope`](@ref):
* [`dim`](@ref dim(::AbstractCentrallySymmetricPolytope))
* [`isempty`](@ref isempty(::AbstractCentrallySymmetricPolytope))
* [`an_element`](@ref an_element(::AbstractCentrallySymmetricPolytope))
