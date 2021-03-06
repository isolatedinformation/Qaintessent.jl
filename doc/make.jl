using Documenter, Qaintessent

makedocs(
    sitename="Qaintessent.jl Documentation",
    pages = [
        "Home" => "index.md",
        "Section" => [
            "gates.md",
            "circuit.md",
            "gradients.md",
            "models.md",
            "view.md",
            "qasm.md"
        ]
    ]
)

deploydocs(
    repo = "github.com/Qaintum/Qaintessent.jl.git",
    push_preview = true
)
