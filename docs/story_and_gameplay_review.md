# Unrailed — Story and Gameplay Review

Build reviewed: the "Dream Intro" demo as it stands on 2026-10-25, updated the same day for the revised fig tree camp and HQ (no radio code, open box, open tower door, three photographs, the empty seat).
Written for: you, the developer, to read the whole scripted story and the gameplay flow in one sitting and mark what to change.

**How to read this.** Every line of player-facing text below is copied from `localization/en.po` and `localization/pt_BR.po` by a script, not retyped, so what you read is what the game shows. Each text appears in English (**EN**) and Brazilian Portuguese (**PT**). Section 6 lists the things I noticed while putting this together (contradictions, leftovers, placeholders). Nothing in the game was changed for this document.

---

## 1. The demo in one page

**Premise.** Juliana wakes in the wagon of a dead train, at night, with a ticket on the seat across the aisle that has her name on it and, on the back, "I SAVED YOU A SEAT." She steps into a forest with three trails. Each trail holds a memory of her and her childhood friend Sophia (and Lucas, Sophia's boyfriend) and gives her one brass telephone token, a *ficha*. With all three she can call from the payphone at the overlook above the town. Sophia answers, in two voices that contradict each other. When the line goes dead the town's lights go out, and Juliana wakes in the wagon again, where something is waiting.

**Who is who (as the texts present them).**

| Character | What the texts say |
|---|---|
| **Juliana** | The player. Writes the "— Juliana" notes. Her badge and prescription (an earlier real world chapter) say she works nights at the railway line and has anxiety and insomnia. Sees what others are afraid to look at ("dead eyes like the birds that drown in the reservoir"). |
| **Sophia** | Juliana's closest friend since childhood and, in the house memories, Lucas's partner. Left for the capital / São Paulo by bus. The "— Sophia" notes are hers. On the phone she is two voices at once. |
| **Lucas** | Sophia's boyfriend. Mechanic, "brute force can fix the machinery". His notebook ends "She is mine forever." His ficha is scratched NEVER LEFT. |
| **Juliana's mother** | Never seen. The narration, in Juliana's voice, says she was "just trying to protect me" and kept the family stories from her, and that "only one of us" is left. |
| **The town "Fenda"** | The trailhead sign: "Bem-vindo à" over a defaced old name, with "Fenda" ("crack") painted in red on top, as if by the children. |

**Structure.**

```
 main menu cinematic (narration)      New Game
              |
      THE WAGON  -- wake up, ticket, flashlight
              |
      fence gate -- trailhead signs, the forest map (key M)
              |
   ---------- three trails, any order, all revisitable ----------
   |                          |                             |
 A. NORTH LOOP            B. MIDDLE                     C. SOUTH
 railway radio            waiting shed                  unfinished house
 fig tree camp            signal box                    time capsule
 signal tower (HQ)        (lever puzzle)                (haunted house)
   |                          |                             |
 Juliana's ficha (1)      Sophia's ficha (3)            Lucas's ficha (2)
   ---------------------------+-----------------------------
              |
      OVERLOOK -- payphone, three fichas, the call
              |
      lights of the town go out
              |
      THE WAGON AGAIN -- the girl, the whisper, the door, the struggle
              |
      title card "UNRAILED" -- back to the main menu (demo complete)
```

**What exists and what does not.**

| Playable now | Not in the demo |
|---|---|
| Everything above, start to finish, in English and Portuguese. | Voice acting: every voice, the girl's crying, the creature's sounds and the music are placeholder or absent. The story is carried by captions. |
| Captions on by default; their language is separate from the interface language. | Real art for the photographs (they are labelled cards), and several stand-in 3D models. |
| Saving and Continue (see section 2). | The real world town (`town_blockout`, chapter 1 items such as the prescription and the badge) is a blockout, not reachable from New Game. |

---

## 2. How it plays

**Controls (defaults, all rebindable under Options, Controls).** W A S D move; Shift walks faster (hold, or toggle in the options); E interacts (open, pick up, read, insert); F flashlight; I inventory; M the forest map once taken; Esc pause; Space skips the main menu cinematic; Enter continues a dialogue. There is **no jump and no crouch**, on purpose. A developer console exists in debug builds only (backquote key).

**The player is small.** The capsule is child sized (about 1 m tall, eyes about 1.25 m up), and everything is built to be seen from that height.

**Movement and the ground (new this week).** Walking pace is slow (1.3 m/s) and the fast pace modest (2.3 m/s). The pace follows the slope: uphill is slower (down to 0.6 at about 32 degrees), downhill quicker (up to 1.2 at about 13 degrees). The body follows: uphill the steps are shorter and heavier, the head leans in and the breath turns heavy; downhill the steps are longer and the heels come down hard. **Stairs** have their own dramatic walk: slower, careful, with a creak on wooden ones. The "Head bobbing" option turns every procedural camera motion off for comfort.

**The flashlight** is the main tool. It is a real light with a small start-up flicker. Scenes take it over on purpose: the house trap makes it stutter; the wagon finale weakens it. The camp's memory leaves it alone.

**Interaction.** A short prompt names what E will do ("[E] Open", "Inspect Radio", "Insert ficha 2", "Pick up Receiver"). Things fall in three groups:
- *Taken* (collectibles): photographs, keys, fichas. They go to the inventory, which has no limit, and can be inspected again later.
- *Read in place* (inspectables): notes, journals, the radio, the thermos. They open a close inspect view (drag turns the object, wheel zooms, E reads a detail, R turns the object over) and stay where they lie.
- *Puzzle screens*: the photo album (drag and drop), the payphone.

**Captions** are the game's only voice. They are used for Juliana's few spoken thoughts, the narration, the cassette recording and the phone call, and have size options. Writing rules followed so far: notes contain no hyphens (signatures use "— Sophia", "— Juliana", "— Lucas"), and long texts are paragraphs.

**Teaching.** Three short hints, each shown once and switchable off in the options: the flashlight (EN: “Press F to turn on the flashlight” · PT: “Pressione F para ligar a lanterna”), walking faster (shown a few steps past the gate) and the inventory (at the first pickup). The map has its own hint when it is first taken.

**Saving.** Three slots. There are no automatic checkpoints: the player saves from the pause menu, which records the position, the inventory and the state of every puzzle. Saving is blocked during scripted scenes (the recording, the house trap, the call, the finale). Loading a manual save skips the wake-up. When the ending is reached the game stores "demo complete" and a snapshot of the overlook, so Continue puts the player back there with the three fichas in the payphone and the receiver still to pick up.

**Atmosphere.** Night, dense fog, a camcorder style filter with a slight fisheye, and almost no light but the flashlight. The fog and the view stay closed through the forest and open up only in the last stretch to the overlook, so the town is first seen from the plaza.

---

## 3. The story in play order

### 3.1 Main menu cinematic and the narration

Before anything is played, the main menu runs a slow cinematic over a fogged forest. A short narration, spoken by Juliana, plays over it (the audio file is still named `intro_placeholder`), captioned in the caption language. These five lines are the only statement of the story's premise before the game starts:

| Time | EN | PT |
|---|---|---|
| 10.0 to 17.5 s | I'm sure my mom was just trying to protect me. | Tenho certeza de que minha mãe só estava tentando me proteger. |
| 18.0 to 19.8 s | Now that there's only one of us left. | Agora que só resta um de nós. |
| 20.0 to 25.0 s | I thought it was time I heard the stories. | Achei que era hora de ouvir as histórias. |
| 26.0 to 32.5 s | But now I'm worried the stories themselves might be the problem. | Mas agora temo que as próprias histórias possam ser o problema. |
| 33.0 to 39.5 s | Maybe we believed so much in a family curse, we made it real. | Talvez a gente tenha acreditado tanto numa maldição de família que a tornou real. |

Held Space skips the cinematic. The menu title is "Unrailed".

### 3.2 The wagon

*New Game, then a slot.* The screen is black. Juliana wakes lying on a bench (a slow head raise), the wagon shakes and its warm lights flicker against a dark, cold outside where the scenery loops. The lights die and she is free to move; the flashlight hint appears: EN: “Press F to turn on the flashlight” · PT: “Pressione F para ligar a lanterna”

On the cushion across the aisle lies **the train ticket**. It is the first object and the first mystery.

**Item: Train Ticket** (PT-BR: *Bilhete de Trem*)  
*Inventory text, EN:* A single ticket left on the seat opposite yours. It has your name on it. The date says tonight.  
*Inventory text, PT-BR:* Um único bilhete deixado no banco à sua frente. Tem o seu nome. A data diz: hoje à noite.

Front (shown first), one line per row on the card:

> **EN**  
> PASSENGER: JULIANA [SURNAME]  
> DESTINATION: [TOWN NAME]  
> DEPARTURE:  
> ARRIVAL: 03:17  
> DATE: TONIGHT
>
> **PT-BR**  
> PASSAGEIRA: JULIANA [SOBRENOME]  
> DESTINO: [NOME DA CIDADE]  
> PARTIDA:  
> CHEGADA: 03:17  
> DATA: HOJE À NOITE

Back (turn it over with R):

> **EN**  
> I SAVED YOU A SEAT.
>
> **PT-BR**  
> GUARDEI UM LUGAR PRA VOCÊ.

Juliana speaks twice (captions), once on each side:

- Opening the front: EN: “I don't remember buying this...” · PT: “Não lembro de ter comprado isso...”
- Turning it over: EN: “That's not her handwriting.” · PT: “Essa não é a letra dela.”

Then she leaves through the wagon door into the forest. The wagon is empty and silent.

### 3.3 The trailhead: signs, gate and map

A short way from the wagon is a fence with a heavy wooden gate. Two signs stand beside it, built to look like the signs of a real public park trail in the 1990s:

- **The welcome sign**, facing the wagon door. It reads "Bem-vindo à" and, under it, the old name "TRILHA DA SERRA", which cannot be read any more because it is covered in red paint and scratches. Over that someone painted, crooked, with drips, **"Fenda"**. These words are the same in both languages, because the sign belongs to the park and to the children.
- **The trail map board**, with no name written on it, and a hand drawn **map pinned in its window**.

Walking up to the map frames it close, then **tearing it from the board** is a 3.9 second scene: the flashlight swings onto the paper, two top pins are worked loose, the paper sags, it is yanked free and the bottom pins stay behind with scraps of paper under them. The player holds it up, fills the screen with it on purpose (so they have to put it away after a while), and can walk while it is open.

**Item: Forest Map** (PT-BR: *Mapa da Floresta*)  
*Inventory text, EN:* A hand drawn map of the trails, taken from the board at the start of the path.  
*Inventory text, PT-BR:* Um mapa desenhado à mão das trilhas, tirado do painel no começo do caminho.

The map is a drawing of the actual trails, baked from the game world, with these places named (each label is a translated text):

| Place | EN | PT |
|---|---|---|
| Title | The Trails | As Trilhas |
| The gate | Fence Door | Porta da Cerca |
| The railway | Railway | Ferrovia |
| Path B | Waiting Shed | Abrigo de Espera |
| Path A | Fig Tree Clearing | Clareira da Figueira |
| Path A | Signal Tower | Torre de Sinalização |
| Path C | Unfinished House | Casa Inacabada |
| End | Overlook | Mirante |

It does not show where the player is. Hints: EN: “Press M to open the map” · PT: “Pressione M para abrir o mapa”; walking faster: EN: “Hold Shift to walk faster” · PT: “Segure Shift para andar mais rápido”

Nothing says where to go. The three trails are told apart by what they look like, not by markers.

### 3.4 The three trails (any order)

| | A. North loop | B. Middle | C. South |
|---|---|---|---|
| Places | Railway radio, fig tree camp, signal tower | Waiting shed beside the old railway | Unfinished house |
| Mood | Camp at night, warm fire, a rain recording | Open concrete shelter, cold light | A house that is wrong |
| Puzzle | Photo album (three photographs, camp and HQ) | Order of three objects, three levers | Locked rooms, a notebook, a trap |
| Memory told | The friendship (photographs, a recording) | Sophia's secret code and Lucas's temper | Lucas and Sophia's love and the red room |
| Reward | **Juliana's ficha (1)** | **Sophia's ficha (3)** | **Lucas's ficha (2)** |

---

### 3.5 Trail A: the fig tree camp

*Arriving.* The trail comes in from the west and arrives at a clearing under a huge fig tree. The first thing the player meets, at the western entrance, is **the railway radio** on a crate. It hisses faintly on a dead channel and its small red lamp glows, so it is heard before it is seen.

**The railway radio** (inspect, read in place; scenery, not a clue). Heavy grey green transmitter, a red needle resting between two printed numbers on its dial, the slider clamped by a bar with two bolts and red sealing wax, a strip of old masking tape above the dial that says HQ.

**Item: Railway Radio** (PT-BR: *Rádio Ferroviário*)  
*Inventory text, EN:* A heavy grey green transmitter from the nineties, the kind the railway kept in its signal huts. Its tuning slider is clamped in place, and a strip of old masking tape above the dial says HQ.  
*Inventory text, PT-BR:* Um transmissor pesado, verde acinzentado, dos anos noventa, daqueles que a ferrovia guardava nas casinhas de sinalização. O seletor de frequência está preso por uma trava, e uma tira de fita crepe velha acima do mostrador diz HQ.

Reading its panel:

> **EN**  
> An old railway transmitter marked HQ.
>
> **PT-BR**  
> Um velho transmissor ferroviário marcado com HQ.

*The camp.* A campfire burns from the start (flames, embers, crackle), ringed by three log seats and a kettle on a stone. Two tents face the fire, each with gear in front (a backpack and a rolled mat, a pair of boots). A wood yard with a chopping block and an axe, a firewood stack, and a clothesline between two trees with a damp mustard coloured jacket (dressing only; nothing to find there). A table by the trail ("the memory table"), lit by a hurricane lantern, holds a **cassette recorder** whose reels turn in silence, a **photo album**, an enamel cup and the photograph *Bus Stop Departure*. There is no gate or wall; the player can walk in and out whenever they like.

**The log table**: a thermos and a green steel lockbox with the letters J and S painted on the lid, standing open.

**Item: Weathered Thermos** (PT-BR: *Garrafa Térmica Gasta*)  
*Inventory text, EN:* A dented green steel thermos, long gone cold. A strip of paper is tied round its middle with twine and held by a brass pin.  
*Inventory text, PT-BR:* Uma garrafa térmica de aço verde, amassada, fria há muito tempo. Uma tira de papel está amarrada no meio dela com barbante e presa por um alfinete de latão.

Reading the strip tied round it (Sophia's hand):

> **EN**  
> Juli, the photo of us as kids is still on the desk at HQ. Don't drink all the coffee at once. — Sophia
>
> **PT-BR**  
> Juli, a foto de quando a gente era pequena ficou na mesa do QG. Não bebe o café todo de uma vez. — Sophia

**The J & S lockbox** stands open from the start, its lid up and its four thumb wheels only dressing: there is no code and nothing to work. On its padding lies the photograph **Old Photograph: Rain at the Station**, and nothing else.

**Photographs.** Three photographs belong in the album, and they are the only ones: two in the camp, one at the HQ.

| Photograph | Where | Space in the album |
|---|---|---|
| Old Photograph: Scraped Knee | Tower, HQ desk | First |
| Old Photograph: Rain at the Station | Camp, in the open lockbox | Second |
| Old Photograph: Bus Stop Departure | Camp, on the memory table beside the album | Third |

(The three red herrings of earlier versions, *Old Photograph: Lucas at the Workshop*, *Old Photograph: The Broken Lever* and *Old Photograph: The Foggy Platform*, are no longer in the world. Their scenes and texts stay so that an old save that carries one still shows it; their texts are in the appendix.)

Each photograph is picked up, looked at, and turned over. Descriptions (what the inventory says), then the handwriting on the back (what the player reads when they turn it over):

**Item: Old Photograph: Scraped Knee** (PT-BR: *Foto Antiga: Joelho Ralado*)  
*Inventory text, EN:* Two girls sit beneath the same fig tree. One has a scraped knee; the other is wrapping it with a strip torn from her school shirt. The edges are ragged, as if it was pulled out of an album.  
*Inventory text, PT-BR:* Duas meninas sentadas debaixo da mesma figueira. Uma está com o joelho ralado; a outra o enfaixa com uma tira rasgada da própria camisa da escola. As bordas estão irregulares, como se a foto tivesse sido arrancada de um álbum.

> **EN**  
> July 1988. She fell on the gravel behind the signal tower. She swore something under the floorboards grabbed her ankle. I told her it was just a loose wire. I lied. I saw it too.
>
> **PT-BR**  
> Julho de 1988. Ela caiu no cascalho atrás da torre de sinalização. Jurou que algo debaixo do assoalho agarrou o tornozelo dela. Eu disse que era só um fio solto. Menti. Eu também vi.

**Item: Old Photograph: Rain at the Station** (PT-BR: *Foto Antiga: Chuva na Estação*)  
*Inventory text, EN:* Two girls under one small umbrella in heavy rain. Almost all of it is tilted over one of them; the other one's outer shoulder is soaked. A faint ring from a wet cup stains the back.  
*Inventory text, PT-BR:* Duas meninas sob um guarda-chuva pequeno em meio a uma chuva forte. Quase todo ele está inclinado sobre uma delas; o ombro de fora da outra está encharcado. Um anel fraco, de um copo molhado, mancha o verso.

> **EN**  
> 1995. It poured for three hours. Sophia insisted on giving me the drier side. She ended up with a cold for a week, but she just laughed about it.
>
> **PT-BR**  
> 1995. Choveu por três horas. A Sophia insistiu em me dar o lado mais seco. Acabou resfriada por uma semana, mas só riu disso.

**Item: Old Photograph: Bus Stop Departure** (PT-BR: *Foto Antiga: Partida no Ponto de Ônibus*)  
*Inventory text, EN:* A young woman stands alone at a rural bus stop above the road out of town, holding something folded. There is handwriting on the back.  
*Inventory text, PT-BR:* Uma jovem está sozinha num ponto de ônibus rural, acima da estrada que sai da cidade, segurando algo dobrado. Há uma frase escrita no verso.

> **EN**  
> The day she said she was leaving for the capital. She kept looking over my shoulder at the trees behind me, like she was waiting for someone to stop her.
>
> **PT-BR**  
> O dia em que ela disse que ia embora para a capital. Ela não parava de olhar por cima do meu ombro, para as árvores atrás de mim, como se esperasse que alguém a impedisse.

What the faces of the three album photographs show (these are placeholder cards for now; the age in the label is the second clue):

- [Placeholder photo: Two Girls under the Fig Tree. They are about 8 years old.]
- [Placeholder photo: Two Girls under an Umbrella. They are about 15.]
- [Placeholder photo: Sophia at the Bus Stop. She is about 28.]

Juliana comments on two of them while the player looks:
- Opening *Rain at the Station*: EN: “You said the rain made everything smell new.” · PT: “Você dizia que a chuva deixava tudo com cheiro de novo.”
- Turning over *Bus Stop Departure*: EN: “I said I would.” · PT: “Eu disse que iria.”

**The album puzzle.** E on the album (Open album) opens a close up of three empty spaces, each with a faded pencil caption, and a tray with the photographs in hand. The player drags photographs onto spaces, swaps them, or takes them back. Nothing reacts to a single placement.

| Space | EN caption | PT caption |
|---|---|---|
| 1 | When we were little. | Quando éramos pequenas. |
| 2 | The year of the rain. | O ano da chuva. |
| 3 | Not long ago. | Há pouco tempo. |

Hint line under the album: EN: “Drag a photograph onto a space. Drag it again to move it or take it back. Right click or Esc to close.” · PT: “Arraste uma fotografia para um espaço. Arraste de novo para mover ou pegar de volta. Botão direito ou Esc para fechar.”

The first time the album is opened, Juliana says: EN: “Why this place?” · PT: “Por que aqui?”

When all three spaces are full the album is judged. A wrong arrangement gives a short burst of static and everything stays where it is, to be moved or taken back. The right one (childhood, rain, bus stop) locks the album and the close up closes. The album can still be opened to look.

**The recording.** The cassette tape stops, pauses, rewinds, and plays: rain round two voices as captions, with the fire still burning. Nothing blocks the player; they may walk away and it plays out.

| Time | Speaker | EN | PT |
|---|---|---|---|
| 3.5 to 6.0 s | Sophia | You don't have to wait for me. | Você não precisa me esperar. |
| 6.6 to 8.2 s | Juliana | Of course I do. | Claro que preciso. |
| 8.8 to 11.2 s | Sophia | Juli, I said you don't have to. | Juli, eu disse que você não precisa. |
| 11.8 to 14.4 s | Juliana | I know. That's why I want to. | Eu sei. É por isso que eu quero. |
| 17.0 to 20.6 s | Sophia | You always make it impossible to be angry with you. | Você sempre torna impossível ficar brava com você. |
| 21.2 to 22.4 s | Juliana | Good. | Ótimo. |

Speaker labels read "Sophia (recording)" and "Juliana (recording)".

**The empty seat.** After Juliana's "Good." the reels stop with a clunk and the rain stops with them. A second and a half of quiet. Then Sophia's last line comes once, plainly, from an empty log by the fire, not from the tape, under her own name ("Sophia"):

| Speaker | EN | PT |
|---|---|---|
| Sophia | That isn't always a good thing. | Isso nem sempre é uma coisa boa. |

A moment later the log gives a short creak and something shifts there, as if someone got up. Then, at once, the fire is cold ash, and on that log lies **Juliana's ficha** (number 1), with a small clink. Nothing appears; the lantern on the memory table and the radio stay as they are, and the flashlight stays in the player's hands. The game cannot be saved from the moment the album is solved until the ficha lies on the log.

**Item: Juliana's Ficha** (PT-BR: *Ficha da Juliana*)  
*Inventory text, EN:* A brass telephone token. Blue nail polish is chipped on its rim.  
*Inventory text, PT-BR:* Uma ficha de telefone de latão. O esmalte azul está lascado na borda.

Inspecting its back shows scratched letters:

- CALL HER / LIGUE PARA ELA

The fichas are marked on the face "TELEFONE".

---

### 3.6 Trail A: the signal tower (the children's HQ)

A ruined two level signal tower stands in a dark bowl east of the camp: a red brick relay room below, a green and yellow siding control cabin above, a stair and balcony up one side, ivy on the brick. The light inside is only the player's flashlight.

**The front door** opens like any door: no key, nothing pinned to it. The balcony door to the control cabin is not locked either. So the camp and the HQ can be visited in either order; the thermos at the camp says the childhood photo is on the HQ desk.

**The headquarters (inside the relay room)** is laid out in three zones round an open aisle. Everything is reachable by walking the aisle:

1. **The desk** (back left: two crates and a plank, two stools, a green desk lamp). The photograph *Scraped Knee* lies flat in the middle of the plank. Under the plank, between the crates, is a **drawer** with a simulated, weighty slide and a sound that is generated from the same motion. In the drawer lies Juliana's note.
2. **The bench** (right wall). Sophia's folded letter lies on the cushion.
3. **The low shelf** (back). An empty tin, and a few of a child's things on the lower board.

**Item: Juliana's Note** (PT-BR: *Bilhete da Juliana*)  
*Inventory text, EN:* A page torn from a school notebook, folded once and left in the desk drawer. A small face with a fringe is drawn in the corner.  
*Inventory text, PT-BR:* Uma folha arrancada de um caderno escolar, dobrada uma vez e deixada na gaveta da mesa. Um rostinho de franja está desenhado no canto.

> **EN**  
> October 1989. The butcher's wife told Sophia at the market that I have dead eyes like the birds that drown in the reservoir during heavy rain. Sophia didn't get angry or shout. She just smiled, took a long bite of her apple, and said, 'Juliana sees the things you're too afraid to look at.' Then she handed me the core and told me to plant it right behind the signal tower so we could watch it grow out of the gravel. She is the only person who doesn't lower her voice when I walk into a room. — Juliana
>
> **PT-BR**  
> Outubro de 1989. A mulher do açougueiro disse à Sophia, no mercado, que eu tenho olhos mortos como os pássaros que se afogam no reservatório quando chove forte. A Sophia não ficou brava nem gritou. Só sorriu, deu uma mordida demorada na maçã e disse: 'A Juliana enxerga as coisas que vocês têm medo demais de olhar.' Depois me entregou o miolo e mandou plantar bem atrás da torre de sinalização, para vermos crescer no meio do cascalho. Ela é a única pessoa que não baixa a voz quando eu entro numa sala. — Juliana

**Item: Sophia's Folded Letter** (PT-BR: *Carta Dobrada da Sophia*)  
*Inventory text, EN:* A sheet of graph paper folded in four, left on the bench cushion with one corner turned back.  
*Inventory text, PT-BR:* Uma folha de papel quadriculado dobrada em quatro, deixada sobre a almofada do banco com um canto virado para trás.

> **EN**  
> To the Chief Operator of HQ No. 1: I overheard my father talking to the station master last night. They think the town is going to close the northern line before winter because the ground keeps shifting under the ties. My father said this place is built on a hollow crust that is slowly caving in. I told him he was being paranoid. But if the tracks do collapse and the trains stop coming, we are keeping this tower, Juli. We will lock the bottom door, pull up the stairs, and let the fog swallow the rest of the valley. — Sophia
>
> **PT-BR**  
> Para a Chefe de Operações do QG Nº 1: Ouvi meu pai conversando com o chefe da estação ontem à noite. Eles acham que a cidade vai fechar a linha norte antes do inverno porque o chão não para de se mexer debaixo dos dormentes. Meu pai disse que este lugar foi construído sobre uma crosta oca que está desabando devagar. Eu disse que ele estava sendo paranoico. Mas se os trilhos desabarem e os trens pararem de vir, nós vamos ficar com esta torre, Juli. Vamos trancar a porta de baixo, puxar a escada e deixar a neblina engolir o resto do vale. — Sophia

**The control cabin** (upstairs) has five heavy iron interlocking levers on a floor frame (the fourth is Lucas's: snapped off short, its top lying on the floor), a stove, a desk with a telegraph and log book, and a bench. It also holds four documents about the town's strange history. They are read in place, are not signed, and name no main character:

**Item: Newspaper Clipping** (PT-BR: *Recorte de Jornal*)  
*Inventory text, EN:* A yellowed clipping from a local paper, folded in four and left on the desk. The corners have gone soft from handling.  
*Inventory text, PT-BR:* Um recorte amarelado de um jornal local, dobrado em quatro e deixado sobre a mesa. Os cantos ficaram macios de tanto manuseio.

> **EN**  
> LOCAL POLICE BRIEF (MAY 1984): Search efforts along the northern rail cutting have been suspended. Maintenance worker E. Silva reported hearing his missing seven year old daughter calling his name from inside the drainage culvert near Mile Marker 4. Search teams examined the pipe and confirmed it has been completely filled with solid granite since 1962. Mr. Silva remains under psychiatric observation following his refusal to stop digging into the stone with his bare hands.
>
> **PT-BR**  
> BREVE POLICIAL LOCAL (MAIO DE 1984): As buscas ao longo do corte ferroviário do norte foram suspensas. O funcionário de manutenção E. Silva afirmou ter ouvido sua filha desaparecida, de sete anos, chamando o nome dele de dentro do bueiro de drenagem perto do Marco de Milha 4. As equipes de busca examinaram o cano e confirmaram que ele está completamente preenchido com granito maciço desde 1962. O Sr. Silva continua sob observação psiquiátrica depois de se recusar a parar de cavar a pedra com as próprias mãos.

**Item: Internal Memo** (PT-BR: *Memorando Interno*)  
*Inventory text, EN:* A typed memorandum pinned to a board on the lever frame, a red stamp smudged across the bottom.  
*Inventory text, PT-BR:* Um memorando datilografado, preso a uma tábua na estrutura das alavancas, com um carimbo vermelho borrado no rodapé.

> **EN**  
> INTERNAL MEMORANDUM (1989): To all signal tower operators: Effective immediately, do not record fog shadows in the official station logbook. Operator M. Santos was relieved of duty last night after stopping three freight trains for non existent obstructions. He insists a woman in a black dress was standing in the center of the tracks holding her head in her hands. Medical officers attribute his vision to severe sleep deprivation and carbon monoxide fumes from the coal heater.
>
> **PT-BR**  
> MEMORANDO INTERNO (1989): A todos os operadores das torres de sinalização: Com efeito imediato, não registrem sombras de neblina no livro de registro oficial da estação. O operador M. Santos foi afastado do serviço na noite passada depois de parar três trens de carga por obstáculos inexistentes. Ele insiste que uma mulher de vestido preto estava parada no meio dos trilhos, segurando a própria cabeça com as mãos. Os médicos atribuem a visão à privação severa de sono e aos gases de monóxido de carbono do aquecedor a carvão.

**Item: Operator's Journal Page** (PT-BR: *Página do Diário do Operador*)  
*Inventory text, EN:* A ruled page torn from a journal, written in a shaky hand. It rests on the very edge of the bench, as if it might fall.  
*Inventory text, PT-BR:* Uma página pautada arrancada de um diário, escrita com mão trêmula. Está na beirada do banco, como se pudesse cair a qualquer momento.

> **EN**  
> November 12. My wife says I am losing my mind because I keep measuring the floorboards with a ruler every morning. She does not understand. The distance between the door and the window was four meters on Monday. Today it is four meters and twelve centimeters. The house is stretching. Or maybe my eyes are failing me just like my father told me they would. I cannot sleep when the wood creaks because it sounds like the walls are catching their breath.
>
> **PT-BR**  
> 12 de novembro. Minha esposa diz que estou perdendo a cabeça porque toda manhã eu meço as tábuas do assoalho com uma régua. Ela não entende. A distância entre a porta e a janela era de quatro metros na segunda. Hoje são quatro metros e doze centímetros. A casa está esticando. Ou talvez minha vista esteja falhando, assim como meu pai me avisou que aconteceria. Não consigo dormir quando a madeira range, porque parece que as paredes estão recuperando o fôlego.

**Item: Public Health Notice** (PT-BR: *Aviso de Saúde Pública*)  
*Inventory text, EN:* A printed municipal notice, taped to the window frame by its top corners. The tape has dried and curled.  
*Inventory text, PT-BR:* Um aviso municipal impresso, colado ao caixilho da janela pelos cantos de cima. A fita secou e está enrolando.

> **EN**  
> MUNICIPAL HEALTH ANNOUNCEMENT (1991): Residents living near the forest line are advised that severe valley acoustic resonance during heavy fog can cause auditory illusions including knocking sounds, whispered names, and perceived footsteps. Doctors confirm these sensations are harmless neurological responses to prolonged atmospheric isolation. Please keep your doors locked and remain inside after dusk.
>
> **PT-BR**  
> AVISO DA SAÚDE MUNICIPAL (1991): Os moradores próximos à linha da floresta são informados de que a forte ressonância acústica do vale durante a neblina intensa pode causar ilusões auditivas, incluindo batidas, nomes sussurrados e passos percebidos. Os médicos confirmam que essas sensações são respostas neurológicas inofensivas ao isolamento atmosférico prolongado. Mantenha as portas trancadas e permaneça dentro de casa após o anoitecer.

The tower has no scripted scare. It is decay and reading.

---

### 3.7 Trail B: the waiting shed and the signal box

The middle trail ends at a small irregular clearing where the old railway crosses the woods in a cutting. A 1950s concrete shelter on slim pillars, with its corner broken, a bench, a mile marker reading "KM 214", a signal box at the shelter's end with three levers and a coin tray, and the rails running into the dark under thick bushes. No rain, no sound.

**Sophia's notebook** lies open on the bench, as if she had only just stepped away, with her backpack beside it. It is the whole riddle:

**Item: Sophia's Notebook** (PT-BR: *Caderno da Sophia*)  
*Inventory text, EN:* Left open on the bench, as if she had only just stepped away.  
*Inventory text, PT-BR:* Deixado aberto no banco, como se ela tivesse acabado de sair.

Left page:

> **EN**  
> Lucas thinks he can force his way through everything with a wrench.
>
> He doesn't get that this old junction box follows a sequence. Remember our secret code for catching the night train, Juli?
>
> **PT-BR**  
> O Lucas acha que consegue passar por tudo à força com uma chave inglesa.
>
> Ele não entende que essa velha caixa de junção segue uma sequência. Lembra do nosso código secreto para pegar o trem da noite, Juli?

Right page (the order of the three levers):

> **EN**  
> First, you light the track.  
> Then, you punch the ticket.  
> Finally, you blow the signal.
>
> **PT-BR**  
> Primeiro, você ilumina os trilhos.  
> Depois, você fura o bilhete.  
> Por fim, você apita o sinal.

**The three objects** are hidden, each in its own place, and each carries a phrase scratched where the player has to turn the object to find it:

| Object | Where it is hidden | Phrase scratched on it | Means |
|---|---|---|---|
| Rusted Railway Lantern (first, "light the track") | Lying in tall weeds beside the rails, where they run into the trees | "Keep your light above the fog." (underside of the base) | UP |
| Brass Ticket Hole-Puncher (second, "punch the ticket") | In a closed wooden box under the bench; E opens its lid | "Press deep into the paper." (back of one arm) | DOWN |
| Carved Wooden Whistle (third, "blow the signal") | Hanging on a hook on the back of the iron mile marker | "Stand tall and make some noise!" (back flat side) | UP |

**Item: Rusted Railway Lantern** (PT-BR: *Lanterna Ferroviária Enferrujada*)  
*Inventory text, EN:* An old brass railway lantern used by night watchmen.  
*Inventory text, PT-BR:* Uma velha lanterna ferroviária de latão, usada por vigias noturnos.

**Item: Brass Ticket Hole-Puncher** (PT-BR: *Furador de Bilhetes de Latão*)  
*Inventory text, EN:* A heavy, cast-iron conductor's ticket puncher.  
*Inventory text, PT-BR:* Um pesado furador de bilhetes de ferro fundido, de condutor.

**Item: Carved Wooden Whistle** (PT-BR: *Apito de Madeira Entalhado*)  
*Inventory text, EN:* A hand-carved conductor's whistle on a faded lanyard.  
*Inventory text, PT-BR:* Um apito de condutor entalhado à mão, preso a um cordão desbotado.

**The levers.** Three real 3D levers on the signal box. The prompt reads "Pull lever N down" or "Push lever N up" (the number is the lever's). The sequence that opens the box is **UP, DOWN, UP**; they start DOWN, UP, DOWN, so each has to be thrown at least once. A wrong combination does nothing but make a lever sound. A right one gives an iron clank and Sophia's ficha and a note slide out of the chute into the coin tray.

**Item: Sophia's Ficha** (PT-BR: *Ficha da Sophia*)  
*Inventory text, EN:* A brass telephone token. Number three.  
*Inventory text, PT-BR:* Uma ficha de telefone de latão. Número três.

**Item: Note on the Ficha** (PT-BR: *Bilhete da Ficha*)  
*Inventory text, EN:* Tied to the token with a thread.  
*Inventory text, PT-BR:* Preso à ficha por um fio.

> **EN**  
> I knew you'd find it, Juli. You're the only one who actually pays attention.
>
> Take the token to the top of the hill — let's make that call.
>
> **PT-BR**  
> Eu sabia que você ia achar, Juli. Você é a única que realmente presta atenção.
>
> Leve a ficha até o topo do morro — vamos fazer essa ligação.

---

### 3.8 Trail C: the unfinished house

The south trail slopes down into a hollow where a pale, unfinished house stands, windows without glass, the front facade glowing faintly in the fog. The player first sees it from above and walks down into it. It has a front door into the living room, a kitchen, a hallway, a pantry, and a master bedroom. The beats run in this order: kitchen, pantry, bedroom, trap, exit.

**1. The kitchen.** The recipe on a grease stained market wrapper. Reading it unlocks the pantry door with a loud bolt click somewhere out of sight, and 0.8 seconds later the pantry door swings gently open.

**Item: Market Wrapper and Recipe** (PT-BR: *Embrulho da Feira e Receita*)  
*Inventory text, EN:* A grease-stained market paper wrapper with handwritten notes on the back.  
*Inventory text, PT-BR:* Um embrulho de papel da feira, manchado de gordura, com anotações à mão no verso.

> **EN**  
> The very first time we tried to cook a real meal together. You insisted on making your mother's potato soup to impress me, but you spilled water and oil all over the floorboards.
>
> Before I could grab a rag, you slipped hard and cracked your head against the counter. You sat on the floor bleeding from your temple, staring past me at the concrete sink right where someone would stand to wash the dishes.
>
> You swore Juliana was standing there in the dark, holding a note in her hands and reading it in silence. I turned around, but the space was empty. I told you that you were just delirious from the knock on your head. Pff... You only saw her because you hated how close we were.
>
> S.
>
> **PT-BR**  
> A primeira vez que tentamos cozinhar uma refeição de verdade juntos. Você insistiu em fazer a sopa de batata da sua mãe para me impressionar, mas derramou água e óleo por todo o assoalho.
>
> Antes que eu pudesse pegar um pano, você escorregou feio e bateu a cabeça na bancada. Ficou sentado no chão, sangrando na têmpora, olhando por cima de mim para a pia de concreto, bem onde alguém ficaria para lavar a louça.
>
> Você jurou que a Juliana estava ali no escuro, segurando um bilhete e lendo em silêncio. Eu me virei, mas não havia ninguém. Falei que você só estava delirando por causa da pancada na cabeça. Pff... Você só a viu porque odiava o quanto nós éramos próximas.
>
> S.

Juliana, after reading: EN: “I remember her telling me about that soup months ago... she couldn't stop laughing.” · PT: “Lembro dela me contando sobre aquela sopa meses atrás... ela não parava de rir.”

**2. The pantry.** A folded note and a rusty key lie a little apart on the middle shelf.

**Item: Folded Note** (PT-BR: *Bilhete Dobrado*)  
*Inventory text, EN:* A note left on the pantry shelf.  
*Inventory text, PT-BR:* Um bilhete deixado na prateleira da despensa.

> **EN**  
> Trapped inside this tiny dark pantry while your family yelled at each other in the dining room.
>
> The air was dusty and smelled like old wood. Your hands were shaking in mine while we held our breath, terrified someone would pull the door open and catch us.
>
> When you finally leaned down and kissed me in the pitch dark, the shouting outside just faded away into nothing. I remember thinking right then that I never wanted to step back out into that hallway.
>
> S.
>
> **PT-BR**  
> Presos dentro desta despensa minúscula e escura enquanto sua família gritava uns com os outros na sala de jantar.
>
> O ar estava empoeirado e cheirava a madeira velha. Suas mãos tremiam nas minhas enquanto prendíamos a respiração, com medo de que alguém abrisse a porta e nos flagrasse.
>
> Quando você finalmente se inclinou e me beijou no escuro total, os gritos lá fora sumiram em nada. Lembro de pensar, bem ali, que eu nunca quis voltar para aquele corredor.
>
> S.

The first time the note is read, muffled arguing fades in from the hallway, and a second later the pantry door quietly closes by itself. The arguing goes on until the player opens the door again.

**Item: Rusty Key** (PT-BR: *Chave Enferrujada*)  
*Inventory text, EN:* A rusty, well-used key.  
*Inventory text, PT-BR:* Uma chave enferrujada, muito usada.

**3. The bedroom** is locked; the rusty key opens it (the key is consumed). In the nightstand drawer is Lucas's notebook.

**Item: Lucas's Notebook** (PT-BR: *Caderno do Lucas*)  
*Inventory text, EN:* An entry in a leather-bound diary.  
*Inventory text, PT-BR:* Uma anotação em um diário encadernado em couro.

Heading on the page: "May 14th, 6:00 AM."

> **EN**  
> The birds were starting in the trees outside, and the room was cold, damp, and grey. We hadn't slept a single minute.
>
> Sophia was lying beside me on the floorboards, staring up at the unfinished rafters. She suddenly grabbed my arm, shaking, and whispered that the red stain on the ceiling wood was dripping onto her chest. I looked up. There was no water, no blood, no stain, just dry pine.
>
> But when I touched her face, her skin was burning hot, and her eyes were reflecting a crimson light that wasn't in the room. She scrambled backward in total panic, her boots scratching the floorboards as she sprinted out into the hallway toward the front door. She kept screaming that the room was bleeding.
>
> But when the sun finally broke through the trees at 06:00 AM, she was still here in town. That was the exact moment I knew she would never leave. She is mine forever.
>
> **PT-BR**  
> Os pássaros começavam a cantar nas árvores lá fora, e o quarto estava frio, úmido e cinzento. Não tínhamos dormido um minuto sequer.
>
> Sophia estava deitada ao meu lado no assoalho, olhando para as vigas inacabadas do telhado. De repente ela agarrou meu braço, tremendo, e sussurrou que a mancha vermelha na madeira do teto estava pingando no peito dela. Eu olhei para cima. Não havia água, nem sangue, nem mancha, só pinho seco.
>
> Mas quando toquei o rosto dela, a pele estava queimando de quente, e os olhos dela refletiam uma luz carmesim que não existia no quarto. Ela se arrastou para trás em pânico total, as botas arranhando o assoalho, e disparou para o corredor em direção à porta da frente. Ela não parava de gritar que o quarto estava sangrando.
>
> Mas quando o sol finalmente atravessou as árvores às 06:00 da manhã, ela ainda estava aqui na cidade. Foi naquele exato momento que eu soube que ela nunca iria embora. Ela é minha para sempre.

**4. The trap.** When the notebook is closed: a vivid red light fades in in the bedroom, 0.7 s later quick running footsteps from the bedroom down the hallway to the living room, and then, in the living room, the latch of the time capsule is thrown with a CLACK. Manual saving is blocked.

In the west end of the hallway, the flashlight is cut when the player enters, and a **still, flat black silhouette** stands over the capsule: about 2.1 m tall, too thin, a small head on a long neck, arms hanging past its knees, no face. The player can switch the light back on freely. When the beam finds the figure (or after 1.5 s of looking at it from within 6 m), the reveal: half a second of a stuttering weak light, in which the figure changes pose only while the light is off (bowed over the capsule, head turned right round, risen and facing the player, then nearer with its head tilted), and the screen smears. The light dies, every door slams and locks. The next time the flashlight is switched on the figure is gone, the red fades out, and the capsule stands open.

**5. The time capsule** (a shallow chest on the living room crate). A hasty note lies on it, and can be read at any time:

**Item: Note on the Time Capsule** (PT-BR: *Bilhete na Cápsula do Tempo*)  
*Inventory text, EN:* A hasty letter pinned under the brass padlock.  
*Inventory text, PT-BR:* Uma carta escrita às pressas, presa sob o cadeado de latão.

> **EN**  
> To be opened in 5 years.
>
> Sophia, my love. Inside this box lies everything we are building toward. It holds our goal, our house, and the future we promised each other in secret.
>
> If you ever forget the code to open it, you don't need a key. You only need to trace the steps of how we began, in the exact order our story unfolded.
>
> — Lucas
>
> **PT-BR**  
> Para abrir daqui a 5 anos.
>
> Sophia, meu amor. Dentro desta caixa está tudo o que estamos construindo. Ela guarda o nosso objetivo, a nossa casa e o futuro que prometemos um ao outro em segredo.
>
> Se um dia você esquecer o código para abri-la, não precisa de chave. Só precisa refazer os passos de como tudo começou, na ordem exata em que a nossa história aconteceu.
>
> — Lucas

Inside, on padding: the house advertisement, Sophia's bus ticket, an unclaimed bus ticket, and **Lucas's ficha** on top.

**Item: House Advertisement** (PT-BR: *Anúncio de Casa*)  
*Inventory text, EN:* The advertisement expired two years ago. Lucas circled every room. Sophia wrote only beneath the photograph.  
*Inventory text, PT-BR:* O anúncio venceu há dois anos. Lucas circulou todos os cômodos. Sophia escreveu apenas embaixo da fotografia.

> **EN**  
> **HOUSE FOR SALE**  
> Town centre
>
> Living room · Kitchen · Bedroom · Bedroom · Pantry
>
> *The blue windows are beautiful.*
>
> **OURS?**
>
> **PT-BR**  
> **CASA À VENDA**  
> Centro da vila
>
> Sala · Cozinha · Quarto · Quarto · Despensa
>
> *As janelas azuis são bonitas.*
>
> **NOSSA?**

**Item: Sophia's Bus Ticket** (PT-BR: *Passagem de Ônibus da Sophia*)  
*Inventory text, EN:* A one-way ticket to São Paulo. Sophia wrote her name on it.  
*Inventory text, PT-BR:* Uma passagem só de ida para São Paulo. Sophia escreveu o nome nela.

> **EN**  
> **BUS TICKET**  
> Railway village / São Paulo  
> One way
>
> Passenger: *Sophia*
>
> **PT-BR**  
> **PASSAGEM DE ÔNIBUS**  
> Vila ferroviária / São Paulo  
> Só ida
>
> Passageiro: *Sophia*

**Item: Unclaimed Bus Ticket** (PT-BR: *Passagem de Ônibus Sem Dono*)  
*Inventory text, EN:* Two tickets for the same departure. Sophia claimed one and left the other for someone to choose.  
*Inventory text, PT-BR:* Duas passagens para a mesma partida. Sophia pegou uma e deixou a outra para alguém escolher.

> **EN**  
> **BUS TICKET**  
> Railway village / São Paulo  
> One way
>
> Passenger: *If you want.*
>
> **PT-BR**  
> **PASSAGEM DE ÔNIBUS**  
> Vila ferroviária / São Paulo  
> Só ida
>
> Passageiro: *Se quiser.*

**Item: Lucas's Ficha** (PT-BR: *Ficha do Lucas*)  
*Inventory text, EN:* A brass telephone token, dented, scratched and a little bent.  
*Inventory text, PT-BR:* Uma ficha de telefone de latão, amassada, riscada e um pouco torta.

On its face is stamped "LUCAS" and on its back scratched "NEVER LEFT" / "NUNCA FUI EMBORA".

**6. The exit.** Closing the ficha's view silently unlocks every door, the front door included. The house is left behind.

---

### 3.9 The overlook: the payphone and the call

The last stretch of trail leads up to a plateau above the sleeping town. A bench, a rusted fence with barbed wire, a streetlamp, and, under the lamp, **a yellow payphone** (an *orelhão*, the shell shaped public phone of Brazil). The fog opens up for the first time: the whole town lies in the valley with mountains behind it, a few lit windows.

A note is taped to the side of the booth:

**Item: Taped Note** (PT-BR: *Bilhete Colado*)  
*Inventory text, EN:* Stuck to the side of the payphone.  
*Inventory text, PT-BR:* Colado na lateral do orelhão.

> **EN**  
> One ficha for each of us.
>
> **PT-BR**  
> Uma ficha para cada um de nós.

**Using the phone.** One interaction at the booth, and the prompt says what E will do:
- With no ficha to put in, Juliana only says: EN: “I need some fichas...” · PT: “Preciso de umas fichas...”
- With a ficha: "Insert ficha N" (the number is the ficha's). Juliana walks calmly up to the booth, the view is locked on the unit, and she can insert one at a time or step away ("Step away") to go and find the others. Inserted fichas stay.
- With all three in, the indicator turns green and the choice becomes "Pick up Receiver".

**The call.** A cinematic shot from behind and above her, looking out over the fence at the town, with a slow push in. No voices: captions only. The lamp flickers once when the voice begins. Sophia says four things in two voices. Both are captioned only as "Sophia", so the player cannot tell which is real. The first and third (marked **warm**) are slow and soft and pull her to come back; the second and fourth (marked **desperate**) are high, fast and rough and warn her away.

| Time | Voice | EN | PT |
|---|---|---|---|
| 1.0 to 3.8 s | warm | Juli... Oh, thank God you called. | Juli... Ah, graças a Deus você ligou. |
| 4.2 to 7.2 s | warm | I was starting to think you forgot about me... | Eu estava começando a achar que tinha se esquecido de mim... |
| 7.6 to 10.6 s | warm | I've been sitting here in the dark, waiting for you to pick up... | Estou aqui sentada no escuro, esperando você atender... |
| 10.9 to 14.0 s | warm | listening to the rain on the roof... but the train hasn't moved all night. | ouvindo a chuva no telhado... mas o trem não se mexeu a noite toda. |
| 15.2 to 17.2 s | desperate | Juli? Juli, listen to me! | Juli? Juli, me escuta! |
| 17.4 to 19.8 s | desperate | I don't know who that is, but don't listen to her! | Eu não sei quem é essa, mas não dê ouvidos a ela! |
| 20.0 to 21.6 s | desperate | Hang up right now! | Desliga agora mesmo! |
| 22.8 to 25.4 s | warm | It's so cold here... Please... | Está tão frio aqui... Por favor... |
| 25.8 to 29.2 s | warm | just come back and be with me... I miss you... | só volte e fique comigo... Sinto sua falta... |
| 30.4 to 32.8 s | desperate | Juli, she's trying to trick you! | Juli, ela está tentando te enganar! |
| 33.0 to 34.6 s | desperate | Stay away from her! | Fique longe dela! |
| 34.8 to 36.8 s | desperate | Don't go near the wagon! | Não chegue perto do vagão! |

The line is cut with a soft hollow click and the receiver is left hanging on its cord.

### 3.10 The finale: the lights go out, the wagon, the door

**The lights of the town go out** during the end of the call, one by one, suddenly, each after a short stutter, never fading. One window stays lit, alone, for a second and a half, then stutters out. The streetlamp dies. The whole picture darkens until it is true black (the camcorder filter is switched off with it). Two seconds of pitch dark.

**The wagon.** The picture fades in slowly, like heavy lids opening, drooping and opening again. Juliana wakes on the bench in the wagon with the same head raise, but dim and slow. The ceiling lights are cold stuttering bulbs; the exit behind her is locked; the flashlight is not on. The hint appears: EN: “Press F to turn on the flashlight” · PT: “Pressione F para ligar a lanterna” It is much weaker than before (16 percent of its usual strength, 7 m of range). She can only walk forward along the aisle, slowly.

At the end of the aisle a **girl**, built from primitives, sits in the middle of the aisle with her back to the player, hugging her knees against the north wall, rocking, silent.

**The cutscene** begins 2.9 m from her. The view is taken, Juliana walks on for a second by herself, and a whisper is captioned (no sound):

> **You're not supposed to be here.** / Você não deveria estar aqui.

She flinches, glances over her shoulder, turns all the way round; **the girl is gone**, the lights stutter as it happens, nothing is left in her place. She stands scared, breathing, then turns back, looks down at the empty spot, sweeps the flashlight left and right and up at the dead lamps (her head always a beat behind the beam), and finally turns to the exit. The lamp above the exit door is dead: it is pure black.

**The door.** The controls return, facing the exit. She walks the aisle toward the corridor door at the end of the wagon in two careful steps, with the beam shaking. When she is 3.4 m from it and looking at it, a **head swings across the doorway like a clock hand**, upside down, half in the dark, from the right, and stops perfectly still. A sting plays. Then her view is taken: she is thrown back, falls, the flashlight flies out of her hand and rolls away along the aisle, and she says:

> **What the fuck?** / Que porra é essa?

The head drops to the floor on a stretched neck and crawls after her legs. Two crawl pulls toward the light of the flashlight, then her foot is yanked back.

**The struggle.** The player must press E again and again to break free:

> Press E again and again to break free!

The thing drags her to the door while a bar drains. **It cannot be won.** The bar holds for 2.25 seconds, then drains faster and faster, and nothing the player does gets it over 95 percent. When it empties she is pulled back toward the door and two hands slap onto her face, one across the eyes, one over the mouth. Black. Silence for a second and a half.

**The title card.** The word "UNRAILED" fades in (1.4 s), holds (3.2 s) and fades out (1 s). The game saves "demo complete" and returns to the main menu.

---

## 4. How the three trails feed the call

| Ficha | Number | What its trail is about | Where it lies when found |
|---|---|---|---|
| Juliana's | 1 | The friendship | On the camp's memory table, after the recording ends |
| Lucas's | 2 | Lucas, Sophia and the house | On top of the time capsule's contents, after the trap |
| Sophia's | 3 | Her private code | In the signal box's coin tray, after UP, DOWN, UP |

Chain of cause for each:

- **Juliana's.** *Rain at the Station* in the open box and *Bus Stop Departure* on the memory table (camp), *Scraped Knee* on the HQ desk (tower, its door open), in either order → album in order → recording → the last line from the empty seat → ficha on that log.
- **Lucas's.** Kitchen recipe → pantry door unlocks → pantry note and rusty key → bedroom door → notebook → trap → capsule → ficha.
- **Sophia's.** Notebook on the bench (the order) → lantern in the weeds, puncher in the box under the bench, whistle on the mile marker (each with its phrase) → levers UP, DOWN, UP → ficha.

No path is required before another. The payphone is the only gate: all three fichas.

---

## 5. Timeline of the lore as written

| When | Event | Source |
|---|---|---|
| 1962 | The culvert near Mile Marker 4 is filled with solid granite. | Tower newspaper clipping |
| May 1984 | A maintenance worker hears his missing seven year old daughter calling from inside it. | Tower newspaper clipping |
| July 1988 | The two girls (about 8) at the fig tree; Sophia's scraped knee; "something under the floorboards grabbed her ankle"; Juliana "saw it too". | *Scraped Knee* |
| October 1989 | The butcher's wife says Juliana has "dead eyes"; Sophia defends her, the apple core planted behind the tower. | Juliana's note |
| 1989 | An operator is relieved of duty for stopping trains for "a woman in a black dress". | Tower memo |
| Before winter, some year | Sophia overhears that the northern line will close "because the ground keeps shifting"; "we are keeping this tower, Juli." | Sophia's folded letter |
| 1991 | The town advises that the fog causes "auditory illusions: knocking, whispered names, footsteps". | Tower health notice |
| 1995 | The girls (about 15) under one umbrella; Sophia gets a cold for a week. | *Rain at the Station* |
| Years later | Sophia (about 28) at the bus stop, "leaving for the capital"; the ticket reads Railway village / São Paulo, one way. | *Bus Stop Departure*, the tickets |
| Undated | Lucas and Sophia want the house ("OURS?"); the first dinner; the pantry kiss; the notebook entry of May 14th, 6:00 AM. | House notes |
| "Tonight", 03:17 | The ticket's date and arrival time. | Train ticket |

---

## 6. Things I noticed while compiling (for you to decide)

I did not change any of these.

**Contradictions or loose threads**
1. **Fixed: the thermos and the board.** The thermos now says only that the childhood photo is on the HQ desk; the key, the code and the board are gone from it.
2. **The time capsule note talks about a code.** "If you ever forget the code to open it, you don't need a key. You only need to trace the steps..." The padlock was removed from the house, so there is no code. It reads as lore, not an instruction, but it can mislead.
3. **When did the station close?** "After the station closed" (1994) in the retired *Broken Lever* photograph's note, against a badge from the earlier real world chapter that has Juliana working nights on the railway line. If the demo's present is later than 1994, say whether the line reopened.
4. **Sophia's ages and the dates.** The 1995 photograph is "about 15", so the third photograph ("about 28") falls around 2008. Nothing in the texts says what year "tonight" is.
5. **"The capital" against São Paulo.** *Bus Stop Departure* says she was leaving "for the capital"; the bus tickets say São Paulo. Fine if intended.
6. **The pocket watch beat is gone.** The stopped watch that whispered "She never came back to the tower, Juli..." when its view closed was removed with the watch. Nothing else uses that whisper now, and the tower is otherwise silent.
7. **Who is the girl?** The finale presents a child sized figure that vanishes, then a head in the doorway. The texts never say whether the girl is Sophia, a memory, or the thing. This is fine if deliberate.

**Placeholders still on screen**
8. The ticket reads `PASSENGER: JULIANA [SURNAME]` and `DESTINATION: [TOWN NAME]` (and an empty "DEPARTURE:" line). The town's name is now "Fenda", but the ticket still shows the bracket.
9. The photograph faces are labelled cards ("[Placeholder photo: ...]").
10. Voices do not exist yet and most sounds are generated stand ins or files named `placeholder_*` (the forest footsteps are your own recording). With captions off the recording, the empty seat's line, the call and the whole finale are silent. The camp has two empty voice sources waiting for clips: one in the recorder (the conversation) and one at the empty seat (the last line).

16. **An item description is stale.** The time capsule note's inventory text still says "A hasty letter pinned under the brass padlock", and there is no padlock any more.
17. **Units.** The tower news and memo say "Mile Marker 4" (Portuguese: "Marco de Milha 4"), while the shed's marker reads "KM 214". Everything else is metric. Pick one for the railway.

**Text rules**
11. The no hyphen rule for notes is broken by one **em dash inside a body** (not the signature): the ficha's note ("...the top of the hill — let's make that call."). Say if you want it changed. (The radio plate's dash went with its new text.)
12. **Profanity** in Juliana's one swear line (`What the fuck?`) is intended per the design; flagging it only for content ratings.
13. **Language of origin.** The Portuguese versions of several notes (the thermos, the radio, the overlook note) are the authored originals and the English is a translation; the trailhead signs are in Portuguese in both languages on purpose.

**Unused text**
14. Three localization keys are defined but never used by any scene or script: `INVENTORY_SLOT_EMPTY`, `INVENTORY_SLOT_ITEM`, `PROMPT_ENTER_CODE`. The texts of the old route are now unused in the world too, but kept: the brass key's and the three retired photographs' (an old save may carry them), and the tower door note and the locked door line (`READABLE_TOWER_DOOR_NOTE`, `ITEM_TOWER_DOOR_NOTE_*`, `CAPTION_TOWER_DOOR_LOCKED`), which nothing shows now.
15. Several chapter 1 item texts (prescription, badge, cellphone, newspaper clipping, station photo, clonazepam) exist and are used only in the real world chapter blockout, not in the dream.

---

## 7. Appendix: every item the player can take or read

| Item | Where | Kind | Notes |
|---|---|---|---|
| Train ticket | Wagon | Read in place | Front, back, Juliana's two lines |
| Flashlight | Always carried | Tool | F |
| Forest map | Trail sign | Taken, own key (M) | Pinned; torn off in a scene |
| Railway radio | Camp entrance | Read in place | Scenery |
| Weathered thermos | Log table | Read in place | Sophia's note: the photo is on the HQ desk |
| Three photographs | Camp (2), tower (1) | Taken | All three belong to the album |
| Photo album | Memory table | Puzzle | Leads to the recording |
| Juliana's ficha | The empty seat by the fire | Taken | After the last line |
| Juliana's note | Tower desk drawer | Read in place | October 1989 |
| Sophia's folded letter | Tower bench | Read in place | Hollow crust, "we are keeping this tower" |
| Four tower documents | Tower cabin | Read in place | News 1984, memo 1989, journal, notice 1991 |
| Sophia's notebook | Shed bench | Read in place | The order |
| Lantern, puncher, whistle | Shed | Inspected in place | Each with a phrase |
| Sophia's ficha and its note | Shed signal box | Taken | After UP, DOWN, UP |
| Recipe, pantry note, rusty key | House | Read / taken | Key opens bedroom |
| Lucas's notebook | House bedroom | Read in place | Triggers the trap |
| Capsule note, advertisement, two bus tickets | House | Read in place | |
| Lucas's ficha | House | Taken | After the trap |
| Taped note | Payphone | Read in place | "One ficha for each of us." |

**Kept for old saves only** (no longer in the world): the brass key and the three retired photographs.

**Item: Brass Signal Key** (PT-BR: *Chave de Latão da Torre*)  
*Inventory text, EN:* A heavy brass key, its bow rubbed bright by small thumbs. Stamped along the shaft: SIGNAL TOWER.  
*Inventory text, PT-BR:* Uma pesada chave de latão, com a argola polida por polegares pequenos. Gravado na haste: TORRE DE SINALIZAÇÃO.

**Item: Old Photograph: Lucas at the Workshop** (PT-BR: *Foto Antiga: Lucas na Oficina*)  
*Inventory text, EN:* A young man in greasy overalls holds a wrench almost as long as his arm, squinting into the flash. There is handwriting on the back.  
*Inventory text, PT-BR:* Um rapaz de macacão engordurado segura uma chave inglesa quase do tamanho do braço, de olhos apertados contra o flash. Há uma frase escrita no verso.

> **EN**  
> Lucas working the late shift. He always thought brute force could fix the machinery in this town.
>
> **PT-BR**  
> Lucas no turno da noite. Ele sempre achou que força bruta consertava as máquinas desta cidade.

**Item: Old Photograph: The Broken Lever** (PT-BR: *Foto Antiga: A Alavanca Quebrada*)  
*Inventory text, EN:* A heavy iron lever bent out of true, its handle snapped halfway down. A boot print is pressed into the oil beside it. There is handwriting on the back.  
*Inventory text, PT-BR:* Uma pesada alavanca de ferro entortada, com o cabo partido no meio. A marca de uma bota está pressionada no óleo ao lado. Há uma frase escrita no verso.

> **EN**  
> 1994. Lucas tried to fix the tracks himself after the station closed. He always thought he owned this place.
>
> **PT-BR**  
> 1994. O Lucas tentou consertar os trilhos sozinho depois que a estação fechou. Ele sempre achou que era dono deste lugar.

**Item: Old Photograph: The Foggy Platform** (PT-BR: *Foto Antiga: A Plataforma na Neblina*)  
*Inventory text, EN:* An empty station platform lost in fog, one lamp burning somewhere behind it. Nobody is in the frame. A date stamp is printed in the corner, and there is handwriting on the back.  
*Inventory text, PT-BR:* Uma plataforma de estação vazia, perdida na neblina, com um único lampião aceso em algum lugar atrás dela. Não há ninguém no quadro. Um carimbo de data está impresso no canto, e há uma frase escrita no verso.

> **EN**  
> I don't remember taking this. The date stamp says 1988, but I was never at the tracks alone at night back then.
>
> **PT-BR**  
> Não lembro de ter tirado esta foto. O carimbo diz 1988, mas eu nunca fiquei sozinha nos trilhos à noite naquela época.
