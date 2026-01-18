------------------------------------------------------------
-- RTD_Improved.lua
-- Applies RTD-style “NPC resurrection repair” to ANY resurrection source.
-- No spell-name filtering: runs on Resurrected event.
------------------------------------------------------------

local MOD_PREFIX = "[RTD]"

------------------------------------------------------------
-- DialogMap (keep/expand as needed)
------------------------------------------------------------
local DialogMap = {
  ["S_FOR_Courier_Dog_3059f69c-068d-4e28-8491-55953c027901"] = {
    dialog  = "DIALOGRESOURCEGUID_CAMP_Courier_Dog_2f2ab0f4-9b0e-3991-b6dd-44474a25e7a3",
    globals = { "GLO_CourierDog_State_IsPermaDefeated_4d17c54b-9507-4948-bbcc-0fe307f79f0b" }
  },
  ["S_GLO_DoubtingArtist_3ae152be-8ff6-420c-81a0-68d6a55cd5bd"] = {
    dialog  = "DIALOGRESOURCEGUID_PLA_ZhentDungeon_DoubtingArtist_4c065742-1c0c-46da-8268-123037c55846",
    ambient = {
      "DIALOGRESOURCEGUID_PLA_ZhentDungeon_DoubtingArtist_AD_Cowering_81706fb0-2d41-4268-aad1-32dc9b3d7ee5"
    }
  },
}

local function IsRealChar(ch)
    return ch
      and ch ~= ""
      and ch ~= "NULL_00000000-0000-0000-0000-000000000000"
      and Osi.IsCharacter(ch) == 1
end

------------------------------------------------------------
-- Respawn helper (same idea as your RTD, just guarded)
------------------------------------------------------------
local function RespawnFromTemplate(npc)
  local x, y, z = 0, 0, 0
  local okP, px, py, pz = pcall(Osi.GetPosition, npc)
  if okP and px then x, y, z = px, py, pz end

  print(string.format("%s Cloning NPC in place at position (%.2f, %.2f, %.2f)", MOD_PREFIX, x, y, z))

  local ok, clone = pcall(Ext.Entity.Clone, npc, true)
  if not ok or not clone or not clone.Uuid then
    print(MOD_PREFIX .. " Clone failed for " .. tostring(npc))
    return npc
  end

  -- Move clone to original position (best-effort)
  pcall(function()
    local tr = Ext.Entity.GetTransform(clone.Uuid)
    if tr and tr.Position then
      tr.Position = {x, y, z}
    end
  end)

  clone:Replicate("RTD_Clone")

  -- Remove old entity
  pcall(Osi.RequestDelete, npc)

  -- Make sure story knows about it
  pcall(Osi.ProcCharacterTemplateAddToLevel, clone.Uuid)
  pcall(Osi.ProcCharacterAddToActiveLevel, clone.Uuid)

  print(MOD_PREFIX .. " Respawned NPC: " .. tostring(clone.Uuid))
  return clone.Uuid
end

------------------------------------------------------------
-- Main RTD repair routine
------------------------------------------------------------
local function ApplyRTDFix(npc)
  if not IsRealChar(npc) then return end

  -- Only fix NON-players (NPCs). This avoids touching origin/party.
  -- (If you ever WANT it for players, remove this block.)
  if Osi.IsPlayer(npc) == 1 then return end

  -- Clean up “defeated / can’t talk / cleanup” DB state
  pcall(function()
    Osi.DB_PermaDefeated:Delete(npc)
    Osi.DB_Defeated:Delete(npc)
    Osi.DB_PermaDefeatedOrOffstage:Delete(npc)
    Osi.DB_CorpseCleanup_ReadyToBeRemoved:Delete(npc)
    Osi.DB_CantAct:Delete(npc)
    Osi.DB_CantTalk_IgnoreDialogsCombat:Delete(npc)
    Osi.DB_CantTalk_IgnoreStatusesCombat:Delete(npc)
    Osi.DB_CantTalk_IgnoreStatuses:Delete(npc)
    Osi.DB_CantTalk:Delete(npc)
  end)

  -- If this NPC is one of our known “special cases”, rebind their dialog/flags
  local cfg = DialogMap[npc]
  if cfg then
    if cfg.globals then
      for _,flag in ipairs(cfg.globals) do
        pcall(function() Osi.DB_GlobalFlag:Delete(flag) end)
      end
    end
    if cfg.dialog then
      pcall(function() Osi.DB_Dialogs(npc, cfg.dialog) end)
    end
    if cfg.ambient then
      for _,a in ipairs(cfg.ambient) do
        pcall(function() Osi.DB_AD_Dialog(npc, a) end)
      end
    end
    print(MOD_PREFIX .. " Applied special-case dialog/flags for " .. tostring(npc))
    return
  end

  -- Generic fallback: if NPC still seems “broken”, respawn them from template
  -- Heuristic: if they still can't act/talk shortly after resurrection.
  Ext.Timer.WaitFor(250, function()
    if not IsRealChar(npc) then return end

    local cantAct = 0
    local cantTalk = 0
    pcall(function() cantAct = Osi.DB_CantAct:Count(npc) end)
    pcall(function() cantTalk = Osi.DB_CantTalk:Count(npc) end)

    if (cantAct and cantAct > 0) or (cantTalk and cantTalk > 0) then
      print(MOD_PREFIX .. " NPC still flagged cantAct/cantTalk -> respawning: " .. tostring(npc))
      RespawnFromTemplate(npc)
    else
      print(MOD_PREFIX .. " NPC resurrected cleanly: " .. tostring(npc))
    end
  end)
end

------------------------------------------------------------
-- THE IMPORTANT PART:
-- Fires for ANY resurrection source (spell/scroll/withers/etc.)
------------------------------------------------------------
Ext.Osiris.RegisterListener("Resurrected", 1, "after", function(character)
  if not IsRealChar(character) then return end
  print(MOD_PREFIX .. " Resurrected: " .. tostring(character))

  -- Run after a tiny delay so story/status settles
  Ext.Timer.WaitFor(100, function()
    ApplyRTDFix(character)
  end)
end)

print(MOD_PREFIX .. " RTD_Improved.lua LOADED (server)")
