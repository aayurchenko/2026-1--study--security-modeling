using DrWatson
@quickactivate "project"

using Plots, Distributions, StatsPlots, JLD2

# Определяем параметры эксперимента
# (должны совпадать с использованными в run_experiment.jl)
params = Dict(
    :λ => 5.0,
    :T => 24.0,
    :num_hours_for_est => 10000
)

# Формируем путь к файлу с данными
# (как в run_experiment.jl)
filename = datadir("attack_sim", savename(params, "jld2"))

# Проверяем существование файла
if !isfile(filename)
    error("Файл $filename не найден. Сначала запустите scripts/run_experiment.jl для генерации данных.")
end

# Загружаем данные
@load filename data

# data — это словарь (Dict), сохранённый в run_experiment.jl

# Извлекаем результаты
hourly_counts = data[:hourly_counts]
intervals = data[:intervals]
attack_times = data[:attack_times]

λ = params[:λ]
T = params[:T]

emp_prob = data[:emp_prob]
theor_prob = data[:theor_prob]

# Выводим вероятности для справки
println("Эмпирическая вероятность P(>10) = ", emp_prob)
println("Теоретическая вероятность = ", theor_prob)

# 1. Гистограмма числа атак за час
p1 = histogram(
    hourly_counts,
    bins = 0:maximum(hourly_counts),
    normalize = :probability,
    label = "Эмпирическая частота",
    xlabel = "Число атак за час",
    ylabel = "Вероятность"
)

x_vals = 0:maximum(hourly_counts)

theor_probs = pdf.(Poisson(λ), x_vals)

plot!(
    p1,
    x_vals,
    theor_probs,
    line = :stem,
    marker = :circle,
    label = "Теоретическое Пуассона(λ=$λ)",
    lw = 2
)

title!(p1, "Распределение числа атак за час")

# 2. Накопленное число атак
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

title!(p2, "Накопленное число атак в течение $(T) ч")

# 3. Гистограмма интервалов
p3 = histogram(
    intervals,
    bins = 30,
    normalize = :pdf,
    label = "Эмпирическая плотность",
    xlabel = "Интервал (ч)",
    ylabel = "Плотность"
)

x_dens = range(
    0,
    maximum(intervals),
    length = 100
)

theor_dens = pdf.(
    Exponential(1 / λ),
    x_dens
)

plot!(
    p3,
    x_dens,
    theor_dens,
    label = "Экспоненциальная плотность",
    lw = 2
)

title!(
    p3,
    "Распределение интервалов между атаками"
)

# 4. QQ-plot интервалов против экспоненциального распределения
p4 = qqplot(
    Exponential(1 / λ),
    intervals,
    qqline = :identity,
    xlabel = "Теоретические квантили",
    ylabel = "Эмпирические квантили",
    title = "QQ-plot интервалов"
)

# Объединяем графики
plot(
    p1,
    p2,
    p3,
    p4,
    layout = (2, 2),
    size = (1000, 800)
)

# Сохраняем графики в папку plots
savefig(
    plotsdir("attack_sim_plots.png")
)

println(
    "Графики сохранены в ",
    plotsdir("attack_sim_plots.png")
)