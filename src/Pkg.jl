# This file is a part of Julia. License is MIT: https://julialang.org/license

module Pkg

import Random
import REPL

export @pkg_str
export PackageSpec
export PackageMode, PKGMODE_MANIFEST, PKGMODE_PROJECT
export UpgradeLevel, UPLEVEL_MAJOR, UPLEVEL_MAJOR, UPLEVEL_MINOR, UPLEVEL_PATCH
export RegistrySpec

depots() = Base.DEPOT_PATH
function depots1()
    d = depots()
    isempty(d) && Pkg.Types.pkgerror("no depots found in DEPOT_PATH")
    return d[1]
end

logdir() = joinpath(depots1(), "logs")
devdir() = get(ENV, "JULIA_PKG_DEVDIR", joinpath(depots1(), "dev"))
envdir(depot = depots1()) = joinpath(depot, "environments")
const UPDATED_REGISTRY_THIS_SESSION = Ref(false)

# load snapshotted dependencies
include("../ext/TOML/src/TOML.jl")

include("GitTools.jl")
include("PlatformEngines.jl")
include("Types.jl")
include("Display.jl")
include("Pkg2/Pkg2.jl")
include("GraphType.jl")
include("Resolve.jl")
include("Operations.jl")
include("API.jl")
include("Registry.jl")
include("REPLMode.jl")

import .REPLMode: @pkg_str
import .Types: UPLEVEL_MAJOR, UPLEVEL_MINOR, UPLEVEL_PATCH, UPLEVEL_FIXED
import .Types: PKGMODE_MANIFEST, PKGMODE_PROJECT
# legacy CI script support
import .API: clone, dir


"""
    PackageMode

An enum with the instances

  * `PKGMODE_MANIFEST`
  * `PKGMODE_PROJECT`

Determines if operations should be made on a project or manifest level.
Used as an argument to  [`PackageSpec`](@ref) or as an argument to [`Pkg.rm`](@ref).
"""
const PackageMode = Types.PackageMode


"""
    UpgradeLevel

An enum with the instances

  * `UPLEVEL_FIXED`
  * `UPLEVEL_PATCH`
  * `UPLEVEL_MINOR`
  * `UPLEVEL_MAJOR`

Determines how much a package is allowed to be updated.
Used as an argument to  [`PackageSpec`](@ref) or as an argument to [`Pkg.update`](@ref).
"""
const UpgradeLevel = Types.UpgradeLevel

# Define new variables so tab comleting Pkg. works.
"""
    Pkg.add(pkg::Union{String, Vector{String})
    Pkg.add(pkg::Union{PackageSpec, Vector{PackageSpec}})

Add a package to the current project. This package will be available using the
`import` and `using` keywords in the Julia REPL and if the current project is
a package, also inside that package.

# Examples
```julia
Pkg.add("Example") # Add a package from registry
Pkg.add(PackageSpec(name="Example", version="0.3")) # Specify version
Pkg.add(PackageSpec(url="https://github.com/JuliaLang/Example.jl", rev="master")) # From url
Pkg.add(PackageSpec(url="/remote/mycompany/juliapackages/OurPackage"))` # From path (has to be a gitrepo)
```

See also [`PackageSpec`](@ref).
"""
const add = API.add

"""
    Pkg.rm(pkg::Union{String, Vector{String})
    Pkg.rm(pkg::Union{PackageSpec, Vector{PackageSpec}})

Remove a package from the current project. If the `mode` of `pkg` is
`PKGMODE_MANIFEST` also remove it from the manifest including all
recursive dependencies of `pkg`.

See also [`PackageSpec`](@ref), [`PackageMode`](@ref).
"""
const rm = API.rm

"""
    Pkg.update(; level::UpgradeLevel=UPLEVEL_MAJOR, mode::PackageMode = PKGMODE_PROJECT)
    Pkg.update(pkg::Union{String, Vector{String})
    Pkg.update(pkg::Union{PackageSpec, Vector{PackageSpec}})

Update a package `pkg`. If no posistional argument is given, update all packages in the manifest if `mode` is `PKGMODE_MANIFEST` and packages in both manifest and project if `mode` is `PKGMODE_PROJECT`.
If no positional argument is given `level` can be used to control what how much packages are allowed to be upgraded (major, minor, patch, fixed).

See also [`PackageSpec`](@ref), [`PackageMode`](@ref), [`UpgradeLevel`](@ref).
"""
const update = API.up


