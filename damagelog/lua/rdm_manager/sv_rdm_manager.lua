util.AddNetworkString("RDMAdd");
util.AddNetworkString("RDMRespond");
util.AddNetworkString("DLRDM_Start");

AddCSLuaFile("cl_rdm_manager.lua");
AddCSLuaFile("sh_notify.lua");
AddCSLuaFile("dermas/cl_respond.lua");
AddCSLuaFile("dermas/cl_infolabel.lua");
AddCSLuaFile("dermas/cl_repport.lua");
AddCSLuaFile("dermas/cl_repportPanel.lua");

include("sh_notify.lua");

Damagelog.rdmReporter = Damagelog.rdmReporter or {};
Damagelog.rdmReporter.stored = Damagelog.rdmReporter.stored or {};
Damagelog.rdmReporter.respond = Damagelog.rdmReporter.respond or {};

function Damagelog.rdmReporter:SendAdmin(ply, index)
	if (!ply) then
		ply = {};
		
		for k, v in pairs(player.GetHumans()) do
			if (v:IsAdmin()) then
				table.insert(ply, v);
			end;
		end;
	end;
	
	if (index) then
		if (self.stored[index]) then
			net.Start("RDMAdd");
				net.WriteTable(self.stored[index]);
			net.Send(ply);
		end;
	else
		for k, v in pairs(self.stored) do
			net.Start("RDMAdd");
				net.WriteTable(v);
			net.Send(ply);
		end;
	end;
end;

function Damagelog.rdmReporter:SendRespond(ply)
	local steamID = ply:SteamID();

	if (Damagelog.rdmReporter.respond[steamID]
	and table.Count(Damagelog.rdmReporter.respond[steamID]) > 0) then
		net.Start("RDMRespond");
			net.WriteTable(Damagelog.rdmReporter.respond[steamID]);
		net.Send(ply);
	end;
end;

function Damagelog.rdmReporter:AddReport(ply, message, killer)
	if Damagelog.RDM_Manager_Enabled != 1 then return end
	if (IsValid(ply) and ply.rdmInfo) then
		local repport = {
			time = ply.rdmInfo.time,
			round = ply.rdmInfo.round,
			message = message,
			
			ply = ply,
			plyName = ply:Nick(),
			plySteam = ply:SteamID(),

			state = 1;
			
			state_ply = NULL,
			
			lastLogs = ply.DeathDmgLog[ply.rdmInfo.round] or {}
		};
		
		repport.index = table.insert(self.stored, repport);

		if (killer and IsValid(killer)) then
			local steamID = killer:SteamID();

			repport.attacker = killer;
			repport.attackerName = killer:Nick();
			repport.attackerSteam = steamID;

			local respond = {
				message = repport.message,
				victim = repport.plyName,
				round = repport.round,
				time = repport.time,
				report = repport.index
			};

			if (!self.respond[steamID]) then
				self.respond[steamID] = {};
			end;

			respond.index = table.insert(self.respond[steamID], respond);

			if (!killer:Alive() or GetRoundState() != ROUND_ACTIVE) then
				Damagelog.rdmReporter:SendRespond(killer);
			end;
		end;
		
		Damagelog.rdmReporter:SendAdmin(nil, repport.index);
		Damagelog.notify:AddMessage("admin", "A new report has been submitted!", nil, "ui/vote_failure.wav");

		ply.rdmInfo = nil;
	end;
end;

function Damagelog.rdmReporter:StartRepport(ply, doesCreate)
	if (doesCreate) then
		ply.rdmInfo = {
			time = Damagelog.Time,
			round = Damagelog.CurrentRound,
		};
	end;
	
	net.Start("DLRDM_Start");
	if ply.DeathDmgLog and ply.DeathDmgLog[Damagelog.CurrentRound] then
		net.WriteUInt(1, 1);
		net.WriteTable(ply.DeathDmgLog[Damagelog.CurrentRound]);
	else
		net.WriteUInt(0,1);
	end;
	net.Send(ply);
end;

function Damagelog.rdmReporter:CanReport(ply)
	if (IsValid(ply)) then
		local found_admin = false
		if #player.GetHumans() <= 1 then
			return false, "You are alone!"
		end
		for k,v in pairs(player.GetHumans()) do
			if v:IsAdmin() then
				found_admin = true
				break
			end
		end
		if not found_admin then
			return false, "No admins online!"
		end
		if (!ply:Alive() or GetRoundState() != ROUND_ACTIVE) then
			if (ply.rdmRoundPlay) then
				return true;
			else
				return false, "You can't report if you didn't play!";
			end;
		else
			return false, "You can't report when you are alive!";
		end;
	end;
end;

net.Receive("RDMAdd", function(len, ply)
	local message = net.ReadString();
	local killer = net.ReadEntity();

	if (ply.rdmInfo and message) then
		Damagelog.rdmReporter:AddReport(ply, message, killer);
	end;
end);

