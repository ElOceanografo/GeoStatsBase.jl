@testset "Partitioning" begin
  setify(lists) = Set(Set.(lists))

  d = RegularGrid(10,10)
  p = partition(d, UniformPartitioner(100))
  @test sprint(show, p) == "100 SpatialPartition"
  @test sprint(show, MIME"text/plain"(), p) == "100 SpatialPartition\n  N° points\n  └─1\n  └─1\n  └─1\n  └─1\n  └─1\n  ⋮\n  └─1\n  └─1\n  └─1\n  └─1\n  └─1"

  @testset "UniformPartitioner" begin
    grid = RegularGrid(3,3)

    Random.seed!(123)
    p = partition(grid, UniformPartitioner(3, false))
    @test setify(subsets(p)) == setify([[1,2,3], [4,5,6], [7,8,9]])
    p = partition(grid, UniformPartitioner(3))
    @test setify(subsets(p)) == setify([[8,6,9], [4,1,7], [2,3,5]])

    grid = RegularGrid(2,3)
    p = partition(grid, UniformPartitioner(3, false))
    @test setify(subsets(p)) == setify([[1,2], [3,4], [5,6]])
  end

  @testset "DirectionPartitioner" begin
    grid = RegularGrid(3,3)

    # basic checks on small regular grid data
    p = partition(grid, DirectionPartitioner((1.,0.)))
    @test setify(subsets(p)) == setify([[1,2,3], [4,5,6], [7,8,9]])

    p = partition(grid, DirectionPartitioner((0.,1.)))
    @test setify(subsets(p)) == setify([[1,4,7], [2,5,8], [3,6,9]])

    p = partition(grid, DirectionPartitioner((1.,1.)))
    @test setify(subsets(p)) == setify([[1,5,9], [2,6], [3], [4,8], [7]])

    p = partition(grid, DirectionPartitioner((1.,-1.)))
    @test setify(subsets(p)) == setify([[1], [2,4], [3,5,7], [6,8], [9]])

    # opposite directions produce same partition
    dir1 = (rand(), rand()); dir2 = .-dir1
    p1 = partition(grid, DirectionPartitioner(dir1))
    p2 = partition(grid, DirectionPartitioner(dir2))
    @test setify(subsets(p1)) == setify(subsets(p2))

    # partition of arbitrarily large regular grid always
    # returns the "lines" and "columns" of the grid
    for n in [10,100,200]
      grid = RegularGrid(n,n)

      p = partition(grid, DirectionPartitioner((1.,0.)))
      @test setify(subsets(p)) == setify([collect((i-1)*n+1:i*n) for i in 1:n])
      ns = [nelms(d) for d in p]
      @test all(ns .== n)

      p = partition(grid, DirectionPartitioner((0.,1.)))
      @test setify(subsets(p)) == setify([collect(i:n:n*n) for i in 1:n])
      ns = [nelms(d) for d in p]
      @test all(ns .== n)
    end
  end

  @testset "FractionPartitioner" begin
    grid = RegularGrid(10,10)

    p = partition(grid, FractionPartitioner(0.5))
    @test nelms(p[1]) == nelms(p[2]) == 50
    @test length(p) == 2

    p = partition(grid, FractionPartitioner(0.7))
    @test nelms(p[1]) == 70
    @test nelms(p[2]) == 30

    p = partition(grid, FractionPartitioner(0.3))
    @test nelms(p[1]) == 30
    @test nelms(p[2]) == 70
  end

  @testset "SLICPartitioner" begin
    𝒮 = georef((z=[ones(10,10) 2ones(10,10); 3ones(10,10) 4ones(10,10)],))
    p = partition(𝒮, SLICPartitioner(4, 1.0))
    @test length(p) == 4
    @test all(nelms.(p) .== 100)
    @test mean(coordinates(p[1]), dims=2) == [ 4.5, 4.5][:,:]
    @test mean(coordinates(p[2]), dims=2) == [14.5, 4.5][:,:]
    @test mean(coordinates(p[3]), dims=2) == [ 4.5,14.5][:,:]
    @test mean(coordinates(p[4]), dims=2) == [14.5,14.5][:,:]

    𝒮 = georef((z=[√(i^2+j^2) for i in 1:100, j in 1:100],))
    p = partition(𝒮, SLICPartitioner(50, 1.0))
    @test length(p) == 49

    if visualtests
      @plottest plot(p) joinpath(datadir,"slic.png") !istravis
    end
  end

  @testset "BlockPartitioner" begin
    grid = RegularGrid(10,10)

    p = partition(grid, BlockPartitioner(5.,5.))
    @test length(p) == 4
    @test all(nelms.(p) .== 25)

    p = partition(grid, BlockPartitioner(5.,2.))
    @test length(p) == 12
    @test Set(nelms.(p)) == Set([5,10])
  end

  @testset "BisectPointPartitioner" begin
    grid = RegularGrid(10,10)

    p = partition(grid, BisectPointPartitioner((0.,1.), (5.,5.1)))
    @test nelms(p[1]) == 60
    @test nelms(p[2]) == 40

    # all points in X₁ are below those in X₂
    X₁ = coordinates(p[1])
    X₂ = coordinates(p[2])
    M₁ = maximum(X₁, dims=2)
    m₂ = minimum(X₂, dims=2)
    @test all(X₁[2,j] < m₂[2] for j in 1:size(X₁,2))
    @test all(X₂[2,j] > M₁[2] for j in 1:size(X₂,2))

    # flipping normal direction is equivalent to swapping subsets
    p₁ = partition(grid, BisectPointPartitioner(( 1.,0.), (5.1,5.)))
    p₂ = partition(grid, BisectPointPartitioner((-1.,0.), (5.1,5.)))
    @test nelms(p₁[1]) == nelms(p₂[2]) == 60
    @test nelms(p₁[2]) == nelms(p₂[1]) == 40
  end

  @testset "BisectFractionPartitioner" begin
    grid = RegularGrid(10,10)

    p = partition(grid, BisectFractionPartitioner((1.,0.), 0.2))
    @test nelms(p[1]) == 20
    @test nelms(p[2]) == 80

    # all points in X₁ are to the left of X₂
    X₁ = coordinates(p[1])
    X₂ = coordinates(p[2])
    M₁ = maximum(X₁, dims=2)
    m₂ = minimum(X₂, dims=2)
    @test all(X₁[1,j] < m₂[1] for j in 1:size(X₁,2))
    @test all(X₂[1,j] > M₁[1] for j in 1:size(X₂,2))

    # flipping normal direction is equivalent to swapping subsets
    p₁ = partition(grid, BisectFractionPartitioner(( 1.,0.), 0.2))
    p₂ = partition(grid, BisectFractionPartitioner((-1.,0.), 0.8))
    @test nelms(p₁[1]) == nelms(p₂[2]) == 20
    @test nelms(p₁[2]) == nelms(p₂[1]) == 80
  end

  @testset "BallPartitioner" begin
    pset = PointSet([
      0 1 1 0 0.2
      0 0 1 1 0.2
    ])

    # 3 balls with 1 point, and 1 ball with 2 points
    p = partition(pset, BallPartitioner(0.5))
    n = nelms.(p)
    @test length(p) == 4
    @test count(i->i==1, n) == 3
    @test count(i->i==2, n) == 1
    @test setify(subsets(p)) == setify([[1,5],[2],[3],[4]])

    # 5 balls with 1 point each
    p = partition(pset, BallPartitioner(0.2))
    @test length(p) == 5
    @test all(nelms.(p) .== 1)
    @test setify(subsets(p)) == setify([[1],[2],[3],[4],[5]])
  end

  @testset "PlanePartitioner" begin
    grid = RegularGrid(3,3)
    p = partition(grid, PlanePartitioner((0.,1.)))
    @test setify(subsets(p)) == setify([[1,2,3],[4,5,6],[7,8,9]])

    grid = RegularGrid(4,4)
    p = partition(grid, PlanePartitioner((0.,1.)))
    @test setify(subsets(p)) == setify([1:4,5:8,9:12,13:16])
  end

  @testset "VariablePartitioner" begin
    z = vec([1 1 1; 2 2 2; 3 3 3])
    sdata = georef(DataFrame(z=z), RegularGrid(3,3))
    p = partition(sdata, VariablePartitioner(:z))
    @test setify(subsets(p)) == setify([[1,4,7],[2,5,8],[3,6,9]])

    # partition with missing values
    z = vec([missing 1 1; 2 missing 2; 3 3 missing])
    sdata = georef(DataFrame(z=z), RegularGrid(3,3))
    p = partition(sdata, VariablePartitioner(:z))
    @test setify(subsets(p)) == setify([[4,7],[2,8],[3,6],[1,5,9]])
  end

  @testset "PredicatePartitioner" begin
    grid = RegularGrid(3,3)

    # partition even from odd locations
    pred(i,j) = iseven(i+j)
    p = partition(grid, PredicatePartitioner(pred))
    @test setify(subsets(p)) == setify([1:2:9,2:2:8])
  end

  @testset "SpatialPredicatePartitioner" begin
    g = RegularGrid(10,10)

    # check if there are 100 partitions, each one having only 1 point
    sp = SpatialPredicatePartitioner((x,y) -> norm(x-y) < 1.0)
    s = subsets(partition(g, sp))
    @test length(s) == 100
    for d in partition(g, sp)
      @test nelms(d) == 1
    end
    # defining a predicate to check if points x and y belong to the square [0.,5.]x[0.,5.]
    pred(x, y) = all([0.,0.] .<= x .<=[5.,5.]) && all([0.,0.] .<= y .<= [5.,5.])
    sp = SpatialPredicatePartitioner(pred)
    p = partition(g, sp)
    s = subsets(p)
    n = nelms.(p)

    # There will be 65 partitions:
    # 1 partition with 36 points (inside square [0.,5.]x[0.,5.])
    # 64 partitions with only 1 point inside each of them
    @test length(s) == 65
    @test maximum(length.(s)) == 36
    @test count(i->i==1, n) == 64
    @test count(i->i==36, n) == 1
  end

  @testset "ProductPartitioner" begin
    g = RegularGrid(100,100)
    bm = BlockPartitioner(10.,10.)
    bn = BlockPartitioner(5.,5.)

    # Bm x Bn = Bn with m > n
    s1 = subsets(partition(g, bm*bn))
    s2 = subsets(partition(g, bn))
    @test setify(s1) == setify(s2)

    # pXp=p (for deterministic p)
    for p in [BlockPartitioner(10.,10.),
              BisectFractionPartitioner((0.1,0.1))]
      s1 = subsets(partition(g, p*p))
      s2 = subsets(partition(g, p))
      @test setify(s1) == setify(s2)
    end
  end

  @testset "HierarchicalPartitioner" begin
    g = RegularGrid(100,100)
    bm = BlockPartitioner(10.,10.)
    bn = BlockPartitioner(5.,5.)

    # Bn -> Bm = Bm with m > n
    s1 = subsets(partition(g, bm → bn))
    s2 = subsets(partition(g, bn))
    @test setify(s1) == setify(s2)
  end

  @testset "Mixed Tests" begin
    g = RegularGrid(100,100)
    bm = BlockPartitioner(10.,10.)
    bn = BlockPartitioner(5.,5.)

    # Bm*Bn = Bm->Bn
    s1 = subsets(partition(g, bm * bn))
    s2 = subsets(partition(g, bm → bn))
    @test setify(s1) == setify(s2)
  end
end
