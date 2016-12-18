extensions[ array table ]

breed[ councils council ]
patches-own[ free ]

globals[
  EARN-EACH
  LOSE-EACH
  BAD-LUCK-EACH
  GOOD-LUCK-EACH
  LIFE-TO-PROCREATE
  RADIUS ;; precio de casa, casas alrededor
  TRACE

  ;; MONITORS
  MONITOR-MAX-SAVINGS
  MONITOR-MEAN-SAVINGS
  MONITOR-MEDIAN-SAVINGS

  MONITOR-HOMELESS
  MONITOR-ONE-HOUSE
  MONITOR-TWO-HOUSES
  MONITOR-MORE-HOUSES

  MONITOR-EMPTY-HOUSES
  MONITOR-FREE-HOUSES
  MONITOR-NOT-EMPTY-HOUSES

  MONITOR-HOUSES-BUILT
  MONITOR-HOUSES-BOUGHT

  ;; LISTS
  LIST-CONSTRUCTION-PRICES
  LIST-BUYING-PRICES

  ;; MEDIATOR
  MEDIATOR-OFFERS
  MEDIATOR-CONSTRUCTIONS
]

__includes[
  "human.nls"
  "house.nls"
  "mediator.nls"
  "plots-and-monitors.nls"
  "formulas.nls"
  ]



to setup
  clear-all
  set TRACE true
  set LIFE-TO-PROCREATE 450
  set EARN-EACH 10
  set LOSE-EACH 10
  set BAD-LUCK-EACH 100
  set GOOD-LUCK-EACH 20
  set RADIUS 5

  ;; initialize all patches to be free for edification
  ask patches [
    set free true
    set pcolor grey
  ]

;;  create-councils INIT-CITY-COUNCILS[
;;    set shape "pentagon"
;;    set color black
;;    setxy 0 0
;;    ask patch-here [ set free false ]
;;  ]

  create-humans MIN-POPULATION [
    initialize_human
  ]


   ;;; estas casas se asignan a los siguientes humanos aleatorios
  create-houses INIT-HOUSES [
    ask patch-here [ set free false ]
    initialize_seed_house_of one-of patches with [free] one-of humans with [num-houses < MAX-HOUSES-IN-PROPERTY]
  ]


  ;; updates shapes
  update_all_humans
  update_all_houses


  setup_lists
  reset-ticks
  setup_monitors
  update_monitors
end

to go


  if ticks mod EARN-EACH = 0 [ humans_earn ]
  ;;if ticks mod LOSE-EACH = 0 [ humans_lose ]

  ask houses [ house_behave ]
  ask humans [ human_behave ]



  if ticks mod BAD-LUCK-EACH = 0 [ humans_bad_luck ]


  if ticks mod GOOD-LUCK-EACH = 0 [ humans_good_luck ]


  ;;if (count humans with [ can-build ]) > 0 [ humans_build ]



  population_control

  ;; updates shapes
  update_all_humans
  update_all_houses

  update_monitors
  tick
end


to humans_earn
  ask humans [
    set money money + SMI * social-status
  ]
end

to humans_lose
  ask humans [
    set money money - (SMI * 0.1 * (5 + random 5))
  ]
end

to humans_bad_luck
  ;; bad loock for some of them
  ask humans with [ money < (max[money] of humans * 0.8) and money > 0 ]
  [
    ifelse money > median [money] of humans
    [set money money - (money * 0.01 * random 10)]
    [set money money - (money * 0.01 * random 80)]
  ]
end

to humans_good_luck
  ;; one luck just for one
  ask one-of humans
  [
    ifelse money > median [money] of humans
    [set money money + (SMI *  (10 + random 10))]
    [set money money + (SMI *  random 10)]
  ]
end


to population_control

  ;; the newcomers
  humans_procreate

  ;; kills elders
  kill_humans

  if count humans < MIN-POPULATION [
    if trace[show (word "Creating humans")]
      create-humans 0.5 * MIN-POPULATION [
        initialize_human
      ]
  ]

  if count humans > 2 * DESIRED-POPULATION [
    if trace[show (word "Killing  humans")    ]
    let _humans sort n-of (0.25 * count humans) humans
    foreach _humans [ kill_human ?]
  ]

