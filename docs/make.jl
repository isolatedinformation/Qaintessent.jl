using Documenter, Qaintessent

makedocs(
    sitename="Qaintessent.jl Documentation",
    pages = [
        "Home" => "index.md",
        "Section" => [
            "gates.md",
            "circuit.md",
            "models.md",
            "view.md"
        ]
    ]
)