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
  -- Scratch / "Courier Dog" (Act 1 Wilderness). Verified against
  -- Act1a_FOR_Courier.txt: his PermaDefeated-mirroring flag and camp dialogue
  -- GUID were already correct. Added one thing: if he dies BEFORE ever
  -- running off to camp (CAMP_Courier_Dog_Moved2Camp never got set), the camp
  -- dialogue would be wrong for him, so we check that flag and fall back to
  -- his original Wilderness dialogue otherwise.
  ["S_FOR_Courier_Dog_3059f69c-068d-4e28-8491-55953c027901"] = {
    globals = { "GLO_CourierDog_State_IsPermaDefeated_4d17c54b-9507-4948-bbcc-0fe307f79f0b" },
    dialogIfFlagSet = {
      { flag = "7dcb7732-1c76-463a-bec9-251f30860e6c", -- CAMP_Courier_Dog_Moved2Camp
        dialog = "DIALOGRESOURCEGUID_CAMP_Courier_Dog_2f2ab0f4-9b0e-3991-b6dd-44474a25e7a3" },
    },
    dialog = "DIALOGRESOURCEGUID_FOR_Courier_Dog_c889e2f6-8381-8f51-361f-18fef4b39a12", -- fallback: original Wilderness dialogue
  },
  -- Oskar Fevros / "Doubting Artist" (Act 1 Zhentarim hideout, Act1_PLA_HuntCoward).
  -- The previous dialogue and ambient GUIDs here were WRONG - both shared the
  -- same GUID prefix as the real resources but a different suffix, so they'd
  -- have silently failed to rebind his dialogue. Corrected against the real
  -- quest file, which also revealed a second issue: his "freed" state is what
  -- gates whether his Act 3 "Oskar's Beloved" storyline unlocks at all -
  -- without it, leaving Act 1 after reviving him would incorrectly mark him
  -- "left unsaved" and lock that entire follow-up questline out. Fixed via
  -- the same two flags the game's own "PLA_ArtistIsFree" debug hook sets
  -- (State_Free and State_FreeBribe, checked by his freed-state query, turned
  -- out to be the exact same flag GUID under two names).
  ["S_GLO_DoubtingArtist_3ae152be-8ff6-420c-81a0-68d6a55cd5bd"] = {
    dialog  = "PLA_ZhentDungeon_DoubtingArtist_4c065742-3512-2eed-ff15-adb10d46e365",
    ambient = {
      "PLA_ZhentDungeon_DoubtingArtist_AD_Cowering_81706fb0-3cb4-c249-ba98-c2180b2237f8",
    },
    globals = { "PLA_DoubtingArtist_State_Dead_0a27ed23-fc91-43ba-8a26-b7053f1f97e2" },
    setFlags = {
      "201c1ed0-ecc3-4c25-8f68-8716bd5ca7ae", -- PLA_DoubtingArtist_State_Leaving
      "4b48199b-dfa4-49f9-8612-79d197e7e3fb", -- PLA_DoubtingArtist_State_Free / State_FreeBribe (same GUID)
    },
  },
  -- Arabella (Act 1 Druid Grove, "Snake Court" incident). Internally named
  -- "SnakeKid" because of the pretend snake-cult game Auntie Ethel's magic
  -- turns dangerous. If nobody talks the situation down in time, the
  -- DEN_SnakeCourt state machine moves her to "SnakeBite" and then kills her
  -- via PROC_DEN_ShadowDruid_KillKid (which also has to strip her normal
  -- SetImmortal(1) protection first - that's why she's killable at all).
  -- The good outcome (talked down / Ethel's hold released) sets
  -- DEN_ShadowDruid_State_KidFreed and calls
  -- PROC_DEN_ShadowDruid_CourtOutcome(1), which progresses her DEN_SnakeCourt
  -- state to "KidFreed" and sends her running to S_DEN_ParentA. We replicate
  -- that outcome directly: set the same flag, call the same outcome proc
  -- (so the state machine and any quest bookkeeping it does are correct),
  -- then teleport her straight to the parent position rather than trying to
  -- replay the "run there" animation, since her actual position/pathing
  -- right after a resurrection is unpredictable and the proc's own move
  -- order would otherwise race against it.
  -- NOTE: this does not restore her original SetImmortal(1) protection - she
  -- stays killable again like any other revived NPC under this mod. Say if
  -- you'd rather she come back essential/unkillable instead.
  ["S_DEN_SnakeKid_02257c1c-bbec-4ae3-9bcb-31c75a0a982f"] = {
    clearFlags = {
      -- DEN_ShadowDruid_State_KidDied. This is a separate flag from
      -- KidFreed below - it's what she actually dying set, and it's what
      -- keeps Rath (S_DEN_DruidOpposed), the druid who opposes Kagha,
      -- in his ongoing "mourning the dead kid" behavior: per
      -- Act1_DEN_ShadowDruid.txt this flag gates a standing reaction that
      -- tracks her position and has Rath walk to/kneel at wherever she
      -- currently is (the game has its own "stop Rath's reaction"
      -- edge-case handling for when her corpse gets moved or looted -
      -- we're triggering the same category of problem by teleporting her
      -- alive, so we clear the flag the same way those edge cases do).
      "5b5de896-e733-47ae-81df-85a4b25ebfd1",
    },
    setFlags = {
      "8d9e9065-7bb5-a516-15c3-c9d8c1f4f5e2", -- DEN_ShadowDruid_State_KidFreed
    },
    procs = {
      { name = "PROC_DEN_ShadowDruid_CourtOutcome", args = { 1 } },
      -- Explicitly interrupt Rath's mourning behavior right now, the same
      -- signal the game itself sends for the "corpse moved/looted" edge
      -- cases above - don't rely on the ClearFlag alone in case his
      -- current walk/kneel order is already in flight.
      { name = "SetEntityEvent", args = { "S_DEN_DruidOpposed_322cf8d2-32ee-453f-987e-f12b32652b5d", "DEN_ShadowDruid_StopMourningKid" } },
    },
    teleportTo = "S_DEN_ParentA_d6d88c8b-6ba7-4350-b3b3-d60565a44e90",
    -- The parents' special "reunited with kid" dialogue
    -- (DEN_GuardedEntrance_ParentsWithKid, see Act1_DEN_SacredPond_
    -- GuardedEntrance.txt) is normally only unlocked when the kid's
    -- CharacterMoveTo-to-parent order finishes and fires this entity event
    -- as its completion callback. Since we teleport her directly instead of
    -- letting that move play out, the event would never fire on its own -
    -- so fire it ourselves to unlock the reunion scene/journal update.
    entityEvents = { "DEN_ShadowDruid_KidRanToParent" },
    -- Dying flips her "can be talked to at all" flag off same as any NPC,
    -- and nothing in the good-outcome chain above turns it back on (that
    -- only happens via her own CourtOutcome dialogue node actually running,
    -- which we're bypassing). Without this she stays clickable-but-mute
    -- even though every quest flag is otherwise correct.
    setHasDialog = true,
    -- Her own click-to-talk dialog. The game binds it once at startup
    -- (Act1_DEN_ShadowDruid.txt line 7) and never again, so the death-wipe
    -- rule removes it for good. The parents' reunion scene is a separate
    -- scripted dialog, which is why she still takes part in it.
    dialog = "DEN_ShadowDruid_KidFreed_5c74f12a-1806-ba6b-8fa1-66d4f6b85281",
  },
  -- Aradin / "Adventurer Leader" (Act 1 Druid Grove entrance, goblin raid +
  -- Zevlor confrontation). Per Act1_DEN_RaidingParty.txt, if he goes down
  -- before the Aradin/Zevlor confrontation resolves, the game's own logic
  -- treats that identically to a peaceful resolution -- his crew is never
  -- told to leave, they just stay put where the fight ended. So which branch
  -- to restore him into depends on what the save actually recorded, not a
  -- guess: check DEN_RaidingParty_State_PeacefulResolution at revival time.
  --  - Peaceful: he was never sent anywhere -- just re-enable his dialogue
  --    and self-healing (mirrors the game's own
  --    PROC_DEN_RaidingParty_RestoreConfrontationCharacters) and leave him
  --    where he is, near his still-alive crewmates.
  --  - Not peaceful (his companions already left down the road): rebind him
  --    to his separate "AdventurersQuest" hub dialogue instead of trying to
  --    replay the Zevlor confrontation, which can't fire cleanly once Zevlor
  --    has already moved on in his own story track.
  ["S_DEN_AdventurerLeader_82d1b843-9e8c-48a5-9d87-caddea5c193c"] = {
    globals = { "DEN_AdventurerLeader_State_PermsaDefeated_ed091ac6-d46e-88e6-0568-844d6cc5a559" }, -- "PermsaDefeated" is a real typo in Larian's own script, not ours
    setHasDialog = true,
    procs = { "PROC_SelfHealing_Enable" },
    dialogIfFlagSet = {
      { flag = "f4529d52-b459-6545-b4bf-8b2fb2cd6f2f", -- DEN_RaidingParty_State_PeacefulResolution
        dialog = "DEN_RaidingParty_AdventurerLeader_0f2f631a-f47b-eee0-6025-2b814050d453" },
    },
    dialog = "DEN_AdventurerLeader_46fea64f-e098-2df5-f4ee-825080ef9728", -- fallback (non-peaceful): AdventurersQuest hub dialogue - best-effort, see chat notes
  },
  -- Baelen Bonecloak (Act 1 Underdark, "Find the Mushroom Picker").
  -- Datamined/fixed by NexusMods user "whyslyy" on the Raise The Dead posts
  -- page (character ID S_GLO_Baelen_711bd763-780d-4132-9662-3a8a06da6b1b).
  -- Killing Baelen during the quest permanently processes his death through
  -- the story system: the journal is updated, several quest-state flags are
  -- flipped, and his Osiris dialogue binding is dropped. Reviving him only
  -- undoes the HP/death state, so all three layers below have to be
  -- reversed by hand for him to run back to Derryth and be talkable again.
  ["S_GLO_Baelen_711bd763-780d-4132-9662-3a8a06da6b1b"] = {
    -- Layer 1: clear the "party saw him dead" / death-journal flags.
    clearFlags = {
      "0bcc675e-bf2d-deef-37f0-45375980bf4e", -- State_SeenDeadBaelenGlobal
      "ae1d68bb-08b2-4b2c-a9d1-18b0d234b57a", -- State_PartySawDeadBaelen
      "09cab6fb-6e63-37be-9472-6305fe1909c5", -- Event_SawDeadBaelen
      "074e6081-b828-47d8-9802-15d310f16a71", -- Event_CorpseMentionedWife
      "0f423316-4bea-75ce-bacc-f4554c71de15", -- Dead_MentionedWife
    },
    -- Layer 2: restore the "rescued" quest-state flags so the journal
    -- and his return-to-Derryth behavior re-trigger.
    -- Verified against the game's own Act1_UND_MushroomHunter.txt goal script,
    -- including two flags (ReportingToWife / MyconidCircle_GainedAccess) taken
    -- from Larian's own "debug_savemh" debug console hook for this NPC, which
    -- whyslyy's manual fix didn't include.
    setFlags = {
      "cd1f8012-322b-4135-bb40-54580bf5cea1", -- UND_MushroomHunter_State_Saved
      "389472a3-44c9-3550-a11a-5ea9df1afb5e", -- Saved_HasMet
      "90057b07-dd2b-4b85-804d-7d65639eb085", -- UND_MushroomHunter_State_ForcedAD
      "b9b27a52-e27b-481f-b483-8fcb95ff2f65", -- UND_MushroomHunter_State_InVillage
      "2c8e6a76-386c-4072-0809-fd0d8bf3db5a", -- UND_MushroomHunter_State_MentionedDerryth
      "3160b3f2-409f-4a79-a3ae-0cc698e91ef6", -- UND_MushroomHunter_State_ReportingToWife
      "fb9b0ee2-a499-cef2-fd3e-d9556050ea6a", -- UND_MyconidCircle_State_GainedAccess
    },
    -- Layer 3: dying through the quest strips his Osiris dialogue
    -- capability entirely, so it has to be turned back on before the
    -- dialog re-assignment below will actually fire on click.
    setOsirisDialog = true,
    dialog = "73879b46-280d-5317-4cdb-5232fe9a8e1e", -- UND_MushroomHunter
  },
  -- Minthara (Drow Commander). Handles the case where she died for real
  -- (e.g. AoE damage) during the Act 1 Grove attack, before the player has
  -- reached Grymforge/Moonrise Towers. Her entire later Moonrise Towers arc
  -- (Execution -> Torture -> Freed -> ToCamp, see Act2_MOO_MintharaFate.txt)
  -- is gated by a single check in PROC_MOO_MintharaFate_Init(): if
  -- DB_PermaDefeated(her) is true, that whole goal just completes and skips
  -- her entirely. The shared cleanup above already deletes DB_PermaDefeated
  -- for every resurrected NPC, so no extra flag work is needed for her to
  -- remain eligible for that arc later.
  -- What the generic cleanup does NOT handle: during the Grove attack she's
  -- placed in the hostile "ACT1_DEN_AttackRaiders_Fighters" faction and
  -- nothing in that combat script ever reverts it for a spared outcome -
  -- normally that's harmless because a spared Minthara is left knocked out
  -- and inert until the story moves her offstage to Moonrise. Resurrecting
  -- her would otherwise bring her back conscious and active while still in
  -- that hostile faction, i.e. she'd likely re-aggro immediately.
  -- Rather than touch her faction, we replicate the actual status vanilla
  -- uses for "spared, incapacitated, waiting to be sent to Moonrise": per
  -- Act2_MOO_MintharaFate.txt she's stripped of KNOCKED_OUT /
  -- KNOCKED_OUT_TEMPORARILY / KNOCKED_OUT_PERMANENTLY once she's brought
  -- back on stage there - so those are what represent that waiting state.
  -- Confirmed against Larian's own bugfix patches (BG3_Act3b_SavegamePatches.txt,
  -- GUSX-8382), which use this exact two-status call to put an NPC back into
  -- a correct "knocked out, story-important" state after a status mixup:
  --   ApplyStatus(character, "KNOCKED_OUT", -1.0);
  --   ApplyStatus(character, "KNOCKED_OUT_PERMANENTLY", -1.0);
  ["S_GOB_DrowCommander_25721313-0c15-4935-8176-9f134385451b"] = {
    procs = {
      { name = "ApplyStatus", args = { "S_GOB_DrowCommander_25721313-0c15-4935-8176-9f134385451b", "KNOCKED_OUT", -1.0 } },
      { name = "ApplyStatus", args = { "S_GOB_DrowCommander_25721313-0c15-4935-8176-9f134385451b", "KNOCKED_OUT_PERMANENTLY", -1.0 } },
    },
  },
  -- Mirkon / "Charmed Kid" (Act 1 harpy beach, Act1_DEN_HarpyMeal.txt).
  -- Dies if the harpies get him, if the party leaves/long-rests while he is
  -- still charmed, or via the Goblin-camp/Minthara paths. Reviving him should
  -- behave like the "saved" ending, so:
  --  * undo the death bookkeeping: VictimDead (set on him via DB_DeadOnceFlag),
  --    LeaderKilledVictim, SawVictimDie (per-player, via DB_SeenDeadNPCPartyFlag)
  --    and DB_DEN_HarpyMeal_CharmedKidDead(1);
  --  * strip the charm statuses;
  --  * if the encounter is already over, call the game's own
  --    PROC_DEN_HarpyMeal_ResolvedHarpies(): it sets HelpedSaveVictim for
  --    players in the cove, swaps his dialog to AfterHarpyEncounter, resets his
  --    fight/crime state and makes him a hideout kid. It also sends the
  --    "DefeatedHarpies" journal update (best effort, may not apply if the
  --    quest already closed on a death entry).
  -- If the encounter is NOT over (harpies still alive), he gets his charmed
  -- dialogue back instead and the normal encounter logic continues.
  ["S_DEN_CharmedKid_3b92c689-6024-4446-a6c9-584e9e8d77ca"] = {
    clearFlags = {
      "41f13c54-8ced-cd7c-d77b-448810338340", -- DEN_HarpyMeal_Event_LeaderKilledVictim
    },
    clearCharFlags = {
      "50cfd9b3-bf92-e441-e166-1466dcf1e185", -- DEN_HarpyMeal_State_VictimDead
    },
    clearPlayerFlags = {
      "b83ca7bf-ad4a-e407-46e8-af775365eafd", -- DEN_HarpyMeal_Event_SawVictimDie
    },
    dbDeletes = {
      { "DB_DEN_HarpyMeal_CharmedKidDead", 1 },
    },
    procs = {
      { name = "RemoveStatus", args = { "S_DEN_CharmedKid_3b92c689-6024-4446-a6c9-584e9e8d77ca", "LURING_SONG" } },
      { name = "RemoveStatus", args = { "S_DEN_CharmedKid_3b92c689-6024-4446-a6c9-584e9e8d77ca", "LURING_SONG_AURA_VICTIM" } },
    },
    procsIfFlagSet = {
      { flag = "48fd55cd-a79a-8b4a-8dd6-901910b5d739", -- DEN_HarpyMeal_State_HarpyEncounterOver
        procs = { { name = "PROC_DEN_HarpyMeal_ResolvedHarpies", args = {} } } },
    },
    setHasDialog = true,
    dialogIfFlagSet = {
      { flag = "48fd55cd-a79a-8b4a-8dd6-901910b5d739", -- HarpyEncounterOver
        dialog = "DEN_HarpyMeal_AfterHarpyEncounter_4632f7e4-5423-2308-858d-b62b3f525ca5" },
    },
    dialog = "DEN_HarpyMeal_CharmedVictim_c6beeee9-6c35-4b8b-8b86-2a15a28f556c", -- encounter still running
  },
  -- Halsin (Act 1, goblin camp, before recruitment). Verified against
  -- Act1_GLO_Halsin.txt, Act1_GOB_WolfPens.txt and GLO_Journal.txt.
  -- Death sets GLO_Halsin_State_PermaDefeated (DB_PermaDefeatedFlag) plus its
  -- compound GOB_WolfPens_State_PrisonerPermaDefeated and, if he hadn't
  -- returned to the Grove yet, GLO_Halsin_State_DeadInGOB. The PermaDefeated
  -- flag also deletes 17 GLO_Tadpole chained journal rows that link his later
  -- entries to "LearnedHalsin". All of that is undone here; the situational
  -- part (did the goblin leaders already die?) runs in the "Halsin" custom
  -- handler below. The "HalsinDiedEarly" journal line itself can't be erased.
  ["S_GLO_Halsin_7628bc0e-52b8-42a7-856a-13a6fd413323"] = {
    clearFlags = {
      "86bc3df1-08b4-fbc4-b542-6241bcd03df1", -- GLO_Halsin_State_PermaDefeated
      "a1bd5b3f-c4fe-4fac-b3b6-52367e97b545", -- GOB_WolfPens_State_PrisonerPermaDefeated
      "268f1aa0-1ba9-43d4-bfba-6c507b8e88ab", -- GLO_Halsin_State_DeadInGOB
    },
    setHasDialog = true,
    custom = "Halsin",
  },
  -- Damon (Weaponsmith) and Eremus (Ranger Trader): Act 1 Druid Attack on the
  -- Grove (Act1_DEN_DruidAttack.txt, Act1_DEN_Misc.txt). Both are "Fight"
  -- tieflings in DEN_DRUIDATTACK_TIEFLINGQUARTERS. What death does to them,
  -- verified in the scripts, and what we undo:
  --  * PROC_StateSet_Defeated removes them from DB_DEN_DruidAttack_NonDruids
  --    (the fight roster: group, dialog, swarm) -> put the row back, but only
  --    while DEN_State_DruidAttack is the current Den state.
  --  * Their DefeatCounter rows are NOT removed on death, and the counter
  --    re-evaluates when DB_Defeated/DB_PermaDefeated go away, so the
  --    "all tieflings defeated" total drops back by itself. Nothing to do.
  --  * PROC_StateSet_PermaDefeated deletes their DB_DEN_NPC row and bumps the
  --    "DEN_MissingTieflings" counter (Misc.txt ~1520-1533, threshold 28 during
  --    the attack). Re-add the row and decrement the counter once, only if the
  --    row is actually missing, so the count can't be over-corrected.
  --  * Death wipes the fight dialog; PROC_DEN_DruidAttack_SetNewDialog is the
  --    game's own routine for restoring it.
  -- We deliberately do NOT touch quest or fight-outcome flags (PrepAfterDeath*,
  -- DruidSetup...): the game should keep recording that the fight happened.
  -- Outside the Druid Attack state, only the DB_DEN_NPC/counter repair and
  -- the generic cleanup apply; their normal dialog is not touched.
  -- Karlach's "Forging of the Heart" (GLO_Origin_Karlach_PostEA.txt): Damon is
  -- her upgrade smith. Seeing him dead sets ORI_Karlach_State_SeenDammonDead
  -- (global) and SeenDammonDeadSpotter (per character, checked on Karlach),
  -- which drive her "Damon is dead" relationship dialog and
  -- ORI_Karlach_Knows_DammonIsDead. Clear all of them. NOTE: the journal
  -- entry "DammonPermadefeated" itself cannot be un-written from Osiris.
  ["S_DEN_Weaponsmith_e2ad06ec-8034-479a-9f69-b86faea6dc79"] = {
    clearFlags = {
      "a39ffb36-e11c-4335-b721-9926e4cba0b5", -- ORI_Karlach_State_SeenDammonDead
      "821a5eea-1a8b-9cc0-259a-4e975ad09189", -- ORI_Karlach_Knows_DammonIsDead
    },
    clearPlayerFlags = {
      "3f8853b9-97ee-41ac-bb87-2b0b6120e271", -- ORI_Karlach_State_SeenDammonDeadSpotter
    },
    procs = {
      { name = "ClearFlag", args = { "3f8853b9-97ee-41ac-bb87-2b0b6120e271", "S_Player_Karlach_2c76687d-93a2-477b-8b18-8a14b549304c", 0 } },
    },
    whenRow = {
      { row = { "DB_DEN_NPC", "S_DEN_Weaponsmith_e2ad06ec-8034-479a-9f69-b86faea6dc79", "*", "*" }, absent = true,
        dbInserts = { { "DB_DEN_NPC", "S_DEN_Weaponsmith_e2ad06ec-8034-479a-9f69-b86faea6dc79", "Defenseless", "DEN_AttackOnDen_Weaponsmith_f74a35e9-5895-dd0f-5c83-52009f6b0379" } },
        procs = { { name = "PROC_DecreaseCounter", args = { "DEN_MissingTieflings" } } } },
      { row = { "DB_State_Current", "S_DEN_RangerDen_SUB_50062397-bf9c-4765-9cbc-e40b5148f211", "DEN", "DEN_State_DruidAttack" },
        dbInserts = { { "DB_DEN_DruidAttack_NonDruids", "S_DEN_Weaponsmith_e2ad06ec-8034-479a-9f69-b86faea6dc79", "Fight", "DEN_DRUIDATTACK_TIEFLINGQUARTERS", "DEN_DruidAttack_Weaponsmith_PostEA_23532629-93cf-a224-d39d-f29825c49025" } },
        procs = {
          { name = "RequestSetSwarmGroup", args = { "S_DEN_Weaponsmith_e2ad06ec-8034-479a-9f69-b86faea6dc79", "DEN_DruidAttack_NonDruids" } },
          { name = "PROC_DEN_DruidAttack_SetNewDialog", args = { "S_DEN_Weaponsmith_e2ad06ec-8034-479a-9f69-b86faea6dc79", "DEN_DruidAttack_Weaponsmith_PostEA_23532629-93cf-a224-d39d-f29825c49025" } },
        } },
    },
  },
  ["S_DEN_TieflingRefugee_RangerTrader_001_637d8d68-2a04-409e-a77d-cf31ac9478ee"] = {
    whenRow = {
      { row = { "DB_DEN_NPC", "S_DEN_TieflingRefugee_RangerTrader_001_637d8d68-2a04-409e-a77d-cf31ac9478ee", "*", "*" }, absent = true,
        dbInserts = { { "DB_DEN_NPC", "S_DEN_TieflingRefugee_RangerTrader_001_637d8d68-2a04-409e-a77d-cf31ac9478ee", "Defenseless", "DEN_AttackOnDen_Refugee001_e9fa7a22-8a76-3170-49de-f2b04d5ae7c7" } },
        procs = { { name = "PROC_DecreaseCounter", args = { "DEN_MissingTieflings" } } } },
      { row = { "DB_State_Current", "S_DEN_RangerDen_SUB_50062397-bf9c-4765-9cbc-e40b5148f211", "DEN", "DEN_State_DruidAttack" },
        dbInserts = { { "DB_DEN_DruidAttack_NonDruids", "S_DEN_TieflingRefugee_RangerTrader_001_637d8d68-2a04-409e-a77d-cf31ac9478ee", "Fight", "DEN_DRUIDATTACK_TIEFLINGQUARTERS", "DEN_DruidAttack_RangerTrader_4a126415-d96e-d718-e489-01eb748fd0e7" } },
        procs = {
          { name = "RequestSetSwarmGroup", args = { "S_DEN_TieflingRefugee_RangerTrader_001_637d8d68-2a04-409e-a77d-cf31ac9478ee", "DEN_DruidAttack_NonDruids" } },
          { name = "PROC_DEN_DruidAttack_SetNewDialog", args = { "S_DEN_TieflingRefugee_RangerTrader_001_637d8d68-2a04-409e-a77d-cf31ac9478ee", "DEN_DruidAttack_RangerTrader_4a126415-d96e-d718-e489-01eb748fd0e7" } },
        } },
    },
  },
}

