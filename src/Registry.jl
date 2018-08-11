module Registry

import ..Pkg, ..Types, ..API
using Pkg: depots1
using ..Types: RegistrySpec, Context


"""
    Pkg.Registry.add(url::String, depot::String=DEPOT_PATH[1])
    Pkg.Registry.add(registry::RegistrySpec, depot::String=DEPOT_PATH[1])

Add new package registries.

# Examples
```julia
Pkg.Registry.add("General")
Pkg.Registry.add(RegistrySpec(uuid = "23338594-aafe-5451-b93e-139f81909106"))
Pkg.Registry.add(RegistrySpec(url = "https://github.com/JuliaRegistries/General.git"))
```
"""
function add end
add(reg::Union{String,RegistrySpec}, depot::String = depots1()) = add([reg], depot)
add(regs::Vector{String}, depot::String = depots1()) =
    add([RegistrySpec(name = name) for name in regs], depot)
add(regs::Vector{RegistrySpec}, depot::String = depots1()) =
    add(Context(), regs, depot)
add(ctx::Context, regs::Vector{RegistrySpec}, depot::String = depots1()) =
    Types.clone_or_cp_registries(ctx, regs, depot)

"""
    Pkg.Registry.rm(registry::String; depot = DEPOT_PATH[1])
    Pkg.Registry.rm(registry::RegistrySpec; depot = DEPOT_PATH[1])

Remove registries.

# Examples
```julia
Pkg.Registry.rm("General")
Pkg.Registry.rm(RegistrySpec(uuid = "23338594-aafe-5451-b93e-139f81909106"))
```
"""
function rm end
rm(reg::Union{String,RegistrySpec}) = rm([reg])
rm(regs::Vector{String}) = rm([RegistrySpec(name = name) for name in regs])
rm(regs::Vector{RegistrySpec}) = rm(Context(), regs)
rm(ctx::Context, regs::Vector{RegistrySpec}) = Types.remove_registries(ctx, regs)

"""
    Pkg.Registry.up(; depot = DEPOT_PATH[1])
    Pkg.Registry.up(registry::RegistrySpec; depot = DEPOT_PATH[1])
    Pkg.Registry.up(registry::Vector{RegistrySpec}; depot = DEPOT_PATH[1])

Update registries. If no registries are given, update
all available registries.

# Examples
```julia
Pkg.Registry.up()
Pkg.Registry.up("General")
Pkg.Registry.rm(RegistrySpec(uuid = "23338594-aafe-5451-b93e-139f81909106"))
```
"""
function up end
up(reg::Union{String,RegistrySpec}) = up([reg])
up(regs::Vector{String}) = up([RegistrySpec(name = name) for name in regs])
up(regs::Vector{RegistrySpec} = Types.collect_registries(;clone_default=false)) = up(Context(), regs)
up(ctx::Context, regs::Vector{RegistrySpec} = Types.collect_registries(;clone_default=false)) =
    Types.update_registries(ctx, regs)

"""
    Pkg.Registry.status()

Display information about available registries.
"""
function status()
    regs = Types.collect_registries(;clone_default=false)
    regs = unique(r -> r.uuid, regs) # Maybe not?
    Types.printpkgstyle(stdout, Symbol("Registry Status"), "")
    if isempty(regs)
        println(" (no registries found)")
    else
        for reg in regs
            printstyled(" [$(string(reg.uuid)[1:8])]"; color = :light_black)
            print(" $(reg.name)")
            reg.url === nothing || print(" ($(reg.url))")
            println()
        end
    end
end

end # module
