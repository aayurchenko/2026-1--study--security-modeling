using DrWatson
@quickactivate "project"

using LinearAlgebra
using DataFrames
using CSV
using Plots
using Statistics

function build_payoff_matrices(
    V::Vector{Float64},
    c_a::Float64,
    c_d::Float64,
)
    n = length(V)
    A = zeros(n, n)
    D = zeros(n, n)

    for i = 1:n, j = 1:n
        if i != j
            A[i, j] = V[i] - c_a
            D[i, j] = -V[i] - c_d
        else
            A[i, j] = -c_a
            D[i, j] = -c_d
        end
    end

    return A, D
end

function mixed_nash_2x2(
    A::Matrix{Float64},
    D::Matrix{Float64},
)
    size(A) == (2, 2) || error("Матрица A должна иметь размер 2×2")
    size(D) == (2, 2) || error("Матрица D должна иметь размер 2×2")

    for i = 1:2, j = 1:2
        attacker_best_response = A[i, j] >= A[3 - i, j]
        defender_best_response = D[i, j] >= D[i, 3 - j]

        if attacker_best_response && defender_best_response
            p = zeros(2)
            p[i] = 1.0

            q = zeros(2)
            q[j] = 1.0

            return (p=p, q=q, type="pure")
        end
    end

    denominator_A =
        (A[1, 1] - A[2, 1]) -
        (A[1, 2] - A[2, 2])

    q_1 = if abs(denominator_A) > 1e-10
        clamp((A[2, 2] - A[1, 2]) / denominator_A, 0.0, 1.0)
    else
        0.5
    end

    denominator_D =
        (D[1, 1] - D[1, 2]) -
        (D[2, 1] - D[2, 2])

    p_1 = if abs(denominator_D) > 1e-10
        clamp((D[2, 2] - D[2, 1]) / denominator_D, 0.0, 1.0)
    else
        0.5
    end

    p = [p_1, 1.0 - p_1]
    q = [q_1, 1.0 - q_1]

    return (p=p, q=q, type="mixed")
end

function run_simulation(params::Dict)
    V = params["V"]
    c_a = params["c_a"]
    c_d = params["c_d"]

    A, D = build_payoff_matrices(V, c_a, c_d)
    equilibrium = mixed_nash_2x2(A, D)

    if equilibrium.type == "pure"
        i = argmax(equilibrium.p)
        j = argmax(equilibrium.q)
        U_A = A[i, j]
        U_D = D[i, j]
    else
        U_A = equilibrium.p' * A * equilibrium.q
        U_D = equilibrium.p' * D * equilibrium.q
    end

    return Dict(
        "p_1" => equilibrium.p[1],
        "p_2" => equilibrium.p[2],
        "q_1" => equilibrium.q[1],
        "q_2" => equilibrium.q[2],
        "type" => equilibrium.type,
        "UA" => U_A,
        "UD" => U_D,
        "V1" => V[1],
        "V2" => V[2],
        "c_a" => c_a,
        "c_d" => c_d,
    )
end

function generate_params()
    params_list = Dict[]
    values = [5.0, 10.0, 15.0]
    attack_costs = [0.0, 1.0, 3.0]
    defense_costs = [0.0, 1.0, 3.0]

    for v_1 in values, v_2 in values
        for c_a in attack_costs, c_d in defense_costs
            push!(
                params_list,
                Dict(
                    "V" => [v_1, v_2],
                    "c_a" => c_a,
                    "c_d" => c_d,
                ),
            )
        end
    end

    return params_list
end

function main_simulations()
    rows = Dict[]

    for params in generate_params()
        push!(rows, run_simulation(params))
    end

    results = DataFrame(rows)
    mkpath(datadir("sims"))
    CSV.write(datadir("sims", "results.csv"), results)

    return results
end


println("Запуск серии экспериментов...")
results = main_simulations()
println("Рассчитано вариантов: ", nrow(results))
println("Результаты сохранены в: ", datadir("sims", "results.csv"))

display(first(results, 10))

equilibrium_counts = combine(groupby(results, :type), nrow => :count)
display(equilibrium_counts)

filtered = results[
    (results.c_a .== 1.0) .&
    (results.c_d .== 1.0),
    :,
]

ratio = filtered.V1 ./ filtered.V2

strategy_plot = scatter(
    ratio,
    filtered.p_1;
    group=filtered.type,
    xlabel="V₁ / V₂",
    ylabel="p₁ — вероятность атаки актива 1",
    title="Стратегия нападающего при cₐ = 1, c_d = 1",
    legend=:topright,
    markersize=6,
)

mkpath(plotsdir())
savefig(strategy_plot, plotsdir("p1_vs_ratio.png"))
display(strategy_plot)

grouped_results = groupby(filtered, [:V1, :V2])
summary = combine(grouped_results, :UA => mean => :UA_mean)

V_1_values = sort(unique(summary.V1))
V_2_values = sort(unique(summary.V2))

payoff_plot = heatmap(
    V_1_values,
    V_2_values,
    (x, y) -> summary[
        (summary.V1 .== x) .&
        (summary.V2 .== y),
        :UA_mean,
    ][1];
    xlabel="Ценность первого актива V₁",
    ylabel="Ценность второго актива V₂",
    title="Средний выигрыш нападающего",
    colorbar_title="Uₐ",
)

savefig(payoff_plot, plotsdir("heatmap_UA.png"))
display(payoff_plot)
