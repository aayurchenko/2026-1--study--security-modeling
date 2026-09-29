using DrWatson
@quickactivate "project"

include(srcdir("experiment_params.jl"))
params = experiment_params
filename = datadir("attack_graph", savename(params, "jld2"))

using Graphs, JLD2, Random

include(srcdir("attack_graph.jl"))

params = Dict(
    :n => 20,
    :edge_prob => 0.2,
    :source => 1,
    :target => 20,
    :cvss_scores => Dict(
        (1, 3) => 0.9,
        (2, 5) => 0.7,
        (3, 8) => 0.8,
        (5, 20) => 0.95,
    ),
    :trust_relations => [(4, 6), (6, 10), (10, 15)],
)

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