using DrWatson
@quickactivate "project"

using Literate

const literate_dir = projectdir("literate")
const source_files = sort(filter(file -> endswith(file, ".jl"), readdir(literate_dir)))

for file in source_files
    input_file = joinpath(literate_dir, file)
    name = splitext(file)[1]

    script_dir = scriptsdir("generated", name)
    notebook_dir = projectdir("notebooks", name)
    quarto_dir = projectdir("markdown", name)

    mkpath(script_dir)
    mkpath(notebook_dir)
    mkpath(quarto_dir)

    Literate.script(input_file, script_dir; credit=false)
    Literate.notebook(input_file, notebook_dir; execute=false, credit=false)
    Literate.markdown(input_file, quarto_dir;
        flavor=Literate.QuartoFlavor(), execute=false, credit=false)

    println("Сгенерированы .jl, .ipynb и .qmd для: ", name)
end
