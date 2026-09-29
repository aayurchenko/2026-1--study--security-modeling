using Distributions
using Statistics

function simulate_attacks(λ::Float64, T::Float64)
    # Моделирование числа атак по часам
    hourly_counts = rand(Poisson(λ), floor(Int, T))

    # Моделирование интервалов между атаками
    intervals = Float64[]
    total_time = 0.0

    while total_time < T
        τ = rand(Exponential(1 / λ))
        push!(intervals, τ)
        total_time += τ
    end

    # Удаляем последнее событие, если оно вышло за пределы T
    if total_time > T
        pop!(intervals)
    end

    attack_times = cumsum(intervals)

    return (
        hourly_counts = hourly_counts,
        intervals = intervals,
        attack_times = attack_times
    )
end

# Обёртка для вызова из скрипта с параметром-словарём
function simulate_attacks(p::Dict)
    return simulate_attacks(p[:λ], p[:T])
end