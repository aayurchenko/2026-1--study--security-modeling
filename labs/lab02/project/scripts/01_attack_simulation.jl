# # Вероятностное моделирование потока кибератак
#
# **Цель:** исследовать простейший пуассоновский поток событий
# на примере моделирования потока атак на веб-сервер.
#
# В данной работе число атак за фиксированный интервал времени
# моделируется распределением Пуассона, а интервалы времени между
# последовательными атаками — экспоненциальным распределением.
#
# ## Инициализация проекта и загрузка пакетов

using DrWatson
@quickactivate "project"

using Distributions
using Statistics
using Plots
using StatsPlots
using JLD2
using Random
using DataFrames
using CSV

# ## Параметры модели
#
# Параметр `λ` задаёт среднее количество атак за один час.
# Параметр `T` определяет продолжительность наблюдения.
# `num_hours_for_est` задаёт число часов, используемых
# для оценки вероятности редкого события.

params = Dict(
    :λ => 5.0,
    :T => 24.0,
    :num_hours_for_est => 10000
)

λ = params[:λ]
T = params[:T]
num_hours_for_est = params[:num_hours_for_est]

# ## Моделирование потока атак
#
# Для простейшего пуассоновского потока число событий за единицу
# времени имеет распределение Пуассона.
#
# Интервалы между последовательными событиями имеют
# экспоненциальное распределение со средним значением `1/λ`.

function simulate_attacks(λ::Float64, T::Float64)
    hourly_counts = rand(Poisson(λ), floor(Int, T))

    intervals = Float64[]
    total_time = 0.0

    while total_time < T
        τ = rand(Exponential(1 / λ))
        push!(intervals, τ)
        total_time += τ
    end

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

# ## Выполнение базового эксперимента
#
# Выполним моделирование потока с заданной интенсивностью `λ`
# на интервале времени `T`.

result = simulate_attacks(λ, T)

hourly_counts = result.hourly_counts
intervals = result.intervals
attack_times = result.attack_times

# ## Оценка вероятности более 10 атак за час
#
# Сначала получим эмпирическую оценку вероятности.
# Для этого генерируется большая выборка почасового числа атак.

hourly_sample = rand(Poisson(λ), num_hours_for_est)

emp_prob = count(hourly_sample .> 10) / num_hours_for_est

# Теоретическая вероятность рассчитывается непосредственно
# из функции распределения Пуассона.

theor_prob = 1 - cdf(Poisson(λ), 10)

println("Эмпирическая вероятность P(>10) = ", emp_prob)
println("Теоретическая вероятность P(>10) = ", theor_prob)

# ## Сравнение эмпирического и теоретического распределений
#
# Построим гистограмму количества атак за час и наложим
# теоретическое распределение Пуассона.

p1 = histogram(
    hourly_counts,
    bins = 0:maximum(hourly_counts),
    normalize = :probability,
    label = "Эмпирическая частота",
    xlabel = "Число атак за час",
    ylabel = "Вероятность"
)

x_vals = 0:maximum(hourly_counts)
poisson_probs = pdf.(Poisson(λ), x_vals)

plot!(
    p1,
    x_vals,
    poisson_probs,
    line = :stem,
    marker = :circle,
    label = "Теоретическое Пуассона(λ=$λ)",
    lw = 2
)

title!(p1, "Распределение числа атак за час")

# ## Накопленное число атак
#
# Сравним смоделированное накопленное число атак
# с теоретическим средним значением `λt`.

p2 = plot(
    attack_times,
    1:length(attack_times),
    label = "Реализация",
    xlabel = "Время (ч)",
    ylabel = "Накопленное число атак"
)

plot!(
    p2,
    0:0.1:T,
    λ * (0:0.1:T),
    label = "Среднее λ·t",
    ls = :dash
)

title!(p2, "Накопленное число атак")

# ## Анализ интервалов между атаками
#
# В простейшем пуассоновском потоке интервалы между
# соседними событиями должны иметь экспоненциальное распределение.
#
# Построим гистограмму интервалов и наложим теоретическую
# экспоненциальную плотность.

