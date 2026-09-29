using DrWatson
@quickactivate "project"

using Graphs, JLD2, Random

include(srcdir("attack_graph.jl"))

include(srcdir("experiment_params.jl"))
params = deepcopy(experiment_params)

println("Число узлов: ", params[:n])
println("Вероятность появления ребра: ", params[:edge_prob])
println("Источник: ", params[:source], ", цель: ", params[:target])

filename = datadir("attack_graph", savename(params, "jld2"))
mkpath(datadir("attack_graph"))

if isfile(filename)
    @load filename data
    println("Данные загружены из $filename")
else
    g = build_attack_graph(
        params[:n],
        params[:edge_prob],
        params[:cvss_scores],
        params[:trust_relations],
    )

    paths = find_all_paths(g, params[:source], params[:target])
    metrics = compute_centrality_metrics(g)
    weights = assign_edge_weights(g, params[:cvss_scores])
    likely_path, prob = most_likely_path(
        g,
        params[:source],
        params[:target],
        weights,
    )

    data = Dict(
        :graph => g,
        :paths => paths,
        :metrics => metrics,
        :weights => weights,
        :likely_path => likely_path,
        :probability => prob,
    )

    @save filename data params
    println("Результаты сохранены в $filename")
end

println("Количество путей атаки: ", length(data[:paths]))
println("Наиболее вероятный путь: ", data[:likely_path])
println("Вероятность успеха: ", data[:probability])
