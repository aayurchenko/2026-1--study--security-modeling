using DrWatson
@quickactivate "project"
using Distributions, Plots, Statistics, Random, JLD2

# Параметры модели
λ = 5.0
theor_prob = 1 - cdf(Poisson(λ), 10)

# Размеры выборки для исследования (логарифмическая шкала)
sample_sizes = [10, 50, 100, 500, 1000, 5000, 10000, 50000, 100000]

# Для воспроизводимости
Random.seed!(123)

# Вычисляем эмпирические оценки для каждого объёма выборки
estimates = Float64[]

println("Вычисление оценок вероятности...")

for n in sample_sizes
    hourly_sample = rand(Poisson(λ), n)
    emp_prob = count(hourly_sample .> 10) / n
    push!(estimates, emp_prob)
    println("n = $n: оценка = $emp_prob")
end

# Построение графика сходимости
p = plot(sample_sizes, estimates,
    xscale = :log10,
    marker = :circle,
    label = "Эмпирическая оценка",
    xlabel = "Объём выборки (часы)",
    ylabel = "Оценка вероятности P(>10)",
    legend = :bottomright)

hline!(p, [theor_prob],
    label = "Теоретическое значение",
    ls = :dash,
    lw = 2,
    color = :red)

title!(p, "Сходимость оценки вероятности P(>10) при λ=$λ")

# Сохраняем график в папку plots
plot_path = plotsdir("convergence.png")
savefig(p, plot_path)
println("График сохранён в $plot_path")

# Сохраняем данные сходимости в JLD2 (опционально)
data_path = datadir("convergence", "convergence_data_λ=$(λ).jld2")
mkpath(datadir("convergence"))

@save data_path sample_sizes estimates λ theor_prob

println("Данные сходимости сохранены в $data_path")