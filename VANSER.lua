local STRATEGY_STABLE = 1 -- 追従 + カプリス
local STRATEGY_UNIQUE = 2 -- サモンのみ + 追従 + カプリス (仮)
local STRATEGY_FOLLOW = 3 -- 詠唱反応 + 通常支援 + 追従 + カプリス
local STRATEGY_DEFEND = 4 -- 詠唱反応 + 通常支援 + 脅威索敵 + 追従 + カプリス
local STRATEGY_ACTIVE = 5 -- 詠唱反応 + 通常支援 + 脅威索敵 + 積極攻撃 + 追従 + カプリス
local STRATEGY_CHANGE = {
 [STRATEGY_STABLE]=STRATEGY_UNIQUE,
 [STRATEGY_UNIQUE]=STRATEGY_FOLLOW,
 [STRATEGY_FOLLOW]=STRATEGY_DEFEND,
 [STRATEGY_DEFEND]=STRATEGY_ACTIVE,
 [STRATEGY_ACTIVE]=STRATEGY_STABLE
}

local STATE_IDLING = 256
local STATE_MOVING = 257
local STATE_ARTING = 258
local STATE_ATTACK = 259
local STATE_PATROL = 260
local STATE_RELIEF = 261
local STATE_SERIES = 300
local STATE_DESIGN = 320

local COOLS = {} -- スキル固有クールタイム COOLS[スキルID][スキルレベル] = ミリ秒
local DELAY = {} -- 使用者スキルディレイ DELAY[スキルID][スキルレベル] = ミリ秒
local COSTP = {}

local SKILL_MIRAGE_ID = 8013 -- i.e. Caprice
COOLS[SKILL_MIRAGE_ID] = {1200, 1400, 1600, 1800, 2000} -- ? http://rrenewal-ro.daa.jp/skill_ra_magician.html
DELAY[SKILL_MIRAGE_ID] = {0, 0, 0, 0, 0} -- ?

local SKILL_REMEDY_ID = 8014 -- i.e. Chaotic venediction
COOLS[SKILL_REMEDY_ID] = {3200, 3200, 3200, 3200, 3200} -- ? http://rrenewal-ro.daa.jp/skill_ra_acolyt.html#Heal
DELAY[SKILL_REMEDY_ID] = {0, 0, 0, 0, 0} -- ?

local SKILL_SUMMON_ID = 8018 -- i.e. Summon legion
COOLS[SKILL_SUMMON_ID] = {2000, 2000, 2000, 2000, 2000} -- http://www.ragfun.net/alchemist/index.php?%A5%DB%A5%E0%A5%F3%A5%AF%A5%EB%A5%B9S%2FHomunType%2FSERA#q3e8d478
DELAY[SKILL_SUMMON_ID] = {0, 0, 0, 0, 0} -- ?

local SKILL_NEEDLE_ID = 8019 -- i.e. Needle of paralyse
COOLS[SKILL_NEEDLE_ID] = {0, 4000, 8000, 12000, 16000} -- http://www.ragfun.net/alchemist/index.php?%A5%DB%A5%E0%A5%F3%A5%AF%A5%EB%A5%B9S%2FHomunType%2FSERA#hc8d6eb8
DELAY[SKILL_NEEDLE_ID] = {0, 0, 0, 0, 0} -- ?

local SKILL_POISON_ID = 8020 -- i.e. Poison mist
COOLS[SKILL_POISON_ID] = {2000, 2000, 2000, 2000, 2000} -- http://www.ragfun.net/alchemist/index.php?%A5%DB%A5%E0%A5%F3%A5%AF%A5%EB%A5%B9S%2FHomunType%2FSERA#g36b6e16
DELAY[SKILL_POISON_ID] = {0, 0, 0, 0, 0} -- ?

local SKILL_RELIEF_ID = 8021 -- i.e. Pain killer
COOLS[SKILL_RELIEF_ID] = {25000, 30000, 30000, 60000, 60000} -- http://www.ragfun.net/alchemist/index.php?%A5%DB%A5%E0%A5%F3%A5%AF%A5%EB%A5%B9S%2FHomunType%2FSERA#h8df5b10
DELAY[SKILL_RELIEF_ID] = {0, 0, 0, 0, 0} -- ?

local DISTANCE_TO_FOLLOW_MIN = 2
local DISTANCE_TO_FOLLOW_MAX = 8
local DISTANCE_TO_SUPPORTING = 11
local DISTANCE_TO_STANDALONE = 13

local MOVING_CHANCE = 5
local ARTING_CHANCE = 5
local AROUND_RATING = 0.95 -- 主人の周辺を移動する確率