p3 = histogram(
    intervals,
    bins = 30,
    normalize = :pdf,
    label = "Эмпирическая плотность",
    xlabel = "Интервал (ч)",
    ylabel = "Плотность"
)

x_dens = range(0, maximum(intervals), length = 100)
exp_density = pdf.(Exponential(1 / λ), x_dens)

plot!(
    p3,
    x_dens,
    exp_density,
    label = "Экспоненциальная плотность",
    lw = 2
)

title!(p3, "Распределение интервалов между атаками")

# ## QQ-plot
#
# Дополнительно проверим соответствие интервалов
# экспоненциальному распределению с помощью QQ-графика.

p4 = qqplot(
    Exponential(1 / λ),
    intervals,
    qqline = :identity,
    xlabel = "Теоретические квантили",
    ylabel = "Эмпирические квантили",
    title = "QQ-plot интервалов"
)

# ## Итоговая визуализация
#
# Объединим четыре диагностических графика.

combined = plot(
    p1,
    p2,
    p3,
    p4,
    layout = (2, 2),
    size = (1000, 800)
)

display(combined)

# ## Исследование сходимости
#
# Исследуем, как объём выборки влияет на точность оценки
# вероятности события «более 10 атак за час».

sample_sizes = [
    10,
    50,
    100,
    500,
    1000,
    5000,
    10000,
    50000,
    100000
]

Random.seed!(123)

estimates = Float64[]

for n in sample_sizes
    sample = rand(Poisson(λ), n)
    estimate = count(sample .> 10) / n
    push!(estimates, estimate)
end

p5 = plot(
    sample_sizes,
    estimates,
    xscale = :log10,
    marker = :circle,
    label = "Эмпирическая оценка",
    xlabel = "Объём выборки",
    ylabel = "P(>10)"
)

hline!(
    p5,
    [theor_prob],
    label = "Теоретическое значение",
    ls = :dash
)

title!(p5, "Сходимость оценки вероятности")

display(p5)

# ## Параметрическое исследование
#
# Исследуем поведение модели при различных значениях интенсивности
# потока атак `λ`.
#
# Для каждого значения `λ` выполним отдельное моделирование и построим:
#
# 1. распределение числа атак за час;
# 2. накопленное число атак;
# 3. распределение интервалов между атаками;
# 4. QQ-график интервалов.
#
# После этого сравним вероятность события `P(N > 10)`
# для различных значений интенсивности.

λ_values = [2.0, 5.0, 8.0, 12.0, 15.0]

theoretical_probs = Float64[]
empirical_probs = Float64[]

Random.seed!(42)

# ## Моделирование для λ = 2
#
# Сначала рассмотрим небольшую интенсивность — в среднем
# две атаки за час.

current_λ = λ_values[1]

result_2 = simulate_attacks(current_λ, T)

hourly_counts_2 = result_2.hourly_counts
intervals_2 = result_2.intervals
attack_times_2 = result_2.attack_times

sample_2 = rand(Poisson(current_λ), num_hours_for_est)

empirical_2 = count(sample_2 .> 10) / num_hours_for_est
theoretical_2 = 1 - cdf(Poisson(current_λ), 10)

push!(empirical_probs, empirical_2)
push!(theoretical_probs, theoretical_2)

p1_2 = histogram(
    hourly_counts_2,
    bins = 0:maximum(hourly_counts_2),
    normalize = :probability,
    label = "Эмпирическая частота",
    xlabel = "Число атак за час",
    ylabel = "Вероятность"
)

x_vals_2 = 0:maximum(hourly_counts_2)

plot!(
    p1_2,
    x_vals_2,
    pdf.(Poisson(current_λ), x_vals_2),
    line = :stem,
    marker = :circle,
    label = "Пуассон(λ=$current_λ)",
    lw = 2
)

p2_2 = plot(
    attack_times_2,
    1:length(attack_times_2),
    label = "Реализация",
    xlabel = "Время (ч)",
    ylabel = "Накопленное число атак"
)

