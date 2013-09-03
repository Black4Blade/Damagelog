
AddCSLuaFile("cl_damagelog.lua")
AddCSLuaFile("cl_tabs/damagetab.lua")
AddCSLuaFile("cl_tabs/settings.lua")
AddCSLuaFile("cl_tabs/shoots.lua")
AddCSLuaFile("cl_tabs/old_logs.lua")
AddCSLuaFile("cl_tabs/rdm_manager.lua")
AddCSLuaFile("cl_tabs/about.lua")
AddCSLuaFile("sh_privileges.lua")
AddCSLuaFile("sh_sync_entity.lua")
AddCSLuaFile("sh_events.lua")
AddCSLuaFile("cl_listview.lua")
AddCSLuaFile("sh_weapontable.lua")
AddCSLuaFile("cl_colors.lua")
AddCSLuaFile("cl_filters.lua")
AddCSLuaFile("not_my_code/orderedPairs.lua")
AddCSLuaFile("not_my_code/von.lua")
AddCSLuaFile("rdm_manager/cl_rdm_manager.lua")
AddCSLuaFile("config/config.lua")

include("config/config.lua")
include("sh_sync_entity.lua")
include("sh_privileges.lua")
include("sh_events.lua")
include("not_my_code/orderedPairs.lua")
include("not_my_code/von.lua")
include("sv_damageinfos.lua") 
include("sh_weapontable.lua")
include("sv_weapontable.lua")
include("sv_oldlogs.lua")
include("rdm_manager/sv_rdm_manager.lua")
include("sv_stupidoverrides.lua")

resource.AddFile("sound/ui/vote_failure.wav")
resource.AddFile("sound/ui/vote_yes.wav")

util.AddNetworkString("DL_AskDamagelog")
util.AddNetworkString("DL_SendDamagelog")
util.AddNetworkString("DL_SendRoles")
util.AddNetworkString("DL_RefreshDamagelog")
util.AddNetworkString("DL_InformSuperAdmins")
util.AddNetworkString("DL_Ded")

Damagelog.DamageTable = Damagelog.DamageTable or {}
Damagelog.old_tables = Damagelog.old_tables or {}
Damagelog.ShootTables = Damagelog.ShootTables or {}
Damagelog.Roles = Damagelog.Roles or {}

function Damagelog:CheckDamageTable()
	if Damagelog.DamageTable[1] == "empty" then
		table.Empty(Damagelog.DamageTable)
	end
end

function Damagelog:TTTBeginRound()
	self.Time = 0
	if not timer.Exists("Damagelog_Timer") then
		timer.Create("Damagelog_Timer", 1, 0, function()
			self.Time = self.Time + 1
		end)
	end
	if IsValid(self:GetSyncEnt()) then
		local rounds = self:GetSyncEnt():GetPlayedRounds()
		self:GetSyncEnt():SetPlayedRounds(rounds + 1)
		if self.add_old then
			self.old_tables[rounds] = table.Copy(self.DamageTable)
		else
			self.add_old = true
		end
		self.ShootTables[rounds + 1] = {}
		self.Roles[rounds + 1] = {}
		for k,v in pairs(player.GetAll()) do
			self.Roles[rounds+1][v:Nick()] = v:GetRole()
		end
		self.CurrentRound = rounds + 1
	end
	self.DamageTable = { "empty" }
	self.OldLogsInfos = {}
	for k,v in pairs(player.GetAll()) do
		self.OldLogsInfos[v:Nick()] = {
			steamid = v:SteamID(),
			role = v:GetRole()
		}
	end
end
hook.Add("TTTBeginRound", "TTTBeginRound_Damagelog", function()
	Damagelog:TTTBeginRound()
end)

-- rip from TTT
-- this one will return a string
function Damagelog:WeaponFromDmg(dmg)
	local inf = dmg:GetInflictor()
	local wep = nil
	if IsValid(inf) then
		if inf:IsWeapon() or inf.Projectile then
			wep = inf
		elseif dmg:IsDamageType(DMG_BLAST) then
			wep = "an explosion"
		elseif dmg:IsDamageType(DMG_DIRECT) or dmg:IsDamageType(DMG_BURN) then
			wep = "fire"
		elseif dmg:IsDamageType(DMG_CRUSH) then
			wep = "falling or prop-killing"
		elseif inf:IsPlayer() then
			wep = inf:GetActiveWeapon()
			if not IsValid(wep) then
				wep = IsValid(inf.dying_wep) and inf.dying_wep
			end
		end
	end
	if type(wep) != "string" then
		return IsValid(wep) and wep:GetClass()
	else
		return wep
	end
end

function Damagelog:SendDamagelog(ply, round)
	if not ply:CanUseDamagelog() then return end
	local damage_send
	local roles = self.Roles[round]
	if round == self:GetSyncEnt():GetPlayedRounds() then
		damage_send = self.DamageTable
	else
		damage_send = self.old_tables[round]
	end
	if not damage_send then 
		damage_send = { "empty" } 
	end
	net.Start("DL_SendRoles")
	net.WriteTable(roles or {})
	net.Send(ply)
	local count = #damage_send
	for k,v in ipairs(damage_send) do
		net.Start("DL_SendDamagelog")
		if v == "empty" then
			net.WriteUInt(1, 1)
		elseif v == "ignore" then
			if count == 1 then
				net.WriteUInt(1, 1)
			else
				net.WriteUInt(0,1)
				net.WriteTable({"ignore"})
			end
		else
			net.WriteUInt(0, 1)
			net.WriteTable(v)
		end
		net.WriteUInt(k == count and 1 or 0, 1)
		net.Send(ply)
	end
	local superadmins = {}
	for k,v in pairs(player.GetHumans()) do
		if v:IsSuperAdmin() then
			table.insert(superadmins, v)
		end
	end
	if ply:IsActive() then
		net.Start("DL_InformSuperAdmins")
		net.WriteString(ply:Nick())
		net.WriteUInt(round, 8)
		net.Send(superadmins)
	end
end
net.Receive("DL_AskDamagelog", function(_, ply)
	Damagelog:SendDamagelog(ply, net.ReadUInt(32))
end)

hook.Add("PlayerDeath", "Damagelog_PlayerDeathLastLogs", function(ply)
	if GetRoundState() == ROUND_ACTIVE then
		local found_dmg = {}
		for k,v in ipairs(Damagelog.DamageTable) do
			if type(v) == "table" and v.time >= Damagelog.Time - 10 and v.time <= Damagelog.Time then
				table.insert(found_dmg, v)
			end
		end
		if not ply.DeathDmgLog then
			ply.DeathDmgLog = {}
		end
		ply.DeathDmgLog[Damagelog.CurrentRound] = found_dmg
	end
end)	