local JAMMER_TO_CASTER = {{5, SKILL_NEEDLE_ID}, {1, SKILL_MIRAGE_ID}} -- 優先度: ニードルオブパラライズLV5 > カプリスLV1
local ARTING_ON_ATTACK = {{5, SKILL_MIRAGE_ID}, {1, SKILL_NEEDLE_ID}} -- 優先度: カプリスLV5 > ニードルオブパラライズLV1

local STORAGES = './AI/USER_AI/Store/VANSER.lua' -- 
local Store = require('./AI/USER_AI/Store') -- テーブルのファイル書き出し・読み込み
local Stack = require('./AI/USER_AI/Stack') -- 割り込み時など中断された状態の復元用スタック
local Set = require('./AI/USER_AI/Set')
local vector2 = require('./AI/USER_AI/Geometry').vector2

local Agent = {}
Agent.new = function(class)
 local obj = {}
 obj.stack = Stack:new()
 obj.state = STATE_IDLING
 obj.cools = {}
 obj.cache = {}
 obj.catch = nil
 obj.delay = 0
 obj.strategy = STRATEGY_STABLE
 return setmetatable(obj, {__index=class, __tostring=class.tostring})
end

Agent.getServant = function(self, env)
 return env:getServant()
end

Agent.getCatchup = function(self, env)
 local catch = self.catch
 local actor = catch and env:getActorByID(catch)
 if actor and not actor:isDead() then
  return actor
 else
  self.catch = nil
  return env:getMaster()
 end
end

Agent.store = function(self)
 return Store:save({
  strategy=self.strategy
 }, STORAGES) and self
end

Agent.restore = function(self)
 local store = Store:load(STORAGES)
 if store then
  self.strategy = store.strategy or self.strategy
  return self, true
 else
  return self, false
 end
end

Agent.appendState = function(self, state, input)
 self.stack:enque({state, input})
 return state, input
end

Agent.resetState = function(self, state, input)
 self.stack = Stack:new()
 self.catch = nil
 return self:setState(state, input)
end

Agent.pushState = function(self, state, input)
 self.stack:push({self.state, self.input})
 return self:setState(state, input) 
end

Agent.setState = function(self, state, input)
 self.state, self.input, self.retry = state, input, nil
 return state, input
end

Agent.popState = function(self)
 local value = self.stack:pop()
 return value and self:setState(unpack(value))
end

Agent.getRetryCount = function(self)
 self.retry = ( self.retry or 0 ) + 1
 return self.retry
end

Agent.getSkillCD = function(self, level, skill)
 return COOLS and COOLS[skill] and COOLS[skill][level], DELAY and DELAY[skill] and DELAY[skill][level]
end

Agent.mayUseSkill = function(self, skill, env)
 local clock = env:getClock()
 return ( not self.delay or self.delay < clock ) and ( not self.cools[skill] or self.cools[skill] < clock ) and clock -- to return clock value
end

Agent.tryUseSkillTarget = function(self, level, skill, target, env)
 local servant = self:getServant(env)
 local clock = self:mayUseSkill(skill, env)
 local cools, delay = self:getSkillCD(level, skill)
 if clock and cools and delay then
  servant:useSkillTarget(level, skill, target)
  self.cools[skill] = clock + cools
  self.delay = clock + delay
  return self
 end
end

--
Agent.tryUseSkillGround = function(self, level, skill, ground, env)
 local servant = self:getServant(env)
 local clock = self:mayUseSkill(skill, env)
 local cools, delay = self:getSkillCD(level, skill)
 if clock and cools and delay then
  servant:useSkillGround(level, skill, ground)
  self.cools[skill] = clock + cools
  self.delay = clock + delay
  return self
 end
end

--
Agent.trySurveyCancel = function(self, env)
 local distance = env:getPeerDistance(math.huge) -- L∞ norm
 return distance and DISTANCE_TO_STANDALONE < distance and self:popState()
end

-- 
Agent.trySurveyMaster = function(self, env)
 local master = self:getCatchup(env)
 local target = master:isAttack() and env:getTargetOf(master)
 local distance = target and target:isMonster() and not target:isDead() and target:getDistanceToTarget(master)
 return distance and distance < DISTANCE_TO_SUPPORTING and self:pushState(STATE_ATTACK, target:getID()) 
end

--
Agent.tryMasterThreat = function(self, env)
 local servant = self:getServant(env)
 local master = self:getCatchup(env)
 local target = master:getID()
 local threat, distance = env:getBeast():getMinimumElement(function(actor)
  return actor:getTargetID() == target and not actor:isDead() and not actor:mayFriendship() and actor:getDistanceToTarget(servant)
 end)
 return threat and distance and distance < DISTANCE_TO_SUPPORTING and self:pushState(STATE_ATTACK, threat:getID())
