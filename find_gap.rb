def solution(n)
  binary = n.to_s(2)
  a = (0 ... binary.length).find_all { |i| binary[i,1] == '1' }
  
  return 0 if a.length <2 || (a.length == 2 && (a[1] - a[0]) == 1)
  
  find_gap(a, 0)
  
end

def find_gap(a,index)
  return @gap if (a.length - 1) == index
  g = a[index+1] - a[index]
  
  @gap = @gap || g
    
  @gap = (g > @gap) ? g : @gap
  
  find_gap(a,index+1)
end


puts solution(17)
