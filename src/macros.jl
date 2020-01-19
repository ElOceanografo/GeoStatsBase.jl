# ------------------------------------------------------------------
# Licensed under the ISC License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    @metasolver solver solvertype body

A helper macro to create a solver named `solver` of type `solvertype`
with parameters specified in `body`.

## Examples

Create a solver with parameters `mean` and `variogram` for each variable
of the problem, and a global parameter that specifies whether or not
to use the GPU:

```julia
julia> @metasolver MySolver AbstractSimulationSolver begin
  @param mean = 0.0
  @param variogram = GaussianVariogram()
  @jparam rho = 0.7
  @global gpu = false
end
```

### Notes

This macro is not intended to be used directly, see other macros defined
below for estimation and simulation solvers.
"""
macro metasolver(solver, solvertype, body)
  # discard any content that doesn't start with @param or @global
  content = filter(arg -> arg isa Expr, body.args)

  # lines starting with @param refer to single variable parameters
  vparams = filter(p -> p.args[1] == Symbol("@param"), content)
  vparams = map(p -> p.args[3], vparams)

  # lines starting with @jparam refer to joint variable parameters
  jparams = filter(p -> p.args[1] == Symbol("@jparam"), content)
  jparams = map(p -> p.args[3], jparams)

  # lines starting with @global refer to global solver parameters
  gparams = filter(p -> p.args[1] == Symbol("@global"), content)
  gparams = map(p -> p.args[3], gparams)

  # add default value of `nothing` if necessary
  gparams = map(p -> p isa Symbol ? :($p = nothing) : p, gparams)

  # replace Expr(:=, a, 2) by Expr(:kw, a, 2) for valid kw args
  gparams = map(p -> Expr(:kw, p.args...), gparams)

  # keyword names
  gkeys = map(p -> p.args[1], gparams)

  # solver parameter type for single variable
  solvervparam = Symbol(solver,"Param")

  # solver parameter type for joint variables
  solverjparam = Symbol(solver,"JointParam")

  # variables are symbols or tuples of symbols
  vtype = Symbol
  jtype = NTuple{<:Any,Symbol}

  esc(quote
    $Parameters.@with_kw_noshow struct $solvervparam
      __dummy__ = nothing
      $(vparams...)
    end

    $Parameters.@with_kw_noshow struct $solverjparam
      __dummy__ = nothing
      $(jparams...)
    end

    @doc (@doc $solvervparam) (
    struct $solver <: $solvertype
      vparams::Dict{$vtype,$solvervparam}
      jparams::Dict{$jtype,$solverjparam}
      $(gkeys...)

      function $solver(vparams::Dict{$vtype,$solvervparam},
                       jparams::Dict{$jtype,$solverjparam},
                       $(gkeys...))
        new(vparams, jparams, $(gkeys...))
      end
    end)

    function $solver(params...; $(gparams...))
      # build dictionaries for inner constructor
      vdict = Dict{$vtype,$solvervparam}()
      jdict = Dict{$jtype,$solverjparam}()

      # convert named tuples to solver parameters
      for (varname, varparams) in params
        kwargs = [k => v for (k,v) in zip(keys(varparams), varparams)]
        if varname isa Symbol
          push!(vdict, varname => $solvervparam(; kwargs...))
        else
          push!(jdict, varname => $solverjparam(; kwargs...))
        end
      end

      $solver(vdict, jdict, $(gkeys...))
    end

    GeoStatsBase.separablevars(solver::$solver) = collect(keys(solver.vparams))

    GeoStatsBase.nonseparablevars(solver::$solver) = collect(keys(solver.jparams))

    function GeoStatsBase.parameters(solver::$solver, var::$vtype)
      if var ∈ keys(solver.vparams)
        solver.vparams[var]
      else
        $solvervparam()
      end
    end

    function GeoStatsBase.parameters(solver::$solver, var::$jtype)
      if var ∈ keys(solver.jparams)
        solver.jparams[var]
      else
        $solverjparam()
      end
    end

    # ------------
    # IO methods
    # ------------
    function Base.show(io::IO, solver::$solver)
      print(io, $solver)
    end

    function Base.show(io::IO, ::MIME"text/plain", solver::$solver)
      println(io, solver)
      for (var, varparams) in merge(solver.vparams, solver.jparams)
        if var isa Symbol
          println(io, "  └─", var)
        else
          println(io, "  └─", join(var, "—"))
        end
        pnames = setdiff(fieldnames(typeof(varparams)), [:__dummy__])
        for pname in pnames
          pval = getfield(varparams, pname)
          if pval ≠ nothing
            print(io, "    └─", pname, " ⇨ ")
            show(IOContext(io, :compact => true), pval)
            println(io, "")
          end
        end
      end
    end
  end)
end

"""
    @estimsolver solver body

A helper macro to create a estimation solver named `solver` with parameters
specified in `body`. For examples, please check the documentation for
`@metasolver`.
"""
macro estimsolver(solver, body)
  esc(quote
    GeoStatsBase.@metasolver $solver GeoStatsBase.AbstractEstimationSolver $body
  end)
end

"""
    @estimsolver solver body

A helper macro to create a simulation solver named `solver` with parameters
specified in `body`. For examples, please check the documentation for
`@metasolver`.
"""
macro simsolver(solver, body)
  esc(quote
    GeoStatsBase.@metasolver $solver GeoStatsBase.AbstractSimulationSolver $body
  end)
end