end

Agent.trySurveyThreat = function(self, env)
 local servant = self:getServant(env)
 local target = servant:getID()
 local threat, distance = env:getBeast():getMinimumElement(function(actor)
  return actor:getTargetID() == target and not actor:isDead() and not actor:mayFriendship() and actor:getDistanceToTarget(servant)
 end)
 return threat and distance and distance < DISTANCE_TO_SUPPORTING and self:pushState(STATE_ATTACK, threat:getID())
end

Agent.tryMasterCaster = function(self, env)
 local servant = self:getServant(env)
 local master = self:getCatchup(env)
 local target = master:getID()
 local caster, distance = env:getBeast():getMinimumElement(function(actor)
  return actor:getTargetID() == target and actor:isCast() and not actor:mayFriendship() and actor:getDistanceToTarget(servant)
 end)
 if caster and distance and distance < DISTANCE_TO_SUPPORTING then
  for index, value in ipairs(JAMMER_TO_CASTER) do
   local level, skill = unpack(value)
   return self:mayUseSkill(skill, env) and self:pushState(STATE_ARTING, {level, skill, caster:getID(), nil})
  end
 end
 return threat and distance and distance < DISTANCE_TO_SUPPORTING and self:pushState(STATE_ATTACK, threat:getID())
end

--
Agent.trySurveyCaster = function(self, env)
 local servant = self:getServant(env)
 local target = servant:getID()
 local caster, distance = env:getBeast():getMinimumElement(function(actor)
  return actor:getTargetID() == target and actor:isCast() and not actor:mayFriendship() and actor:getDistanceToTarget(servant)
 end)
 if caster and distance and distance < DISTANCE_TO_SUPPORTING then
  for index, value in ipairs(JAMMER_TO_CASTER) do
   local level, skill = unpack(value)   
   return self:mayUseSkill(skill, env) and self:pushState(STATE_ARTING, {level, skill, caster:getID(), nil})
  end
 end
end

--
Agent.trySurveyBeasts = function(self, env)
 local servant = self:getServant(env)
 local master = self:getCatchup(env)
 local sID = servant:getID()
 local mID = master:getID()
 local target = env:getBeast():getMinimumElement(function(actor)
  local cover = not actor:isDead() and env:getTargetOf(actor)
  local exist = cover and not cover:isDead() and not cover:isMonster()
  return not actor:mayFriendship() and not exist and not env:getOther():any(function(other)
   return other:getTargetID() == actorID
  end) and servant:getDistanceToTarget(actor)
 end)
 local distance = target and target:getDistanceToTarget(master, math.huge)
 return distance and distance < DISTANCE_TO_SUPPORTING and self:pushState(STATE_ATTACK, target:getID())
end

Agent.trySurveySummon = function(self, env)
 local servant = self:getServant(env)
 local master = self:getCatchup(env)
 local sID = servant:getID()
 local mID = master:getID()
 local threat, distance = env:getBeast():getMinimumElement(function(actor)
  local tID = not actor:isDead() and not actor:mayFriendship() and actor:getTargetID()
  return ( tID == sID or tID == mID ) and actor:getDistanceToTarget(servant)
 end)
 if threat and distance and distance < DISTANCE_TO_SUPPORTING then
  local legion = env:getLegion()
  if legion:isEmpty() then
   local level, skill = 5, SKILL_SUMMON_ID
   return self:mayUseSkill(skill, env) and self:pushState(STATE_ARTING, {level, skill, threat:getID(), nil})   
  elseif legion:filter(function(actor) local enemy = env:getTargetOf(actor) return enemy and not enemy:isDead() end):isEmpty() then
   local range = servant:getAttackRange()
   if range < distance then
    return self:getRetryCount() < MOVING_CHANCE and servant:stepToTarget(threat)
   else
    return servant:attackTarget(threat) and servant:stepToTarget(threat)
   end
  end
 end
end

Agent.trySurveyRelief = function(self, env, target)
 local servant = self:getServant(env)
 local level, skill = 1, SKILL_RELIEF_ID
 local range = servant:getSkillAttackRange(skill)
 local object = env:getActorByID(target)
 local distance = object and not object:isDead() and servant:getDistanceToTarget(object)
 if not distance then
  -- nil
 elseif range < distance then
  return servant:stepToTarget(object)
 elseif self:mayUseSkill(skill, env) then
  return not self:tryUseSkillTarget(level, skill, object, env)
 end
end

