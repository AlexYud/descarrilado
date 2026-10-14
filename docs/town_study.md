# Town study: a small Brazilian railway town in the serra

Design notes for the town blockout (`scripts/environment/town_blockout.gd`): what a small
country town in São Paulo state looks like, and what that means for our map. The town has
to read well from the dream intro's city overlook (about 200 m above the valley and 600 m
away) and be the base for chapter 1 onwards.

## What these towns are made of

**They grow along the railway and the water, not on a square.** Most interior São Paulo
towns grew along the line: the station and its warehouses formed one pole, and the old
centre (the *matriz* and its *praça*) the other, often a little apart. The line also cut
the town in two. Where the land is steep (the Serra do Mar, Paranapiacaba) the town follows
the valley floor and climbs the slopes in terraces, so the outline is long and ragged, with
fingers reaching up side valleys and roads.

**Paranapiacaba has three parts:**
- the *Parte Baixa*: the company's workers' village, a regular grid of standard wooden houses
  in semi-detached pairs and fours, sized by the worker's rank, with the rail yard in the
  middle;
- the *Parte Alta*: older and irregular, laid out like the Portuguese colonial towns, with the
  church;
- the *Rabique*: steep, informal houses on the slope.

Our playable core already plays the Parte Alta and the yard. The new ring adds the rest.

**The recurring pieces:**

| Piece | Where it goes | Why it matters from the overlook |
|---|---|---|
| *Igreja Matriz* + *praça* with a *coreto* (bandstand), palms and ipês | the old centre, on flat ground, the street grid around it | the white towers are the town's landmark |
| Commerce around the praça: two-storey shops with homes above, the *prefeitura*, a bank, a pharmacy, a bakery, bars | facing the praça and the main street | dense, colourful, lit at night |
| *Estação* with its platform canopy, *armazém* (warehouse), railway *caixa d'água* (the water tank for the engines), a siding with wagons | on the line, a little apart from the centre | a long low silhouette and a tank on legs |
| *Vila operária*: identical semi-detached houses in straight rows | beside the yard | a regular pattern next to the irregular rest |
| River (*ribeirão*) with a road bridge and an iron rail bridge | the valley floor | a dark ribbon that leads the eye |
| *Campo de várzea* (dirt football pitch) | the flood plain by the river (it floods, so nothing else is built there) | a pale rectangle, unmistakable from above |
| School with a covered court, health post | edge of the centre | a large roof and a court |
| Municipal *caixa d'água* (concrete tower) | the highest point of the town | a tall vertical marker |
| Cemetery with white tombs | on a slope at the edge of town | white dots on green |
| *Cruzeiro* (big cross) on the hilltop, sometimes a radio or TV mast | the peak above the town | silhouette against the sky, a red light at night |
| Petrol station, small bus station | where the road comes in | a lit canopy |
| Periphery: small, unfinished block houses (*puxadinhos*), grey plaster or bare brick, corrugated roofs | climbing the slopes along dirt lanes | thinning, irregular edge |
| *Chácaras* (smallholdings) with fruit trees, pastures with fences, eucalyptus plantations in rows, banana groves, coffee rows | outside the town, on the gentler slopes | patchwork that reads as "countryside" |
| Atlantic forest (*Mata Atlântica*) | the steep slopes and hilltops | dark, dense, frames everything |
| Dirt roads, wooden power poles along them | from town to the farms | thin lines across the patchwork |

## Rules for our map

1. **Shape:** the town is long and follows the valley: the old upper town (playable) on the
   north slope, the station and the centre down the valley to the east, the river along the
   south, a bridge to the south bank. Fingers of houses climb the north hill (periphery) and
   follow the entrance road to the south-west. The west is a forested hill with the tunnel.
   No straight outer edge: density fades from the centre to the farms.
2. **Playable vs scenery:** the playable core stays as it is (compact, sealed). Everything new
   is scenery: no collision, merged meshes (cheap), lit windows and street lamps so it reads at
   night from the overlook. Later chapters can promote a district to playable using the same
   lane builder.
3. **Scale:** about 650 x 650 m of terrain, the town itself about 450 x 300 m, about 400-600
   buildings in all, so it fills the view from the overlook.
4. **Colours:** pastel and saturated paints in the centre (pink, blue, yellow, green), white
   church and tombs, grey and bare-brick periphery, terracotta and fibre-cement roofs, red key
   buildings unchanged in the playable core.

## Sources

- Small towns and their *praça*, *matriz* and *coreto*: [Paulínia coreto (Correio da Manhã)](https://digital.correiodamanha.com.br/jornalcorreiodamanha/2026/08/11/0124ce/pdf/1108campinas_cmanha18.pdf), [Itabaiana-PB (UFPB)](https://repositorio.ufpb.br/jspui/bitstream/123456789/22861/1/TCC_LARISSA_VASCONCELOS.pdf)
- Railway and urban form: [Alta Sorocabana towns (Unesp)](https://repositorio.unesp.br/bitstreams/2b21d399-a302-4161-8851-3037363565e5/download), [Ourinhos morphology](https://publicacoes.amigosdanatureza.org.br/index.php/gerenciamento_de_cidades/en/article/download/6169/6109/13628), [stations as economic poles (Univap)](https://www.inicepg.univap.br/cd/INIC_2024/anais/arquivos/RE_0876_0541_01.pdf)
- Paranapiacaba: [Revista CPC (USP)](https://revistas.usp.br/cpc/article/download/74963/92653/128731), [Pós FAU-USP](https://revistas.usp.br/posfau/article/download/137106/132899/264550), [ABC do ABC](https://abcdoabc.com.br/vila-de-paranapiacaba-patrimonio-arquitetonico-do-brasil-2/)
- Station complexes (station, warehouse, workers' village, water tank): [Piratininga](https://www.ipatrimonio.org/wp-content/uploads/2017/03/Ferrovi%C3%A1ria-de-Piratininga-res.pdf), [Chavantes](https://www.ipatrimonio.org/wp-content/uploads/2016/03/ferroviaria-chavantes.pdf), [Rio Grande da Serra](https://www.ipatrimonio.org/wp-content/uploads/2013/12/esta%C3%A7%C3%A3o-ferroviaria-rio-grande-da-serra.pdf)
- Cemetery on the slope, cruzeiro on the hill: [Mucugê (Olhar Digital)](https://olhardigital.com.br/curiosidades/?p=21259)