plot!(
    p2_2,
    0:0.1:T,
    current_λ * (0:0.1:T),
    label = "Среднее λ·t",
    ls = :dash
)

p3_2 = histogram(
    intervals_2,
    bins = 30,
    normalize = :pdf,
    label = "Эмпирическая плотность",
    xlabel = "Интервал (ч)",
    ylabel = "Плотность"
)

x_dens_2 = range(0, maximum(intervals_2), length = 100)

plot!(
    p3_2,
    x_dens_2,
    pdf.(Exponential(1 / current_λ), x_dens_2),
    label = "Экспоненциальная плотность",
    lw = 2
)

p4_2 = qqplot(
    Exponential(1 / current_λ),
    intervals_2,
    qqline = :identity,
    xlabel = "Теоретические квантили",
    ylabel = "Эмпирические квантили"
)

combined_2 = plot(
    p1_2,
    p2_2,
    p3_2,
    p4_2,
    layout = (2, 2),
    size = (1000, 800),
    plot_title = "Параметрическое исследование: λ = $current_λ"
)

display(combined_2)

# ## Моделирование для λ = 5
#
# Теперь интенсивность составляет в среднем пять атак за час.

current_λ = λ_values[2]

result_5 = simulate_attacks(current_λ, T)

hourly_counts_5 = result_5.hourly_counts
intervals_5 = result_5.intervals
attack_times_5 = result_5.attack_times

sample_5 = rand(Poisson(current_λ), num_hours_for_est)

empirical_5 = count(sample_5 .> 10) / num_hours_for_est
theoretical_5 = 1 - cdf(Poisson(current_λ), 10)

push!(empirical_probs, empirical_5)
push!(theoretical_probs, theoretical_5)

p1_5 = histogram(
    hourly_counts_5,
    bins = 0:maximum(hourly_counts_5),
    normalize = :probability,
    label = "Эмпирическая частота",
    xlabel = "Число атак за час",
    ylabel = "Вероятность"
)

x_vals_5 = 0:maximum(hourly_counts_5)

plot!(
    p1_5,
    x_vals_5,
    pdf.(Poisson(current_λ), x_vals_5),
    line = :stem,
    marker = :circle,
    label = "Пуассон(λ=$current_λ)",
    lw = 2
)

p2_5 = plot(
    attack_times_5,
    1:length(attack_times_5),
    label = "Реализация",
    xlabel = "Время (ч)",
    ylabel = "Накопленное число атак"
)

plot!(
    p2_5,
    0:0.1:T,
    current_λ * (0:0.1:T),
    label = "Среднее λ·t",
    ls = :dash
)

p3_5 = histogram(
    intervals_5,
    bins = 30,
    normalize = :pdf,
    label = "Эмпирическая плотность",
    xlabel = "Интервал (ч)",
    ylabel = "Плотность"
)

x_dens_5 = range(0, maximum(intervals_5), length = 100)

plot!(
    p3_5,
    x_dens_5,
    pdf.(Exponential(1 / current_λ), x_dens_5),
    label = "Экспоненциальная плотность",
    lw = 2
)

p4_5 = qqplot(
    Exponential(1 / current_λ),
    intervals_5,
    qqline = :identity,
    xlabel = "Теоретические квантили",
    ylabel = "Эмпирические квантили"
)

combined_5 = plot(
    p1_5,
    p2_5,
    p3_5,
    p4_5,
    layout = (2, 2),
    size = (1000, 800),
    plot_title = "Параметрическое исследование: λ = $current_λ"
)

display(combined_5)

# ## Моделирование для λ = 8

current_λ = λ_values[3]

result_8 = simulate_attacks(current_λ, T)

hourly_counts_8 = result_8.hourly_counts
intervals_8 = result_8.intervals
attack_times_8 = result_8.attack_times

sample_8 = rand(Poisson(current_λ), num_hours_for_est)

