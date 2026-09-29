using DrWatson
@quickactivate "project"

using Graphs, JLD2, Plots, GraphRecipes

include(srcdir("attack_graph.jl"))

include(srcdir("experiment_params.jl"))
params = deepcopy(experiment_params)
filename = datadir("attack_graph", savename(params, "jld2"))
isfile(filename) || error("Сначала выполните базовый эксперимент: файл $filename не найден.")
@load filename data

g = data[:graph]
metrics = data[:metrics]

pagerank = metrics[:pagerank]
min_rank, max_rank = extrema(pagerank)

norm_rank = if max_rank == min_rank
    fill(0.5, length(pagerank))
else
    (pagerank .- min_rank) ./ (max_rank - min_rank)
end

colors = [cgrad(:RdYlGn, rev=true)[norm_rank[i]] for i = 1:nv(g)]

attack_plot = graphplot(
    g,
    nodeshape=:circle,
    curves=false,
    linecolor=:black,
    nodecolor=colors,
    nodelabel=1:nv(g),
    title="Граф атак (цвет = PageRank)",
    size=(800, 600),
)

mkpath(plotsdir())
savefig(attack_plot, plotsdir("attack_graph.png"))
println("График сохранён в ", plotsdir("attack_graph.png"))

display(attack_plot)

println("=== Анализ графа атак ===")
println("Количество узлов: ", nv(g))
println("Количество рёбер: ", ne(g))
println(
    "Количество путей от ",
    params[:source],
    " к ",
    params[:target],
    ": ",
    length(data[:paths]),
)

if !isempty(data[:paths])
    path_lengths = length.(data[:paths])
    println("Длина пути в вершинах: от ", minimum(path_lengths), " до ", maximum(path_lengths))
    println("Наиболее вероятный путь: ", data[:likely_path])
else
    println("Цель недостижима из выбранного источника.")
end

println("\nТоп-5 узлов по in-degree:")
top_indeg = sortperm(metrics[:in_degree], rev=true)[1:min(5, nv(g))]

for i in top_indeg
    println(" Узел $i: in-degree = $(metrics[:in_degree][i])")
end

println("\nТоп-5 узлов по PageRank:")
top_pr = sortperm(metrics[:pagerank], rev=true)[1:min(5, nv(g))]

for i in top_pr
    println(" Узел $i: PageRank = $(round(metrics[:pagerank][i], digits=4))")
end
