require('./AI/Const')

local MOTION_STAND		= 0
local MOTION_MOVE		= 1
local MOTION_ATTACK		= 2
local MOTION_DEAD		= 3
local MOTION_DAMAGE 	= 4
local MOTION_PICKUP 	= 5
local MOTION_SIT 		= 6
local MOTION_SKILL 		= 7	
local MOTION_CAST 		= 8
local MOTION_ATTACK2 	= 9
local MOTION_SPIRAL 	= 11
local MOTION_TOSS 		= 12
local MOTION_COUNTER 	= 13
local MOTION_RECITAL 	= 17
local MOTION_UP 		= 19
local MOTION_DOWN 		= 20
local MOTION_SOUL 		= 23
local MOTION_LANDING 	= 25
local MOTION_SLIMPP 	= 28
local MOTION_GUNKATA 	= 38
local MOTION_FULLBUSTE 	= 42

local SUMMON_LEGION = {[2158]=true, [2159]=true, [2160]=true} 
local SUMMON_PLANTS = {[1579]=true, [1589]=true, [1575]=true, [1555]=true, [1590]=true}
local SUMMON_SPHERE = {[1142]=true}

local KINOKO_COLOUR = {[1085]='r', [1084]='k'}
local HERBAL_COLOUR = {[1078]='r', [1081]='y', [1080]='g', [1079]='b', [1082]='w', [1083]='x'}

local VISIBLE_RANGE = 15

local vector2 = require('./AI/USER_AI/Geometry').vector2
local Set = require('./AI/USER_AI/Set')

local Actor = {}
Actor.new = function(class, id)
 return setmetatable({id}, {__index=class, __tostring=class.tostring})
end
Actor.getID = function(self)
 return self[1]
end
Actor.getTargetID = function(self)
 return GetV(V_TARGET, self:getID())
end
Actor.isMonster = function(self)
 return IsMonster(self:getID()) == 1
end
Actor.getType = function(self)
 return GetV(V_TYPE, self:getID())
end
Actor.getSubType = function(self)
 return GetV(V_HOMUNTYPE, self:getID())
end
Actor.isLegion = function(self)
 return self:isMonster() and SUMMON_LEGION[self:getSubType()]
end
Actor.isPlants = function(self)
 return self:isMonster() and SUMMON_PLANTS[self:getSubType()]
end
Actor.isSphere = function(self)
 return self:isMonster() and SUMMON_SPHERE[self:getSubType()]
end
Actor.isKinoko = function(self)
 return self:isMonster() and KINOKO_COLOUR[self:getSubType()]
end
Actor.isHerbal = function(self)
 return self:isMonster() and HERBAL_COLOUR[self:getSubType()]
end
Actor.getMasterID = function(self)
 return GetV(V_OWNER, self:getID())
end
Actor.getPosition = function(self)
 local x, y = GetV(V_POSITION, self:getID())
 return 0 < x and 0 < y and vector2(x, y)
end
Actor.mayFriendship = function(self)
 return ( not self:isMonster() ) or self:isLegion() or self:isPlants()
end
Actor.getAttackRange = function(self)
 return GetV(V_ATTACKRANGE, self:getID())
end
Actor.getSkillAttackRange = function(self, skill)
 return GetV(V_SKILLATTACKRANGE, self:getID(), skill)
end
Actor.getHPSP = function(self, currentID, maximumID)
 local current = GetV(currentID, self:getID())
 local maximum = GetV(maximumID, self:getID())
 return current and maximum and 0 < maximum and {current=current, maximum=maximum, ratio=current/maximum}
end
Actor.getHP = function(self)
 return self:getHPSP(V_HP, V_MAXHP)
end
Actor.getSP = function(self)
 return self:getHPSP(V_SP, V_MAXSP)
end
Actor.getMotion = function(self)
 local result = {}
 local motion = GetV(V_MOTION, self:getID())
 if not motion then
  -- nil
 elseif motion == MOTION_STAND then
  result.isStand = true 
 elseif motion == MOTION_MOVE then
  result.isMove = true
 elseif motion == MOTION_ATTACK or motion == MOTION_ATTACK2 then
  result.isAttack = true
 elseif motion == MOTION_DEAD then
  result.isDead = true
 elseif motion == MOTION_DAMAGE then
  result.isDamange = true
 elseif motion == MOTION_PICKUP then
  result.isPickup = true
 elseif motion == MOTION_SIT then
  result.isSit = true
 elseif motion == MOTION_SKILL then
  result.isSkill = true
 elseif motion == MOTION_CAST then
  result.isCast = true
 end
 return result, motion
end
Actor.isStand = function(self)
 return GetV(V_MOTION, self:getID()) == MOTION_STAND
end
Actor.isMove = function(self)
 return GetV(V_MOTION, self:getID()) == MOTION_MOVE
end
Actor.isAttack = function(self)
 return GetV(V_MOTION, self:getID()) == MOTION_ATTACK or GetV(V_MOTION, self:getID()) == MOTION_ATTACK2
end
Actor.isDead = function(self)
 return GetV(V_MOTION, self:getID()) == MOTION_DEAD
end
Actor.isDamange = function(self)
 return GetV(V_MOTION, self:getID()) == MOTION_DAMAGE
end
Actor.isPickup = function(self)
 return GetV(V_MOTION, self:getID()) == MOTION_PICKUP
end
Actor.isSit = function(self)
 return GetV(V_MOTION, self:getID()) == MOTION_SIT
end
Actor.isSkill = function(self)
 return GetV(V_MOTION, self:getID()) == MOTION_SKILL
end
Actor.isCast = function(self)
 return GetV(V_MOTION, self:getID()) == MOTION_CAST
end
Actor.getDistanceToTarget = function(self, target, p)
 local ground = target and target:getPosition()
 return ground and self:getDistanceToGround(ground, p)
end
Actor.getDistanceToGround = function(self, ground, p)
 local actual = self and self:getPosition()
 return actual and ( ground - actual ):len(p or 2)
end
Actor.moveToMaster = function(self)
 MoveToOwner(self:getID())
 return self
end
Actor.moveToGround = function(self, ground)
 Move(self:getID(), unpack(ground))
 return self
end
Actor.stepToGround = function(self, ground)
 local actual = self and self:getPosition()
 return actual and self:moveToGround(actual + (ground-actual):map(function(x) return math.floor(x/2) end))
end
Actor.moveToTarget = function(self, target)
 local ground = target and target:getPosition()
 return ground and self:moveToGround(ground)
end
Actor.stepToTarget = function(self, target)
 local ground = target and target:getPosition()
 return ground and self:stepToGround(ground)
end
Actor.useSkillTarget = function(self, level, skill, target)
 SkillObject(self:getID(), level, skill, target:getID())
 return self
end
Actor.useSkillGround = function(self, level, skill, ground)
 SkillGround(self:getID(), level, skill, unpack(ground))
 return self
end
Actor.attackTarget = function(self, target)
 Attack(self:getID(), target:getID())
 return self
end
Actor.tostring = function(self, visit)
 local check = visit or Set:new()
 local index = check:insert(self)
 return string.format('Actor<table %d>{%d}', index, self:getID())
end
return Actor