-- 
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

---	This function is run when npc_combat_creature.bonushp is loaded
function onInit()
	setInitialHpFields()
	
	local nodeNpc = getDatabaseNode().getParent()
	DB.addHandler(DB.getPath(nodeNpc, 'hpfromhd'), 'onUpdate', calculateAbilHp)
	DB.addHandler(DB.getPath(nodeNpc, 'hpabilused'), 'onUpdate', calculateAbilHp)
	DB.addHandler(DB.getPath(nodeNpc, 'strength'), 'onUpdate', calculateAbilHp)
	DB.addHandler(DB.getPath(nodeNpc, 'dexterity'), 'onUpdate', calculateAbilHp)
	DB.addHandler(DB.getPath(nodeNpc, 'constitution'), 'onUpdate', calculateAbilHp)
	DB.addHandler(DB.getPath(nodeNpc, 'intelligence'), 'onUpdate', calculateAbilHp)
	DB.addHandler(DB.getPath(nodeNpc, 'wisdom'), 'onUpdate', calculateAbilHp)
	DB.addHandler(DB.getPath(nodeNpc, 'charisma'), 'onUpdate', calculateAbilHp)
	DB.addHandler(DB.getPath(nodeNpc, 'effects.*.label'), 'onUpdate', calculateAbilHp)
	DB.addHandler(DB.getPath(nodeNpc, 'effects.*.isactive'), 'onUpdate', calculateAbilHp)
	DB.addHandler(DB.getPath(nodeNpc, 'effects'), 'onChildDeleted', calculateAbilHp)
end

function onClose()
	local nodeNpc = getDatabaseNode().getParent()
	DB.removeHandler(DB.getPath(nodeNpc, 'hpfromhd'), 'onUpdate', calculateAbilHp)
	DB.removeHandler(DB.getPath(nodeNpc, 'hpabilused'), 'onUpdate', calculateAbilHp)
	DB.removeHandler(DB.getPath(nodeNpc, 'strength'), 'onUpdate', calculateAbilHp)
	DB.removeHandler(DB.getPath(nodeNpc, 'dexterity'), 'onUpdate', calculateAbilHp)
	DB.removeHandler(DB.getPath(nodeNpc, 'constitution'), 'onUpdate', calculateAbilHp)
	DB.removeHandler(DB.getPath(nodeNpc, 'intelligence'), 'onUpdate', calculateAbilHp)
	DB.removeHandler(DB.getPath(nodeNpc, 'wisdom'), 'onUpdate', calculateAbilHp)
	DB.removeHandler(DB.getPath(nodeNpc, 'charisma'), 'onUpdate', calculateAbilHp)
	DB.removeHandler(DB.getPath(nodeNpc, 'effects.*.label'), 'onUpdate', calculateAbilHp)
	DB.removeHandler(DB.getPath(nodeNpc, 'effects.*.isactive'), 'onUpdate', calculateAbilHp)
	DB.removeHandler(DB.getPath(nodeNpc, 'effects'), 'onChildDeleted', calculateAbilHp)
end

function setInitialHpFields()
	local nHdHp = window.hdhp.getValue()
	if nHdHp == 0 then
		local nBonusHp = 0
		local sHd = window.hd.getValue()
		local nHpTotal = window.hp.getValue()

		local sType = window.type.getValue()
		if string.find(sType, 'undead', 1) then
			DB.setValue(getDatabaseNode().getParent(), 'hpabilused', 'string', 'charisma')
		end

		local nHdCountEndPos = string.find(sHd, 'd', 1)
		local sHdCount = string.sub(sHd, 1, nHdCountEndPos - 1)
	
		local nHdBonusChar = string.match(sHd, '%p', 1)
		if nHdBonusChar then
			local nHdBonusStartPos = string.find(sHd, nHdBonusChar, 1) + 1
			local nHdBonusEndPos = string.len(sHd)
			
			nBonusHp = tonumber(string.sub(sHd, nHdBonusStartPos, nHdBonusEndPos))
		end
		setValue(nBonusHp)
		window.hdhp.setValue(nHpTotal - nBonusHp)
	end
end


---	Get the bonus to the npc's ability mod from effects in combat tracker
local function getAbilEffects(nodeNpc)
	local rActor = ActorManager.getActor("npc", nodeNpc)

	local sAbilNameUsed = DB.getValue(nodeNpc, 'hpabilused', '')
	local sAbilUsed = 'CON'

	if sAbilNameUsed == 'strength' then sAbilUsed = 'STR' end
	if sAbilNameUsed == 'dexterity' then sAbilUsed = 'DEX' end
	if sAbilNameUsed == '' then sAbilNameUsed = 'constitution' end
	if sAbilNameUsed == 'intelligence' then sAbilUsed = 'INT' end
	if sAbilNameUsed == 'wisdom' then sAbilUsed = 'WIS' end
	if sAbilNameUsed == 'charisma' then sAbilUsed = 'CHA' end
	
	local nAbilFromEffects = EffectManagerLHFC.getEffectsBonus(rActor, sAbilUsed, true)

	return sAbilUsed, sAbilNameUsed, nAbilFromEffects
end

local function calculateTotalHp()
	local sAbilHp = window.bonushp.getValue()
	local sHdHp = window.hdhp.getValue()
	window.hp.setValue(sHdHp + sAbilHp)
end

function calculateAbilHp()
	local sHd = window.hd.getValue()
	local nHdCountEndPos = string.find(sHd, 'd', 1)
	local sHdCount = string.sub(sHd, 1, nHdCountEndPos - 1)
	
	local sAbilUsed, sAbilNameUsed, nAbilFromEffects = getAbilEffects(window.getDatabaseNode())
	
	local nodeAbil = DB.findNode(getDatabaseNode().getParent().getPath() .. '.' .. sAbilNameUsed)
	if nodeAbil.getValue() == 0 then nodeAbil = 10 end
	
	local nAbilScore = nodeAbil.getValue() + nAbilFromEffects
	
	local nAbilScoreBonus = math.floor((nAbilScore - 10) / 2)
	setValue(nAbilScoreBonus * sHdCount)
	
	calculateTotalHp()
end