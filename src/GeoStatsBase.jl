# ------------------------------------------------------------------
# Copyright (c) 2017, Júlio Hoffimann Mendes <juliohm@stanford.edu>
# Licensed under the ISC License. See LICENCE in the project root.
# ------------------------------------------------------------------

__precompile__()

module GeoStatsBase

using Missings

include("spatialdata.jl")
include("domains.jl")
include("mappers.jl")
include("problems.jl")
include("solutions.jl")
include("solvers.jl")

export
  # spatial data
  AbstractSpatialData,
  coordinates,
  coordtype,
  variables,
  valuetype,
  npoints,
  value,
  valid,

  # domains
  AbstractDomain,
  coordtype,
  npoints,
  coordinates,
  nearestlocation,

  # mappers
  AbstractMapper,
  SimpleMapper,

  # problems
  AbstractProblem,
  EstimationProblem,
  SimulationProblem,
  data,
  domain,
  variables,
  coordinates,
  datamap,
  hasdata,
  nreals,

  # solutions
  AbstractSolution,
  EstimationSolution,
  SimulationSolution,
  domain,
  digest,

  # solvers
  AbstractSolver,
  AbstractEstimationSolver,
  AbstractSimulationSolver,
  solve, solve_single

end
