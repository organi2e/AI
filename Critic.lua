require('./AI/Const')

local Actor = require('./AI/USER_AI/Actor')
local Array = require('./AI/USER_AI/Array')
local Set = require('./AI/USER_AI/Set')

-- Env class: Begin
local Env = {}
Env.new = function(class, servant, config)
 local obj = {}
 obj.clock = GetTick()
 obj.cache = {}
 do
  local master = GetV(V_OWNER, servant) 
  
  -- Allocation
  local keyed = {}
  local whole = Array:new()
  local other = Array:new()
  local amity = Array:new()
  local beast = Array:new()
  for index, value in ipairs(GetActors(servant)) do
   if value and 0 < value then
    local actor = Actor:new(value)
	keyed[value] = actor
	whole:push(actor)
	if not actor:getID() then
	 -- nil
	elseif actor:getID() == master then
	 obj.master = actor
	elseif actor:getID() == servant then
	 obj.servant = actor 
	elseif actor:isMonster() then
	 beast:push(actor)
	elseif false then
	 amity:push(actor)
	else
	 other:push(actor)
	end
   end
  end
  obj.servant = obj.servant or Actor.new(servant)
  obj.master = obj.master or Actor.new(master)
  obj.keyed = keyed
  obj.whole = whole
  obj.beast = beast
  obj.amity = amity
  obj.other = other
 end
 return setmetatable(obj, {__index=class})
end
Env.getClock = function(self)
 return self.clock
end
Env.getWhole = function(self)
 return self.whole
end
Env.getActorByID = function(self, id)
 return self.keyed[id]
end
Env.getActorsByPosition = function(self, ground)
 return self.whole:filter(function(actor)
  return actor:getPosition() == ground
 end)
end
Env.getMaster = function(self)
 return self.master
end
Env.getMasterID = function(self)
 return self:getMaster():getID()
end
Env.getServant = function(self)
 return self.servant
end
Env.getServantID = function(self)
 return self:getServant():getID()
end
Env.getPeerDistance = function(self, p)
 local servant = self:getServant()
 local master = self:getMaster()
 return servant and master and servant:getDistanceToTarget(master, p)
end
Env.getBeast = function(self)
 return self.beast
end
Env.getAmity = function(self)
 return self.amity
end
Env.getOther = function(self)
 return self.other
end
Env.getTargetOf = function(self, hero)
 return self:getActorByID(hero:getTargetID())
end
Env.getThreatOf = function(self, hero)
 local id = hero:getID()
 return self:getWhole():filter(function(actor)
  return actor:getTargetID() == id
 end)
end
Env.getLegion = function(self)
 local masterID = self:getMasterID()
 return self:getBeast():filter(function(actor)
  return actor:getMasterID() == masterID and actor:isLegion()
 end)
end
Env.getPlants = function(self)
 local masterID = self:getMasterID()
 return self:getBeast():filter(function(actor)
  return actor:getMasterID() == masterID and actor:isPlants()
 end)
end
Env.getSphere = function(self)
 local masterID = self:getMasterID()
 return self:getBeast():filter(function(actor)
  return actor:getMasterID() == masterID and actor:isSphere()
 end)
end
Env.tostring = function(self, visit)
 local check = visit or Set:new()
 local index = check:insert(self)
 return string.format('Env<table %d> {clock=%d, whole=%d}', index, self.clock, #whole)
end
-- Env class: End

-- Critic class: Begin
local Critic = {}
Critic.new = function(class)
 return setmetatable({}, {__index=class, __tostring=class.tostring})
end
Critic.store = function(self)
 return self
end
Critic.restore = function(self)
 return self
end
Critic.observe = function(self, servant)
 return Env:new(servant, self.config)
end
Critic.execute = function(self, cmd, env)
 
end
Critic.tostring = function(self, visit)
 local check = visit or Set:new()
 local index = check:insert(self)
 return string.format('Critic<table %d> {}', index)
end
-- Critic class: End
return Critic