Agent.tryCuringFellow = function(self, env)
 local servant = self:getServant(env)
 local master = self:getCatchup(env)
 local shp = servant:getHP()
 local ssp = servant:getSP()
 local mhp = master:getHP()
 local msp = master:getSP()
 local shpr = shp and shp.ratio
 local sspr = ssp and ssp.ratio
 local mhpr = mhp and mhp.ratio
 local mspr = msp and msp.ratio
 local skill = SKILL_REMEDY_ID
 local range = servant:getSkillAttackRange(skill)
 local peace = env:getBeast():all(function(actor)
  local distance = servant:getDistanceToTarget(actor)
  return ( not distance or range < distance ) or actor:isDead() or actor:mayFriendship()
 end)
 if not peace or not self:mayUseSkill(skill, env) or not shpr or not sspr then
  -- nil
 elseif mhpr and mhpr < sspr and shpr < sspr then
  return self:pushState(STATE_ARTING, {5, skill, servant:getID(), nil})
 elseif mhpr and mhpr < sspr then
  return self:pushState(STATE_ARTING, {3, skill, servant:getID(), nil})
 elseif shpr < sspr then
  return self:pushState(STATE_ARTING, {4, skill, servant:getID(), nil})
 end
end

Agent.tryAroundMaster = function(self, env)
 local servant = self:getServant(env)
 local master = self:getCatchup(env)
 if master and master:isSit() and AROUND_RATING < math.random() then
  local target = master:getID()
  local series = coroutine.create(function(env)
   for v = 1, 16 do
    local object = env:getActorByID(target)
    local ground = object:getPosition()
    local around = vector2(math.random(-1, 1), math.random(-1, 1))
    env = coroutine.yield(STATE_MOVING, ground + around)
   end
  end)
  return self:pushState(STATE_SERIES, series)
 end
end

Agent.tryFollowMaster = function(self, env)
 local servant = self:getServant(env)
 local master = self:getCatchup(env)
 local distance = servant:getDistanceToTarget(master)
 if not distance then
  -- nil
 elseif distance > DISTANCE_TO_FOLLOW_MAX then
  return servant:moveToMaster()
 elseif distance > DISTANCE_TO_FOLLOW_MIN then
  return servant:stepToTarget(master)
 end
end

Agent.tryFollowTarget = function(self, env, target)
 local servant = self:getServant(env)
 local object = env:getActorByID(target)
 local distance = object and not object:isDead() and servant:getDistanceToTarget(object)
 if not distance then
  -- nil
 elseif distance > DISTANCE_TO_FOLLOW_MIN then
  return servant:stepToTarget(object)
 end
end

Agent.tryMovingGround = function(self, env, ground)
 local servant = self:getServant(env)
 local range = 0
 local distance = servant:getDistanceToGround(ground, math.huge) -- L∞ norm
 if not distance then
  -- nil
 elseif range < distance then
  return self:getRetryCount() < MOVING_CHANCE and servant:moveToGround(ground)
 end
end

Agent.tryArtingTarget = function(self, env, level, skill, target)
 local servant = self:getServant(env)
 local range = servant:getSkillAttackRange(skill)
 local object = env:getActorByID(target)
 local distance = object and not object:isDead() and servant:getDistanceToTarget(object)
 if not distance then
  -- nil
 elseif range < distance then
  return self:getRetryCount() < MOVING_CHANCE and servant:stepToTarget(object)
 elseif self:mayUseSkill(skill, env) then
  return not self:tryUseSkillTarget(level, skill, object, env)
 end
end

Agent.tryArtingGround = function(self, env, level, skill, ground)
 local servant = self:getServant(env)
 local range = servant:getSkillAttackRange(skill)
 local distance = servant:getDistanceToGround(ground)
 if not distance then
  -- nil
 elseif range < distance then
  return self:getRetryCount() < MOVING_CHANCE and servant:stepToGround(ground)
 elseif self:mayUseSkill(skill, env) then
  return not self:tryUseSkillGround(level, skill, ground, env)
 end
end

Agent.tryAttackArting = function(self, env, target)
 local servant = self:getServant(env)
 local master = self:getCatchup(env)
 local shp = servant:getHP()
 local ssp = servant:getSP()
 local mhp = master:getHP()
 local msp = master:getSP()
 local shpr = shp and shp.ratio
 local sspr = ssp and ssp.ratio
 local mhpr = mhp and mhp.ratio
 local mspr = msp and msp.ratio
 local range = DISTANCE_TO_SUPPORTING
 local actor = env:getActorByID(target)
 local distance = actor and not actor:isDead() and servant:getDistanceToTarget(actor)
 if not distance or not shpr or not sspr then
  -- nil
 elseif distance <= range and shpr * ( mhpr or shpr ) <= sspr then
  for index, value in ipairs(ARTING_ON_ATTACK) do
   local level, skill = unpack(value)
   if level and skill and self:mayUseSkill(skill, env) then
    return self:pushState(STATE_ARTING, {level, skill, target, nil})
   end
  end
 end