------------------------------------------------------------
-- Secondary lookup keyed by just the trailing UUID.
-- The same character can be referenced under different name prefixes in
-- different parts of the game's own story scripts (confirmed for the
-- Doubting Artist: "S_PLA_DoubtingArtist_..." and "S_GLO_DoubtingArtist_..."
-- are the exact same character, same UUID, different compiled alias). If
-- Osiris ever hands this listener a differently-prefixed name than the one
-- we used as the DialogMap key, this still finds the right entry.
------------------------------------------------------------
local DialogMapByUuid = {}
for key, mapCfg in pairs(DialogMap) do
  local uuid = key:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)$")
  if uuid then
    DialogMapByUuid[uuid] = mapCfg
  end
end

local function IsRealChar(ch)
    return ch
      and ch ~= ""
      and ch ~= "NULL_00000000-0000-0000-0000-000000000000"
      and Osi.IsCharacter(ch) == 1
end

------------------------------------------------------------
-- Custom per-NPC handlers, for fixes that depend on story state at the
-- moment of revival and need more than the declarative DialogMap fields.
-- Selected by cfg.custom = "<name>"; run at the end of ApplyRTDFix.
------------------------------------------------------------
local RTD_NULL = "NULL_00000000-0000-0000-0000-000000000000"

local function RTD_GlobalFlagSet(flagGuid)
  local isSet = false
  pcall(function() isSet = (Osi.DB_GlobalFlag:Count(flagGuid) or 0) > 0 end)
  return isSet
