AddCSLuaFile()

local meta = FindMetaTable("Player")

CreateConVar("cwslide_enabled", 1, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the sliding mechanic be enabled?", 0, 1)
CreateConVar("cwslide_time", 0.575, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "The time it takes to stop sliding while continuously holding the crouch button", 0.1, 60)
CreateConVar("cwslide_speed", 400, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "The speed of the player while sliding", 0, 1600)
CreateConVar("cwslide_fixed", 1, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the angles of the velocity be fixed while sliding?", 0, 1)
CreateConVar("cwslide_sound", "player/suit_sprint.wav", {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "What sound should it play when sliding?")
CreateConVar("cwslide_dynamic", 1, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the sliding time be reduced or increased if sliding upwards or downwards?", 0, 1)
CreateConVar("cwslide_footsteps", 0, {FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should footstep sounds play when sliding?", 0, 1)

if SERVER then
    util.AddNetworkString("coldwar_slide_updatestatus")
end

function meta:SetSliding(set)
    self.IsCWSliding = set

    if SERVER and game.SinglePlayer() then
        net.Start("coldwar_slide_updatestatus")
        net.WriteBool(set)
        net.Send(self)
    end
end

function meta:GetSliding()
    return self.IsCWSliding
end

local function ensureToNumber(number, fallback)
    return tonumber(number) or fallback
end

hook.Add("SetupMove", "coldwar_slide_setupmove", function(ply, mv)
    if not GetConVar("cwslide_enabled"):GetBool() then return end
    if not ply:Alive() then return end

    ply.IsCWSliding = ply.IsCWSliding or false
    ply.CWSlideTime = ply.CWSlideTime or 0
    ply.CWSlideAngles = ply.CWSlideAngles or Angle(0, 0, 0)
    ply.CWSlideMP = ply.CWSlideMP or 1

    if mv:KeyDown(IN_DUCK) and ply:IsSprinting() and mv:GetVelocity() ~= Vector(0, 0, 0) and ply:OnGround() and not ply.IsCWSliding then
        ply.CWSlideTime = CurTime() + ensureToNumber(GetConVar("cwslide_time"):GetFloat(), 0.575)
        ply:SetSliding(true)
        ply:ViewPunch(Angle(mv:GetVelocity():Angle():Forward():Dot(mv:GetAngles():Forward()) * -4.5, 0, mv:GetVelocity():Angle():Right():Dot(mv:GetAngles():Forward()) * 7.5))
        ply.CWSlideAngles = mv:GetVelocity():Angle()
        ply.CWSlideMP = 1

        ply:EmitSound(GetConVar("cwslide_sound"):GetString())
    end
    if ply:GetSliding() and ply.CWSlideTime < CurTime() or not ply:KeyDown(IN_DUCK) then
        ply:SetSliding(false)
    end

    if ply:GetSliding() and ply:OnGround() then
        if not GetConVar("cwslide_fixed"):GetBool() then
            ply.CWSlideAngles = mv:GetVelocity():Angle()
        end

        if not ply.OldCWSlidePos then
            ply.OldCWSlidePos = mv:GetOrigin()
        end

        mv:SetVelocity(ply.CWSlideAngles:Forward() * ensureToNumber(GetConVar("cwslide_speed"):GetFloat(), 400) * ply.CWSlideMP)

        if GetConVar("cwslide_dynamic"):GetBool() then
            if mv:GetOrigin().z > ply.OldCWSlidePos.z then
                ply.CWSlideTime = ply.CWSlideTime - 0.01
                ply.CWSlideMP = math.Clamp(ply.CWSlideMP * 0.998875, 0.45, 1)
            elseif mv:GetOrigin().z < ply.OldCWSlidePos.z then
                ply.CWSlideTime = CurTime() + math.max(0.1, GetConVar("cwslide_time"):GetFloat()) * 0.5
                ply.CWSlideMP = math.Clamp(ply.CWSlideMP * 1.001125, 1, 1.4795)
            end
        end

        ply.OldCWSlidePos = mv:GetOrigin()
    end
end)

hook.Add("StartCommand", "coldwar_slide_startcommand", function(ply, cmd)

end)

hook.Add("PlayerFootstep", "coldwar_slide_footsteps", function(ply)
    if ply:GetSliding() then return GetConVar("cwslide_footsteps"):GetBool() end
end)

if CLIENT then
    CreateConVar("cwslide_vfx", 1, {FCVAR_ARCHIVE, FCVAR_NEVER_AS_STRING}, "Should visual effects play when sliding?", 0, 1)

    hook.Add("PopulateToolMenu", "CWSlideMenuSettings", function()
        spawnmenu.AddToolMenuOption("Utilities", "CWSlide", "CWSlide", "CWSlide Settings", "", "", function(panel)
            panel:ClearControls()

            local presetmanager = panel:ToolPresets("coldwarius", {
                ["cwslide_enabled"] = 1,
                ["cwslide_time"] = 0.575,
                ["cwslide_speed"] = 400,
                ["cwslide_fixed"] = 1,
                ["cwslide_sound"] = "player/suit_sprint.wav",
                ["cwslide_dynamic"] = 1,
                ["cwslide_footsteps"] = 0,
                ["cwslide_vfx"] = 1,
            })

            panel:Help("Server Controls\n")

            panel:CheckBox("Enabled", "cwslide_enabled")
            panel:ControlHelp("Enable sliding?\n")

            panel:NumSlider("Time", "cwslide_time", 0.1, 60)
            panel:ControlHelp("The time it takes to stop sliding while continuously holding the crouch button.\n")

            panel:NumSlider("Speed", "cwslide_speed", 0, 1600)
            panel:ControlHelp("The speed of the player while sliding.\n")

            panel:CheckBox("Fixed?", "cwslide_fixed")
            panel:ControlHelp("Should the angles of the velocity be fixed while sliding?\n")

            panel:TextEntry("Sound", "cwslide_sound")
            panel:ControlHelp("What sound should it play when sliding?\n")

            panel:CheckBox("Dynamic?", "cwslide_dynamic")
            panel:ControlHelp("Should the sliding time be reduced or increased if sliding upwards or downwards?\n")

            panel:CheckBox("Footsteps?", "cwslide_footsteps")
            panel:ControlHelp("Should footstep sounds play when sliding?\n")

            panel:Help("\nClient Controls\n")
            
            panel:CheckBox("VFX", "cwslide_vfx")
            panel:ControlHelp("Should visual effects play when sliding?\nWARNING! May conflict with Modern Warfare Base and TPCGM!\n")
        end)
    end)

    net.Receive("coldwar_slide_updatestatus", function(len)
        if not game.SinglePlayer() then return end
        LocalPlayer().IsCWSliding = net.ReadBool()
    end)

    local slideMP = 0
    hook.Add("RenderScreenspaceEffects", "coldwar_slide_toytown", function()
        if not GetConVar("cwslide_vfx"):GetBool() then return end

        slideMP = Lerp(FrameTime() * 15, slideMP, 0)
        if LocalPlayer():GetSliding() then
            slideMP = 0.5
            DrawMotionBlur(0.4, 0.2, 0.005)
        end
        if slideMP ~= 0 then
            DrawToyTown(1, ScrH() * slideMP)
        end
    end)

    local effectMP = 0
    local trueEffectMP = 0
    local rollLerp = 0
    local angleOffset = Angle(0, 0, 0)
    hook.Add("CalcView", "coldwar_slide_calcview", function(ply, pos, ang, fov, znear, zfar)
        if not GetConVar("cwslide_vfx"):GetBool() then return end

        if ply.HasSled ~= ply:GetSliding() then
            ply.HasSled = ply:GetSliding()

            if ply.HasSled == true then
                trueEffectMP = 2.45
            end
        end

        if not ply.HasSled then
            ply.HasSled = false
        end

        local angles = ang

        local tempOffset = Angle(0, 0, 0)
        local tempOffsetNoLerp = Angle(0, 0, 0)
        if ply:GetSliding() then
            effectMP = ((ply:GetVelocity():Length()) / (GetConVar("cwslide_speed"):GetFloat() * 0.9795)) * trueEffectMP
            trueEffectMP = Lerp(FrameTime() * 2.5, trueEffectMP, 0.178525)

            tempOffsetNoLerp.p = (0.125 * effectMP) * math.sin(2 * math.pi * 24.28170 * UnPredictedCurTime())
            tempOffsetNoLerp.y = (0.125 * effectMP) * math.sin(2 * math.pi * 48.56340 * UnPredictedCurTime())

            tempOffset.r = ply:GetVelocity():Angle():Right():Dot(angles:Forward()) * 7.5

            tempOffset.r = tempOffset.r - (0.125 * effectMP) * math.sin(2 * math.pi * 48.56340 * UnPredictedCurTime())
        end

        angleOffset = LerpAngle(FrameTime() * 15, angleOffset, tempOffset)

        angles = angles + angleOffset + tempOffsetNoLerp

        local view = {
            angles = angles,
        }

        return view
    end)
end