end

--
Agent.tryAttackTarget = function(self, env, target)
 local servant = env:getServant()
 local actor = env:getActorByID(target)
 local range = servant:getAttackRange()
 local distance = actor and not actor:isDead() and servant:getDistanceToTarget(actor)
 if not distance then
  -- nil
 elseif range < distance then
  return self:getRetryCount() < MOVING_CHANCE and servant:stepToTarget(actor)
 else
  return servant:attackTarget(actor) and servant:stepToTarget(actor)
 end
end

--
Agent.onIdlingState = function(self, env)
 if not self.strategy then
  -- nil
 elseif self.strategy == STRATEGY_STABLE then --　遊戯 or 追従 or カプリス 
  return self:tryAroundMaster(env) or self:tryFollowMaster(env) or self:tryCuringFellow(env)
 elseif self.strategy == STRATEGY_UNIQUE then -- 召喚 or 追従 or カプリス
  return self:trySurveySummon(env) or self:tryFollowMaster(env) or self:tryCuringFellow(env)
 elseif self.strategy == STRATEGY_FOLLOW then -- 詠唱反応(master) or 詠唱反応(servant) or 支援(master) or 追従 or カプリス
  return self:tryMasterCaster(env) or self:trySurveyCaster(env) or self:trySurveyMaster(env) or self:tryFollowMaster(env) or self:tryCuringFellow(env)
 elseif self.strategy == STRATEGY_DEFEND then -- 詠唱反応(master) or 詠唱反応(servant) or 支援(master) or 迎撃(master) or 迎撃(servant) or 追従 or カプリス
  return self:tryMasterCaster(env) or self:trySurveyCaster(env) or self:trySurveyMaster(env) or self:tryMasterThreat(env) or self:trySurveyThreat(env) or self:tryFollowMaster(env) or self:tryCuringFellow(env)
 elseif self.strategy == STRATEGY_ACTIVE then -- 詠唱反応(master) or 詠唱反応(servant) or 支援(master) or 迎撃(master) or 迎撃(servant) or 迎撃 or 追従 or カプリス
  return self:tryMasterCaster(env) or self:trySurveyCaster(env) or self:trySurveyMaster(env) or self:tryMasterThreat(env) or self:trySurveyThreat(env) or self:trySurveyBeasts(env) or self:tryFollowMaster(env) or self:tryCuringFellow(env)
 end
end

--
Agent.onPatrolState = function(self, env)
 local ground = self.input
 if not ground then
  -- nil
 elseif self.strategy == STRATEGY_STABLE then -- 中断 or 待機 or カプリス or 継続
  return self:trySurveyCancel(env) or self:tryMovingGround(env, ground) or self:tryCuringFellow(env) or true
 elseif self.strategy == STRATEGY_UNIQUE then -- 中断 or 召喚 or 待機 or カプリス or 継続
  return self:trySurveyCancel(env) or self:trySurveySummon(env) or self:tryMovingGround(env, ground) or self:tryCuringFellow(env) or true
 elseif self.strategy == STRATEGY_FOLLOW then -- 中断 or 詠唱反応(servant) or 詠唱反応(master) or 待機 or カプリス or 継続
  return self:trySurveyCancel(env) or self:trySurveyCaster(env) or self:tryMasterCaster(env) or self:tryMovingGround(env, ground) or self:tryCuringFellow(env) or true
 elseif self.strategy == STRATEGY_DEFEND then -- 中断 or 詠唱反応(servant) or 詠唱反応(master) or 迎撃(servant) or 迎撃(master) or 待機 or カプリス or 継続
  return self:trySurveyCancel(env) or self:trySurveyCaster(env) or self:tryMasterCaster(env) or self:trySurveyThreat(env) or self:tryMasterThreat(env) or self:tryMovingGround(env, ground) or self:tryCuringFellow(env) or true
 elseif self.strategy == STRATEGY_ACTIVE then -- 中断 or 詠唱反応(servant) or 詠唱反応(master) or 迎撃(servant) or 迎撃(master) or 索敵 or 待機 or カプリス or 継続
  return self:trySurveyCancel(env) or self:trySurveyCaster(env) or self:tryMasterCaster(env) or self:trySurveyThreat(env) or self:tryMasterThreat(env) or self:trySurveyBeasts(env) or self:tryMovingGround(env, ground) or self:tryCuringFellow(env) or true
 end