end

local function RTD_InCombat(char)
  local inCombat = false
  pcall(function()
    local rows = Osi.DB_Is_InCombat:Get(char, nil)
    inCombat = type(rows) == "table" and #rows > 0
  end)
  return inCombat
end

local HALSIN = "S_GLO_Halsin_7628bc0e-52b8-42a7-856a-13a6fd413323"
local HALSIN_FLAGS = {
  LeadersAreDead   = "a1c5b01f-4b7f-47ab-82b0-d24d9c6d8bc6", -- GOB_State_LeadersAreDead (global)
  LeftCage         = "4cd17a8b-7605-47c7-a13c-93821e68f177", -- GOB_WolfPens_State_PrisonerLeftCage (on Halsin)
  Returned         = "5af86099-47f9-ba69-199a-fe91292a41bd", -- GLO_Halsin_State_Returned (global)
  IsFollowing      = "b6cb47ab-d002-0985-b378-d78f3c4ccd59", -- GOB_WolfPens_State_HalsinIsFollowing (on player)
  HelpedKillLeaders= "f40ff780-3bad-7826-ef4b-06c9a29cb700", -- GOB_WolfPens_State_HalsinHelpedToKillLeaders (global)
}
local HALSIN_AFTERCOMBAT_DIALOG = "GOB_WolfPens_HalsinsBear_AfterCombat_00675ad1-8413-8548-7a91-77405b2860be"

