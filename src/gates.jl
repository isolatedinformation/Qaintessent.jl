using LinearAlgebra


"""
    AbstractGate{N}

Abtract unitary quantum gate. `N` is the number of "wires" the gate acts on.
"""
abstract type AbstractGate{N} end

"""
Pauli X gate

``X = \\begin{pmatrix} 0 & 1 \\\\ 1 & 0 \\end{pmatrix}``
"""
struct XGate <: AbstractGate{1} end

"""
Pauli Y gate

``Y = \\begin{pmatrix} 0 & -i \\\\ i & 0 \\end{pmatrix}``
"""
struct YGate <: AbstractGate{1} end

"""
Pauli Z gate

``Z = \\begin{pmatrix} 1 & 0 \\\\ 0 & -1 \\end{pmatrix}``
"""
struct ZGate <: AbstractGate{1} end

matrix(::XGate) = ComplexF64[0.  1.; 1.  0.]
matrix(::YGate) = [0. -im; im  0.]
matrix(::ZGate) = ComplexF64[1.  0.; 0. -1.]

LinearAlgebra.ishermitian(::XGate) = true
LinearAlgebra.ishermitian(::YGate) = true
LinearAlgebra.ishermitian(::ZGate) = true

# Pauli matrices are Hermitian
Base.adjoint(X::XGate) = X
Base.adjoint(Y::YGate) = Y
Base.adjoint(Z::ZGate) = Z

# corresponding instances
X = XGate()
Y = YGate()
Z = ZGate()


"""
Hadamard gate

``H = \\frac{1}{\\sqrt{2}} \\begin{pmatrix} 1 & 1 \\\\ 1 & 1 \\end{pmatrix}``
"""
struct HadamardGate <: AbstractGate{1} end

matrix(::HadamardGate) = [1 1; 1 -1] / sqrt(2)

LinearAlgebra.ishermitian(::HadamardGate) = true
# Hadamard gate is Hermitian
Base.adjoint(H::HadamardGate) = H


"""
S gate

``S = \\frac{1}{\\sqrt{2}} \\begin{pmatrix} 1 & 0 \\\\ 0 & i \\end{pmatrix}``
"""
struct SGate <: AbstractGate{1} end


"""
T gate

``T = \\frac{1}{\\sqrt{2}} \\begin{pmatrix} 1 & 0 \\\\ 0 & e^{\\frac{iπ}{4}} \\end{pmatrix}``
"""
struct TGate <: AbstractGate{1} end


"""
S† gate

``S^{†} = \\begin{pmatrix} 1 & 0 \\\\ 0 & -i \\end{pmatrix}``
"""
struct SdagGate <: AbstractGate{1} end

"""
T† gate

``T^{†} = \\begin{pmatrix} 1 & 0 \\\\ 0 & e^{-\\frac{iπ}{4}} \\end{pmatrix}``
"""
struct TdagGate <: AbstractGate{1} end

matrix(::SGate) = [1. 0.; 0. im]
matrix(::TGate) = [1. 0.; 0. Base.exp(im*π/4)]

matrix(::SdagGate) = [1. 0.; 0. -im]
matrix(::TdagGate) = [1. 0.; 0. Base.exp(-im*π/4)]

LinearAlgebra.ishermitian(::SGate) = false
LinearAlgebra.ishermitian(::TGate) = false

LinearAlgebra.ishermitian(::SdagGate) = false
LinearAlgebra.ishermitian(::TdagGate) = false

Base.adjoint(::SGate) = SdagGate()
Base.adjoint(::TGate) = TdagGate()

Base.adjoint(::SdagGate) = SGate()
Base.adjoint(::TdagGate) = TGate()


