local PANEL = {};

local state = {
	"Waiting",
	"In progress",
	"Finished"
};

function PANEL:Init()
	Damagelog.rdmReporter.panel = self;
	
	self:SetSpacing(10);
	
	self.ManagerSelection = vgui.Create("ColoredBox");
	self.ManagerSelection:SetHeight(170);
	self.ManagerSelection:SetColor(Color(90, 90, 95));
	
	self.reportList = vgui.Create("DListView", self.ManagerSelection);
	self.reportList:AddColumn("Victim's name"):SetFixedWidth(137);
	self.reportList:AddColumn("Reported player's name"):SetFixedWidth(137);
	self.reportList:AddColumn("Round"):SetFixedWidth(54);
	self.reportList:AddColumn("Time"):SetFixedWidth(72);
	self.reportList:AddColumn("State"):SetFixedWidth(100);
	self.reportList.OnRowSelected = function (panel, lineID, line)
		Damagelog.rdmReporter.histPanel = line.index;
		self:Update();
	end;
				
	self.removeReport = vgui.Create("DButton", self.ManagerSelection);
	self.removeReport:SetText("Take action");
	self.removeReport:SetDisabled(true);
	self.removeReport.DoClick = function()
		local report = Damagelog.rdmReporter:GetSelectedReport();
		local menuPanel = DermaMenu()
		menuPanel:AddOption("Force the reported player to respond", function()
			if IsValid(report.attacker) then
				print(report.attacker, report.attacker:EntIndex())
				RunConsoleCommand("DLRDM_ForceVictim", tostring(report.attacker:EntIndex()))
			else
				Derma_Message("The reported player isn't valid! (disconnected?)", "Error", "OK")
			end
		end):SetImage("icon16/clock_red.png")
		if ulx then
			if ulx.slaynr then
				local slaynr_pnl = vgui.Create("DMenuOption", menuPanel)
				local slaynr = DermaMenu(menuPanel)
				slaynr:SetVisible(false)
				slaynr_pnl:SetSubMenu(slaynr)
				slaynr_pnl:SetText("Slay next round")
				slaynr_pnl:SetImage("icon16/lightning_go.png")
				menuPanel:AddPanel(slaynr_pnl)
				slaynr:AddOption("Victim", function()
					if IsValid(report.ply) then
						RunConsoleCommand("ulx", "slaynr", report.ply:Nick())
					else
						Derma_Message("The victim isn't valid! (disconnected?)", "Error", "OK")
					end
				end):SetImage("icon16/user.png")
				slaynr:AddOption("Reported player", function()
					if IsValid(report.attacker) then
						RunConsoleCommand("ulx", "slaynr", report.attacker:Nick())
					else
						Derma_Message("The reported isn't valid! (disconnected?)", "Error", "OK")
					end
				end):SetImage("icon16/user_delete.png")
			end
			menuPanel:AddOption("Slay the reported player", function()
				if IsValid(report.attacker) then
					RunConsoleCommand("ulx", "slay", report.attacker:Nick())
				else
					Derma_Message("The reported isn't valid! (disconnected?)", "Error", "OK")
				end
			end):SetImage("icon16/lightning.png")
		end
		menuPanel:Open()
	end
			
	
	self.setState = vgui.Create("DButton", self.ManagerSelection);
	self.setState:SetText("Set state..");
	self.setState:SetDisabled(true);
	self.setState.DoClick = function()
		local menuPanel = DermaMenu();
		local report = Damagelog.rdmReporter:GetSelectedReport();

		for k, v in pairs(state) do
			menuPanel:AddOption(v, function()
				RunConsoleCommand("DLRDM_State", tostring(report.index), tostring(k));
			end);
		end;

		menuPanel:Open();
	end;
	
	self:AddItem(self.ManagerSelection);
			
	self.VictimInfos = vgui.Create("DPanel");
	self.VictimInfos:SetHeight(160);

	self.VictimInfos.Paint = function(panel, w, h)
		surface.SetDrawColor(Color(0,0,0));
		surface.DrawOutlinedRect(1, 1, w-2, h-2);
		surface.DrawLine(w/2, 1, w/2, h);
		surface.DrawLine(1, 27, w-1, 27);
		surface.SetDrawColor(Color(0, 200, 0));
		surface.DrawRect(2, 2, (w/2)-3, 25);
		surface.SetDrawColor(Color(200, 0, 0));
		surface.DrawRect((w/2)+1, 2, (w/2)-2, 25);
		draw.SimpleText("Victim's message", "DL_RDM_Manager", 90, 5, Color(0,0,0), TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT);
		draw.SimpleText("Reported player's message", "DL_RDM_Manager", 375, 5, Color(0,0,0), TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT);
	end;
		
	self.victim_message = vgui.Create("DTextEntry", self.VictimInfos);
	self.victim_message:SetMultiline(true);
	self.victim_message:SetKeyboardInputEnabled(false);
		
	self.killer_message = vgui.Create("DTextEntry", self.VictimInfos);
	self.killer_message:SetMultiline(true);
	self.killer_message:SetKeyboardInputEnabled(false);
	
	self:AddItem(self.VictimInfos);
	
	self.VictimLogs = vgui.Create("DForm");
	self.VictimLogs:SetName("Logs before the victim's death");
	
	self._VictimLogs = vgui.Create("DListView");
	self._VictimLogs:AddColumn("Time"):SetFixedWidth(40);
	self._VictimLogs:AddColumn("Type"):SetFixedWidth(40);
	self._VictimLogs:AddColumn("Event"):SetFixedWidth(555);
	self._VictimLogs:SetHeight(230);
	self.VictimLogs:AddItem(self._VictimLogs);
	
	self:AddItem(self.VictimLogs);

	self:Update();
