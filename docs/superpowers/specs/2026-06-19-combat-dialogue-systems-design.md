# MRG City — Combat, Dialogue & GTA-Systems Design
**Date:** 2026-06-19
**Phase:** 2 (post-map foundation)
**Approach:** Stack modulare — ogni sistema file separato, comunicazione via segnali Godot

---

## Architecture

Ogni sistema = Node child di Main, agganciato in `_setup_ui()` / `_ready()`.
Comunicazione tramite segnali — nessun sistema parla direttamente all'altro.

```
Main
├── PlayerStats    (hp, money, wanted_level)
├── CombatManager  (hit detection, knockdown, combo)
├── DialogueManager (frasi NPC, conversazioni a coppia)
├── WantedSystem   (stelle, spawn polizia)
├── HUD            (hp bar, money, stelle, minimappa)
└── (player.gd, npc.gd, mission_01.gd — invariati)
```

**Flusso hit:**
1. `player.gd` emette `hit_npc(npc_node)`
2. `CombatManager` → calcola danno → chiama `npc.take_hit()`
3. `npc.gd` reagisce secondo tipo (FIGHTER / CIVILIAN)
4. `WantedSystem` riceve stesso segnale → +1 stella se civile
5. `HUD` osserva `PlayerStats` e si aggiorna da solo

---

## 1. PlayerStats (`player_stats.gd`)

```gdscript
var hp: int = 100
var money: int = 0
var wanted_level: int = 0  # 0-5
signal hp_changed(new_hp)
signal money_changed(new_money)
signal wanted_changed(new_level)
```

---

## 2. HUD (`hud.gd`)

CanvasLayer con 4 elementi PS2-style:
- **HP bar** — barra rossa bassa sinistra, colore verde→giallo→rosso al calare
- **Soldi** — `€ 0` giallo basso destra, animazione +/- al cambio
- **Stelle wanted** — ⭐×5 alto destra (grigie inattive, gialle attive)
- **Minimappa** — cerchio basso sinistra via SubViewport + camera ortografica
  - dot bianco = player, dot giallo = obiettivo missione, dot rosso = polizia

**Pickup salute:** box verde emissivo in giro per mappa (parco, bar, garage, campetto).
Tocchi → +25 HP. 5 spawn fissi.

---

## 3. CombatManager (`combat_manager.gd`)

**Hitbox:** durante `_punch_timer > 0`, raycast/overlap 1.8m davanti al player.
**Danno:** colpo singolo = -25 HP NPC | combo (F×2 < 0.4s) = -45 HP NPC
**NPC HP:** 60 base. Barra HP sopra testa visibile solo quando danneggiato.

### Tipi NPC

| Tipo | Personaggi | Reazione | A 0 HP |
|------|-----------|---------|--------|
| `FIGHTER` | Huncho, Chakour, Peco + polizia | Gira, insulta, contrattacca | Knockdown 5s poi si rialza |
| `CIVILIAN` | Passanti anonimi, Behope | Insulta e scappa | Cade, si rialza, scappa |

### Insulti (Label3D sopra testa, 2 sec)

```
FIGHTER:  ["Sei morto!", "Vaffanculo!", "Ti spacco!", "Hai rotto i coglioni!"]
CIVILIAN: ["Aiuto!", "Che cavolo fai?!", "Chiamo la madama!", "Sei scemo?!"]
```

---

## 4. WantedSystem (`wanted_system.gd`)

| Stelle | Trigger | Risposta |
|--------|---------|---------|
| ⭐ | Colpisci 1 NPC civile | NPC ostili, no polizia |
| ⭐⭐ | 3+ NPC colpiti o 1 poliziotto | Spawn 1 poliziotto |
| ⭐⭐⭐ | Continui a combattere | Spawn 2 poliziotti + auto |
| ⭐⭐⭐⭐⭐ | Cap a 3 stelle per ora | Espandibile Phase 3 |

**Cooldown:** 10 sec senza danni fuori vista → stelle -1 ogni 5 sec fino a 0.
**Poliziotto:** usa `npc.gd` tipo FIGHTER, colore blu divisa, nome "Madama". Spawna 30m dal player fuori campo visivo.

---

## 5. MoneySystem

- Missione completata → +$200
- NPC FIGHTER in KO → droppa $15 a terra (pickup)
- Phase 3: negozi, economia completa

---

## 6. DialogueManager (`dialogue_manager.gd`)

### Battute al player (avvicinarsi < 4m, cooldown 8 sec per NPC)

```
Huncho:   ["Ue frat, tutto ok?", "Sei pronto per stasera?", "Non fare il coglione eh"]
Chakour:  ["Bro che fai in giro?", "Stai attento alla madama", "Vieni al campetto dopo?"]
Behope:   ["Tutto apposto?", "Hai visto Mimmo?", "Stasera si esce frat"]
Passante: ["Bella giornata eh", "Ciao", "Lasciami stare"]
```

### Conversazioni a coppia (due NPC del blocco entro 3m, ogni 6 sec)

```
Huncho → Chakour: "Hai sentito di ieri sera?"
Chakour → Huncho: "Sì bro, situazione pesante"
Huncho → Chakour: "Stasera ci becchiamo giù"

Behope → Huncho: "Che fai stanotte?"
Huncho → Behope: "Niente di speciale frat"
Behope → Huncho: "Vieni giù allora"
```

**Implementazione:** Label3D sopra NPC + Tween fade in/out. Niente grafica complessa.

---

## Implementation Order

1. `player_stats.gd` + `hud.gd` (HP bar, soldi, stelle)
2. `combat_manager.gd` + `npc.take_hit()` + insulti Label3D
3. `wanted_system.gd` + spawn polizia
4. `dialogue_manager.gd` + conversazioni a coppia
5. Pickup salute + money drop
6. Minimappa (SubViewport)
