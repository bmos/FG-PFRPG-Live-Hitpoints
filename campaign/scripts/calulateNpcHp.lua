-- 
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

---	This function is run when npc_combat_creature.bonushp is loaded
function onInit()
	
	local nodeNpc = getDatabaseNode().getParent()
	local bIsInCT = (getDatabaseNode().getChild('...').getName() == 'list')
	window.hdhp.setVisible(bIsInCT)
	window.hdhp_label.setVisible(bIsInCT)
	window.bonushp.setVisible(bIsInCT)
	window.bonushp_label.setVisible(bIsInCT)
--	window.stat.setVisible(bIsInCT)
--	window.abilused_label.setVisible(bIsInCT)

	if bIsInCT then
		setInitialHpFields()
		
		DB.addHandler(DB.getPath(nodeNpc, 'hpfromhd'), 'onUpdate', setAbilHp)
		DB.addHandler(DB.getPath(nodeNpc, 'hpabilused'), 'onUpdate', setAbilHp)
		DB.addHandler(DB.getPath(nodeNpc, 'strength'), 'onUpdate', setAbilHp)
		DB.addHandler(DB.getPath(nodeNpc, 'dexterity'), 'onUpdate', setAbilHp)
		DB.addHandler(DB.getPath(nodeNpc, 'constitution'), 'onUpdate', setAbilHp)
		DB.addHandler(DB.getPath(nodeNpc, 'intelligence'), 'onUpdate', setAbilHp)
		DB.addHandler(DB.getPath(nodeNpc, 'wisdom'), 'onUpdate', setAbilHp)
		DB.addHandler(DB.getPath(nodeNpc, 'charisma'), 'onUpdate', setAbilHp)
		DB.addHandler(DB.getPath(nodeNpc, 'effects.*.label'), 'onUpdate', setAbilHp)
		DB.addHandler(DB.getPath(nodeNpc, 'effects.*.isactive'), 'onUpdate', setAbilHp)
		DB.addHandler(DB.getPath(nodeNpc, 'effects'), 'onChildDeleted', setAbilHp)
	end
end

function onClose()
	local nodeNpc = getDatabaseNode().getParent()
	local bIsInCT = (getDatabaseNode().getChild('...').getName() == 'list')

	if bIsInCT then
		DB.removeHandler(DB.getPath(nodeNpc, 'hpfromhd'), 'onUpdate', setAbilHp)
		DB.removeHandler(DB.getPath(nodeNpc, 'hpabilused'), 'onUpdate', setAbilHp)
		DB.removeHandler(DB.getPath(nodeNpc, 'strength'), 'onUpdate', setAbilHp)
		DB.removeHandler(DB.getPath(nodeNpc, 'dexterity'), 'onUpdate', setAbilHp)
		DB.removeHandler(DB.getPath(nodeNpc, 'constitution'), 'onUpdate', setAbilHp)
		DB.removeHandler(DB.getPath(nodeNpc, 'intelligence'), 'onUpdate', setAbilHp)
		DB.removeHandler(DB.getPath(nodeNpc, 'wisdom'), 'onUpdate', setAbilHp)
		DB.removeHandler(DB.getPath(nodeNpc, 'charisma'), 'onUpdate', setAbilHp)
		DB.removeHandler(DB.getPath(nodeNpc, 'effects.*.label'), 'onUpdate', setAbilHp)
		DB.removeHandler(DB.getPath(nodeNpc, 'effects.*.isactive'), 'onUpdate', setAbilHp)
		DB.removeHandler(DB.getPath(nodeNpc, 'effects'), 'onChildDeleted', setAbilHp)
	end
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
	local nAbilHp = 0

	for _,v in ipairs(tHd) do
		if string.find(v, 'd', 1) then
			local nHdEndPos = string.find(v, 'd', 1)
			local nHd = tonumber(string.sub(v, 1, nHdEndPos-1))
			nHdCount = nHdCount + nHd
		elseif not string.match(v, '%D', 1) then
			nAbilHp = nAbilHp + v
		end
	end
	
	return nHdCount, nAbilHp
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

local function getFeats(nodeNpc)
	local sFeats = string.lower(window.feats.getValue())
	
	local bToughness = false
	if string.find(sFeats, 'toughness') then bToughness = true end
	
	return bToughness
end

local function calculateAbilHp()
	local nHdCount = processHd()
	
	local sAbilUsed, sAbilNameUsed, nAbilFromEffects = getAbilEffects(window.getDatabaseNode())
	
	local nodeAbil = DB.findNode(getDatabaseNode().getParent().getPath() .. '.' .. sAbilNameUsed)
	local nAbilBase = nodeAbil.getValue()
	if not nAbilBase then nAbilBase = 0 end
	
	local nAbilScore = nAbilBase + nAbilFromEffects
	local nAbilScoreBonus = (nAbilScore - 10) / 2

	local nFeatBonus = 0
	
	local bToughness = getFeats(nodeNpc)
	if bToughness then nFeatBonus = (math.max(nHdCount, 3)) end

	local nMiscBonus = window.bonushpbak.getValue()

	return math.floor((nAbilScoreBonus * nHdCount) + nFeatBonus + nMiscBonus)
end

function setInitialHpFields()
	local nHdHp = window.hdhp.getValue()
	if nHdHp == 0 then
		local sType = window.type.getValue()
		if string.find(sType, 'undead', 1) and DataCommon.isPFRPG() then
			DB.setValue(getDatabaseNode().getParent(), 'hpabilused', 'string', 'charisma')
		end

		local nHdCount, nAbilHp = processHd()
		local nHpTotal = window.hp.getValue()

		setValue(nAbilHp)
		window.hdhp.setValue(nHpTotal - nAbilHp)
		
		local nCalcAbilHp = calculateAbilHp()
		window.bonushpbak.setValue(nAbilHp - nCalcAbilHp)
	end
end

local function calculateTotalHp()
	local nAbilHp = window.bonushp.getValue()
	local nHdHp = window.hdhp.getValue()
	window.hp.setValue(nHdHp + nAbilHp)
end

function setAbilHp()
	local nAbilHp = calculateAbilHp()
	setValue(nAbilHp)

	calculateTotalHp()
end