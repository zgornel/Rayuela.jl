
using Rayuela, HDF5

function get_dataset_numbers(dataset_name::String)
  nquery, nbase, ntrain = 0, 0, 0
  if dataset_name == "MNIST"
    nquery, nbase, ntrain = Int(10e3), Int(60e3), Int(60e3)
  elseif dataset_name == "labelme"
    nquery, nbase, ntrain = Int(2e3), Int(20019), Int(20019)
  elseif dataset_name in ["SIFT1M", "Convnet1M"]
    nquery, nbase, ntrain = Int(1e4), Int(1e6), Int(1e5)
  else
    error("dataset unknown")
  end
  return nquery, nbase, ntrain
end


function test_experiment(
  dataset_name::String,
  m::Integer,
  trial::Integer)

  @show dataset_name, m, trial
  bpath = joinpath("/home/julieta/Desktop/CQ/build/results/", lowercase(dataset_name) * "_$m", "trial_$trial")
  h = 256

  # Read the codes
  B = read_cq_bvecs(joinpath(bpath, "B"))
  B = convert(Matrix{Int16}, B)
  B .+= 1

  # Read the codebooks
  K = read_cq_fvecs(joinpath(bpath, "D"))
  C = Vector{Matrix{Cfloat}}(m)
  indices = splitarray(1:(m*h), m)
  for i = 1:m
    C[i] = K[:, indices[i]]
  end

  # Load the data
  nquery, nbase, ntrain = get_dataset_numbers(dataset_name)
  verbose = true
  Xt = Rayuela.read_dataset(dataset_name, ntrain)
  Xb = Rayuela.read_dataset(dataset_name * "_base", nbase)
  Xq = Rayuela.read_dataset(dataset_name * "_query", nquery, verbose)[:,1:nquery]
  gt = Rayuela.read_dataset(dataset_name * "_groundtruth", nquery, verbose)
  if dataset_name == "SIFT1M" || dataset_name == "GIST1M"
    gt = gt .+ 1
  end
  gt = convert( Vector{UInt32}, gt[1,1:nquery] )

  qerr = qerror(Xt, B, C) * nbase
  @printf("Qerror: %e\n", qerr )

  if dataset_name in ["SIFT1M", "Convnet1M"]
    # Encode the base
    B_base = convert(Matrix{Int16}, rand(1:h, m, size(Xb,2)))
    ilsiter, icmiter, randord, npert, cpp, V = 4, 4, false, 0, true, true
    B_base = Rayuela.encoding_icm(Xb, B_base, C, ilsiter, icmiter, randord, npert, cpp, V)

    qerr = qerror(Xb, B_base, C)
    @printf("%e\n", qerr)

    # Put the base codes into B
    B = B_base
  end

  # Fast search
  knn = 1000
  if verbose; print("Querying m=$m ... "); end
  @time dists, idx = linscan_cq(B, Xq, C, knn)
  if verbose; println("done"); end
  rec = eval_recall(gt, idx, knn)

  h5write(joinpath(bpath, "recall.h5"), "recall", rec)
end


function run_experiments(
  dataset_name::String,
  dictionaries_count::Int=8)

  ntrials = 10
  for trial = 1:1

    @show "trial", trial

    a = CQ_parameters()
    a.output_file_prefix = "/home/julieta/Desktop/CQ/build/results/sift_$(dictionaries_count)/trial_$trial/"
    a.dictionaries_count = dictionaries_count
    # a.max_iter=1

    if dataset_name == "SIFT1M"
      # do nothing
    elseif dataset_name == "MNIST"
      a.points_count     = Int(60e3)
      a.space_dimension  = 28 * 28
      a.mu               = 0.00001f0
      a.queries_count    = Int(10e3)
      a.groundtruth_length = 1
      a.output_file_prefix = "/home/julieta/Desktop/CQ/build/results/mnist_$(dictionaries_count)/trial_$trial/"
      a.points_file        = "/home/julieta/Desktop/CQ/build/data/mnist/mnist_learn.fvecs"
      a.queries_file       = "/home/julieta/Desktop/CQ/build/data/mnist/mnist_query.fvecs"
      a.groundtruth_file   = "/home/julieta/Desktop/CQ/build/data/mnist/mnist_groundtruth.ivecs"
    elseif dataset_name == "labelme"
      a.points_count     = 20019
      a.space_dimension  = 512
      a.mu               = 100f0
      a.queries_count    = 2000
      a.groundtruth_length = 1
      a.output_file_prefix = "/home/julieta/Desktop/CQ/build/results/labelme_$(dictionaries_count)/trial_$trial/"
      a.points_file        = "/home/julieta/Desktop/CQ/build/data/labelme/labelme_learn.fvecs"
      a.queries_file       = "/home/julieta/Desktop/CQ/build/data/labelme/labelme_query.fvecs"
      a.groundtruth_file   = "/home/julieta/Desktop/CQ/build/data/labelme/labelme_groundtruth.ivecs"
    else
      error("dataset unknown")
    end

    a.trained_dictionary_file = joinpath(a.output_file_prefix, "D")
    a.trained_binary_codes_file = joinpath(a.output_file_prefix, "B")
    a.output_retrieved_results_file = joinpath(a.output_file_prefix, "recall")

    # Prepare output folder
    if !Base.Filesystem.ispath(a.output_file_prefix)
      mkpath(a.output_file_prefix)
    end

    # Write parameters
    pname = "/home/julieta/Desktop/CQ/build/config.txt"
    dump_CQ_parameters(a, pname)

    # Run the experiment
    cmd = joinpath("/home/julieta/Desktop/CQ/build/CompositeQuantization")
    run(`$cmd $pname`)

  end
end

function dump_dataset(dataset_name, verbose=true)
  nquery, nbase, ntrain = get_dataset_numbers(dataset_name)
  Xt = Rayuela.read_dataset(dataset_name * "_base", ntrain)
  Xb = Rayuela.read_dataset(dataset_name * "_base", nbase)
  Xq = Rayuela.read_dataset(dataset_name * "_query", nquery, verbose)[:,1:nquery]
  gt = Rayuela.read_dataset(dataset_name * "_groundtruth", nquery, verbose)

  bpath = joinpath("/home/julieta/Desktop/CQ/build/data/", lowercase(dataset_name))
  if !Base.Filesystem.ispath(bpath)
    mkpath(bpath)
  end

  fvecs_write(Xt, joinpath(bpath, "$(lowercase(dataset_name))_learn.fvecs"))
  fvecs_write(Xb, joinpath(bpath, "$(lowercase(dataset_name))_base.fvecs"))
  fvecs_write(Xq, joinpath(bpath, "$(lowercase(dataset_name))_query.fvecs"))
  ivecs_write(convert(Matrix{Int32},gt.-=1), joinpath(bpath, "$(lowercase(dataset_name))_groundtruth.ivecs"))
end

# dump_dataset("MNIST")
# dump_dataset("labelme")
# dump_dataset("Convnet1M")

# @show("run_experiments")
# run_experiments("MNIST", 16)
run_experiments("labelme", 8)
# run_experiments("SIFT1M", 16)
# run_experiments("Convnet1M")

for trial = 3
  # test_experiment("labelme", 8, trial)
  # test_experiment("labelme", 16, trial)
  # test_experiment("MNIST", 8, trial)
  # test_experiment("MNIST", 16, trial)

  # test_experiment("SIFT1M", 8, trial)
  # test_experiment("SIFT1M", 16, trial)
end
