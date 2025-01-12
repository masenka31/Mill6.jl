
@testset "convolution shift" begin
    @test _convshift(2) == 0:1
    @test _convshift(3) == -1:1
    @test _convshift(4) == -1:2
    @test _convshift(5) == -2:2
end

@testset "matvec and vecvec products " begin
    W = randn(3, 4)
    Wt = Matrix(transpose(W))
    xs = sprand(4, 10, 0.5)
    x = Matrix(xs)

    o = zeros(3, 10)
    foreach(i -> Mill._addmatvec!(o, i, W, x, i), 1:10)
    @test o ≈ W*x
    fill!(o, 0)
    foreach(i -> Mill._addmatvec!(o, i, W, xs, i), 1:10)
    @test o ≈ W*x

    o = zeros(3, 1)
    foreach(i -> Mill._addmatvec!(o, 1, W, x, i), 1:10)
    @test o ≈ sum(W*x, dims = 2)
    fill!(o, 0)
    foreach(i -> Mill._addmatvec!(o, 1, W, xs, i), 1:10)
    @test o ≈ sum(W*x, dims = 2)

    o = zeros(3, 10)
    foreach(i -> Mill._addmattvec!(o, i, Wt, x, i), 1:10)
    @test o ≈ W*x

    o = zeros(3, 1)
    foreach(i -> Mill._addmattvec!(o, 1, Wt, x, i), 1:10)
    @test o ≈ sum(W*x, dims = 2)

    xs = sprand(10, 1, 0.5)
    r, s = randn(10,1), Matrix(xs)
    o = zeros(10, 10)
    Mill._addvecvect!(o, r, 1, s, 1)
    @test o ≈ r * transpose(s)
    fill!(o, 0)
    Mill._addvecvect!(o, r, 1, xs, 1)
    @test o ≈ r * transpose(s)
end

@testset "forward convolution & gradient" begin
    x = [1 10  100  1000  10000]
    y = 2 .* x
    z = 4 .* x
    Δ = ones(1, 5)
    for bags in [AlignedBags([1:2,3:5]), ScatteredBags([[1,2],[3,4,5]])]
        @test convsum(bags, x) == x
        @test convsum(bags, x, y) == [21  10  2100  21000  10000]
        @test convsum(bags, x, y, z) == [42  21  4200  42100  21000]
        @test @gradtest (x, y, z) -> convsum(bags, x, y, z)
    end
end

@testset "the convolution" begin
    xs = sprand(3, 15, 0.5)
    x = Matrix(xs)
    filters = randn(4, 3, 3)
    fs = [filters[:,:,i] for i in 1:3]
    for bags in [AlignedBags([1:1, 2:3, 4:6, 7:15]), ScatteredBags(collect.([1:1, 2:3, 4:6, 7:15]))]
        @test bagconv(x, bags, fs...) ≈ legacy_bagconv(x, bags, filters)
        @test bagconv(x, bags, fs...) ≈ bagconv(xs, bags, fs...)
        @test @gradtest fs -> bagconv(x, bags, fs...) [x]
        @test @gradtest fs -> bagconv(xs, bags, fs...) [xs]
        @test @gradtest x -> bagconv(x, bags, fs...) [fs]
        @test @gradtest xs -> bagconv(xs, bags, fs...) [fs]
        @test @gradtest (x, fs) -> bagconv(x, bags, fs...)
        @test @gradtest (xs, fs) -> bagconv(xs, bags, fs...)
    end
end

@testset "convolution with ScatteredBags" begin
    xs = sprand(3, 7, 0.5)
    x = Matrix(xs)
    filters = randn(4, 3, 3)
    fs = [filters[:,:,i] for i in 1:3]
    baga = AlignedBags([1:3, 4:7])
    bags = ScatteredBags([[1,2,3],[4,5,6,7]])
    bagsp = ScatteredBags([[1,4,7],[2,3,5,6]])
    xp = x[:, [1,4,5,2,6,7,3]]

    @testset "Test that all versions of convolutions are equal" begin
        @test bagconv(x, baga, fs...) == bagconv(x, bags, fs...)
        @test x[:,bags[1]] == xp[:,bagsp[1]]
        @test x[:,bags[2]] == xp[:,bagsp[2]]
        @test bagconv(x, bags, fs...)[:,bags[1]] == bagconv(xp, bagsp, fs...)[:,bagsp[1]]
        @test bagconv(x, bags, fs...)[:,bags[2]] == bagconv(xp, bagsp, fs...)[:,bagsp[2]]
    end

    @testset "Test that gradient of scattered convolution is correct" begin
        @test @gradtest fs -> bagconv(x, bags, fs...) [x]
        @test @gradtest fs -> bagconv(xp, bags, fs...) [xp]
        @test @gradtest x -> bagconv(x, bags, fs...) [fs]
        @test @gradtest xp -> bagconv(x, bagsp, fs...) [fs]
        @test @gradtest (x, fs) -> bagconv(x, bagsp, fs...)
        @test @gradtest (xp, fs) -> bagconv(xp, bagsp, fs...)
    end
end

@testset "convolution layer" begin
    xs = sprand(3, 15, 0.5)
    x = Matrix(xs)
    for bags in [AlignedBags([1:1, 2:3, 4:6, 7:15]), ScatteredBags(collect.([1:1, 2:3, 4:6, 7:15]))]
        m = BagConv(3, 4, 3, relu)
        @test length(Flux.params(m)) == 3
        @test size(m(x, bags)) == (4, 15)
        @test size(m(xs, bags)) == (4, 15)

        m = BagConv(3, 4, 1)
        @test size(m(x, bags)) == (4, 15)
        @test size(m(xs, bags)) == (4, 15)

        m = BagChain(BagConv(3, 4, 3, relu), BagConv(3, 4, 2))
        @test length(Flux.params(m)) == 5
    end
end
