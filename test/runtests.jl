# This file is a part of Julia. License is MIT: https://julialang.org/license

module PkgTests

include("pkg.jl")
include("resolve.jl")

# clean up local registry
rm(joinpath(@__DIR__, "registry"); force = true, recursive = true)

end # module