"""
    Pkg.test(; coverage::Bool=true)
    Pkg.test(pkg::Union{String, Vector{String}; coverage::Bool=true)
    Pkg.test(pkgs::Union{PackageSpec, Vector{PackageSpec}}; coverage::Bool=true)

Run the tests for package `pkg` or if no positional argument is given to `test`,
the current project is tested (which thus needs to be a package).
A package is tested by running its `test/runtests.jl` file.

The tests are run by generating a temporary environment with only `pkg` and its (recursive) dependencies
(recursively) in it. If a manifest exist, the versions in that manifest is used, otherwise
a feasible set of package are resolved and installed.

During the test, test-specific dependencies are active, which are
given in the project file as e.g.

```
[extras]
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[targets]
test = [Test]
```

Coverage statistics for the packages may be generated by
passing `coverage=true`. The default behavior is not to run coverage.

The tests are executed in a new process with `check-bounds=yes` and by default `startup-file=no`.
If using the startup file (`~/.julia/config/startup.jl`) is desired, start julia with `--startup-file=yes`.
"""
const test = API.test

"""
    Pkg.gc()

Garbage collect packages that are no longer reachable from any project.
Only packages that are tracked by version are deleted, so no packages
that might contain local changes are touched.
"""
const gc = API.gc


"""
    Pkg.build()
    Pkg.build(pkg::Union{String, Vector{String})
    Pkg.build(pkgs::Union{PackageSpec, Vector{PackageSpec}})

Run the build script in `deps/build.jl` for `pkg` and all of the dependencies in
depth-first recursive order.
If no argument is given to `build`, the current project is built, which thus needs
to be a package.
This function is called automatically one any package that gets installed
for the first time.
"""
const build = API.build

# TODO: decide what to do with this
const installed = API.installed

"""
    Pkg.pin(pkg::Union{String, Vector{String})
    Pkg.pin(pkgs::Union{Packagespec, Vector{Packagespec}})

Pin a package to the current version (or the one given in the `packagespec` or a certain
git revision. A pinned package is never updated.
"""
const pin = API.pin

"""
    Pkg.free(pkg::Union{String, Vector{String})
    Pkg.free(pkgs::Union{Packagespec, Vector{Packagespec}})

Free a package which removes a `pin` if it exists, or if the package is tracking a path,
e.g. after [`Pkg.develop`](@ref), go back to tracking registered versions.

# Examples
```julia
Pkg.free("Package")
Pkg.free(PackageSpec("Package"))
```
"""
const free = API.free


"""
    Pkg.develop(pkg::Union{String, Vector{String})
    Pkg.develop(pkgs::Union{Packagespec, Vector{Packagespec}})

Make a package available for development by tracking it by path.
If `pkg` is given with only a name or by a URL the packages will be downloaded
to the location by the environment variable `JULIA_PKG_DEVDIR` with
`.julia/dev` as the default.

If `pkg` is given as a local path, the package at that path will be tracked.

# Examples
```julia
# By name
Pkg.develop("Example")

# By url
Pkg.develop(PackageSpec(url="https://github.com/JuliaLang/Compat.jl"))

# By path
Pkg.develop(PackageSpec(path="MyJuliaPackages/Package.jl")
```

See also [`PackageSpec`](@ref)

"""
const develop = API.develop

#TODO: Will probably be deprecated for something in PkgDev
const generate = API.generate

"""
    Pkg.instantiate()

If a `Manifest.toml` file exist in the current project, download all
the packages declared in that manifest.
Else, resolve a set of feasible packages from the `Project.toml` files
and install them.
"""
const instantiate = API.instantiate

"""
    Pkg.resolve()

Update the current manifest with eventual changes to the dependency graph
from packages that are tracking a path.
"""
const resolve = API.resolve

"""
    Pkg.status(mode::PackageMode=PKGMODE_PROJECT)

Print out the status of the project/manifest.
If `mode` is `PKGMODE_PROJECT` prints out status about only those packages
that are in the project (explicitly added). If `mode` is `PKGMODE_MANIFEST`
also print for those in the manifest (recursive dependencies).
"""
const status = API.status


"""
    Pkg.activate([s::String]; shared::Bool=false)

Activate the environment at `s`. The active environment is the environment
that is modified by executing package commands.
The logic for what path is activated is as follows:

  * If `shared` is `true`, the first existing environment named `s` from the depots
    in the depot stack will be activated. If no such environment exists yet,
    activate it in the first depot.
  * If `s` is a path that exist, that environment will be activated.
  * If `s` is a package name in the current project activate that is tracking a path,
    activate the environment at that path.
  * If `s` is a non-existing path, activate that path.

If no argument is given to `activate`, activate the home project,
which is the one specified by either `--project` command line when starting julia,
or `JULIA_PROJECT` environment variable.

# Examples
```
Pkg.activate()
Pkg.activate("local/path")
Pkg.activate("MyDependency")
```
"""
const activate = API.activate


