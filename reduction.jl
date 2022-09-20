using MPI
using Random
using BenchmarkTools, TimerOutputs
using Statistics

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


function mean_value_sum_reduction!(mean_value::AbstractVector{T}, arr::AbstractArray{T}) where T

    mean!(mean_value, arr)
    MPI.Reduce!(mean_value, +, 0, MPI.COMM_WORLD)
    if mpi_rank == 0
        mean_value ./= mpi_size
    end
    
end

function variance_double_sum_reduction!(variance::AbstractVector{T}, mean_value::AbstractVector{T}, arr::AbstractArray{T}, buffer::AbstractArray{T}) where T

    mean_value_sum_reduction!(mean_value, arr)
    MPI.Bcast!(mean_value, 0, MPI.COMM_WORLD)
    buffer .= (arr .- mean_value).^2
    sum!(variance, buffer)
    MPI.Reduce!(variance, +, 0, MPI.COMM_WORLD)
    if mpi_rank == 0
        variance ./= (mpi_size * n - 1)
    end

end

function variance_custom_reduction!(variance::AbstractVector{T}, statistics::AbstractVector{SummaryStat{T}}) where T

    MPI.Reduce!(statistics, stats_reduction, 0, MPI.COMM_WORLD)
    for idx in CartesianIndices(statistics)
        variance[idx] = statistics[idx].var
    end
    
end

MPI.Init()
mpi_size = MPI.Comm_size(MPI.COMM_WORLD)
mpi_rank = MPI.Comm_rank(MPI.COMM_WORLD)

N = 1000000
n = 10
T = Float64

Random.seed!(123 + mpi_rank)

timer = TimerOutput()

arr = rand(T, N, n)
buf = Matrix{Float64}(undef, N, n)
mean_value = Vector{Float64}(undef, N)
var1 = Vector{Float64}(undef, N)
var2 = Vector{Float64}(undef, N)
stats = Vector{SummaryStat{Float64}}(undef, N)
for idx in CartesianIndices(stats)
    stats[idx] = SummaryStat(@view(arr[idx,:]))
end


for i in 1:10
    @timeit timer "mean" mean_value_sum_reduction!(mean_value, arr)
    @timeit timer "two pass var" variance_double_sum_reduction!(var1, mean_value, arr, buf)
    @timeit timer "one pass var" variance_custom_reduction!(var2, stats)
end

if mpi_rank == 0

    @show mpi_size
    @show median(mean_value)
    @show median(var1)
    @show median(var2)
    
    print_timer(timer)
end