end


to humans_procreate
  let able-to-procreate sort-on [money] humans with [ life < LIFE-TO-PROCREATE and can-procreate]
  foreach able-to-procreate[

    let max-sons 2
    ;; if population is low, humans may have more than 1 son
    ifelse count humans < DESIRED-POPULATION / 2
    [
      set max-sons 4
    ]
    [
      if count humans < DESIRED-POPULATION
      [
        set max-sons 3
      ]
    ]
    let sons random max-sons

    if trace [ show (word ? " has " sons " sons") ]

    create-humans sons[
      initialize_son ?
    ]
    ;; father loses 25% of money
    ask ? [
      set money 0.75 * money
      set can-procreate false
      ]

  ]
end



to kill_humans
  let _humans sort humans with [life < 0]
  foreach _humans
  [
    kill_human ?
  ]
end

to kill_human [ _human ]
  ask _human[
    let sons humans with [father = myself]

    ifelse any? sons
    [
      ;; give money to one son
      ask one-of sons [ set money money + [money] of myself ]

      ;; give houses randomly
      ask houses with [owner = myself]
      [
        set owner one-of sons

      ]
    ]
    ;; destroy properties
    [

       ask houses with [owner =  myself][die]
    ]
    die
  ]
end

to update_all_humans
  ask humans [
    human_update_color
    update_shape
  ]
end

to update_all_houses
 ask houses[ house_update_colors ]
end


@#$#@#$#@
GRAPHICS-WINDOW
16
10
524
539
40
40
6.15
1
10
1
1
1
0
1
1
1
-40
40
-40
40
1
1
1
ticks
30.0

BUTTON
628
13
706
46
SETUP
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

SLIDER
630
72
1144
105
SMI
SMI
1
1500
593
1
1
€
HORIZONTAL

SLIDER
625
435
870
468
MIN-POPULATION
MIN-POPULATION
1
50
50
1
1
NIL
HORIZONTAL

SLIDER
628
197
800
230
INIT-HOUSES
INIT-HOUSES
0
50
34
1
1
NIL
HORIZONTAL

SLIDER
628
246
800
279
INIT-CITY-COUNCILS
INIT-CITY-COUNCILS
1
1
1
1
1
NIL
HORIZONTAL

BUTTON
724
13
787
46
GO
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

PLOT
15
555
456
780
Savings
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"plot 0" ""
PENS
"max" 1.0 0 -2674135 true "" "plot MONITOR-MAX-SAVINGS"
"mean" 1.0 0 -955883 true "" "plot MONITOR-MEAN-SAVINGS"
"median" 1.0 0 -13840069 true "" "plot MONITOR-MEDIAN-SAVINGS"

SLIDER
627
294
853
327
MAX-HOUSES-IN-PROPERTY
MAX-HOUSES-IN-PROPERTY
1
5
1
1
1
NIL
HORIZONTAL

PLOT
18
799
457
1005
Home posession
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Homeless" 1.0 0 -1184463 true "" "plot MONITOR-HOMELESS"
"1 House" 1.0 0 -13345367 true "" "plot MONITOR-ONE-HOUSE"
"2 Houses" 1.0 0 -5825686 true "" "plot MONITOR-TWO-HOUSES"
"+ Houses" 1.0 0 -16777216 true "" "plot MONITOR-MORE-HOUSES"

PLOT
556
555
1036
783
Houses
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"empty" 1.0 0 -2674135 true "" "plot MONITOR-EMPTY-HOUSES"
"free" 1.0 0 -955883 true "" "plot MONITOR-FREE-HOUSES"
"not empty" 1.0 0 -13840069 true "" "plot MONITOR-NOT-EMPTY-HOUSES"

PLOT
554
800
1029
988
Population
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"elders" 1.0 0 -955883 true "" "plot count humans with [ life < 200 ]"
"adult" 1.0 0 -13840069 true "" "plot count humans with [ life >= 300 and life < 550 ]"
"young" 1.0 0 -7500403 true "" "plot count humans with [ life >= 550 ]"
"total" 1.0 0 -16777216 true "" "plot count humans"