"""
Rotation-X gate

``R_{x}(\\theta) = \\begin{pmatrix} \\cos(\\frac{\\theta}{2}) & -i\\sin(\\frac{\\theta}{2}) \\\\ -i\\sin(\\frac{\\theta}{2}) & \\cos(\\frac{\\theta}{2}) \\end{pmatrix}``
"""
struct RxGate <: AbstractGate{1}
    # use a reference type (array with 1 entry) for compatibility with Flux
    θ::Vector{<:Real}

    function RxGate(θ::Real)
        new([θ])
    end
end

function matrix(g::RxGate)
    c = cos(g.θ[]/2)
    s = sin(g.θ[]/2)
    [c -im*s; -im*s c]
end

function LinearAlgebra.ishermitian(g::RxGate)
    if mod2pi(g.θ[]) < eps()
        return true
    end
    return false
end

"""
Rotation-Y gate

``R_{y}(\\theta) = \\begin{pmatrix} \\cos(\\frac{\\theta}{2}) & -\\sin(\\frac{\\theta}{2}) \\\\ \\sin(\\frac{\\theta}{2}) & \\cos(\\frac{\\theta}{2}) \\end{pmatrix}``
"""
struct RyGate <: AbstractGate{1}
    # use a reference type (array with 1 entry) for compatibility with Flux
    θ::Vector{<:Real}

    function RyGate(θ::Real)
        new([θ])
    end
end

function matrix(g::RyGate)
    c = cos(g.θ[]/2)
    s = sin(g.θ[]/2)
    ComplexF64[c -s; s c]
end

function LinearAlgebra.ishermitian(g::RyGate)
    if mod2pi(g.θ[]) < eps()
        return true
    end
    return false
end

"""
Rotation-Z gate

``R_{z}(\\theta) = \\begin{pmatrix} e^{\\frac{-i\\theta}{2}} & 0 \\\\ 0 & e^{\\frac{i\\theta}{2}} \\end{pmatrix}``
"""
struct RzGate <: AbstractGate{1}
    # use a reference type (array with 1 entry) for compatibility with Flux
    θ::Vector{<:Real}
    function RzGate(θ::Real)
        new([θ])
    end
end

function matrix(g::RzGate)
    [Base.exp(-im*g.θ[]/2) 0; 0 Base.exp(im*g.θ[]/2)]
end

function LinearAlgebra.ishermitian(g::RzGate)
    if mod2pi(g.θ[]) < eps()
        return true
    end
    return false
end

Base.adjoint(g::RxGate) = RxGate(-g.θ[])
Base.adjoint(g::RyGate) = RyGate(-g.θ[])
Base.adjoint(g::RzGate) = RzGate(-g.θ[])


"""
General rotation operator gate: rotation by angle `θ` around unit vector `n`.

``R_{\\vec{n}}(\\theta) = \\cos(\\frac{\\theta}{2})I - i\\sin(\\frac{\\theta}{2})\\vec{n}\\sigma, \\\\ \\sigma = [X, Y, Z]``
"""
struct RotationGate <: AbstractGate{1}
    nθ::AbstractVector{<:Real}

    function RotationGate(nθ::AbstractVector{<:Real})
        length(nθ) == 3 || error("Rotation axis vector must have length 3.")
        new(nθ)
    end

    function RotationGate(θ::Real, n::AbstractVector{<:Real})
        length(n) == 3 || error("Rotation axis vector must have length 3.")
        norm(n) ≈ 1 || error("Norm of rotation axis vector must be 1.")
        new(n*θ)
    end
end

function matrix(g::RotationGate)
    θ = norm(g.nθ)
    if θ == 0
        return Matrix{Complex{eltype(g.nθ)}}(I, 2, 2)
    end
    n = g.nθ/θ
    cos(θ/2)*I - im*sin(θ/2)*pauli_vector(n...)
end

function LinearAlgebra.ishermitian(g::RotationGate)
    if norm(g.nθ + g.nθ) < eps()
        return true
    end
    return false
end

Base.adjoint(g::RotationGate) = RotationGate(-g.nθ)


