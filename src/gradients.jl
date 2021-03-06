
# `backward` functions return gates storing derivatives

backward(g::XGate, Δ::AbstractMatrix) = g
backward(g::YGate, Δ::AbstractMatrix) = g
backward(g::ZGate, Δ::AbstractMatrix) = g


backward(g::HadamardGate, Δ::AbstractMatrix) = g


backward(g::SGate, Δ::AbstractMatrix) = g
backward(g::TGate, Δ::AbstractMatrix) = g

backward(g::SdagGate, Δ::AbstractMatrix) = g
backward(g::TdagGate, Δ::AbstractMatrix) = g

backward(g::MatrixGate, Δ::AbstractMatrix) = g


function backward(g::RxGate, Δ::AbstractMatrix)
    c = cos(g.θ[]/2)
    s = sin(g.θ[]/2)
    # using conjugated derivative matrix; factor 2 cancels 1/2 from θ/2
    RxGate(sum(real([-s im*c; im*c -s] .* Δ)))
end

function backward(g::RyGate, Δ::AbstractMatrix)
    c = cos(g.θ[]/2)
    s = sin(g.θ[]/2)
    # using conjugated derivative matrix; factor 2 cancels 1/2 from θ/2
    RyGate(sum(real([-s -c; c -s] .* Δ)))
end

function backward(g::RzGate, Δ::AbstractMatrix)
    # using conjugated derivative matrix; factor 2 cancels 1/2 from θ/2
    eθ = exp(im*g.θ[]/2)
    RzGate(real(im*eθ*Δ[1, 1] - im*conj(eθ)*Δ[2, 2]))
end


function backward(g::RotationGate, Δ::AbstractMatrix)
    θ = norm(g.nθ)
    if θ == 0
        σ = (matrix(X), matrix(Y), matrix(Z))
        RotationGate([real(sum(conj(-im*σ[i]) .* Δ)) for i in 1:3])
    else
        n = g.nθ/θ
        c = cos(θ/2)
        s = sin(θ/2)
        dRθ = -s*I - im*c*pauli_vector(n...)
        dn = (I - reshape(kron(n, n), 3, 3))/θ
        # using conjugated derivative matrix
        RotationGate([2*real(sum(conj(0.5*n[i]*dRθ - im*s*pauli_vector(dn[:, i]...)) .* Δ)) for i in 1:3])
    end
end


function backward(g::PhaseShiftGate, Δ::AbstractMatrix)
    # using conjugated derivative matrix
    PhaseShiftGate(2*real(-im*Base.exp(-im*g.ϕ[1])*Δ[2, 2]))
end


backward(g::SwapGate, Δ::AbstractMatrix) = g


function backward(g::EntanglementXXGate, Δ::AbstractMatrix)
    c = cos(g.θ[]/2)
    s = sin(g.θ[]/2)
    # using conjugated derivative matrix; factor 2 cancels 1/2 from θ/2
    EntanglementXXGate(sum(real([-s 0 0 im*c; 0 -s im*c 0; 0 im*c -s 0; im*c 0 0 -s] .* Δ)))
end

function backward(g::EntanglementYYGate, Δ::AbstractMatrix)
    c = cos(g.θ[]/2)
    s = sin(g.θ[]/2)
    # using conjugated derivative matrix; factor 2 cancels 1/2 from θ/2
    EntanglementYYGate(sum(real([-s 0 0 -im*c; 0 -s im*c 0; 0 im*c -s 0; -im*c 0 0 -s] .* Δ)))
end

function backward(g::EntanglementZZGate, Δ::AbstractMatrix)
    eθ = exp(im*g.θ[]/2)
    # using conjugated derivative matrix; factor 2 cancels 1/2 from θ/2
    EntanglementZZGate(sum(real(im*eθ*Δ[1, 1] - im*conj(eθ)*Δ[2, 2] - im*conj(eθ)*Δ[3, 3] + im*eθ*Δ[4, 4])))
end


function backward(g::ControlledGate{M,N}, Δ::AbstractMatrix) where {M,N}
    # Note: target qubits correspond to fastest varying indices
    ControlledGate{M,N}(backward(g.U, Δ[end-2^M+1:end, end-2^M+1:end]))
end


function backward(cg::CircuitGate{M,N,G}, ψ::AbstractVector, Δ::AbstractVector) where {M,N,G}
    ρ = rdm(N, cg.iwire, Δ, ψ)
    CircuitGate{M,N,G}(cg.iwire, backward(cg.gate, ρ))
end

function backward(m::Moment{N}, ψ::AbstractVector, Δ::AbstractVector) where {N}
    gates = AbstractCircuitGate{N}[]
    for cg in reverse(m.gates)
        Udag = Base.adjoint(cg)
        ψ = apply(Udag, ψ)
        # backward step of quantum state
        pushfirst!(gates, backward(cg, ψ, Δ))
        Δ = apply(Udag, Δ)
    end
    return Moment{N}(gates), ψ, Δ
end

function backward(cgc::CircuitGateChain{N}, ψ::AbstractVector, Δ::AbstractVector) where {N}
    dcgc = CircuitGateChain{N}(AbstractCircuitGate{N}[])
    for moment in reverse(cgc.moments)
        # backward step of quantum state
        (m, ψ, Δ) = backward(moment, ψ, Δ)
        pushfirst!(dcgc.moments, m)
    end
    return dcgc, Δ
end


"""
    gradients(c::Circuit{N}, ψ::AbstractVector, Δ::AbstractVector{<:Real}) where {N}

Perform a backward pass to compute gradients of a (fictitious) cost function with
respect to the circuit parameters of `c` and input wavefunction `ψ`. `Δ` contains
the cost function gradients with respect to the circuit outputs (measurement operator averages).
The gradients with respect to the circuit parameters are returned in a duplicate circuit;
the overall return value is the tuple (dc::Circuit{N}, dψ::AbstractVector).
"""
function gradients(c::Circuit{N}, ψ::AbstractVector, Δ::AbstractVector{<:Real}) where {N}
    # length of circuit output vector must match gradient vector
    @assert length(Δ) == length(c.meas.mops)
    # forward pass through unitary gates
    ψ = apply(c.cgc, ψ)
    # gradient (conjugated Wirtinger derivatives) of cost function with respect to ψ
    ψbar = sum([Δ[i] * (c.meas.mops[i]*ψ) for i in 1:length(Δ)])
    # backward pass through unitary gates
    dcgc, ψbar = backward(c.cgc, ψ, ψbar)
    # TODO: efficiently represent Kronecker product without explicitly storing matrix entries
    dmeas = MeasurementOps{N}([Δ[i]*reshape(kron(conj(ψ), ψ), length(ψ), length(ψ)) for i in 1:length(Δ)])
    return Circuit{N}(dcgc, dmeas), ψbar
end