end

Agent.onReliefState = function(self, env)
 local target = self.input
 if not target then
  -- nil
 elseif self.strategy == STRATEGY_STABLE then -- 中断 or スキル or カプリス or 継続
  return self:trySurveyCancel(env) or self:trySurveyRelief(env, target) or self:tryCuringFellow(env) or true
 elseif self.strategy == STRATEGY_UNIQUE then -- 中断 or スキル or 召喚 or カプリス or 継続
  return self:trySurveyCancel(env) or self:trySurveyRelief(env, target) or self:trySurveySummon(env) or self:tryCuringFellow(env) or true
 elseif self.strategy == STRATEGY_FOLLOW then -- 中断 or スキル or 詠唱反応(servant) or 詠唱反応(master) or カプリス or 継続
  return self:trySurveyCancel(env) or self:trySurveyRelief(env, target) or self:trySurveyCaster(env) or self:tryMasterCaster(env) or self:tryCuringFellow(env) or true
 elseif self.strategy == STRATEGY_DEFEND then -- 中断 or スキル or 詠唱反応(servant) or 詠唱反応(master) or 迎撃(servant) or カプリス or 継続
  return self:trySurveyCancel(env) or self:trySurveyRelief(env, target) or self:trySurveyCaster(env) or self:tryMasterCaster(env) or self:trySurveyThreat(env) or self:tryCuringFellow(env) or true
 elseif self.strategy == STRATEGY_ACTIVE then -- 中断 or スキル or 詠唱反応(servant) or 詠唱反応(master) or 迎撃(servant) or 索敵 or カプリス or 継続
  return self:trySurveyCancel(env) or self:trySurveyRelief(env, target) or self:trySurveyCaster(env) or self:tryMasterCaster(env) or self:trySurveyThreat(env) or self:trySurveyBeasts(env) or self:tryCuringFellow(env) or true
 end
end

Agent.onAttackState = function(self, env)
 local target = self.input
 if not target then
  -- nil
 elseif self.strategy == STRATEGY_STABLE then -- 中断 or スキル or 攻撃
  return self:trySurveyCancel(env) or self:tryAttackArting(env, target) or self:tryAttackTarget(env, target)
 elseif self.strategy == STRATEGY_UNIQUE then -- 中断 or 召喚 or 攻撃
  return self:trySurveyCancel(env) or self:trySurveySummon(env) or self:tryAttackTarget(env, target)
 elseif self.strategy == STRATEGY_FOLLOW then -- 中断 or 詠唱反応(master) or 詠唱反応(servant) or 支援(master) or スキル or 攻撃
  return self:trySurveyCancel(env) or self:tryMasterCaster(env) or self:trySurveyCaster(env) or self:trySurveyMaster(env) or self:tryAttackArting(env, target) or self:tryAttackTarget(env, target)
 elseif self.strategy == STRATEGY_DEFEND then -- 中断 or 詠唱反応(master) or 詠唱反応(servant) or スキル or 攻撃
  return self:trySurveyCancel(env) or self:tryMasterCaster(env) or self:trySurveyCaster(env) or self:tryAttackArting(env, target) or self:tryAttackTarget(env, target)
 elseif self.strategy == STRATEGY_ACTIVE then -- 中断 or 詠唱反応(master) or 詠唱反応(servant) or スキル or 攻撃
  return self:trySurveyCancel(env) or self:tryMasterCaster(env) or self:trySurveyCaster(env) or self:tryAttackArting(env, target) or self:tryAttackTarget(env, target)
 end
end

Agent.onArtingState = function(self, env)
 local level, skill, target, ground = unpack(self.input)
 if not level or not skill then
  -- nil
 elseif target then
  return self:trySurveyCancel(env) or self:tryArtingTarget(env, level, skill, target)
 elseif ground then
  return self:trySurveyCancel(env) or self:tryArtingGround(env, level, skill, ground)
 end
end

Agent.onMovingState = function(self, env)
 local ground = self.input
 if ground then
  return self:trySurveyCancel(env) or self:tryMovingGround(env, ground)
 end
end

Agent.onSeriesState = function(self, env)
 local series = self.input
 if series then
  local yield, state, input = coroutine.resume(series, env)
  return yield and state and self:pushState(state, input) and self:routine(env)
 end
end

Agent.onDesignState = function(self, env)
 local master = env:getMaster()
 return master and master:isSit() and self:onMovingState(env)
end

Agent.onRecallState = function(self, env)
 return self:popState()
end

Agent.onDefectState = function(self, env)
 return self:onIdlingState(env)
end

