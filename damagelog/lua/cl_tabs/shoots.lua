
function Damagelog:DrawShootsTab()

	self.Shoots = vgui.Create("DPanelList")
	self.Shoots:SetSpacing(10)
	
	self.ShootsRefresh = vgui.Create("DButton")
	self.ShootsRefresh:SetText("Refresh")
	self.ShootsRefresh.DoClick = function()
		if not tonumber(self.SelectedRound) then return end
		self.ShootTableTemp = {}
		self.ReceivingST = true
		self.ShootsList:Clear()
		self.ShootsList:AddLine("Loading..")
		net.Start("DL_AskShootLogs")
		net.WriteUInt(self.SelectedRound, 8)
		net.SendToServer()
	end
	self.Shoots:AddItem(self.ShootsRefresh)
	
	self.ShootsList = vgui.Create("DListView")
	self.ShootsList:SetHeight(575)
	self.ShootsList:AddColumn("")
	self.Shoots:AddItem(self.ShootsList)
	
	self.Tabs:AddSheet("Shoots", self.Shoots, "icon16/page_white_find.png", false, false)

end

net.Receive("DL_SendShootLogs", function()
	if not Damagelog.ReceivingST then return end
	local tbl = net.ReadTable()
	local finished = net.ReadUInt(1) == 1
	if tbl[1] != "empty" then
		table.insert(Damagelog.ShootTableTemp, tbl)
	end
	if finished and ValidPanel(Damagelog.ShootsList) then
		Damagelog.ShootsList:Clear()
		Damagelog:SetDamageInfosLV(Damagelog.ShootsList, nil, nil, nil, nil, Damagelog.ShootTableTemp)
	end
end)