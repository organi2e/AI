local Set = {}
Set.new = function(class)
 return setmetatable({}, {__index=class, __tostring=class.tostring})
end
Set.insert = function(self, value)
 self[value] = self[value] or ( self:count() + 1 )
 return self[value]
end
Set.remove = function(self, value)
 self[value] = nil
end
Set.count = function(self)
 local count = 0
 table.foreach(self, function()
  count = count + 1
 end)
 return count
end
Set.index = function(self, value)
 return self[value]
end
Set.tostring = function(self, visit)
 local check = visit or Set:new()
 local index = check:index(self)
 if index then
  return string.format('<table %d>', index)
 else
  local result = nil
  local index = check:insert(self)
  table.foreach(self, function(index, value)
   if type(index) == type(self) then
	result = ( result and result .. ', ' or '' ) .. ( getmetatable(index).__tostring or tostring ) ( index, check )
   else
    result = ( result and result .. ', ' or '' ) .. tostring(index)
   end
  end)
  return string.format('Set<table %d> {%s}', index, result or '')
 end
end
return Set