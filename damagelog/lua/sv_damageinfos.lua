
util.AddNetworkString("DL_AskDamageInfos")
util.AddNetworkString("DL_SendDamageInfos")
util.AddNetworkString("DL_AskShootLogs")
util.AddNetworkString("DL_SendShootLogs")

function Damagelog:shootCallback(weapon)
	local owner = weapon.Owner
	if GetRoundState() == ROUND_ACTIVE then
		if self.ShootTables[self.CurrentRound][self.Time] then
			local info = { owner:Nick(), weapon:GetClass() }
			table.insert(self.ShootTables[self.CurrentRound][self.Time], info)			
		else
			table.insert(self.ShootTables[self.CurrentRound], self.Time, {})
			local info = { owner:Nick(), weapon:GetClass() }
			table.insert(self.ShootTables[self.CurrentRound][self.Time], info)
		end
	end
end
	 
function Damagelog:DamagelogInfos()
	for k,v in pairs(weapons.GetList()) do		
		if v.Base == "weapon_tttbase" then
			if not v.PrimaryAttack then
				v.PrimaryAttack = function(wep)
					wep.BaseClass.PrimaryAttack(wep)
					if wep.BaseClass.CanPrimaryAttack(wep) and IsValid(wep.Owner) then
						self:shootCallback(wep)
					end
				end
			else
				local oldprimary = v.PrimaryAttack
				v.PrimaryAttack = function(wep)
					oldprimary(wep)
					Damagelog:shootCallback(wep)
				end
			end
		end
	end
end
	
hook.Add("Initialize", "Initialize_DamagelogInfos", function()	
	Damagelog:DamagelogInfos()
end)

function Damagelog:SendDamageInfos(ply, t, att, victim, round)
	local results = {}
	local found = false
	for k,v in pairs(self.ShootTables[round] or {}) do
	    if k >= t - 10 and k <= t then
		    for s,i in pairs(v) do
		        if i[1] == victim or i[1] == att then
		            if results[k] == nil then
					    table.insert(results, k, {})
					end
					table.insert(results[k], i)
			        found = true
				end
			end
		end
	end
	local beg = t - 10
	if found then
		net.Start("DL_SendDamageInfos")
		net.WriteUInt(0,1)
		net.WriteUInt(beg, 32)
		net.WriteUInt(t, 32)
		net.WriteTable(results)
		net.WriteString(victim)
		net.WriteString(att)
		net.Send(ply)
	else 
		net.Start("DL_SendDamageInfos")
		net.WriteUInt(1,1)
		net.WriteUInt(beg, 32)
		net.WriteUInt(t, 32)
		net.WriteString(victim)
		net.WriteString(att)
		net.Send(ply)
    end
end 

net.Receive("DL_AskDamageInfos", function(_, ply)
	local time = net.ReadUInt(32)
	local attacker = net.ReadString()
	local victim = net.ReadString()
	local round = net.ReadUInt(32)
	Damagelog:SendDamageInfos(ply, time, attacker, victim, round)
end)

local orderedPairs = Damagelog.orderedPairs
net.Receive("DL_AskShootLogs", function(_, ply)
	if not ply:CanUseDamagelog() then return end
	local data = Damagelog.ShootTables[net.ReadUInt(8)]
	if not data then return end
	data = table.Copy(data)
	local count = table.Count(data)
	local i = 0
	if count <= 0 then
		net.Start("DL_SendShootLogs")
		net.WriteTable({"empty"})
		net.WriteUInt(1, 1)
		net.Send(ply)
	else
		for k,v in orderedPairs(data) do
			i = i + 1
			net.Start("DL_SendShootLogs")
			net.WriteTable(v)
			net.WriteUInt(i == count and 1 or 0, 1)
			net.Send(ply)
		end
	end
end)