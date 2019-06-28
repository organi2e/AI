require 'AI/Const'

local Set = require('./AI/USER_AI/Set')
local vector2 = require('./AI/USER_AI/Geometry').vector2

local Command = {}
Command.new = function(class, msg, env, config, reserved)
 local obj = {raw={msg}, clock=GetTick()}
 if not msg or not env then
 elseif msg[1] == NONE_CMD then
 elseif msg[1] == MOVE_CMD then
  local ground = vector2(msg[2], msg[3])
  obj[reserved and "patrol" or "moving"] = true
  obj.ground = ground
  obj.primal = {}
 elseif msg[1] == ATTACK_OBJECT_CMD then
  obj[reserved and "select" or "attack"] = true
  obj.target = msg[2]
  obj.primal = {msg[2] == env:getMasterID(), msg[2] == env:getServantID()}
 elseif msg[1] == ATTACK_AREA_CMD then
  local ground = vector2(msg[2], msg[3])
  obj.attack = true
  obj.ground = ground
 elseif msg[1] == PATROL_CMD then
  local ground = vector2(msg[2], msg[3])
  obj.patrol = true
  obj.ground = ground
 elseif msg[1] == HOLD_CMD then
  obj.keepup = true
 elseif msg[1] == SKILL_OBJECT_CMD then
  obj.arting = true
  obj.level, obj.skill = msg[2], msg[3]
  obj.target = msg[4]
 elseif msg[1] == SKILL_AREA_CMD then
  local ground = vector2(msg[4], msg[5])
  obj.arting = true
  obj.level, obj.skill = msg[2], msg[3]
  obj.ground = ground
 elseif msg[1] == FOLLOW_CMD then -- Custom ordering by Alt + T
  local master = env:getMaster()
  if master and master:isSit() then
   obj.design = true
   obj.ground = master:getPosition()
  else
   obj.revise = true
  end
 end
 return setmetatable(obj, {__index=class, __tostring=class.tostring})
end
Command.tostring = function(self, visit)
 local check = visit or Set:new()
 local index = check:insert(self)
 return string.format('Command<table %d>', self.raw[1])
end

local Order = {}
Order.new = function(class)
 return setmetatable({}, {__index=class, __tostring=class.tostring})
end
Order.store = function(self)
 return self
end
Order.restore = function(self)
 return self
end
Order.observe = function(self, id, env)
 local msg = GetMsg(id)
 local res = GetResMsg(id)
 if not env then
  -- nil
 elseif msg and msg[1] and msg[1] ~= NONE_CMD then
  return Command:new(msg, env, self.config, false)
 elseif res and res[1] and res[1] ~= NONE_CMD then
  return Command:new(res, env, self.config, true)
 end
end
Order.tostring = function(self, visit)
 local check = visit or Set:new()
 local index = check:insert(self)
 return string.format('Order<table %d>', index)
end

return Order