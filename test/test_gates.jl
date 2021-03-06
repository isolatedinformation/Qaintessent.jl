using Test
using TestSetExtensions
using LinearAlgebra
using Qaintessent


isunitary(g::AbstractGate) = Qaintessent.matrix(g) * Qaintessent.matrix(Base.adjoint(g)) ≈ I


@testset ExtendedTestSet "quantum gates" begin

    θ = 2π*rand()
    ϕ = 2π*rand()
    n = randn(3); n /= norm(n)

    @testset "basic quantum gates" begin
        for g in [X, Y, Z, HadamardGate(), SGate(), TGate(), RxGate(θ), RyGate(θ), RzGate(θ), RotationGate(θ, n), PhaseShiftGate(ϕ), SwapGate(), EntanglementXXGate(θ), EntanglementYYGate(θ), EntanglementZZGate(θ), controlled_not()]
            @test isunitary(g)
            gdag = adjoint(g)

            @test Qaintessent.matrix(gdag) == adjoint(Qaintessent.matrix(g))
            @test LinearAlgebra.ishermitian(g) == (Qaintessent.matrix(gdag) == Qaintessent.matrix(g))
        end
    end


    @testset "general rotation gate" begin
        @test Qaintessent.matrix(RotationGate(θ, [1, 0, 0])) ≈ Qaintessent.matrix(RxGate(θ))
        @test Qaintessent.matrix(RotationGate(θ, [0, 1, 0])) ≈ Qaintessent.matrix(RyGate(θ))
        @test Qaintessent.matrix(RotationGate(θ, [0, 0, 1])) ≈ Qaintessent.matrix(RzGate(θ))

        @test Qaintessent.matrix(RotationGate([θ, 0, 0])) ≈ Qaintessent.matrix(RxGate(θ))
        @test Qaintessent.matrix(RotationGate([0, θ, 0])) ≈ Qaintessent.matrix(RyGate(θ))
        @test Qaintessent.matrix(RotationGate([0, 0, θ])) ≈ Qaintessent.matrix(RzGate(θ))
    end


    @testset "general rotation gate exceptions" begin
        @test_throws ErrorException("Rotation axis vector must have length 3.") Qaintessent.matrix(RotationGate(θ, [1, 0, 0, 0]))
        @test_throws ErrorException("Norm of rotation axis vector must be 1.") Qaintessent.matrix(RotationGate(θ, [1, 2, 0]))
        @test_throws ErrorException("Rotation axis vector must have length 3.") Qaintessent.matrix(RotationGate([0, θ, 0, 1]))
    end


    @testset "general unitary gate" begin

        # test MatrixGate
        N = 3
        d = 2
        A = randn(ComplexF64, d^N, d^N)
        U, _ = qr(A)
        U = Array(U)
        gateU = MatrixGate(U)
        gateUdag = adjoint(gateU)
        @test Qaintessent.matrix(gateU) ≈ U
        @test isunitary(gateU)
        @test LinearAlgebra.ishermitian(gateU) == (Qaintessent.matrix(gateUdag) == Qaintessent.matrix(gateU))

        U = Qaintessent.matrix(X)
        gateU = MatrixGate(U)
        gateUdag = adjoint(gateU)
        @test Qaintessent.matrix(gateU) ≈ U
        @test isunitary(gateU)
        @test true == (Qaintessent.matrix(gateUdag) == Qaintessent.matrix(gateU))
    end

    # not unitary
    @testset "general unitary gate exceptions" begin

        N = 3
        d = 2
        @test_throws ErrorException("Quantum operators must be unitary") MatrixGate(randn(ComplexF64, d^N, d^N))
    end


    @testset "general controlled gate" begin
        # test MatrixGate
        N = 4
        M = 2
        d = 2
        A = randn(ComplexF64, d^M, d^M)
        U, _ = qr(A)
        U = Array(U)
        gateU = MatrixGate(U)
        cgateU = ControlledGate{M,N}(gateU)

        cgateUdag = adjoint(cgateU)
        @test LinearAlgebra.ishermitian(cgateU) == (Qaintessent.matrix(cgateU) == Qaintessent.matrix(cgateUdag))
    end
end
