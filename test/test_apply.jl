using Test
using TestSetExtensions
using LinearAlgebra
using Random
using Qaintessent


"""Checks that tailored apply gives same result as general apply"""

@testset ExtendedTestSet "apply gates to state vector" begin
    N = 6
    θ = 0.7π
    ϕ = 0.4π
    n = randn(3); n /= norm(n)
    ψ = rand(ComplexF64, 2^N)

    @testset "apply basic gates" begin
        # single qubit gates
        for g in [X, Y, Z, HadamardGate(), SGate(), TGate(), RxGate(θ), RyGate(θ), RzGate(θ), RotationGate(θ, n), PhaseShiftGate(ϕ)]
            i = rand(1:N)
            cg = single_qubit_circuit_gate(i, g, N)
            cga = CircuitGate{1,N,AbstractGate{1}}(cg.iwire, cg.gate) # generate same gate with type AbstractGate{1}

            @test apply(cg, ψ) ≈ apply(cga, ψ)
        end
    end

    @testset "apply basic controlled gates" begin
        # control gate
        for g in [X, Y, Z, RotationGate(θ,n), PhaseShiftGate(ϕ)]
            i = rand(1:N)
            j = rand([1:i-1; i+1:N])
            cg = controlled_circuit_gate(i, j, g, N)
            cga = CircuitGate{2,N,AbstractGate{2}}(cg.iwire, cg.gate)

            @test apply(cg, ψ) ≈ apply(cga, ψ)
        end
    end

    @testset "apply swap gate" begin
        i = rand(1:N)
        j = rand([1:i-1; i+1:N])
        cg = CircuitGate((i,j), SwapGate(), N)
        cga = CircuitGate{2,N,AbstractGate{2}}(cg.iwire, cg.gate)

        @test apply(cg, ψ) ≈ apply(cga, ψ)
    end

    @testset "apply 1-qubit MatrixGate" begin
        # MatrixGate: one qubit
        d = 2
        A = rand(ComplexF64, d, d)
        U, R = qr(A)
        U = Array(U);
        g = MatrixGate(U)
        i = rand(1:N)
        cg = single_qubit_circuit_gate(i, g, N)
        cga = CircuitGate{1,N,AbstractGate{1}}(cg.iwire, cg.gate) # generate same gate with type AbstractGate{1}

        @test apply(cg, ψ) ≈ apply(cga, ψ)

    end

    @testset "apply k-qubit MatrixGate" begin
        # MatrixGate: k qubits
        k = rand(1:N)
        A = rand(ComplexF64, 2^k, 2^k)
        U, R = qr(A)
        U = Array(U);
        g = MatrixGate(U)
        iwire = [rand(1:N)]
        for j in 1:k-1
            l = rand(1:N-j)
            i = setdiff([1:N...], iwire)[l]
            push!(iwire, i)
        end
        sort!(iwire)
        cga = CircuitGate{k,N,AbstractGate{k}}((iwire...,), g)
        m = Qaintessent.matrix(cga)
        @test apply(cga, ψ) ≈ m*ψ
    end
end


@testset ExtendedTestSet "apply gates to density matrix" begin
    N = 5
    ψ = randn(ComplexF64, 2^N)
    ψ /= norm(ψ)
    ρ = density_from_statevector(ψ)

    @testset "density matrix apply basic gates" begin
        # single qubit gates
        for g in [X, Y, Z, HadamardGate(), SGate(), SdagGate(), TGate(), TdagGate(), RxGate(-1.1), RyGate(0.7), RzGate(0.4), RotationGate([-0.3, 0.1, 0.23]), PhaseShiftGate(0.9)]
            cg = CircuitGate((rand(1:N),), g, N)
            ψs = apply(cg, ψ)
            ρsref = density_from_statevector(ψs)
            ρs = apply(cg, ρ)
            @test ρs.v ≈ ρsref.v

            # generate same gate with type AbstractGate{1}
            cga = CircuitGate{1,N,AbstractGate{1}}(cg.iwire, cg.gate)
            ρsa = apply(cga, ρ)
            @test ρs.v ≈ ρsa.v
        end
    end

    @testset "density matrix apply swap gate" begin
        # swap gate
        i = rand(1:N)
        j = rand([1:i-1; i+1:N])
        cg = CircuitGate((i, j), SwapGate(), N)
        ψs = apply(cg, ψ)
        ρsref = density_from_statevector(ψs)
        ρs = apply(cg, ρ)
        @test ρs.v ≈ ρsref.v
    end

    @testset "density matrix apply controlled gate" begin
        # controlled gate
        iwperm = Tuple(randperm(N))
        # number of control and target wires
        nt = rand(1:2)
        nc = rand(1:3)
        cg = controlled_circuit_gate(iwperm[1:nt], iwperm[nt+1:nt+nc], nt == 1 ? RotationGate(rand(3) .- 0.5) : MatrixGate(Array(qr(randn(ComplexF64, 4, 4)).Q)), N)
        ψs = apply(cg, ψ)
        ρsref = density_from_statevector(ψs)
        ρs = apply(cg, ρ)
        @test ρs.v ≈ ρsref.v
    end

    @testset "density matrix apply general unitary gate" begin
        # matrix gate (general unitary gate)
        iwperm = Tuple(randperm(N))
        cg = CircuitGate(iwperm[1:3], MatrixGate(Array(qr(randn(ComplexF64, 8, 8)).Q)), N)
        ψs = apply(cg, ψ)
        ρsref = density_from_statevector(ψs)
        ρs = apply(cg, ρ)
        @test ρs.v ≈ ρsref.v
    end
end