-- The GLO_Tadpole chained rows GLO_Journal.txt deletes when Halsin's
-- PermaDefeated flag is set (lines ~392-409), copied from its INIT section.
local HALSIN_TADPOLE_CHAINS = {
  "LearnedLostHalsin", "LearnedResearchHalsin", "FoundHalsin_Unknown_KillLeaders",
  "FoundHalsin_Known_KillLeaders", "FoundHalsin_Unknown_AoD", "HalsinLeft_NoHelp_Known",
  "HalsinLeft_NoHelp_Unknown", "HalsinAtGrove_Known", "HalsinAtGrove_Unknown",
  "HalsinAtGrove_Known_Asharak", "HalsinAtGrove_Unknown_Asharak", "HalsinAtGrove_Known_Cerys",
  "HalsinAtGrove_Unknown_Cerys", "HalsinAtGrove_Known_Talked", "HalsinAtGrove_Unknown_Talked",
  "GoToMoonrise", "GoToMoonrise_NoIntro", "LearnedHalsinDiary",
}

-- Leaders dead + Halsin had left his cage: replay what Act1_GOB_WolfPens.txt
-- does when the leaders die while he follows the party (rules ~1317-1361):
-- drop him as follower, back to human form and his after-combat dialogue,
-- mark that he helped kill the leaders, and start his thank-you dialogue,
-- which leads into his normal "leave the goblin camp -> Grove/camp" path.
-- Waits (up to ~60s) for combat to end, like the game's own rule does.
local function HalsinLeadersDeadOutcome(attempt)
  attempt = attempt or 1
  local host = nil
  pcall(function() host = Osi.GetHostCharacter() end)
  if not host then return end
  if (RTD_InCombat(HALSIN) or RTD_InCombat(host)) and attempt < 30 then
    Ext.Timer.WaitFor(2000, function() HalsinLeadersDeadOutcome(attempt + 1) end)
    return
  end
  pcall(function() Osi.SetFlag(HALSIN_FLAGS.HelpedKillLeaders, RTD_NULL, 0) end)
  pcall(function() Osi.DB_IgnoreMutingStatussesDialog(HALSIN_AFTERCOMBAT_DIALOG) end)
  pcall(function() Osi.PROC_GOB_WolfPens_Halsin_RemoveFromParty(host) end)
  pcall(function() Osi.PROC_GOB_WolfPens_StartHalsinDialog(host) end)
  print(MOD_PREFIX .. " Halsin: leaders are dead - restored his 'helped kill the leaders' outcome and started his dialogue")
