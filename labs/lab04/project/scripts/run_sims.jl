using DrWatson

@quickactivate "project"

include(srcdir("simulation.jl"))

println("Запуск симуляций...")

results = main_simulations()

println("Готово!")
println("Рассчитано вариантов: ", nrow(results))
println(
    "Результаты сохранены в: ",
    datadir("sims", "results.csv"),
)

println("\nПервые строки таблицы:")
println(first(results, 5))