Agent.isIdlingState = function(self) return self.state == STATE_IDLING end
Agent.isMovingState = function(self) return self.state == STATE_MOVING end
Agent.isArtingState = function(self) return self.state == STATE_ARTING end
Agent.isAttackState = function(self) return self.state == STATE_ATTACK end
Agent.isPatrolState = function(self) return self.state == STATE_PATROL end
Agent.isReliefState = function(self) return self.state == STATE_RELIEF end
Agent.isSeriesState = function(self) return self.state == STATE_SERIES end
Agent.isDesignState = function(self) return self.state == STATE_DESIGN end

Agent.executeArtingCommand = function(self, cmd)
 local level = cmd.level
 local skill = cmd.skill
 local target = cmd.target
 local ground = cmd.ground
 if not level or not skill then
  -- nil
 elseif target then
  return self:pushState(STATE_ARTING, {level, skill, target, nil})
 elseif ground then
  return self:pushState(STATE_ARTING, {level, skill, nil, ground})
 end
end

Agent.executeAttackCommand = function(self, cmd)
 local target = cmd.target
 local append = cmd.append
 return append and self:appendState(STATE_ATTACK, target) or self:pushState(STATE_ATTACK, target)
end

Agent.executeAttendCommand = function(self, cmd)
 -- nil
end

Agent.executeAssistCommand = function(self, cmd)
 local target = cmd.target
 return target and self:resetState(STATE_RELIEF, target)
end

Agent.executeDesignCommand = function(self, cmd)
 local ground = cmd.ground
 local indicate = function(ground, strategy)
  if not strategy or not ground then
   -- nil
  elseif strategy == STRATEGY_STABLE then -- 往復
   return self:resetState(STATE_DESIGN, ground + vector2( 1, 0))
     and self:appendState(STATE_DESIGN, ground + vector2(-1, 0))
     and self:appendState(STATE_DESIGN, ground + vector2( 1, 0))
     and self:appendState(STATE_DESIGN, ground + vector2(-1, 0))
     and self:appendState(STATE_DESIGN, ground + vector2( 1, 0))
  elseif strategy == STRATEGY_UNIQUE then -- S
   return self:resetState(STATE_DESIGN, ground + vector2( 1, 1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1, 1))
     and self:appendState(STATE_DESIGN, ground + vector2( 1,-1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1,-1))
     and self:appendState(STATE_DESIGN, ground + vector2( 1, 1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1, 1))
     and self:appendState(STATE_DESIGN, ground + vector2( 1,-1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1,-1))
     and self:appendState(STATE_DESIGN, ground + vector2( 1, 1))
  elseif strategy == STRATEGY_FOLLOW then -- Z
   return self:resetState(STATE_DESIGN, ground + vector2(-1, 1))
     and self:appendState(STATE_DESIGN, ground + vector2( 1, 1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1,-1))
     and self:appendState(STATE_DESIGN, ground + vector2( 1,-1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1, 1))
     and self:appendState(STATE_DESIGN, ground + vector2( 1, 1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1,-1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1, 1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1, 1))
  elseif strategy == STRATEGY_DEFEND then -- 時計回り
   return self:resetState(STATE_DESIGN, ground + vector2( 0, 1))
	 and self:appendState(STATE_DESIGN, ground + vector2( 1, 0))
	 and self:appendState(STATE_DESIGN, ground + vector2( 0,-1))
	 and self:appendState(STATE_DESIGN, ground + vector2(-1, 0))
     and self:appendState(STATE_DESIGN, ground + vector2( 0, 1))
	 and self:appendState(STATE_DESIGN, ground + vector2( 1, 0))
	 and self:appendState(STATE_DESIGN, ground + vector2( 0,-1))
	 and self:appendState(STATE_DESIGN, ground + vector2(-1, 0))
     and self:appendState(STATE_DESIGN, ground + vector2( 0, 1))
  elseif strategy == STRATEGY_ACTIVE then -- 反時計回り
   return self:resetState(STATE_DESIGN, ground + vector2( 0, 1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1, 0))
     and self:appendState(STATE_DESIGN, ground + vector2( 0,-1))
     and self:appendState(STATE_DESIGN, ground + vector2( 1, 0))
     and self:appendState(STATE_DESIGN, ground + vector2( 0, 1))
     and self:appendState(STATE_DESIGN, ground + vector2(-1, 0))
     and self:appendState(STATE_DESIGN, ground + vector2( 0,-1))
     and self:appendState(STATE_DESIGN, ground + vector2( 1, 0))
     and self:appendState(STATE_DESIGN, ground + vector2( 0, 1))
  end
 end
 if not ground then
  -- nil
 elseif self:isDesignState() then 
  self.strategy = self.strategy and STRATEGY_CHANGE[self.strategy] or STRATEGY_STABLE  
  return self:store() and indicate(ground, self.strategy) 
 elseif self:isIdlingState() then
  return                  indicate(ground, self.strategy)
 else
  return self:resetState(STATE_IDLING, nil)
 end
