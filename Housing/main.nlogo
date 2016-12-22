extensions[ array table ]

breed[ councils council ]
councils-own[ floor-price ]
patches-own[ free soil-price]

globals[
  EARN-EACH
  LOSE-EACH
  BAD-LUCK-EACH
  GOOD-LUCK-EACH
  LIFE-TO-PROCREATE
  RADIUS ;; precio de casa, casas alrededor

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
  MONITOR-HOMELESS-HOUSES-BOUGHT

  MONITOR-MAX-EMTPY
  MONITOR-MAX-NOT-EMTPY
  MONITOR-MEAN-EMTPY
  MONITOR-MEAN-NOT-EMPTY
  MONITOR-MIN-EMPTY
  MONITOR-MIN-NOT-EMPTY

  ;; LISTS
  LIST-CONSTRUCTION-PRICES
  LIST-BUYING-PRICES

  ;; MEDIATOR
  MEDIATOR-OFFERS
  MEDIATOR-CONSTRUCTIONS

  OBS-CURRENT-MESSAGES
  OBS-NEXT-MESSAGES
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
    set soil-price 0
  ]

  create-councils INIT-CITY-COUNCILS[
    set shape "pentagon"
    set color black
    setxy 0 0
    ask patch-here [ set free false ]
  ]

  create-humans MIN-POPULATION [
    initialize_human
  ]


   ;;; estas casas se asignan a los siguientes humanos aleatorios
  create-houses INIT-HOUSES [
    ask patch-here [ set free false ]
    initialize_seed_house_of one-of councils one-of patches with [free] one-of humans with [num-houses < MAX-HOUSES-IN-PROPERTY]
  ]


  ;; updates shapes
  update_all_humans
  update_all_houses


  setup_lists
  reset-ticks
  setup_mediator
  setup_monitors
  update_monitors
end

to go

  ask councils[ if any? houses[ set floor-price min [base-price] of houses]]

  if ticks mod EARN-EACH = 0 [ humans_earn ]
  if ticks mod LOSE-EACH = 0 [ humans_lose ]

  if ticks mod 10 = 0
  [
    ask houses [ house_update_new_price]
    ask houses [ house_swap_price]
  ]
  ask humans [ human_behave ]



  ;;if ticks mod BAD-LUCK-EACH = 0 [ humans_bad_luck ]


  if ticks mod GOOD-LUCK-EACH = 0 [ humans_good_luck ]


  ;;if (count humans with [ can-build ]) > 0 [ humans_build ]

  mediator_behave

  population_control

  ;; updates shapes
  update_all_humans
  update_all_houses


  update_monitors
  tick
end


to humans_earn
  ask humans [
    set money money + SMI *  social-status
  ]
end

to humans_lose
  ask humans [
    set money money - (SMI * 0.01 * random 20)
  ]
end