end

local RTD_CustomHandlers = {
  Halsin = function(npc)
    for _, step in ipairs(HALSIN_TADPOLE_CHAINS) do
      pcall(function() Osi.DB_QuestDef_ChainedState("GLO_Tadpole", step, "LearnedHalsin") end)
    end

    if RTD_GlobalFlagSet(HALSIN_FLAGS.Returned) then
      print(MOD_PREFIX .. " Halsin: had already returned to the Grove - generic restore only")
      return
    end

    local leftCage = false
    pcall(function() leftCage = (Osi.GetFlag(HALSIN_FLAGS.LeftCage, npc) == 1) end)
    local leadersDead = RTD_GlobalFlagSet(HALSIN_FLAGS.LeadersAreDead)
    local host = nil
    pcall(function() host = Osi.GetHostCharacter() end)

    if leadersDead and leftCage then
      Ext.Timer.WaitFor(3500, function() HalsinLeadersDeadOutcome(1) end)
    elseif leadersDead then
      -- Still in his cage when the leaders died: the game's own path for
      -- this case (Act1_GOB_WolfPens.txt, case 4.2) is break out and leave.
      pcall(function() Osi.PROC_GOB_WolfPens_HalsinForceBreakoutAndLeaving() end)
      print(MOD_PREFIX .. " Halsin: leaders dead, still caged - using the game's break-out-and-leave path")
    elseif leftCage and host then
      -- Leaders still alive and he'd been freed: make him follow the party
      -- again, through the same flag reaction his recruitment dialogue uses
      -- (adds him as a follower and re-applies his bear form/dialogue).
      pcall(function() Osi.SetFlag(HALSIN_FLAGS.IsFollowing, host, 0) end)
      pcall(function() Osi.PROC_FlagReactionAfterDialog(host, HALSIN_FLAGS.IsFollowing) end)
      print(MOD_PREFIX .. " Halsin: leaders alive - following the party again")
    else
      print(MOD_PREFIX .. " Halsin: still caged and leaders alive - generic restore only")
    end
  end,
}

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

  -- Many quest/named NPCs get SetCharacterLootOwned(npc, 1) applied to their
  -- corpse on death (e.g. Arabella/SnakeKid in Act1_DEN_ShadowDruid.txt),
  -- which is what makes their body and gear show the red "belongs to someone
  -- else" theft overlay and flags looting them as a crime. The game's own
  -- scripts clear this the same way (SetCharacterLootOwned(npc, 0)) once a
  -- corpse is done being "someone's body" - do the same for ANY resurrected
  -- NPC generically, since a living person's gear obviously shouldn't still
  -- be flagged as stolen goods.
  pcall(function() Osi.SetCharacterLootOwned(npc, 0) end)

  -- If this NPC is one of our known “special cases”, rebind their dialog/flags
  local cfg = DialogMap[npc]
  if not cfg then
    local uuid = npc:match("(%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x)$")
    if uuid then cfg = DialogMapByUuid[uuid] end
  end
  if cfg then
    -- Clear stale "was seen dead" / death-journal flags left behind by the
    -- story system processing their death.
    -- Flag calls use the game's own full form (flag, object, dialogInstance);
    -- the old short form is kept as a fallback in case the binding accepts it.
    local NULLG = "NULL_00000000-0000-0000-0000-000000000000"
    local function FlagOp(fn, flag, who)
      local ok = pcall(function() Osi[fn](flag, who or NULLG, 0) end)
      if not ok then pcall(function() Osi[fn](flag) end) end
    end
    local function ForEachPlayer(cb)
      local rows = {}
      pcall(function() rows = Osi.DB_Players:Get(nil) or {} end)
      for _,row in ipairs(rows) do
        local p = type(row) == "table" and row[1] or row
        if p then cb(p) end
      end
    end
    if cfg.clearFlags then
      for _,flag in ipairs(cfg.clearFlags) do FlagOp("ClearFlag", flag) end
    end
    -- Flags stored on the NPC itself / on each player (e.g. Mirkon's death flags).
    if cfg.clearCharFlags then
      for _,flag in ipairs(cfg.clearCharFlags) do FlagOp("ClearFlag", flag, npc) end
    end
    if cfg.clearPlayerFlags then
      for _,flag in ipairs(cfg.clearPlayerFlags) do
        ForEachPlayer(function(p) FlagOp("ClearFlag", flag, p) end)
      end
    end
    -- Plain Osiris DB rows to remove: { "DB_Name", arg1, arg2, ... }.
    if cfg.dbDeletes then
      for _,d in ipairs(cfg.dbDeletes) do
        pcall(function() Osi[d[1]]:Delete(table.unpack(d, 2)) end)
      end
    end
    -- Restore whatever "rescued/alive" quest-state flags the story expects
    -- once they're back on their feet.
    if cfg.setFlags then
      for _,flag in ipairs(cfg.setFlags) do FlagOp("SetFlag", flag) end
    end
    if cfg.globals then
      for _,flag in ipairs(cfg.globals) do
        pcall(function() Osi.DB_GlobalFlag:Delete(flag) end)
      end
    end
    -- Some NPCs lose their Osiris dialogue capability entirely once the
    -- story marks them dead; it has to be turned back on before reassigning
    -- the dialog below will actually do anything on click.
    if cfg.setOsirisDialog then
      pcall(function() Osi.SetHasOsirisDialog(npc, 1) end)
    end
    -- Plain "this NPC can have dialogue at all" toggle - separate from Osiris
    -- dialogue capability above, and separate from WHICH dialogue is bound.
    if cfg.setHasDialog then
      pcall(function() Osi.SetHasDialog(npc, 1) end)
    end
    -- Call named base-game Osiris PROCs directly by name, e.g. to reuse the
    -- game's own cleanup routines (self-healing re-enable, state-machine
    -- outcome procs, etc.) instead of reconstructing their side effects by
    -- hand. Entries are either a plain string (called with npc as the sole
    -- argument) or a {name=..., args={...}} table (called with exactly those
    -- literal arguments, npc NOT auto-included - use this when the proc's
    -- signature isn't "take one character", e.g. PROC_Foo(1)).
    if cfg.procs then
      for _,p in ipairs(cfg.procs) do
        if type(p) == "table" then
          pcall(function() Osi[p.name](table.unpack(p.args or {})) end)
        else
          pcall(function() Osi[p](npc) end)
        end
      end
    end
    -- Procs that should only run when a global flag is currently set
    -- (e.g. Mirkon: only "resolve" the harpy encounter if it is really over).
    if cfg.procsIfFlagSet then
      for _,entry in ipairs(cfg.procsIfFlagSet) do
        local isSet = false
        pcall(function() isSet = (Osi.DB_GlobalFlag:Count(entry.flag) or 0) > 0 end)
        if isSet then
          for _,p in ipairs(entry.procs or {}) do
            pcall(function() Osi[p.name](table.unpack(p.args or {})) end)
          end
        end
      end
    end
    -- Conditional DB inserts / procs, gated on whether an Osiris DB row exists
    -- (or, with absent=true, does NOT exist). row = { "DB_Name", arg1, ... },
    -- "*" is a wildcard. Used e.g. to put a tiefling back on the Druid Attack
    -- roster only while that fight is the current Den state.
    if cfg.whenRow then
      for _,e in ipairs(cfg.whenRow) do
        local exists = false
        pcall(function()
          local a, n = {}, #e.row - 1
          for i = 2, #e.row do
            if e.row[i] ~= "*" then a[i-1] = e.row[i] end
          end
          local rows = Osi[e.row[1]]:Get(table.unpack(a, 1, n)) or {}
          exists = #rows > 0
        end)
        if exists == (e.absent ~= true) then
          for _,ins in ipairs(e.dbInserts or {}) do
            pcall(function() Osi[ins[1]](table.unpack(ins, 2)) end)
          end
          for _,p in ipairs(e.procs or {}) do
            pcall(function() Osi[p.name](table.unpack(p.args or {})) end)
          end
        end
      end
    end
    -- Teleport the NPC to a fixed target position/character, overriding
    -- whatever "walk there" order a proc call above may have just issued -
    -- more reliable than replaying a scripted movement after a resurrection,
    -- since the NPC's actual position/pathing state is unpredictable.
    if cfg.teleportTo then
      pcall(function() Osi.TeleportTo(npc, cfg.teleportTo) end)
    end
    -- Fire any Osiris entity events the NPC's own quest logic listens for
    -- (e.g. movement-completion callbacks we've bypassed by teleporting).
    if cfg.entityEvents then
      for _, evt in ipairs(cfg.entityEvents) do
        pcall(function() Osi.SetEntityEvent(npc, evt) end)
      end
    end
    -- Some NPCs need a different dialogue depending on which stage of their
    -- own quest they'd already reached before dying (e.g. Scratch: camp
    -- dialogue if he'd already run off to camp, otherwise his original one).
    -- Check each candidate in order and use the first whose flag is set;
    -- otherwise fall through to the plain cfg.dialog below.
    local dialogAssigned = false
    if cfg.dialogIfFlagSet then
      for _,candidate in ipairs(cfg.dialogIfFlagSet) do
        local flagIsSet = false
        pcall(function() flagIsSet = (Osi.DB_GlobalFlag:Count(candidate.flag) or 0) > 0 end)
        if flagIsSet then
          pcall(function() Osi.DB_Dialogs(npc, candidate.dialog) end)
          dialogAssigned = true
          break
        end
      end
    end
    if not dialogAssigned and cfg.dialog then
      pcall(function() Osi.DB_Dialogs(npc, cfg.dialog) end)
    end
    if cfg.ambient then
      for _,a in ipairs(cfg.ambient) do
        pcall(function() Osi.DB_AD_Dialog(npc, a) end)
      end
    end
    if cfg.custom and RTD_CustomHandlers[cfg.custom] then
      local okCustom, errCustom = pcall(RTD_CustomHandlers[cfg.custom], npc)
      if not okCustom then
        print(MOD_PREFIX .. " Custom handler '" .. tostring(cfg.custom) .. "' failed: " .. tostring(errCustom))
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
-- Arabella (SnakeKid) never gets flagged as "someone else's property" at
-- all, even for the brief window between her death and any resurrection.
-- The base game calls SetCharacterLootOwned(Arabella, 1) the instant
-- PROC_DEN_ShadowDruid_KillKid runs (Act1_DEN_ShadowDruid.txt) - that's what
-- puts the red "stolen goods" overlay on her body/gear and turns looting her
-- into a crime. Osiris "before" listeners can't cancel a call outright, so
-- instead we watch for this specific call and immediately set it back to 0
-- the moment it fires - faster than anyone can see or interact with her
-- corpse, so the flag is effectively never present for her.
------------------------------------------------------------
local ARABELLA_UUID = "S_DEN_SnakeKid_02257c1c-bbec-4ae3-9bcb-31c75a0a982f"
Ext.Osiris.RegisterListener("SetCharacterLootOwned", 2, "after", function(character, isOwned)
  if character == ARABELLA_UUID and isOwned == 1 then
    pcall(function() Osi.SetCharacterLootOwned(character, 0) end)
  end
end)

------------------------------------------------------------
-- Stale "Downed" cleanup after resurrection (ANY character, including
-- party members - ApplyRTDFix deliberately skips players).
--
-- Found from a live "revived companion can't be talked to until a long rest
-- or a combat" report. In the game's __AAA_FirstGoal.txt, DB_Downed (plus a
-- DB_DefeatedCauses(char,"Downed",0) row) is added when someone drops to 0 HP
-- and is removed ONLY by the engine's DownedChanged(char,0) event. Resurrected
-- clears DB_Dead but never DB_Downed, so a character who died while downed and
-- is later revived can keep DB_Downed forever. DB_Downed is one of the feeders
-- of the root can't-talk row DB_CantTalk_IgnoreDialogsCombatStatusesDead, so
-- the whole DB_CantTalk chain and DB_Defeated stay set: no talk button, and
-- relationship-dialog "!" markers refuse to queue. A long rest or combat only
-- "fixes" it because that makes the engine send DownedChanged(char,0).
--
-- This does what the game's own rule (DownedChanged(_,0) AND DB_Downed ->
-- NOT DB_DefeatedCauses, NOT DB_Downed) would have done, then removes the
-- derived can't-talk layers - but ONLY when the character is alive, not
-- genuinely downed, and nothing else that legitimately blocks talking is set.
------------------------------------------------------------
local function DbHasRow(dbName, guid)
  local db = Osi[dbName]
  if not db then return false end
  local getters = {
    function() return db:Get(guid) end,
    function() return db:Get(guid, nil) end,
    function() return db:Get(nil, guid) end,
  }
  for _, g in ipairs(getters) do
    local ok, rows = pcall(g)
    if ok and type(rows) == "table" and #rows > 0 then return true end
  end
  return false