"""
    PackageSpec(name::String, [uuid::UUID, version::VersionNumber])
    PackageSpec(; name, url, path, rev, version, mode, level)

A `PackageSpec` is a representation of a package with various metadata.
This includes:

  * The `name` of the package.
  * The package unique `uuid`.
  * A `version` (for example when adding a package. When upgrading, can also be an instance of
   the enum [`UpgradeLevel`](@ref)
  * A `url` and an optional git `rev`ision. `rev` could be a branch name or a git commit SHA.
  * A local path `path`. This is equivalent to using the `url` argument but can be more descriptive.
  * A `mode`, which is an instance of the enum [`PackageMode`](@ref) which can be either `PKGMODE_PROJECT` or
   `PKGMODE_MANIFEST`, defaults to `PKGMODE_PROJECT`. Used in e.g. [`Pkg.rm`](@ref).

Most functions in Pkg take a `Vector` of `PackageSpec` and do the operation on all the packages
in the vector.

Below is a comparison between the REPL version and the `PackageSpec` version:

| `REPL`               | `API`                                         |
|:---------------------|:----------------------------------------------|
| `Package`            | `PackageSpec("Package")`                      |
| `Package@0.2`        | `PackageSpec(name="Package", version="0.2")`  |
| `Package=a67d...`    | `PackageSpec(name="Package", uuid="a67d..."`  |
| `Package#master`     | `PackageSpec(name="Package", rev="master")`   |
| `local/path#feature` | `PackageSpec(path="local/path"; rev="feature)` |
| `www.mypkg.com`      | `PackageSpec(url="www.mypkg.com")`              |
| `--manifest Package` | `PackageSpec(name="Package", mode=PKGSPEC_MANIFEST)`|
| `--major Package`    | `PackageSpec(name="Package", version=PKGLEVEL_MAJOR`)|
"""
const PackageSpec = Types.PackageSpec

"""
    Pkg.setprotocol!(proto::Union{Nothing, AbstractString}=nothing)

Set the protocol used to access GitHub-hosted packages when `add`ing a url or `develop`ing a package.
Defaults to 'https', with `proto == nothing` delegating the choice to the package developer.
"""
const setprotocol! = API.setprotocol!

"""
    RegistrySpec(name::String)
    RegistrySpec(; name, url, path)

A `RegistrySpec` is a representation of a registry with various metadata, much like
[`PackageSpec`](@ref).

Most registry functions in Pkg take a `Vector` of `RegistrySpec` and do the operation
on all the registries in the vector.

Below is a comparison between the REPL version and the `RegistrySpec` version:

| `REPL`               | `API`                                           |
|:---------------------|:------------------------------------------------|
| `Registry`           | `RegistrySpec("Registry")`                      |
| `Registry=a67d...`   | `RegistrySpec(name="Registry", uuid="a67d..."`  |
| `local/path`         | `RegistrySpec(path="local/path")`               |
| `www.myregistry.com` | `RegistrySpec(url="www.myregistry.com")`        |
"""
const RegistrySpec = Types.RegistrySpec


function __init__()
    if isdefined(Base, :active_repl)
        REPLMode.repl_init(Base.active_repl)
    else
        atreplinit() do repl
            if isinteractive() && repl isa REPL.LineEditREPL
                isdefined(repl, :interface) || (repl.interface = REPL.setup_interface(repl))
                REPLMode.repl_init(repl)
            end
        end
    end
end

METADATA_compatible_uuid(pkg::String) = Types.uuid5(Types.uuid_package, pkg)

##################
# Precompilation #
##################

const CTRL_C = '\x03'
const precompile_script = """
    import Pkg
    tmp = mktempdir()
    cd(tmp)
    empty!(DEPOT_PATH)
    pushfirst!(DEPOT_PATH, tmp)
    # Prevent cloning registry
    mkdir("registries")
    touch("registries/blocker") # prevents default registry from cloning
    touch("Project.toml")
    ] activate .
    $CTRL_C
    Pkg.add("Test") # adding an stdlib doesn't require internet access
    ] add Te\t\t$CTRL_C
    ] st
    $CTRL_C
    rm(tmp; recursive=true)"""

end # module
