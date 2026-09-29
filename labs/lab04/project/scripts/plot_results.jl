using DrWatson

@quickactivate "project"

using Plots
using DataFrames
using Statistics

include(srcdir("simulation.jl"))

# Загружаем результаты ранее выполненных симуляций.
results = load_results()

# Для графиков выбираем эксперименты с фиксированными затратами.
filtered = results[
    (results.c_a .== 1.0) .&
    (results.c_d .== 1.0),
    :,
]

isempty(filtered) && error(
    "Не найдены результаты для c_a = 1.0 и c_d = 1.0",
)

mkpath(plotsdir())

# Зависимость вероятности атаки на первый актив
# от отношения ценностей активов.
ratio = filtered.V1 ./ filtered.V2

strategy_plot = scatter(
    ratio,
    filtered.p_1;
    group = filtered.type,
    xlabel = "V₁ / V₂",
    ylabel = "p₁ — вероятность атаки актива 1",
    title = "Стратегия нападающего при cₐ = 1, c_d = 1",
    legend = :topright,
    markersize = 6,
)

strategy_plot_path = plotsdir("p1_vs_ratio.png")
savefig(strategy_plot, strategy_plot_path)

println("График стратегии сохранён в: ", strategy_plot_path)

# Средний выигрыш нападающего для различных значений V₁ и V₂.
grouped_results = groupby(filtered, [:V1, :V2])

summary = combine(
    grouped_results,
    :UA => mean => :UA_mean,
)

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
    xlabel = "Ценность первого актива V₁",
    ylabel = "Ценность второго актива V₂",
    title = "Средний выигрыш нападающего",
    colorbar_title = "Uₐ",
)

payoff_plot_path = plotsdir("heatmap_UA.png")
savefig(payoff_plot, payoff_plot_path)

println("Тепловая карта сохранена в: ", payoff_plot_path)

display(strategy_plot)
display(payoff_plot)