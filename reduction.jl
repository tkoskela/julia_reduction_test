using MPI
using Random
using BenchmarkTools

struct SummaryStat{T}
    avg::T
    var::T
    n::Int
end

function SummaryStat(X::AbstractVector)
    m = mean(X)
    v = varm(X,m, corrected=true)
    n = length(X)
    SummaryStat(m,v,n)
end

function stats_reduction(S1::SummaryStat, S2::SummaryStat)

    n = S1.n + S2.n
    m = (S1.avg*S1.n + S2.avg*S2.n) / n

    # Calculate pooled unbiased sample variance of two groups. From https://stats.stackexchange.com/q/384951
    # Can be found in https://www.tandfonline.com/doi/abs/10.1080/00031305.2014.966589
    # To get the uncorrected variance, use
    # v = (S1.n * (S1.var + S1.avg * (S1.avg-m)) + S2.n * (S2.var + S2.avg * (S2.avg-m)))/n
    v = ((S1.n-1) * S1.var + (S2.n-1) * S2.var + S1.n*S2.n/n * (S2.avg - S1.avg)^2 )/(n-1)

    SummaryStat(m, v, n)

end


function mean_sum_reduction!(mean::T, arr::AbstractVector{T}) where T

    size = MPI.Comm_size(MPI.COMM_WORLD)
    sum = 0.0
    MPI.Reduce!(arr, sum, +, 0, MPI.COMM_WORLD)
    mean = sum/size
    
end

function variance_custom_reduction(var::T, statistics, arr::AbstractVector{T}) where T

    statistics = SummaryStat(arr)
    MPI.Reduce!(statistics, stats_reduction, 0, MPI.COMM_WORLD)
    
end

function variance_double_sum_reduction!(var::T, arr::AbstractVector{T}) where T

    mean = 0.0
    mean_sum_reduction!(mean, arr)
    MPI.Bcast!(mean, 0, MPI.COMM_WORLD)
    d = (arr - mean) ** 2
    mean_sum_reduction!(var, d)
    var =/ (size-1)

end

MPI.Init()
mpi_size = MPI.Comm_size(MPI.COMM_WORLD)
mpi_rank = MPI.Comm_rank(MPI.COMM_WORLD)

N = 100000
T = Float64

statistics = Vector{SummaryStat{T}}(undef, N)
Random.seed(123 + mpi_rank)
arr = rand(T, N)

mean = floatmax(T)
var1 = floatmax(T)
var2 = floatmax(T)

@btime mean_sum_reduction!(mean, arr)
@btime variance_double_sum_reduction!(var1, arr)
@btime variance_custom_reduction!(var2, arr)

if mpi_rank == 0
    @show mpi_size
    @show mean
    @show var1
    @show var2
end
