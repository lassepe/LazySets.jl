```@meta
CurrentModule = LazySets
```

# Utility functions

## Functions and Macros

```@docs
an_element_helper
binary_search_constraints
get_radius!
is_tighter_same_dir_2D
sign_cadlag
_leq_trig
_random_zero_sum_vector
rectify
same_block_structure
σ_helper
get_constrained_lowdimset
minmax
arg_minmax
@neutral
@absorbing
@neutral_absorbing
@declare_array_version
@array_neutral
@array_absorbing
```

## Types

```@docs
CachedPair
```

## Inspection of set interfaces

```@docs
implementing_sets
```

## Reading and writing

```@docs
LazySets.read_gen(::String)
```

## Sampling

```@docs
_sample_unit_nsphere_muller!
_sample_unit_nball_muller!
sample
LazySets.AbstractSampler
LazySets.CombinedSampler
LazySets.FaceSampler
LazySets.HalfSpaceSampler
LazySets.HyperplaneSampler
LazySets.SingletonSampler
LazySets.RejectionSampler
LazySets.RandomWalkSampler
```

## Volume

```@docs
volume
```

## Symbolics

```@docs
LazySets._vec
```
