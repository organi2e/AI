local complex = {}
complex.new = function(class, r, i)
 return setmetatable({r, i or 0}, class)
end
complex.__unm = function(x)
 local xr, xi = unpack(x)
 return complex:new(-xr, -xi)
end
complex.__add = function(x, y)
 local xr, xi = unpack(x)
 local yr, yi = unpack(y)
 return complex:new(xr + yr, xi + yi)
end
complex.__sub = function(x, y)
 local xr, xi = unpack(x)
 local yr, yi = unpack(y)
 return complex:new(xr - yr, xi - yi)
end
complex.__mul = function(x, y)
 local xr, xi = unpack(x)
 local yr, yi = unpack(y)
 return complex:new( xr * yr - xi * yi, xi * yr + xr * yi )
end
complex.__div = function(x, y)
 local xr, xi = unpack(x)
 local yr, yi = unpack(y)
 local yp = yr * yr + yi * yi
 return complex:new( ( xr * yr + xi * yi ) / yp, ( xi * yr - xr * yi ) / yp )
end
complex.__eq = function(x, y)
 local xr, xi = unpack(x)
 local yr, yi = unpack(y)
 return xr == yr and xi == yi
end
complex.__ne = function(x, y)
 local xr, xi = unpack(x)
 local yr, yi = unpack(y)
 return xr ~= yr and xi ~= yi
end
complex.__lt = function(x, y)
 local xr, xi = unpack(x)
 local yr, yi = unpack(y)
 return xr < yr and xi < yi
end
complex.__le = function(x, y)
 local xr, xi = unpack(x)
 local yr, yi = unpack(y)
 return xr <= yr and xi <= yi
end
complex.__gt = function(x, y)
 local xr, xi = unpack(x)
 local yr, yi = unpack(y)
 return xr > yr and xi > yi
end
complex.__ge = function(x, y)
 local xr, xi = unpack(x)
 local yr, yi = unpack(y)
 return xr >= yr and xi >= yi
end
complex.__tostring = function(x)
 local r, i = unpack(x)
 if not i then
  return string.format('%g', r)
 elseif r == 0 then
  return string.format('%gi', i)
 elseif i == 0 then
  return string.format('%g', r)
 elseif i < 0 then
  return string.format('%g%gj', r, i)
 else
  return string.format('%g+%gj', r, i)
 end
end
complex.__index = {
 cnj=function(x)
  local r, i = unpack(x)
  return complex:new(r, -i)
 end,
 pow=function(x)
  local r, i = unpack(x)
  return r * r + i * i
 end,
 mag=function(x)
  return math.sqrt(x:pow())
 end,
 arg=function(x)
  local r, i = unpack(x)
  return math.atan2(i, r)
 end,
 log=function(x)
  return complex:new(math.log(x:mag()), x:arg())
 end,
 exp=function(x)
  local r, i = unpack(x)
  local m = math.exp(r)
  return complex:new(m * math.cos(i), m * math.sin(i))
 end,
 cos=function(x)
  local r, i = unpack(x)
  return ( complex:new(-i, r):exp() + complex:new(i, -r):exp() ) / complex:new(2, 0)
 end,
 sin=function(x)
  local r, i = unpack(x)
  return ( complex:new(-i, r):exp() - complex:new(i, -r):exp() ) / complex:new(0, 2)
 end
}

local vector2 = {}
vector2.new = function(class, p, q)
 return setmetatable({p, q or p}, class)
end
vector2.__unm = function(v)
 local v1, v2 = unpack(v)
 return vector2:new(-v1, -v2)
end
vector2.__add = function(x, y)
 local x1, x2 = unpack(x)
 local y1, y2 = unpack(y)
 return vector2:new(x1+y1, x2+y2)
end
vector2.__sub = function(x, y)
 local x1, x2 = unpack(x)
 local y1, y2 = unpack(y)
 return vector2:new(x1-y1, x2-y2)
end
vector2.__mul = function(x, y)
 local x1, x2 = unpack(x)
 local y1, y2 = unpack(y)
 return vector2:new(x1*y1, x2*y2)
end
vector2.__div = function(x, y)
 local x1, x2 = unpack(x)
 local y1, y2 = unpack(y)
 return vector2:new(x1/y1, x2/y2)
end
vector2.__ne = function(x, y)
 local x1, x2 = unpack(x)
 local y1, y2 = unpack(y)
 return x1 ~= y1 and x2 ~= y2
end
vector2.__eq = function(x, y)
 local x1, x2 = unpack(x)
 local y1, y2 = unpack(y)
 return x1 == y1 and x2 == y2
end
vector2.__lt = function(x, y)
 local x1, x2 = unpack(x)
 local y1, y2 = unpack(y)
 return x1 < y1 and x2 < y2
end
vector2.__le = function(x, y)
 local x1, x2 = unpack(x)
 local y1, y2 = unpack(y)
 return x1 <= y1 and x2 <= y2
end
vector2.__gt = function(x, y)
 local x1, x2 = unpack(x)
 local y1, y2 = unpack(y)
 return x1 > y1 and x2 > y2
end
vector2.__ge = function(x, y)
 local x1, x2 = unpack(x)
 local y1, y2 = unpack(y)
 return x1 >= y1 and x2 >= y2
end
vector2.__tostring = function(x)
 local x1, x2 = unpack(x)
 return string.format('vector(%g, %g)', x1, x2)
end
vector2.__index = {
 map=function(x, f)
  local x1, x2 = unpack(x)
  return vector2:new(f(x1), f(x2))
 end,
 all=function(x)
  local x1, x2 = unpack(x)
  return ( x1 and x2 ) and true or false 
 end,
 any=function(x)
  local x1, x2 = unpack(x)
  return ( x1 or x2 ) and true or false
 end,
 len=function(x, p)
  local x1, x2 = unpack(x)
  local d1, d2 = math.abs(x1), math.abs(x2) 
  if not p then
   return vector2:new(d1, d2)
  elseif p == 0 then
   return ( d1 == 0 and 0 or 1 ) + ( d2 == 0 and 0 or 1 )
  elseif p == 1 then
   return d1 + d2
  elseif p == 2 then
   return math.sqrt(d1^2+d2^2)
  elseif p == math.huge then
   return math.max(d1, d2)
  elseif p == -1 then
   return d1 * d2 / ( d1 + d2 )
  elseif p == -math.huge then
   return math.min(d1, d2)
  else
   return math.pow(math.pow(d1, p) + math.pow(d2, p), 1 / p)
  end
 end,
 c2p=function(x)
  local x1, x2 = unpack(x)
  return vector2:new(math.sqrt(x1^2+x2^2), math.atan2(x2, x1))
 end,
 p2c=function(x)
  local x1, x2 = unpack(x)
  return vector2:new(x1*math.cos(x2), x1*math.sin(x2))
 end,
}

local Geometry = {}
Geometry.complex = function(r, i)
 return complex:new(r, i)
end
Geometry.vector2 = function(x, y)
 return vector2:new(x, y)
end
return Geometry