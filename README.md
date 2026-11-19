# Raise The Dead

A Baldur's Gate 3 Script Extender mod that lets you resurrect NPCs, not just your party, and makes them behave properly once they're back.

In vanilla BG3, a story NPC who dies has their death written into the story. Their dialogue is removed, quest flags record them as dead, and they're marked "defeated". Raising the body only restores their HP, so you get someone standing there who can't be talked to, has gear flagged as stolen, and whose quest thinks they're still dead. Raise The Dead repairs that state. For specific characters, it also replays the outcome you'd have got if they had survived.

It works no matter how the character is revived: spell, scroll, Withers or console.

---

## Requirements
- [BG3 Script Extender](https://github.com/Norbyte/bg3se)

**Using Damage Destruction?** Don't install this mod as well. Damage Destruction already includes these fixes.

---

## Features

### Resurrection works on anyone
The Resurrection spell (`Teleportation_Resurrection`) can target any dead character, not just your party.

### What every revived character gets
- **Cleared defeated state:** leftover "defeated / can't act / can't talk" story state is removed, so they aren't a mute husk.
- **No "stolen" overlay:** the red "belongs to someone else" overlay is removed from their body and gear, so touching their things isn't a crime.
- **Talk works straight away:** a stale "downed" marker can make a revived character, companions included, impossible to talk to until a long rest or a fight. It's cleaned up automatically.
- **Respawn fallback:** an unlisted NPC who still can't act or talk shortly after revival is respawned in place.

---

## NPCs accounted for

- **Baelen Bonecloak** (Act 1, Underdark). Restores his full "rescued" quest state and his dialogue, and sends him back to Derryth.
- **Scratch** (Act 1). Restores the right dialogue for how far his quest had gone: camp dialogue, or his original wilderness dialogue.
- **Oskar Fevros** (Act 1, Zhentarim hideout). Restores his dialogue and his "freed" flags, so his Act 3 *Oskar's Beloved* quest stays available.
- **Arabella** (Act 1, Druid Grove). Sets the outcome you'd get by talking Kagha down. Sends her to her parents and unlocks their reunion. Stops Rath mourning her and restores her click-to-talk dialogue. Her corpse never gets the "stolen goods" overlay. *Confirmed in play.*
- **Aradin** (Act 1, Grove entrance). Restores his dialogue and self-healing, and picks the right dialogue for whether his confrontation with Zevlor ended peacefully.
- **Minthara** (Act 1 Grove attack, before Grymforge or Moonrise). Puts her in the game's own "spared, knocked out" state, so she follows the normal path to Moonrise instead of re-aggroing.
- **Mirkon** (Act 1, harpy beach). Removes his death flags and charm. If the harpies are already dead, it runs the game's own "saved the victim" outcome; if not, he goes back to the charmed encounter.
- **Halsin** (Act 1, goblin camp, before recruitment). Clears his death flags and repairs his journal links. If the goblin leaders are dead, he gets the outcome where he helped you kill them: his thank-you dialogue, then he leaves for the Grove. If they're alive, he follows you again.
- **Damon** (Act 1, Druid Grove). Put back on the tiefling side of the Druid Attack fight with his fight dialogue, and back on the Grove's NPC list, with the "too few tieflings" count corrected. Karlach's "Damon is dead" memory is cleared, so he can still upgrade her. *Confirmed in play.*
- **Eremus** (Act 1, Druid Grove). Same Druid Attack repair as Damon: roster, dialogue, NPC list and tiefling count. *Confirmed in play.*

### Known limits
- **Journal entries:** an entry that has already been written, such as "X was defeated", can't be erased. If a quest closed because of a death, the game won't reopen it, so the journal may stop tracking even though the character works normally.
- **No generic fix:** every story NPC in BG3 is scripted by hand, so fixes are added one character at a time. A revived NPC who isn't listed only gets the universal fixes. Requests are welcome.

---

## Installation
1. Install BG3 Script Extender.
2. Install Raise The Dead with your mod manager, then enable it.

## Credits
- Author: A Human
- Baelen fix originally datamined by NexusMods user **whyslyy**.
