-- 
-- Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

---	This function is run when npc_combat_creature.bonushp is loaded
function onInit()	
	local bIsInCT = (window.getDatabaseNode().getParent().getName() == 'list')
	window.hp.setReadOnly(bIsInCT)
	window.hdhp.setVisible(bIsInCT)
	window.hdhp_label.setVisible(bIsInCT)
	window.bonushp.setVisible(bIsInCT)
	window.bonushp_label.setVisible(bIsInCT)
end
