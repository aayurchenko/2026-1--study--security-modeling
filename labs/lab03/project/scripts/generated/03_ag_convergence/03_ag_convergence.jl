using DrWatson
@quickactivate "project"

using Graphs
using Plots
using JLD2
using Random

include(srcdir("attack_graph.jl"))

sizes = [10, 15, 20, 21, 22, 23, 24, 25]
time_vals = Float64[]
path_counts = Int[]

Random.seed!(123)

for n in sizes
    println("Размер сети: $n")
    g = build_attack_graph(n, 0.2, Dict(), [])
    t = @elapsed paths = find_all_paths(g, 1, n)

    push!(time_vals, t)
    push!(path_counts, length(paths))

    println(" Время: $(round(t, digits=3)) с, путей: $(length(paths))")
end

p1 = plot(
    sizes,
    time_vals,
    marker=:circle,
    xlabel="Число узлов",
    ylabel="Время (с)",
    title="Время поиска всех путей",
    legend=false,
)

p2 = plot(
    sizes,
    path_counts,
    marker=:circle,
    xlabel="Число узлов",
    ylabel="Количество путей",
    title="Количество путей атаки",
    legend=false,
)

combined = plot(p1, p2, layout=(2, 1), size=(800, 600))
mkpath(plotsdir())
savefig(combined, plotsdir("convergence.png"))
display(combined)

data = Dict(:sizes => sizes, :times => time_vals, :path_counts => path_counts)
mkpath(datadir("convergence"))
@save datadir("convergence", "convergence_data.jld2") data
