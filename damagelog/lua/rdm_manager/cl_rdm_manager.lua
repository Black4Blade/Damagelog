include("sh_notify.lua");
include("dermas/cl_infolabel.lua");
include("dermas/cl_respond.lua");
include("dermas/cl_repport.lua");
include("dermas/cl_repportPanel.lua");

Damagelog.rdmReporter = Damagelog.rdmReporter or {};
Damagelog.rdmReporter.stored = Damagelog.rdmReporter.stored or {};
Damagelog.rdmReporter.respond = Damagelog.rdmReporter.respond or {};
Damagelog.rdmReporter.histPanel = Damagelog.rdmReporter.histPanel or 1;

function Damagelog.rdmReporter:GetSelectedReport()
	if (self.stored[self.histPanel]) then
		return self.stored[self.histPanel], self.histPanel;
	end
end;

function Damagelog.rdmReporter:GetAll()
	return self.stored;
end;

hook.Add("OnPlayerChat", "DLRDM_Command", function(ply, text, teamOnly, isDead)
	text = text:lower();

	if (text == "!report") then
		if (ply == LocalPlayer()) then
			if (LocalPlayer():Alive() and GetRoundState() == ROUND_ACTIVE) then
				chat.AddText(Color(255, 62, 62), "You can't report when you are alive!");
			else
				RunConsoleCommand("DLRDM_Repport");
			end;
		end;

		return true;
	end;

	if (text == "!respond") then
		if (ply == LocalPlayer()) then
			RunConsoleCommand("DLRDM_SendRespond");
		end;

		return true;
	end;
end);

net.Receive("RDMAdd", function(len)
	local recue = net.ReadTable();

	if (recue.index) then
		recue.round = recue.round or 0;
		recue.time = recue.time or 0;
		recue.attackerMessage = recue.attackerMessage or "No message yet";

		Damagelog.rdmReporter.stored[recue.index] = recue;
		
		if (ValidPanel(Damagelog.rdmReporter.panel)) then
			Damagelog.rdmReporter.panel:Update();
		end;
	end;
end);

net.Receive("RDMRespond", function(len, ply)
	local liste = net.ReadTable();
	local count = table.Count(liste);

	Damagelog.rdmReporter.respond = liste;
	Damagelog.notify:AddMessage("You have "..count.." awaiting reports!");

	if (ValidPanel(Damagelog.rdmReporter.RespondPanel)) then
		Damagelog.rdmReporter.RespondPanel:Close();
		Damagelog.rdmReporter.RespondPanel:Remove();
	end;
	
	Damagelog.rdmReporter.RespondPanel = vgui.Create("DLRespond");
	Damagelog.rdmReporter.RespondPanel:MakePopup();
end);

net.Receive("DLRDM_Start", function()
	local tbl
	if net.ReadUInt(1) == 1 then
		tbl = net.ReadTable()
	end
	if (ValidPanel(Damagelog.RepportPanel)) then
		Damagelog.RepportPanel:Close();
		Damagelog.RepportPanel:Remove();
	end;
	
	Damagelog.RepportPanel = vgui.Create("DLRepport");
	Damagelog.RepportPanel:Populate(tbl);
	Damagelog.RepportPanel:MakePopup();
end);

usermessage.Hook("DLRDM_Remove", function(msg)
	local index = msg:ReadShort();

	Damagelog.rdmReporter.stored[index] = nil;

	if (ValidPanel(Damagelog.rdmReporter.panel)) then
		Damagelog.rdmReporter.panel:Update();
	end;
end);
