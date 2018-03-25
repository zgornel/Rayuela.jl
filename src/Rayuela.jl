module Rayuela

# For PQ/OPQ training and encoding
using Clustering, Distances

# For LSQR
using IterativeSolvers

# For sampling
using Distributions

# For LSQ encoding in the GPU
using CUDAdrv, CUBLAS # NO GPU in this branch

using HDF5

### Load and initialize the linscan binaries ###
const depsfile = joinpath(dirname(@__DIR__), "deps", "deps.jl")
if isfile(depsfile)
  include(depsfile)
else
  error("Rayuela is not properly installed. Please run Pkg.build(\"Rayuela\")")
end
cudautilsptx = cudautils[1:end-2] * "ptx"

# === Functions to read data ===
include("xvecs_read.jl")
include("read_datasets.jl")

# === Utility functions mostly ===
include("utils.jl")
include("qerrors.jl")

include("Linscan.jl")
include("codebook_update.jl")

# === Orthogonal quantizers ===
include("PQ.jl")  # Product Quantizer
include("OPQ.jl") # Optimized Product Quantizer

# === Non-orthogonal quantizers ===
include("ChainQ.jl") # Chain (Tree) Quantization
include("CQ.jl")     # Functions to interact with C++ release
include("RVQ.jl")    # RVQ
include("ERVQ.jl")   # ERVQ / Stacked quantizers
include("CompetitiveQ.jl") # Slow version

# === LSQ Quantizer ===
include("LSQ.jl") # Local search quantization
include("SR_perturbations.jl") # Utils for SR
include("SR.jl")  # Stochastic relaxations

# === CUDA ports ===
include("CudaUtilsModule.jl")
include("LSQ_GPU.jl") # Local search quantization

end # module
