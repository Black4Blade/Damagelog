
surface.CreateFont("DL_RDM_Manager", {
	font = "DermaLarge",
	size = 20,
	bold = false
})

function Damagelog:DrawRDMManager(x,y)
	if LocalPlayer():IsAdmin() and Damagelog.RDM_Manager_Enabled == 1 then
		local Manager = vgui.Create("DLRDMManag");
		self.Tabs:AddSheet("RDM Manager", Manager, "icon16/magnifier.png", false, false)	
	end
end
