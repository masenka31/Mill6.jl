@testset "creating bags" begin
	k = [2, 2, 2, 1, 1, 3]
	@test all(NestedMill.bag(k) .== [1:3,4:5,6:6])
end


@testset "testing remapping for subsets" begin
  @test all(NestedMill.remapbag([1:1,2:3,4:5],[2,3])[1] .== [1:2,3:4])
  @test all(NestedMill.remapbag([1:1,2:3,4:5],[2,3])[2] .== [2,3,4,5])
  @test all(NestedMill.remapbag([1:2,3:3,4:5],[1,3])[1] .== [1:2,3:4])
  @test all(NestedMill.remapbag([1:2,3:3,4:5],[1,3])[2] .== [1,2,4,5])
  @test all(NestedMill.remapbag([1:2,3:3,4:5],[2,3])[1] .== [1:1,2:3])
  @test all(NestedMill.remapbag([1:2,3:3,4:5],[2,3])[2] .== [3,4,5])

  @test all(NestedMill.remapbag([1:2,0:-1,3:4],[2,3])[1] .== [0:-1,1:2])
  @test all(NestedMill.remapbag([1:2,0:-1,3:4],[2,3])[2] .== [3,4])
end



import NestedMill: Ragged

a = Ragged(rand(3,4),[1:4])
b = Ragged(rand(3,4),[1:2,3:4])
c = Ragged(rand(3,4),[1:1,2:2,3:4])
d = Ragged(rand(3,4),[1:4,0:-1])

@testset "testing Ragged hcat" begin
  @test all(cat(a,b,c).data .== hcat(a.data,b.data,c.data))
  @test all(cat(a,b,c).bags .== [1:4,5:6,7:8,9:9,10:10,11:12])
  @test all(cat(c,a).data .== hcat(c.data,a.data))
  @test all(cat(c,a).bags .== [1:1,2:2,3:4,5:8])
  @test all(cat(a,c).data .== hcat(a.data,c.data))
  @test all(cat(a,c).bags .== [1:4,5:5,6:6,7:8])
  @test all(cat(a,d).data .== hcat(a.data,d.data))
  @test all(cat(a,d).bags .== [1:4,5:8,0:-1])
  @test all(cat(d,a).data .== hcat(d.data,a.data))
  @test all(cat(d,a).bags .== [1:4,0:-1,5:8])
  @test all(cat(d).data .== hcat(d.data))
  @test all(cat(d).bags .== [1:4,0:-1])
end

@testset "testing Ragged hcat" begin
  @test all(a[1].data .== a.data)
  @test all(a[1].bags .== [1:4])
  @test all(b[1:2].data .== b.data)
  @test all(b[1:2].bags .== [1:2,3:4])
  @test all(b[2].data .== b.data[:,3:4])
  @test all(b[2].bags .== [1:2])
  @test all(b[1].data .== b.data[:,1:2])
  @test all(b[1].bags .== [1:2])
  @test all(c[1].data .== c.data[:,1:1])
  @test all(c[1].bags .== [1:1])
  @test all(c[[1,2]].data .== c.data[:,1:2])
  @test all(c[[1,2]].bags .== [1:1,2:2])
  @test all(c[[2,1]].data .== c.data[:,[2,1]])
  @test all(c[[2,1]].bags .== [1:1,2:2])
  @test all(d[[2,1]].data .== d.data)
  @test all(d[[2,1]].bags .== [0:-1,1:4])
  @test all(d[1:2].data .== d.data)
  @test all(d[1:2].bags .== [1:4,0:-1])
  @test all(d[2].data .== d.data[:,0:-1])
  @test all(d[2].bags .== [0:-1])
end



@testset "testing nested ragged array" begin
  a = Ragged(rand(3,10),[1:2,3:3,0:-1,4:5,6:6,7:10])
  b = Ragged(a,[1:2,3:3,4:5,6:6])
  @test all(b[1].data.data .== a.data[:,1:3])
  @test all(b[1].data.bags .== [1:2,3:3])
  @test all(b[1:2].data.data .== a.data[:,1:3])
  @test all(b[1:2].data.bags .== [1:2,3:3,0:-1])
  @test all(b[2:3].data.data .== a.data[:,4:6])
  @test all(b[2:3].data.bags .== [0:-1,1:2,3:3])
end

import NestedMill: lastcat
@testset "testing lastcat" begin
  a = (rand(3,2),rand(3,1),Ragged(randn(3,2)))
  b = (rand(3,2),rand(3,1),Ragged(randn(3,2)))
  @test all(lastcat(a,b)[1] .== hcat(a[1],b[1]))
  @test all(lastcat(a,b)[2] .== hcat(a[2],b[2]))
  @test all(lastcat(a,b)[3].data .== hcat(a[3].data,b[3].data))
end
# @testset "testing nested ragged array" begin
#   @test all(b[1].data.data .== a.data[:,1:3])
#   @test all(b[1].data.bags .== [1:2,3:3])
#   @test all(b[1:2].data.data .== a.data[:,1:3])
#   @test all(b[1:2].data.bags .== [1:2,3:3,0:-1])
#   @test all(b[2:3].data.data .== a.data[:,4:6])
#   @test all(b[2:3].data.bags .== [0:-1,1:2,3:3])
# end