to humans_bad_luck
  ;; bad loock for some of them
  ask humans with [ money < (max[money] of humans * 0.8) and money > 0 ]
  [
    ifelse money > median [money] of humans
    [set money money - (money * 0.01 * random 50) ]
    [set money money - (money * 0.01 * random 30) ]
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


  ;;; EXTREME CASES
  ;;if count humans < MIN-POPULATION [
  ;;  if trace[show (word "Creating humans")]
  ;;    create-humans 0.5 * MIN-POPULATION [
  ;;      initialize_human
  ;;    ]
  ;;]

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

    if trace and sons > 0 [ show (word ? " has " sons " sons") ]

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
    let heritage nobody
    if any? sons
    [
      ;; give money to one son
      ask one-of sons [ set money money + [money] of myself ]

      ;; give houses randomly
      ask houses with [owner = myself]
      [
        set heritage self
        let lucky-son one-of sons with [num-houses < MAX-HOUSES-IN-PROPERTY]
        ;; if there is nobody, this house will be removed at the end of the procedure
        ;; ugly though
        if lucky-son != nobody[
          set owner lucky-son
          if trace [ show (word myself " dies and gives " self " to " lucky-son )]

          ;; checks if the son is homeless to add the house as a main house
          ifelse [base-home = nobody] of lucky-son [
            if trace [ show (word lucky-son " was homeless but not anymore, " heritage " is its new home ")]
            ask lucky-son[ set base-home heritage]
            set empty false
          ]
          [
            set empty true
          ]

          ;; updates the num of houses of the son
          ask lucky-son[ set num-houses num-houses + 1]
          ;; updates the price of the house
          set base-price base-price + (base-price * (TRANSACTION-TAX * 0.01))
        ]
      ]
    ]

    if SOCIAL-HOUSES
    [
      ;; gives the rest houses to homeless people
      ask houses with [owner = myself]
      [

        set heritage self
        let homeless min-one-of humans with [num-houses = 0] [money]
        ;; if there is nobody, this house will be removed at the end of the procedure
        if homeless != nobody[
          set owner homeless
          if trace [ show (word "Social house " self " from " myself " to " homeless )]
          ask homeless[
            set base-home heritage
            set num-houses num-houses + 1
            ]

          set empty false
        ]
      ]
    ]

    ;; destroy rest of properties
    if trace [ show (word "DESTROYING " count houses with [ owner = myself ] " houses ")]
    ask houses with [owner =  myself][
      ask patch-here [
        if not free[
          if trace [ show (word "Setting soil free")]
          set free true
        ]
      ]
      die
    ]
    ;; human dies pacefully
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
510
525
20
20
11.805
1
10
1
1
1
0
1
1
1
-20
20
-20
20
1
1
1
ticks
30.0

BUTTON
520
10
598
43
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
522
70
1036
103
SMI
SMI
1
2000
1000
1
1
€
HORIZONTAL

SLIDER
522
107
757
140
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
522
192
757
225
INIT-HOUSES
INIT-HOUSES
0
100
5
1
1
NIL
HORIZONTAL

SLIDER
522
282
754
315
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
616
10
679
43
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
1005
455
1225
Savings
NIL
€
0.0
10.0
0.0
10.0
true
true
"plot 0" ""
PENS
"mean" 1.0 0 -955883 true "" "plot MONITOR-MEAN-SAVINGS"
"median" 1.0 0 -13840069 true "" "plot MONITOR-MEDIAN-SAVINGS"

SLIDER
522
237
757
270
MAX-HOUSES-IN-PROPERTY
MAX-HOUSES-IN-PROPERTY
1
20
2
1
1
NIL
HORIZONTAL

PLOT
15
790
454
996
Home posession
NIL
humans
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
houses
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"empty" 1.0 0 -2674135 true "" "plot MONITOR-EMPTY-HOUSES"
"not empty" 1.0 0 -13840069 true "" "plot MONITOR-NOT-EMPTY-HOUSES"
"total" 1.0 0 -16777216 true "" "plot count houses"

PLOT
555
790
1030
995
Population
NIL
humans
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
768
233
1038
266
SOCIAL-STATUSES
SOCIAL-STATUSES
1
5
1
1
1
NIL
HORIZONTAL

MONITOR
460
1010
537
1055
max
MONITOR-MAX-SAVINGS
0
1
11

MONITOR
460
1060
537
1105
mean
MONITOR-MEAN-SAVINGS
0
1
11

MONITOR
460
1110
536
1155
median
MONITOR-MEDIAN-SAVINGS
0
1
11

MONITOR
460
795
540
840
homeless
MONITOR-HOMELESs
0
1
11

MONITOR
461
847
541
892
1 house
MONITOR-ONE-HOUSE
0
1
11

MONITOR
462
895
542
940
2 houses
MONITOR-TWO-HOUSES
0
1
11

MONITOR
462
945
542
990
+ houses
MONITOR-MORE-HOUSES
0
1
11

MONITOR
1035
600
1114
645
empty
MONITOR-EMPTY-HOUSES
17
1
11

MONITOR
1035
645
1114
690
not empty
MONITOR-NOT-EMPTY-HOUSES
17
1
11

MONITOR
1035
555
1115
600
total
count houses
0
1
11

MONITOR
525
430
591
475
humans
count humans
0
1
11

MONITOR
975
1005
1032
1050
built
MONITOR-HOUSES-BUILT
0
1
11

MONITOR
975
1055
1033
1100
bought
MONITOR-HOUSES-BOUGHT
0
1
11

SLIDER
765
148
1035
181
DESIRED-POPULATION
DESIRED-POPULATION
100
1000
1000
1
1
NIL
HORIZONTAL

SWITCH
522
327
755
360
HOMELESS-CAN-BUILD
HOMELESS-CAN-BUILD
0
1
-1000

SWITCH
694
11
797
44
TRACE
TRACE
1
1
-1000

PLOT
15
550
540
785
Prices
NIL
€
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"max-empty" 1.0 0 -2674135 true "" "plot MONITOR-MAX-EMTPY"
"max-not-empty" 1.0 0 -13840069 true "" "plot MONITOR-MAX-NOT-EMTPY"
"mean-empty" 1.0 0 -955883 true "" "plot MONITOR-MEAN-EMTPY"
"mean-not-empty" 1.0 0 -13791810 true "" "plot MONITOR-MEAN-NOT-EMPTY"
"min-empty" 1.0 0 -9276814 true "" "plot MONITOR-MIN-EMPTY"
"min-not-empty" 1.0 0 -5825686 true "" "plot MONITOR-MIN-NOT-EMPTY"

PLOT
555
1005
970
1225
Constructions / transactions
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
"built" 1.0 0 -2674135 true "" "plot MONITOR-HOUSES-BUILT"
"bought" 1.0 0 -13791810 true "" "plot MONITOR-HOUSES-BOUGHT"
"h bought" 1.0 0 -13840069 true "" "plot MONITOR-HOMELESS-HOUSES-BOUGHT"

CHOOSER
767
370
1039
415
UPDATE-HOUSE-PRICE
UPDATE-HOUSE-PRICE
"min" "mean" "median" "max"
1

SLIDER
768
190
1038
223
CONSTRUCTION-TAX
CONSTRUCTION-TAX
0
100
2
1
1
%
HORIZONTAL

MONITOR
825
430
1027
475
House with max transactions
max [transactions] of houses
17
1
11

MONITOR
605
430
697
475
homeless %
(count humans with [num-houses = 0]) / (count humans) * 100
0
1
11

MONITOR
710
430
812
475
empty houses %
(count houses with[empty])/ (count houses) * 100
0
1
11

PLOT
1045
1000
1500
1225
percentuals
NIL
%
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"empty houses" 1.0 0 -2674135 true "" "plot (count houses with[empty])/ (count houses) * 100"
"homeless" 1.0 0 -1184463 true "" "plot (count humans with [num-houses = 0]) / (count humans) * 100"

SLIDER
768
278
1038
311
DEVALUATE-EMPTY-HOUSE
DEVALUATE-EMPTY-HOUSE
0
5
1
1
1
%
HORIZONTAL

SWITCH
522
367
755
400
SOCIAL-HOUSES
SOCIAL-HOUSES
1
1
-1000

PLOT
1120
605
1500
780
Population per Social Status
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
"Level 1" 1.0 0 -7500403 true "" "plot count humans with [ social-status = 1 ]"
"Level 2" 1.0 0 -13840069 true "" "plot count humans with [ social-status = 2 ]"
"Level 3" 1.0 0 -13345367 true "" "plot count humans with [ social-status = 3 ]"
"Level 4" 1.0 0 -5825686 true "" "plot count humans with [ social-status = 4 ]"
"Level 5" 1.0 0 -955883 true "" "plot count humans with [ social-status = 5 ]"

PLOT
1040
790
1500
990
Homeless Population per Social Status
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
"Level 1" 1.0 0 -7500403 true "" "plot count humans with [ social-status = 1 and num-houses = 0 ]"
"Level 2" 1.0 0 -13840069 true "" "plot count humans with [ social-status = 2 and num-houses = 0 ]"
"Level 3" 1.0 0 -13345367 true "" "plot count humans with [ social-status = 3 and num-houses = 0 ]"
"Level 4" 1.0 0 -5825686 true "" "plot count humans with [ social-status = 4 and num-houses = 0 ]"
"Level 5" 1.0 0 -955883 true "" "plot count humans with [ social-status = 5 and num-houses = 0 ]"

MONITOR
1185
555
1242
600
1
count humans with [ social-status = 1 ]
0
1
11

MONITOR
1250
555
1307
600
2
count humans with [ social-status = 2 ]
0
1
11

MONITOR
1315
555
1372
600
3
count humans with [ social-status = 3 ]
0
1
11

MONITOR
1380
555
1437
600
4
count humans with [ social-status = 4 ]
0
1
11

MONITOR
1445
555
1502
600
5
count humans with [ social-status = 5 ]
0
1
11

SLIDER
767
325
1037
358
NEGOTIATION-POWER
NEGOTIATION-POWER
0
30
0
1
1
%
HORIZONTAL

SLIDER
522
147
757
180
TRANSACTION-TAX
TRANSACTION-TAX
0
100
2
1
1
%
HORIZONTAL

MONITOR
460
1160
535
1205
min
min [money] of humans
0
1
11

SLIDER
765
108
1035
141
CONSTRUCTION-BASE-PRICE
CONSTRUCTION-BASE-PRICE
0
50
0
1
1
smis
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

HOUSING (a general understanding of what the model is trying to show or explain)

## HOW IT WORKS


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
1.0
    org.nlogo.sdm.gui.AggregateDrawing 1
        org.nlogo.sdm.gui.ConverterFigure "attributes" "attributes" 1 "FillColor" "Color" 130 188 183 219 188 50 50
            org.nlogo.sdm.gui.WrappedConverter "" ""
@#$#@#$#@
<experiments>
  <experiment name="social-status-easy" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>(count humans with [num-houses = 0]) / (count humans) * 100</metric>
    <metric>mean [money] of humans</metric>
    <metric>median [money] of humans</metric>
    <metric>mean [base-price] of houses</metric>
    <enumeratedValueSet variable="CONSTRUCTION-TAX">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="UPDATE-HOUSE-PRICE">
      <value value="&quot;mean&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MAX-HOUSES-IN-PROPERTY">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="INIT-CITY-COUNCILS">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="NEGOTIATION-POWER">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MIN-POPULATION">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SMI">
      <value value="300"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DEVALUATE-EMPTY-HOUSE">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIAL-HOUSES">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="HOMELESS-CAN-BUILD">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TRACE">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="INIT-HOUSES">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DESIRED-POPULATION">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TRANSACTION-TAX">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIAL-STATUSES">
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="social-status-c" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>(count humans with [num-houses = 0]) / (count humans) * 100</metric>
    <metric>mean [money] of humans</metric>
    <metric>median [money] of humans</metric>
    <metric>mean [base-price] of houses</metric>
    <enumeratedValueSet variable="HOMELESS-CAN-BUILD">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="UPDATE-HOUSE-PRICE">
      <value value="&quot;mean&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="INIT-HOUSES">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MAX-HOUSES-IN-PROPERTY">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="INIT-CITY-COUNCILS">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TRACE">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MIN-POPULATION">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DESIRED-POPULATION">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CONSTRUCTION-TAX">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DEVALUATE-EMPTY-HOUSE">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TRANSACTION-TAX">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIAL-HOUSES">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="NEGOTIATION-POWER">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIAL-STATUSES">
      <value value="1"/>
      <value value="2"/>
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SMI">
      <value value="1000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="negotiation-power-c" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>(count humans with [num-houses = 0]) / (count humans) * 100</metric>
    <metric>mean [money] of humans</metric>
    <metric>median [money] of humans</metric>
    <metric>mean [base-price] of houses</metric>
    <enumeratedValueSet variable="HOMELESS-CAN-BUILD">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="UPDATE-HOUSE-PRICE">
      <value value="&quot;mean&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="INIT-HOUSES">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CONSTRUCTION-BASE-PRICE">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MAX-HOUSES-IN-PROPERTY">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="INIT-CITY-COUNCILS">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TRACE">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MIN-POPULATION">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DESIRED-POPULATION">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CONSTRUCTION-TAX">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DEVALUATE-EMPTY-HOUSE">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TRANSACTION-TAX">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIAL-HOUSES">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="NEGOTIATION-POWER">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIAL-STATUSES">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SMI">
      <value value="500"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="negotiation-power-d" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>(count humans with [num-houses = 0]) / (count humans) * 100</metric>
    <metric>mean [money] of humans</metric>
    <metric>median [money] of humans</metric>
    <metric>mean [base-price] of houses</metric>
    <enumeratedValueSet variable="HOMELESS-CAN-BUILD">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="UPDATE-HOUSE-PRICE">
      <value value="&quot;mean&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="INIT-HOUSES">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CONSTRUCTION-BASE-PRICE">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MAX-HOUSES-IN-PROPERTY">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="INIT-CITY-COUNCILS">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TRACE">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MIN-POPULATION">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DESIRED-POPULATION">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CONSTRUCTION-TAX">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DEVALUATE-EMPTY-HOUSE">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TRANSACTION-TAX">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIAL-HOUSES">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="NEGOTIATION-POWER">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIAL-STATUSES">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SMI">
      <value value="1000"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="negotiation-power-d-2" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="20000"/>
    <metric>(count humans with [num-houses = 0]) / (count humans) * 100</metric>
    <metric>mean [money] of humans</metric>
    <metric>median [money] of humans</metric>
    <metric>mean [base-price] of houses</metric>
    <enumeratedValueSet variable="HOMELESS-CAN-BUILD">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="UPDATE-HOUSE-PRICE">
      <value value="&quot;mean&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="INIT-HOUSES">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CONSTRUCTION-BASE-PRICE">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MAX-HOUSES-IN-PROPERTY">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="INIT-CITY-COUNCILS">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TRACE">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="MIN-POPULATION">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DESIRED-POPULATION">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="CONSTRUCTION-TAX">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="DEVALUATE-EMPTY-HOUSE">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TRANSACTION-TAX">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIAL-HOUSES">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="NEGOTIATION-POWER">
      <value value="5"/>
      <value value="10"/>
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SOCIAL-STATUSES">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SMI">
      <value value="1000"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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