"""
Phase shift gate

``P(\\phi) = \\begin{pmatrix} 1 & 0 \\\\ 0 & e^{i\\phi} \\end{pmatrix}``
"""
struct PhaseShiftGate <: AbstractGate{1}
    # use a reference type (array with 1 entry) for compatibility with Flux
    ϕ::Vector{<:Real}

    function PhaseShiftGate(ϕ::Real)
        new([ϕ])
    end
end

matrix(g::PhaseShiftGate) = [1 0; 0 Base.exp(im*g.ϕ[])]

function LinearAlgebra.ishermitian(g::PhaseShiftGate)
    if abs(g.ϕ[]) < eps()
        return true
    end
    return false
end

Base.adjoint(g::PhaseShiftGate) = PhaseShiftGate(-g.ϕ[])


"""
Swap gate

``SWAP = \\begin{pmatrix} 1 & 0 & 0 & 0 \\\\ 0 & 0 & 1 & 0 \\\\ 0 & 1 & 0 & 0 \\\\ 0 & 0 & 0 & 1 \\end{pmatrix}``
"""
struct SwapGate <: AbstractGate{2} end


matrix(::SwapGate) = ComplexF64[1. 0. 0. 0.; 0. 0. 1. 0.; 0. 1. 0. 0.; 0. 0. 0. 1.]

# swap gate is Hermitian
LinearAlgebra.ishermitian(::SwapGate) = true
Base.adjoint(s::SwapGate) = s


"""
General controlled gate: the `M` wires corresponding to the fastest running indices are the target and the remaining `N - M` wires the control
"""
struct ControlledGate{M,N,G} <: AbstractGate{N}
    U::AbstractGate{M}
    function ControlledGate{M,N,G}(U::AbstractGate{M}) where {M,N,G}
        M < N || error("Number of target wires of a controlled gate must be smaller than overall number of wires.")
        g = typeof(U)
        new{M,N,g}(U)
    end
end

function matrix(g::ControlledGate{M,N,G}) where {M,N,G}
    Umat = matrix(g.U)
    CU = sparse(one(eltype(Umat)) * I, 2^N, 2^N)
    # Note: target qubit(s) corresponds to fastest varying index
    CU[end-size(Umat, 1)+1:end, end-size(Umat, 2)+1:end] = Umat
    return CU
end

LinearAlgebra.ishermitian(g::ControlledGate{M,N,G}) where {M,N,G} =
    LinearAlgebra.ishermitian(g.U)

Base.adjoint(g::ControlledGate{M,N,G}) where {M,N,G} =
    ControlledGate{M,N,G}(Base.adjoint(g.U))

controlled_not() = ControlledGate{1,2,XGate}(X)

isunitary(m::AbstractMatrix) = (m * Base.adjoint(m) ≈ I)


"""
MatrixGate: general gate constructed from an unitary matrix
"""
struct MatrixGate{N} <: AbstractGate{N}
    matrix::AbstractMatrix
    function MatrixGate(m)
        d = 2
        @assert size(m, 1) == size(m, 2)
        isunitary(m) || error("Quantum operators must be unitary")
        N = Int(log(d, size(m, 1)))
        return new{N}(m)
    end
end

matrix(g::MatrixGate{N}) where {N} = g.matrix

Base.adjoint(g::MatrixGate{N}) where {N} = MatrixGate(Base.adjoint(g.matrix))

LinearAlgebra.ishermitian(g::MatrixGate{M}) where {M} =
    LinearAlgebra.ishermitian(Qaintessent.matrix(g))

function Base.isapprox(g1::G, g2::G) where {G<:AbstractGate{N}} where {N}
    for name in fieldnames(G)
        if !(getfield(g1, name) ≈ getfield(g2, name))
            return false
        end
    end
    return true
end

# handle different gate types or dimensions
Base.isapprox(::AbstractGate, ::AbstractGate) = false