end

Agent.executeMovingCommand = function(self, cmd)
 local ground = cmd.ground
 if ground then
  return self:isMovingState() and self:setState(STATE_MOVING, ground) or self:pushState(STATE_MOVING, ground)
 end
end

Agent.executePatrolCommand = function(self, cmd)
 local ground = cmd.ground
 return ground and self:resetState(STATE_PATROL, ground)
end

Agent.executeReviseCommand = function(self, cmd)
 local forced = cmd.forced
 return forced and self:resetState(STATE_IDLING, nil) or self:popState()
end

Agent.executeSelectCommand = function(self, cmd)
 self.catch = cmd.target
 return self.catch
end

Agent.execute = function(self, cmd)
 if not cmd then
  -- nil
 elseif cmd.arting and self:executeArtingCommand(cmd) then -- TraceAI("Execute arting command")
 elseif cmd.assist and self:executeAssistCommand(cmd) then -- TraceAI("Execute assist command")
 elseif cmd.attack and self:executeAttackCommand(cmd) then -- TraceAI("Execute attack command")
 elseif cmd.attend and self:executeAttendCommand(cmd) then -- TraceAI("Execute attend command")
 elseif cmd.design and self:executeDesignCommand(cmd) then -- TraceAI("Execute design command")
 elseif cmd.moving and self:executeMovingCommand(cmd) then -- TraceAI("Execute moving command")
 elseif cmd.patrol and self:executePatrolCommand(cmd) then -- TraceAI("Execute patrol command")
 elseif cmd.revise and self:executeReviseCommand(cmd) then -- TraceAI("Execute revise command")
 elseif cmd.select and self:executeSelectCommand(cmd) then -- TraceAI("Execute select command")
 else
  -- TraceAI(tostring(self))
  -- TraceAI(tostring(cmd))
 end
end

Agent.routine = function(self, env)
 if not env then
  -- nil
 elseif self:isIdlingState() and self:onIdlingState(env) then -- TraceAI("is idling state")
 elseif self:isMovingState() and self:onMovingState(env) then -- TraceAI("is moving state")
 elseif self:isArtingState() and self:onArtingState(env) then -- TraceAI("is arting state")
 elseif self:isAttackState() and self:onAttackState(env) then -- TraceAI("is attack state")
 elseif self:isPatrolState() and self:onPatrolState(env) then -- TraceAI("is patrol state")
 elseif self:isReliefState() and self:onReliefState(env) then -- TraceAI('is relief state')
 elseif self:isSeriesState() and self:onSeriesState(env) then -- TraceAI("is series state")
 elseif self:isDesignState() and self:onDesignState(env) then -- TraceAI("is design state")
 elseif                          self:onRecallState(env) then -- TraceAI('is recall state') -- やることがなければスタックを戻して割り込み前の状態に戻す
 elseif                          self:onDefectState(env) then -- TraceAI('is defect state') -- 状態が戻せないならdefect
 else
  -- TraceAI(tostring(self))
  -- TraceAI(tostring(env))
 end
 
 if true then
  local legion = env:getLegion()
  if not legion:isEmpty() then
   local servant = self:getServant(env)
   local master = self:getCatchup(env)
   local sID = servant:getID()
   local mID = master:getID()
   local target = master:isAttack() and env:getTargetOf(master)
   local threat = env:getBeast():getMinimumElement(function(actor)
    local tID = not actor:mayFriendship() and not actor:isDead() and actor:getTargetID()
	return ( tID == mID or tID == sID ) and actor:getDistanceToTarget(master)
   end)
   if not target or not threat then
    legion:forEach(function(actor)
	 actor:stepToTarget(master)
	end)
   elseif target then
    legion:forEach(function(actor)
	 actor:attackTarget(target)
	 actor:stepToTarget(target)
	end)
   elseif threat then
    legion:forEach(function(actor)
	 actor:attackTarget(target)
	 actor:stepToTarget(target)
	end)    
   end
  end
 end 
end

Agent.tostring = function(self, visit)
 local check = visit or Set:new()
 local index = check:insert(self)
 return string.format('VANSER<table %d> {\r\n\tstrategy=%d, \r\n\tstate=%d, \r\n\tstack=%s\t\n}', index, self.strategy, self.state, self.stack:tostring(check))
end

return Agent