end

-- Top-down order = the order the game's own clear-rules cascade in.
local CANTALK_LAYERS_TOP_DOWN = {
  "DB_CantTalk_IgnoreDialogsCombatStatusesDead",
  "DB_CantTalk_IgnoreDialogsCombatDead",
  "DB_CantTalk_IgnoreDialogsCombat",
  "DB_CantTalk_IgnoreDialogs",
  "DB_CantTalk_IgnoreStatusesCombatDead",
  "DB_CantTalk_IgnoreStatusesCombat",
  "DB_CantTalk_IgnoreStatusesDead",
  "DB_CantTalk_IgnoreStatuses",
  "DB_CantTalk_IgnoreCombatDead",
  "DB_CantTalk_IgnoreCombat",
  "DB_CantTalk_IgnoreDead",
  "DB_CantTalk",
}

-- Anything here being set means talking is blocked for a real reason.
local CANTALK_REAL_BLOCKERS = {
  "DB_Dead", "DB_KnockedOut", "DB_FeignDeath", "DB_Petrified", "DB_IronFlasked",
  "DB_CRIME_FledOutOfSight", "DB_Is_EngineBlock_Talk", "DB_Is_WildShaped",
  "DB_Is_InCombat", "DB_InteractiveDialogSpeaker",
}