empirical_8 = count(sample_8 .> 10) / num_hours_for_est
theoretical_8 = 1 - cdf(Poisson(current_λ), 10)

push!(empirical_probs, empirical_8)
push!(theoretical_probs, theoretical_8)

p1_8 = histogram(
    hourly_counts_8,
    bins = 0:maximum(hourly_counts_8),
    normalize = :probability,
    label = "Эмпирическая частота",
    xlabel = "Число атак за час",
    ylabel = "Вероятность"
)

x_vals_8 = 0:maximum(hourly_counts_8)

plot!(
    p1_8,
    x_vals_8,
    pdf.(Poisson(current_λ), x_vals_8),
    line = :stem,
    marker = :circle,
    label = "Пуассон(λ=$current_λ)",
    lw = 2
)

p2_8 = plot(
    attack_times_8,
    1:length(attack_times_8),
    label = "Реализация",
    xlabel = "Время (ч)",
    ylabel = "Накопленное число атак"
)

plot!(
    p2_8,
    0:0.1:T,
    current_λ * (0:0.1:T),
    label = "Среднее λ·t",
    ls = :dash
)

p3_8 = histogram(
    intervals_8,
    bins = 30,
    normalize = :pdf,
    label = "Эмпирическая плотность",
    xlabel = "Интервал (ч)",
    ylabel = "Плотность"
)

x_dens_8 = range(0, maximum(intervals_8), length = 100)

plot!(
    p3_8,
    x_dens_8,
    pdf.(Exponential(1 / current_λ), x_dens_8),
    label = "Экспоненциальная плотность",
    lw = 2
)

p4_8 = qqplot(
    Exponential(1 / current_λ),
    intervals_8,
    qqline = :identity,
    xlabel = "Теоретические квантили",
    ylabel = "Эмпирические квантили"
)

combined_8 = plot(
    p1_8,
    p2_8,
    p3_8,
    p4_8,
    layout = (2, 2),
    size = (1000, 800),
    plot_title = "Параметрическое исследование: λ = $current_λ"
)

display(combined_8)

# ## Моделирование для λ = 12

current_λ = λ_values[4]

result_12 = simulate_attacks(current_λ, T)

hourly_counts_12 = result_12.hourly_counts
intervals_12 = result_12.intervals
attack_times_12 = result_12.attack_times

sample_12 = rand(Poisson(current_λ), num_hours_for_est)

empirical_12 = count(sample_12 .> 10) / num_hours_for_est
theoretical_12 = 1 - cdf(Poisson(current_λ), 10)

push!(empirical_probs, empirical_12)
push!(theoretical_probs, theoretical_12)

p1_12 = histogram(
    hourly_counts_12,
    bins = 0:maximum(hourly_counts_12),
    normalize = :probability,
    label = "Эмпирическая частота",
    xlabel = "Число атак за час",
    ylabel = "Вероятность"
)

x_vals_12 = 0:maximum(hourly_counts_12)

plot!(
    p1_12,
    x_vals_12,
    pdf.(Poisson(current_λ), x_vals_12),
    line = :stem,
    marker = :circle,
    label = "Пуассон(λ=$current_λ)",
    lw = 2
)

p2_12 = plot(
    attack_times_12,
    1:length(attack_times_12),
    label = "Реализация",
    xlabel = "Время (ч)",
    ylabel = "Накопленное число атак"
)

plot!(
    p2_12,
    0:0.1:T,
    current_λ * (0:0.1:T),
    label = "Среднее λ·t",
    ls = :dash
)

p3_12 = histogram(
    intervals_12,
    bins = 30,
    normalize = :pdf,
    label = "Эмпирическая плотность",
    xlabel = "Интервал (ч)",
    ylabel = "Плотность"
)

x_dens_12 = range(0, maximum(intervals_12), length = 100)

plot!(
    p3_12,
    x_dens_12,
    pdf.(Exponential(1 / current_λ), x_dens_12),
    label = "Экспоненциальная плотность",
    lw = 2
)

