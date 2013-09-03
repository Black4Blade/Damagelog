
include("config/config.lua")
include("cl_tabs/damagetab.lua")
include("cl_tabs/settings.lua")
include("cl_tabs/shoots.lua")
include("cl_tabs/old_logs.lua")
include("cl_tabs/rdm_manager.lua")
include("cl_tabs/about.lua")
include("sh_privileges.lua")
include("sh_sync_entity.lua")
include("cl_filters.lua")
include("cl_colors.lua")
include("sh_events.lua")
include("cl_listview.lua")
include("sh_weapontable.lua")
include("not_my_code/orderedPairs.lua")
include("not_my_code/von.lua")
include("rdm_manager/cl_rdm_manager.lua")

function Damagelog:OpenMenu()
	local x,y = 665, 680
	self.Menu = vgui.Create("DFrame")
	self.Menu:SetSize(x, y)
	self.Menu:SetTitle("Damagelog menu") -- do me a favor. don't put your community's name here
	self.Menu:SetDraggable(false)
	self.Menu:MakePopup()
	self.Menu:Center()	
	self.Tabs = vgui.Create("DPropertySheet", self.Menu)
	self.Tabs:SetPos(5, 30)
	self.Tabs:SetSize(x-10, y-35)	
	self:DrawDamageTab(x, y)
	self:DrawShootsTab(x, y)
	self:DrawOldLogs(x, y)
	self:DrawRDMManager(x, y)
	self:DrawSettings(x, y)
	self:About(x,y)
end

function Damagelog:CheckPrivileges()
	if not LocalPlayer():CanUseDamagelog() then
		chat.AddText(Color(255, 62, 62, 255), "You are currently not allowed to open the Damagelog Menu.")
		return false
	end
	return true
end

concommand.Add("damagelog", function()
	local allowed = Damagelog:CheckPrivileges()
	if allowed then
		Damagelog:OpenMenu()
	end
end)

Damagelog.pressed_key = false
function Damagelog:Think()
	if input.IsKeyDown(KEY_F8) and not self.pressed_key then
		self.pressed_key = true
		if self:CheckPrivileges() then
			if not ValidPanel(self.Menu) then
				self:OpenMenu()
			else
				self.Menu:Close()
			end
		end
	elseif self.pressed_key and not input.IsKeyDown(KEY_F8) then
		self.pressed_key = false
	end
end

hook.Add("Think", "Think_Damagelog", function()
	Damagelog:Think()
end)

function Damagelog:StrRole(role)
	if role == ROLE_TRAITOR then return "traitor"
	elseif role == ROLE_DETECTIVE then return "detective"
	else return "innocent" end
end

net.Receive("InformPlayersDL", function()
	local nick = net.ReadString()
	local round = net.ReadUInt(8)
	if nick and round then
		chat.AddText(Color(255,62,62), nick, color_white, " is alive and viewing the logs of the round ", Color(98,176,255), tostring(round), color_white, ".")
	end
end)

net.Receive("DL_Ded", function()
	
	if net.ReadUInt(1,1) == 1 and Damagelog.RDM_Manager_Window == 1 then
	
		local death_reason = net.ReadString()
	
		local frame = vgui.Create("DFrame")
		frame:SetSize(250, 120)
		frame:SetTitle("You died, "..LocalPlayer():Nick())
		frame:ShowCloseButton(false)
		frame:Center()
	
		local reason = vgui.Create("DLabel", frame)
		reason:SetText("You were killed by "..death_reason)
		reason:SizeToContents()
		reason:SetPos(5, 32)
	
		local report = vgui.Create("DButton", frame)
		report:SetPos(5, 55)
		report:SetSize(240, 25)
		report:SetText("Open the report menu")
		report.DoClick = function()
			RunConsoleCommand("DLRDM_Repport")
			frame:Close()
		end
	
		local report_icon = vgui.Create("DImageButton", report)
		report_icon:SetMaterial("materials/icon16/report_go.png")
		report_icon:SetPos(1, 5)
		report_icon:SizeToContents()
	
		local close = vgui.Create("DButton", frame)
		close:SetPos(5, 85)
		close:SetSize(240, 25)	
		close:SetText("He didn't random kill me")
		close.DoClick = function()
			frame:Close()
		end
	
		local close_icon = vgui.Create("DImageButton", close)
		close_icon:SetPos(2, 5)
		close_icon:SetMaterial("materials/icon16/cross.png")
		close_icon:SizeToContents()
	
		frame:MakePopup()
		
	end
	
	chat.AddText(Color(255,62,62), "[RDM Manager] ", Color(255,255, 255), "You died! Open the report menu using the ", Color(98,176,255), Damagelog.RDM_Manager_Command, Color(255, 255, 255), " command.")
	
end)