end;

function PANEL:Update()
	self.reportList:Clear();

	local report, hist = Damagelog.rdmReporter:GetSelectedReport();
	local reports = Damagelog.rdmReporter:GetAll();

	for i=0, #reports - 1 do
		local v = reports[#reports - i];
		if (v) then
			v.time = v.time or 0;
			v.round = v.round or 0;
			local time = util.SimpleTime(math.max(0, v.time), "%02i:%02i");

			local statename = state[v.state] or v.state
			if IsValid(v.state_ply) then
				statename = statename.." by "..v.state_ply:Nick()
			end
			local line = self.reportList:AddLine(v.plyName, v.attackerName, v.round, time, statename);
			line.PaintOver = function(self)
				if self:IsLineSelected() then return end
				self.Columns[1]:SetTextColor(Color(0, 190, 0))
				self.Columns[2]:SetTextColor(Color(190, 0, 0))
				if statename == "Waiting" then
					self.Columns[5]:SetTextColor(Color(100,100, 0))
				elseif statename == "In progress" then
					self.Columns[5]:SetTextColor(Color(0,0,190))
				elseif statename == "Finished "then
					self.Columns[5]:SetTextColor(Color(0,190, 0))
				end
			end
			line.index = v.index;

			if (hist == v.index) then
				line:SetSelected(true);
			end;
		end;
	end;

	if (report) then
		self.removeReport:SetDisabled(false);
		self.setState:SetDisabled(false);

		self.victim_message:SetText(report.message);
		self.killer_message:SetText(report.attackerMessage);
		
		if report.lastLogs then
			self._VictimLogs:Clear()
			Damagelog:SetListViewTable(self._VictimLogs, report.lastLogs, true)
		end
	end;
end;

function PANEL:PerformLayout()
	self.reportList:SetSize(500, 160);
	self.reportList:SetPos(5, 5);

	self.setState:SetPos(510, 5);
	self.setState:SetSize(125, 25);

	self.removeReport:SetPos(510, 35);
	self.removeReport:SetSize(125, 25);

	self.victim_message:SetPos(1, 27);
	self.victim_message:SetSize(639/2, 132);

	self.killer_message:SetPos(639/2, 27);
	self.killer_message:SetSize(639/2, 132);

	self.VictimLogs.Items[1]:DockPadding(0,5,0,0)

	DPanelList.PerformLayout(self);
end

vgui.Register("DLRDMManag", PANEL, "DPanelList");