local function ClearStaleDownedState(char)
  if not char then return end

  local dead = nil
  pcall(function() dead = Osi.IsDead(char) end)
  if dead ~= 0 then return end                       -- unknown or dead: leave alone
  if not DbHasRow("DB_Downed", char) then return end -- nothing stale

  local downedNow = nil
  pcall(function() downedNow = Osi.HasActiveStatus(char, "DOWNED") end)
  if downedNow ~= 0 then return end                  -- really downed (or unknown): leave alone

  pcall(function() Osi.DB_DefeatedCauses:Delete(char, "Downed", 0) end)
  pcall(function() Osi.DB_Downed:Delete(char) end)

  for _, blocker in ipairs(CANTALK_REAL_BLOCKERS) do
    if DbHasRow(blocker, char) then
      print(MOD_PREFIX .. " Cleared stale DB_Downed on " .. tostring(char) ..
            " but left can't-talk layers alone (real blocker: " .. blocker .. ")")
      return
    end
  end

  for _, layer in ipairs(CANTALK_LAYERS_TOP_DOWN) do
    pcall(function() Osi[layer]:Delete(char) end)
  end

  -- DB_Defeated only if no other defeat cause remains.
  if not DbHasRow("DB_DefeatedCauses", char) then
    pcall(function() Osi.DB_Defeated:Delete(char) end)
  end

  print(MOD_PREFIX .. " Cleared stale Downed/can't-talk state on revived " .. tostring(char))
end

------------------------------------------------------------
-- THE IMPORTANT PART:
-- Fires for ANY resurrection source (spell/scroll/withers/etc.)
------------------------------------------------------------
Ext.Osiris.RegisterListener("Resurrected", 1, "after", function(character)
  if not IsRealChar(character) then return end
  print(MOD_PREFIX .. " Resurrected: " .. tostring(character))

  -- Stale-Downed cleanup for ANY revived character (party members included).
  -- Two passes so a late-arriving engine update can't leave it behind.
  Ext.Timer.WaitFor(400, function() ClearStaleDownedState(character) end)
  Ext.Timer.WaitFor(3000, function() ClearStaleDownedState(character) end)

  -- Run after a tiny delay so story/status settles
  Ext.Timer.WaitFor(100, function()
    ApplyRTDFix(character)
  end)
end)

print(MOD_PREFIX .. " RTD_Improved.lua LOADED (server)")