p4_12 = qqplot(
    Exponential(1 / current_λ),
    intervals_12,
    qqline = :identity,
    xlabel = "Теоретические квантили",
    ylabel = "Эмпирические квантили"
)

combined_12 = plot(
    p1_12,
    p2_12,
    p3_12,
    p4_12,
    layout = (2, 2),
    size = (1000, 800),
    plot_title = "Параметрическое исследование: λ = $current_λ"
)

display(combined_12)

# ## Моделирование для λ = 15

current_λ = λ_values[5]

result_15 = simulate_attacks(current_λ, T)

hourly_counts_15 = result_15.hourly_counts
intervals_15 = result_15.intervals
attack_times_15 = result_15.attack_times

sample_15 = rand(Poisson(current_λ), num_hours_for_est)

empirical_15 = count(sample_15 .> 10) / num_hours_for_est
theoretical_15 = 1 - cdf(Poisson(current_λ), 10)

push!(empirical_probs, empirical_15)
push!(theoretical_probs, theoretical_15)

p1_15 = histogram(
    hourly_counts_15,
    bins = 0:maximum(hourly_counts_15),
    normalize = :probability,
    label = "Эмпирическая частота",
    xlabel = "Число атак за час",
    ylabel = "Вероятность"
)

x_vals_15 = 0:maximum(hourly_counts_15)

plot!(
    p1_15,
    x_vals_15,
    pdf.(Poisson(current_λ), x_vals_15),
    line = :stem,
    marker = :circle,
    label = "Пуассон(λ=$current_λ)",
    lw = 2
)

p2_15 = plot(
    attack_times_15,
    1:length(attack_times_15),
    label = "Реализация",
    xlabel = "Время (ч)",
    ylabel = "Накопленное число атак"
)

plot!(
    p2_15,
    0:0.1:T,
    current_λ * (0:0.1:T),
    label = "Среднее λ·t",
    ls = :dash
)

p3_15 = histogram(
    intervals_15,
    bins = 30,
    normalize = :pdf,
    label = "Эмпирическая плотность",
    xlabel = "Интервал (ч)",
    ylabel = "Плотность"
)

x_dens_15 = range(0, maximum(intervals_15), length = 100)

plot!(
    p3_15,
    x_dens_15,
    pdf.(Exponential(1 / current_λ), x_dens_15),
    label = "Экспоненциальная плотность",
    lw = 2
)

p4_15 = qqplot(
    Exponential(1 / current_λ),
    intervals_15,
    qqline = :identity,
    xlabel = "Теоретические квантили",
    ylabel = "Эмпирические квантили"
)

combined_15 = plot(
    p1_15,
    p2_15,
    p3_15,
    p4_15,
    layout = (2, 2),
    size = (1000, 800),
    plot_title = "Параметрическое исследование: λ = $current_λ"
)

display(combined_15)

# ## Сводная таблица
#
# Сравним теоретические и экспериментальные вероятности
# для всех исследованных значений интенсивности.

results_df = DataFrame(
    λ = λ_values,
    theoretical = theoretical_probs,
    empirical = empirical_probs
)

results_df

# ## Итоговая зависимость вероятности от λ
#
# Последний график показывает, как изменение интенсивности потока
# влияет на вероятность появления более 10 атак за один час.

p_final = plot(
    λ_values,
    [theoretical_probs empirical_probs],
    label = [
        "Теоретическая P(>10)"
        "Эмпирическая P(>10)"
    ],
    marker = :circle,
    xlabel = "Интенсивность λ (атак/час)",
    ylabel = "Вероятность P(>10)",
    title = "Зависимость вероятности от интенсивности атак"
)

display(p_final)

# ## Вывод
#
# При увеличении интенсивности `λ` среднее число атак за час
# возрастает. Поэтому увеличивается и вероятность того, что
# за один час произойдёт более 10 атак.
#
# Полученные графики позволяют сравнить экспериментальные
# реализации пуассоновского потока при различных значениях `λ`
# и сопоставить результаты с соответствующими теоретическими
# распределениями.