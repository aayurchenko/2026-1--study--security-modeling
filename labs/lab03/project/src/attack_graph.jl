using Graphs, LinearAlgebra

"""
    build_attack_graph(n, edge_prob, vulnerabilities, trust_relations)

Создаёт ориентированный граф атак с заданными параметрами.
"""
function build_attack_graph(n, edge_prob, vulnerabilities, trust_relations)
    g = SimpleDiGraph(n)

    # случайные рёбра
    for i = 1:n, j = 1:n
        if i != j && rand() < edge_prob
            add_edge!(g, i, j)
        end
    end

    # доверительные отношения
    for (u, v) in trust_relations
        add_edge!(g, u, v)
    end

    return g
end

"""
    find_all_paths(g, source, target)

Рекурсивный поиск всех простых путей от source до target.
"""
function find_all_paths(g, source, target)
    paths = []

    function dfs(current, path)
        if current == target
            push!(paths, copy(path))
            return
        end

        for neighbor in outneighbors(g, current)
            if !(neighbor in path)
                push!(path, neighbor)
                dfs(neighbor, path)
                pop!(path)
            end
        end
    end

    dfs(source, [source])
    return paths
end

"""
    compute_centrality_metrics(g)

Вычисляет основные метрики центральности.
"""
function compute_centrality_metrics(g)
    indeg = indegree(g)
    outdeg = outdegree(g)
    betweenness = betweenness_centrality(g)
    closeness = closeness_centrality(g)
    pagerank = simple_pagerank(g)  # используем нашу реализацию

    return Dict(
        :in_degree => indeg,
        :out_degree => outdeg,
        :betweenness => betweenness,
        :closeness => closeness,
        :pagerank => pagerank,
    )
end

"""
    assign_edge_weights(g, cvss_scores)

Присваивает каждому ребру вес на основе CVSS-оценок (по умолчанию 0.5).
"""
function assign_edge_weights(g, cvss_scores)
    weights = Dict{Edge,Float64}()

    for e in edges(g)
        u, v = src(e), dst(e)
        key = (u, v)
        weight = get(cvss_scores, key, 0.5)
        weights[e] = weight
    end

    return weights
end

"""
    most_likely_path(g, source, target, weights)

Находит путь с максимальным произведением вероятностей.
"""
function most_likely_path(g, source, target, weights)
    n = nv(g)

    # Создаём матрицу весов размером n×n, заполненную бесконечностью
    distmx = fill(Inf, n, n)

    for e in edges(g)
        u, v = src(e), dst(e)
        w = weights[e]            # вероятность успешной атаки на ребре
        distmx[u, v] = -log(w)    # вес для Дейкстры (логарифм обратной вероятности)
    end

    state = dijkstra_shortest_paths(g, source, distmx)
    dist = state.dists
    parents = state.parents

    if dist[target] == Inf
        return [], 0.0
    end

    # Восстанавливаем путь
    path = Int[]
    current = target

    while current != source
        push!(path, current)
        current = parents[current]
    end

    push!(path, source)
    reverse!(path)
    prob = exp(-dist[target])  # преобразуем обратно в вероятность

    return path, prob
end

"""
    simple_pagerank(g; α=0.85, max_iter=100, tol=1e-6)

Простая реализация PageRank для ориентированного графа.
"""
function simple_pagerank(g; α=0.85, max_iter=100, tol=1e-6)
    n = nv(g)
    n == 0 && return Float64[]

    pr = fill(1.0 / n, n)

    for _ = 1:max_iter
        pr_new = fill((1 - α) / n, n)

        for i = 1:n
            outdeg = outdegree(g, i)

            if outdeg > 0
                for j in outneighbors(g, i)
                    pr_new[j] += α * pr[i] / outdeg
                end
            else
                # телепортация из узлов без исходящих рёбер
                for j = 1:n
                    pr_new[j] += α * pr[i] / n
                end
            end
        end

        diff = maximum(abs.(pr_new - pr))
        pr = pr_new

        if diff < tol
            break
        end
    end

    return pr
end