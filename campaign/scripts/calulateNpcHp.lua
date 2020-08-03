-- 
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

---	This function is run when npc_combat_creature.bonushp is loaded
function onInit()
	setInitialHpFields()
	
	local nodeNpc = getDatabaseNode().getParent()
	Debug.chat(nodeNpc.getName())
	window.hdhp.setVisible(nodeNpc.getParent().getName() == 'list')
	window.hdhp_label.setVisible(nodeNpc.getParent().getName() == 'list')
	window.bonushp.setVisible(nodeNpc.getParent().getName() == 'list')
	window.bonushp_label.setVisible(nodeNpc.getParent().getName() == 'list')
	window.stat.setVisible(nodeNpc.getParent().getName() == 'list')
	window.abilused_label.setVisible(nodeNpc.getParent().getName() == 'list')

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

local function processHd()
	local sHd = window.hd.getValue()
	local sHdErrorEnd = string.find(sHd, '%)', 1)
	if sHdErrorEnd then
		sHd = string.sub(sHd, 1, sHdErrorEnd - 1)
		ChatManager.SystemMessage(window.nonid_name.getValue() .. ' has HD data entered incorrectly. Please report this: https://www.fantasygrounds.com/forums/showthread.php?38100-Official-Pathfinder-Modules-Bug-Report-Thread')
	end

	sHd = sHd .. '+'        -- ending comma
	local tHd = {}        -- table to collect fields
	local fieldstart = 1
	repeat
		local nexti = string.find(sHd, '+', fieldstart)
		table.insert(tHd, string.sub(sHd, fieldstart, nexti-1))
		fieldstart = nexti + 1
	until fieldstart > string.len(sHd)

	local nHdCount = 0
	local sAbilHp = 0

	for _,v in ipairs(tHd) do
		if string.find(v, 'd', 1) then
			local nHdEndPos = string.find(v, 'd', 1)
			local nHd = tonumber(string.sub(v, 1, nHdEndPos-1))
			nHdCount = nHdCount + nHd
		elseif not string.match(v, '%D', 1) then
			sAbilHp = sAbilHp + v
		end
	end
	
	return nHdCount, sAbilHp
end

function setInitialHpFields()
	local nHdHp = window.hdhp.getValue()
	if nHdHp == 0 then
		local sType = window.type.getValue()
		if string.find(sType, 'undead', 1) then
			DB.setValue(getDatabaseNode().getParent(), 'hpabilused', 'string', 'charisma')
		end

		local nHdCount, sAbilHp = processHd()
		local nHpTotal = window.hp.getValue()

		setValue(sAbilHp)
		window.hdhp.setValue(nHpTotal - sAbilHp)
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
	local sHdCount = processHd()
	
	local sAbilUsed, sAbilNameUsed, nAbilFromEffects = getAbilEffects(window.getDatabaseNode())
	
	local nodeAbil = DB.findNode(getDatabaseNode().getParent().getPath() .. '.' .. sAbilNameUsed)
	if nodeAbil.getValue() == 0 then nodeAbil = 10 end
	
	local nAbilScore = nodeAbil.getValue() + nAbilFromEffects
	
	local nAbilScoreBonus = (nAbilScore - 10) / 2
	setValue(math.floor(nAbilScoreBonus * sHdCount))
	
	calculateTotalHp()
end