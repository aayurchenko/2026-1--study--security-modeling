using LinearAlgebra
using DataFrames
using CSV
using DrWatson

"""
    build_payoff_matrices(V, c_a, c_d)

Строит платёжные матрицы нападающего `A` и защитника `D`.

Строка матрицы соответствует активу, выбранному нападающим.
Столбец соответствует активу, выбранному защитником.
"""
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
            # Атакуется незащищённый актив: атака успешна.
            A[i, j] = V[i] - c_a
            D[i, j] = -V[i] - c_d
        else
            # Атакуется защищённый актив: атака отражена.
            A[i, j] = -c_a
            D[i, j] = -c_d
        end
    end

    return A, D
end

"""
    mixed_nash_2x2(A, D)

Ищет равновесие Нэша в биматричной игре 2×2.

Сначала проверяет наличие равновесия в чистых стратегиях.
Если его нет, вычисляет смешанное равновесие из условий
безразличия игроков.
"""
function mixed_nash_2x2(
    A::Matrix{Float64},
    D::Matrix{Float64},
)
    size(A) == (2, 2) || error("Матрица A должна иметь размер 2×2")
    size(D) == (2, 2) || error("Матрица D должна иметь размер 2×2")

    # Проверка четырёх возможных чистых равновесий.
    for i = 1:2, j = 1:2
        attacker_best_response = A[i, j] >= A[3 - i, j]
        defender_best_response = D[i, j] >= D[i, 3 - j]

        if attacker_best_response && defender_best_response
            p = zeros(2)
            p[i] = 1.0

            q = zeros(2)
            q[j] = 1.0

            return (
                p = p,
                q = q,
                type = "pure",
            )
        end
    end

    # Вычисляем стратегию защитника, при которой нападающему
    # безразлично, какой из двух активов атаковать.
    denominator_A =
        (A[1, 1] - A[2, 1]) -
        (A[1, 2] - A[2, 2])

    if abs(denominator_A) > 1e-10
        q_1 = (A[2, 2] - A[1, 2]) / denominator_A
        q_1 = clamp(q_1, 0.0, 1.0)
    else
        q_1 = 0.5
    end

    q = [q_1, 1.0 - q_1]

    # Вычисляем стратегию нападающего, при которой защитнику
    # безразлично, какой из двух активов защищать.
    denominator_D =
        (D[1, 1] - D[1, 2]) -
        (D[2, 1] - D[2, 2])

    if abs(denominator_D) > 1e-10
        p_1 = (D[2, 2] - D[2, 1]) / denominator_D
        p_1 = clamp(p_1, 0.0, 1.0)
    else
        p_1 = 0.5
    end

    p = [p_1, 1.0 - p_1]

    return (
        p = p,
        q = q,
        type = "mixed",
    )
end

"""
    run_simulation(params)

Выполняет один эксперимент и возвращает равновесные стратегии,
тип равновесия, ожидаемые выигрыши и исходные параметры.
"""
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

"""
    generate_params()

Формирует полную сетку параметров:

- V₁, V₂ ∈ {5, 10, 15};
- cₐ, c_d ∈ {0, 1, 3}.
"""
function generate_params()
    params_list = Dict[]

    values = [5.0, 10.0, 15.0]
    attack_costs = [0.0, 1.0, 3.0]
    defense_costs = [0.0, 1.0, 3.0]

    for v_1 in values, v_2 in values
        for c_a in attack_costs, c_d in defense_costs
            params = Dict(
                "V" => [v_1, v_2],
                "c_a" => c_a,
                "c_d" => c_d,
            )

            push!(params_list, params)
        end
    end

    return params_list
end

"""
    main_simulations()

Выполняет все комбинации параметров и сохраняет результаты
в `data/sims/results.csv`.
"""
function main_simulations()
    params_list = generate_params()
    rows = Dict[]

    for params in params_list
        result = run_simulation(params)
        push!(rows, result)
    end

    results = DataFrame(rows)

    mkpath(datadir("sims"))
    output_path = datadir("sims", "results.csv")

    CSV.write(output_path, results)

    return results
end

"""
    load_results()

Загружает результаты из `data/sims/results.csv`.
"""
function load_results()
    input_path = datadir("sims", "results.csv")

    if isfile(input_path)
        return CSV.read(input_path, DataFrame)
    end

    error(
        "Файл с результатами не найден: $input_path. Сначала выполните scripts/run_sims.jl.",
    )
end