SLIDER
628
394
800
427
SOCIAL-STATUSES
SOCIAL-STATUSES
2
5
4
1
1
NIL
HORIZONTAL

SLIDER
807
151
1143
184
HOUSE-BASE-VALUE
HOUSE-BASE-VALUE
1
100
9
1
1
smis
HORIZONTAL

MONITOR
463
555
540
600
max
MONITOR-MAX-SAVINGS
0
1
11

MONITOR
463
605
540
650
mean
MONITOR-MEAN-SAVINGS
0
1
11

MONITOR
463
655
539
700
median
MONITOR-MEDIAN-SAVINGS
0
1
11

SLIDER
806
196
1143
229
HOUSE-CONSTRUCTION-REQUIRED-SMI
HOUSE-CONSTRUCTION-REQUIRED-SMI
1
100
4
1
1
smis
HORIZONTAL

MONITOR
460
798
538
843
homeless
MONITOR-HOMELESs
0
1
11

MONITOR
461
847
537
892
1 house
MONITOR-ONE-HOUSE
0
1
11

MONITOR
462
895
536
940
2 houses
MONITOR-TWO-HOUSES
0
1
11

MONITOR
462
945
539
990
+ houses
MONITOR-MORE-HOUSES
0
1
11

MONITOR
1041
555
1120
600
empty
MONITOR-EMPTY-HOUSES
17
1
11

MONITOR
1041
607
1120
652
free
MONITOR-FREE-HOUSES
0
1
11

MONITOR
1042
659
1121
704
not empty
MONITOR-NOT-EMPTY-HOUSES
17
1
11

MONITOR
550
10
618
55
houses
count houses
0
1
11

MONITOR
551
64
617
109
humans
count humans
0
1
11

SLIDER
631
112
1143
145
IPC
IPC
1
100
3
1
1
%
HORIZONTAL

MONITOR
552
151
609
196
built
MONITOR-HOUSES-BUILT
0
1
11

MONITOR
553
204
611
249
bought
MONITOR-HOUSES-BOUGHT
0
1
11

SLIDER
815
245
1140
278
HOMELESS-LIFE-EXPECTANCY
HOMELESS-LIFE-EXPECTANCY
-10
-1
-3
1
1
ticks
HORIZONTAL

SLIDER
885
435
1145
468
DESIRED-POPULATION
DESIRED-POPULATION
500
1000
600
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

HOUSING (a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

### Humanos

* Tienen una vida entre 500 y 1000 ticks

* Cada 10 ticks reciben sueldo (el SMI)

* Caminan de forma aleatoria, intentando comprar casas o construyendolas

* Un slider que defina el numero maximo de casas que puede tener un human (2 por defecto)

* Un humano solo puede vivir en una casa al mismo tiempo, si posee mas estas no estaran ocupadas

* Un humano tiene un padre o nobody

* Cuando un humano muere las pertenencias pasan al hijo


### Casas



### Ofertas

* Un humano puede hacer una oferta de compra  RFQ al dueño de una casa que no vive en ella

    * de las x casas que tiene a distancia y, con un precio base menor que su dinero, si esta libre, la compra !prioriza la libre siempre por delante de la que tiene dueño

    * si las x casas que tiene a distancia y, con un precio base menor que su dinero, todas tienen dueño, decide hacer z ofertas mediante las siguientes condiciones:

        * let assumed-value ( ( max [ base-price of x ] - min [ base-price of x ] ) / SOCIAL-STATUSES ) * social-status
        * base-price < assumed-value and money < assumed-value

    * human-sender "RFQ" ( list house-id money ) donde money es base-price del

* un humano puede recibir una oferta de compra RFQ de distintos humanos compradores:

    * de las x ofertas recibidas, escogerá en función de distintas estrategias:

        * maximizar la cantidad de dinero. El comprador que ofrezca más dinero en la primera ronda se queda la casa.

        * maximiza la cantidad de dinero y el comprador es de un estátus social igual o por encima del vendedor.

* un humano vendedor puede hacer una contra-oferta "OFFER" pidiendo más dinero por la casa.

* Un humano puede comprar una casa que esta libre



## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
1
@#$#@#$#@