net.Receive("RDMRespond", function(len, ply)
	local message = net.ReadString();
	local index = net.ReadUInt(8);
	local steamID = ply:SteamID();

	if (Damagelog.rdmReporter.respond[steamID]) then
		local respond = Damagelog.rdmReporter.respond[steamID][index];

		if (respond) then
			table.remove(Damagelog.rdmReporter.respond[steamID], index);
			Damagelog.rdmReporter.stored[respond.report].attackerMessage = message;
			Damagelog.rdmReporter:SendAdmin(nil, respond.report, true);
			Damagelog.notify:AddMessage("admin", "A response has been submitted!", "icon16/error.png", "ui/vote_yes.wav");
		end;
	end;
end);

hook.Add("TTTEndRound", "RDM_Respond", function()
	for k, v in pairs(player.GetHumans()) do
		local steamID = v:SteamID();

		if (v:Alive()) then
			Damagelog.rdmReporter:SendRespond(v);
		end;
	end;
end);

hook.Add("TTTBeginRound", "RDM_Respond", function()
	for k, v in pairs(player.GetHumans()) do
		v.rdmRoundPlay = true;
		v.rdmSend = nil;
		v.rdmInfo = nil;
	end;
end);

concommand.Add("DLRDM_ForceVictim", function(ply, cmd, args)
	local victim = args[1]
	print(victim, tonumber(victim), Entity(tonumber(victim)))
	if tonumber(victim) and IsValid(Entity(tonumber(victim))) then
		victim = Entity(tonumber(victim))
		Damagelog.rdmReporter:SendRespond(victim)
	end
end)

hook.Add("PlayerDeath", "RDM_Killer", function(victim, infl, attacker)
	if (Damagelog.RDM_Manager_Window == 1) then
		victim.rdmSend = true;
		victim.rdmInfo = {
			time = Damagelog.Time,
			round = Damagelog.CurrentRound,
		};
	end;

	Damagelog.rdmReporter:SendRespond(victim);
end);

hook.Add("PlayerSay", "DLRDM_Command", function(ply, text, teamOnly)
	text = text:lower();

	if (text == "!report") and Damagelog.RDM_Manager_Enabled == 1 then
		local succes, fail = Damagelog.rdmReporter:CanReport(ply);
		if (succes) then
			Damagelog.rdmReporter:StartRepport(ply, true);
		else
			if (fail) then
				Damagelog.notify:AddMessage(ply, fail,
				"icon16/information.png", "buttons/weapon_cant_buy.wav");
			end;
		end;

		return "";
	end;

	if (text == "!respond") and Damagelog.RDM_Manager_Enabled == 1  then
		Damagelog.rdmReporter:SendRespond(ply);

		return "";
	end;
end);

hook.Add("PlayerInitialSpawn", "RDM_SendAdmin", function(plt)
	timer.Simple(4, function()
		if (IsValid(ply) and ply:IsAdmin()) and Damagelog.RDM_Manager_Enabled == 1 then
			Damagelog.rdmReporter:SendAdmin(ply);
		end;
	end)
end);

concommand.Add("DLRDM_Repport", function(ply)
	if Damagelog.RDM_Manager_Enabled != 1 then return end
	if (IsValid(ply)) then
		if (!ply:Alive()) then
			if (ply.rdmSend) then
				ply.rdmSend = nil;
				Damagelog.rdmReporter:StartRepport(ply);
			else
				Damagelog.rdmReporter:StartRepport(ply, true);
			end;
		end;
	end;
end);

--[[concommand.Add("DLRDM_Remove", function(ply, cmd, args, str)
	if Damagelog.RDM_Manager_Enabled != 1 then return end 
	if (IsValid(ply) and ply:IsAdmin()) then
		if (args[1]) then
			local index = tonumber(args[1]);

			if (index and Damagelog.rdmReporter.stored[index]) then
				Damagelog.rdmReporter.stored[index] = nil;

				local plys = RecipientFilter();

				for k, v in pairs(player.GetHumans()) do
					if (v:IsAdmin()) then
						plys:AddPlayer(v);
					end;
				end;

				umsg.Start("DLRDM_Remove", plys)
					umsg.Short(index);
				umsg.End();
			end;
		end;
	end;
end);]]--

concommand.Add("DLRDM_State", function(ply, cmd, args, str)
	if Damagelog.RDM_Manager_Enabled != 1 then return end 
	if (IsValid(ply) and ply:IsAdmin()) then
		if (args[1] and args[2]) then
			local index = tonumber(args[1]);
			local state = tonumber(args[2]);

			if (index and Damagelog.rdmReporter.stored[index] and state) then
				local report = Damagelog.rdmReporter.stored[index];
				report.state = state;
				if state == 2 then
					report.state_ply = ply
				else
					report.state_ply = NULL
				end

				Damagelog.rdmReporter:SendAdmin(ply, index);
				Damagelog.notify:AddMessage(ply, "A report has been updated!", "icon16/information.png");
			end;
		end;
	end;
end);
