; Global variables ;
globals [
  objects        ; objects contains all the elements that are in the market
  current-offer  ; [object quantity cost winner]
  marketValue    ; The current value of the offer right now
  initial-market-value ; the marketValue when the offer was raised
  deadline       ; Time until the offer expires
  gold-value     ; current value of the gold
  incense-value  ; current value of the incense
  myrrh-value    ; current value of the myrrh
  raw-taxes      ;
  max-offer-duration ; max duration of the offer
  num-agents     ; num of agents which participate in the simulation
  the-winner     ;
  money-average  ;

  ; allien set up ;
  allien-win-percent         ; how much the alliens wanna win
  allien-panic-level         ; sell everything to stay alive
]

; Create breeds ;
breed [hoomans hooman]
breed [alliens allien]
breed [cows cow]

; Breed variables ;
turtles-own [
  money              ; current money of the turtle
  bag                ; the objects in the bag are follow this structure [element quantity payed]
  bid                ; current bid
  max-bid            ; max amount it's up to pay
  min-money          ; min money it must have
  bag-capacity       ; capacity of the bag
  panic-level
  taxes-payed        ; how much taxes have payed this turtle
  money-received
  total-contribution
  win-percent        ; how much it expects to win with an iteam
  win-percent-gold
  win-percent-incense
  win-percent-myrrh
  max-percent
  threshold          ; used to cow-offer
  risk               ; risk that the cows take
  class              ; poor, rich or average
]

; Setup the environment ;
to setup
  clear-all
  setup-variables
  create-agents
  setup-patches
  reset-ticks
end

; initialize all the variables ;
to setup-variables
  set objects ["gold" "incense" "myrrh"]
  set gold-value (random 200) + 300
  set incense-value (random 200) + 100
  set myrrh-value (random 200) + 50
  set deadline -1
  set max-offer-duration 10
  set num-agents 10
  set the-winner -1
  set bank-initial-percent 65
  set fading-collected-percent 0.21

  ; ui ;
  set raw-taxes 10
  set taxes-increment 1.5 ; > 1
  set tax-frequency 25
  set initial-money 5000

  set gold-volatility 4
  set incense-volatility 10
  set myrrh-volatility 20

  ; set up the allien strategy ;
  set allien-win-percent 1.05
  set allien-panic-level (raw-taxes + 100) ; must be bigger than taxes

end

; beautiful, right? ;
to setup-patches
  ask patches [ set pcolor white ]
end

; Main loop ;
to go

  if deadline < 0 [ create-offer ]
  ;update all stuff;
  update-market
  ; time to offersss ;
  cow-offer
  allien-offer
  hooman-offer

  ; update auction ;
  update-auction

  ; raise taxes each 500 ticks ;
  if ticks mod 500 = 0 [
    set raw-taxes (raw-taxes * taxes-increment)
  ]

  ; time to sell ;
  time-to-sell

 ; time to pay taxes ;
  if ticks > 1 [
    if ticks mod tax-frequency = 0 [
      pay-taxes
    ]
  ]

  ; get stats
  set money-average 0
  ask turtles [
    set money-average (money-average + money)
  ]
  set money-average (money-average / count turtles )
  update-class

  tick

  check-end
end

; step by step ;
to next-step

  if deadline < 0 [ create-offer ]
  ;update all stuff;
  update-market
  ; time to offersss ;
  cow-offer
  allien-offer
  hooman-offer

  ; update auction ;
  update-auction

  ; raise taxes each 500 ticks ;
  if ticks mod 500 = 0 [
    set raw-taxes (raw-taxes * taxes-increment)
  ]

  ; time to sell ;
  time-to-sell

  ; time to pay taxes ;
  if ticks > 1 [
    if ticks mod tax-frequency = 0 [
      pay-taxes
    ]
  ]

  ; get stats
  ask turtles [
    set money-average (money-average + money)
  ]
  set money-average (money-average / count turtles )
  update-class

  tick
  check-end

end

to check-end
  ifelse (count alliens = 0)[
    if (count hoomans = 0)[ set the-winner "cows" ]
    if (count cows = 0)[ set the-winner "hoomans" ]
  ][
    if (count hoomans = 0)[
      if (count cows = 0)[ set the-winner "alliens" ]
    ]
  ]

  if ( the-winner != -1) [
    user-message (word "John Davison Rockefeller would be proud of you, " the-winner ".")
    stop
  ]
end

to time-to-sell
  ; cows just sell the object as soon as they get it ;
  ask cows [
    if (length bag) > 1 [
      let current-object (item 0 bag)
      ; get the value of that item in the market ;
      let object-value ((item 1 current-object) * get-element-value (item 0 current-object))
      ; update money ;
      set money (money + object-value)
      ; remove object from the bag ;
      set bag remove-item 0 bag
      ; update threshold
      set threshold (random-float risk * money)
    ]
  ]

  ; if the alliens gain the money that they want, they just sell
  ask alliens [
    if (length bag) > 1 [
      let current-object (item 0 bag)
      ; get the value of that item in the market ;
      let object-value ((item 1 current-object) * get-element-value (item 0 current-object))
      let payed (item 2 current-object)
      if object-value > (payed * win-percent) [
        ; update money ;
        set money (money + object-value)
        ; remove object from the bag ;
        set bag remove-item 0 bag
      ]
    ]
  ]

  ; the behavoir of the hooman depends of the user ;
  ask hoomans [
    let i 0
    let current-object 0
    let object-value 0
    while [i < ((length bag) - 1)]
    [
      set current-object (item i bag)
      ; get the value of that item in the market and mult per quantity ;
      set object-value ((item 1 current-object) * get-element-value (item 0 current-object))
      let element (item 0 current-object)
      let payed (item 2 current-object)
      ; if I need the money ;
      ifelse money < panic-level
      [
        set money (money + object-value)
        set bag remove-item i bag
      ]
      ; If I dont need the money ;
      [
        ; if bag capacity is 0, sell the objects now
        ifelse (bag-capacity = 0)
        [
          set money (money + object-value)
          set bag remove-item i bag
        ]
      ; if bag capacity > 0 and money > panic-level, I can wait
      [
        ifelse element = "gold"
          [ ; if it's gold ;
            if object-value > (payed * win-percent-gold)
            [
              set money (money + object-value)
              set bag remove-item i bag
            ]
          ]
        [
         ifelse element = "incense"
          [ ; if it's incense ;
            if object-value > (payed * win-percent-incense)
            [
              set money (money + object-value)
              set bag remove-item i bag
            ]
          ]
          [ ; it's myrrh ;
            if object-value > (payed * win-percent-myrrh)
            [
              set money (money + object-value)
              set bag remove-item i bag
            ]
          ]
        ]
       ] ; end bag capacity 0 ;
      ]; end panic level if  ;
      ; check the next item of the bag ;
      set i (i + 1)
    ] ; end while ;
  ]
end

to pay-taxes
  ; it the mode distribute-system is avaible, the money collected by the taxes will be
  ; re-distributed. Everyones pays X taxes, and then the system calculates the average of the money
  ; among the turtles, the turtles that are below the average, will receive money.
  let to-pay 0
  ifelse distribute-system
  [
    let collected 0
    let average 0
    ask turtles [
      ifelse (taxes-percent = true)
      [
        set to-pay (money * (percent-of-taxes / 100) + raw-taxes)
        set money (money - to-pay)
      ]
      ; ELSE
      [
        set to-pay raw-taxes
        set money (money - to-pay)
      ]
        set collected (collected + to-pay)
        set taxes-payed (taxes-payed + to-pay)
        set average (average + money)
    ]
   set collected (collected - (collected * fading-collected-percent))
   ; Normalize average
   set collected (collected / (count turtles) )
   ask turtles [
     set money-received (money-received + collected)
     set total-contribution (taxes-payed - money-received)
     set money (money + collected)
   ]

  ]
  ; ELSE
  [
    ; if there is not distribute system the turtles just pay the taxes
    ask turtles [
      ifelse (taxes-percent = true)
      [
        set to-pay (money * (percent-of-taxes / 100) + raw-taxes)
        set money (money - to-pay)
      ]
      ; ELSE
      [
        set to-pay raw-taxes
        set money (money - to-pay)
      ]
      ; update variables
      set taxes-payed (taxes-payed + to-pay)
      set money-received (money-received + 0)
      set total-contribution (taxes-payed - money-received)
    ]
  ]
  ask turtles[
    ; if you can not pay, you must die
      if money < 0 [die]
  ]
end

; If the marketValue is bigger than the cost of the offer,
; the cows will raise the bid a 5% of the current cost. Muuuu!
to cow-offer
  ; am i the winner ?
  let winner (item 3 current-offer)
  ; If the cost is smaller than the marketValue, im gonna make money with this bb
  ask cows [
    if winner != who
    [
      let cost (item 2 current-offer)
      if cost < (marketValue + threshold)
      [
        if (money - (cost + (cost * 0.02))) > min-money
        [
          set bid (cost + (cost * 0.02))
          ; update current-offer
          set current-offer replace-item 2 current-offer bid
          set current-offer replace-item 3 current-offer who
        ]
      ]
  ]
  ask cows [set max-bid bid ]
  ]
end

; The alliens pay until they get an object, then they wait to their benefit comes magicaly
to allien-offer

   ; am i the winner ?
  let winner (item 3 current-offer)
  ; If the cost is smaller than my money, SHUT UP AND TAKE MY MONEY
  ask alliens [
    if winner != who
    [
      let cost (item 2 current-offer)
      if (cost * 1.01) < money
      [
        if length(bag) = 1 [
          set bid cost * 1.01
          ; update current-offer
          set current-offer replace-item 2 current-offer bid
          set current-offer replace-item 3 current-offer who
        ]
      ]
    ]
  ]
end

; hooman strategy
;
to hooman-offer
  ; update max-bid ;
  let hooman-max-bid 0
  let cost (item 2 current-offer)
  ; Calculate the max offert Im up to make ;
  ask hoomans [
    if (max-bid = -1) [
      set max-bid (cost * (max-percent))
    ]
    set hooman-max-bid max-bid
  ]

  let winner (item 3 current-offer)

  ; if the bag-capacity is 0, I need win instant money ;
  ask hoomans [
    ; If im not the winner, calculate next bid ;
    if winner != who
    [
      ifelse (bag-capacity = 0)
      [
        ; I need instant money. (cows strategy)  ;
        if (cost < marketValue)
        [
          if money - (cost + (cost * 0.03)) > min-money
          [ set bid (cost + (cost * 0.03)) ]
        ]
      ]
      ; If I can keep the item, i dont care of the current market Value ;
      [
        if (bag-capacity > (length bag) - 1)[
          ; am i up to pay that amount? ;
          if (cost < hooman-max-bid)
          [
            ; do i have enough money to pay my bid? ;
            if (money - (cost + (cost * 0.01))) > min-money
            [
              set bid (cost + (cost * 0.01))
              ; update current-offer
              set current-offer replace-item 2 current-offer bid
              set current-offer replace-item 3 current-offer who
            ]
          ]; end if ;
        ]
      ];end else bag-capacity ;
    ]
  ]
end


; Create agents ;
to create-agents

  create-alliens num-agents
  ask alliens [
    set shape "face happy"
    set color green
    setxy -10 0
    set bag-capacity 0
    set min-money 100
    ; Global variable ;
    set win-percent (random-float 1) + 1
    set panic-level allien-panic-level
  ]
  create-hoomans num-agents
  ask hoomans [
    set shape "person"
    set color black
    setxy 0 0
    set bag-capacity hooman-bag-capacity
    set min-money hooman-min-money
    ;; Cambiar el rango en el que se mueven los intervalos aleatorios
    ;; para que se ajusten a la input del usuario
    set panic-level (hooman-panic-level * (my-random-float(0.5) + 1))
    set win-percent-gold (hooman-win-percent-gold + my-random-float(0.2))
    set win-percent-incense (hooman-win-percent-incense + my-random-float(0.3))
    set win-percent-myrrh (hooman-win-percent-myrrh + my-random-float(0.4))
    set max-percent (hooman-max-percent + my-random-float(0.3))
  ]
  create-cows num-agents
  ask cows [
    set shape "cow"
    set color brown
    setxy 10 0
    set bag-capacity 0
    set min-money 1
    set risk random-float 0.10
    set threshold (random-float risk * initial-money)
  ]

  ; To all of them
  ask turtles [
    ; Random interval
    let plus random-float 0.5
    let minus random-float -0.5
    let total (plus + minus)
    set money (initial-money + (total * initial-money))
    set size 10 ; para que el tamanyo no se dispare
    ; initialize list ;
    set bag (list "$")
    ; initialize max-bid ;
    set max-bid -1
    ; initialize contributions ;
    set taxes-payed 0
    set money-received 0
    set total-contribution 0
    set money-average (money-average + money)
  ]
  set money-average money-average / (count turtles)

  update-class
end

to update-class
  let Hbound (money-average * 1.25)
  let Lbound (money-average * 0.75)
  ask turtles [
    ifelse(money > Hbound)[ set class "rich" ]
    [;ELSE
      ifelse(money < Lbound) [ set class "poor" ] [set class "average"]
    ]
  ]
end

; Create new offer
to create-offer
  ; pick random object
  let object one-of objects
  ; quantity of the object
  let quantity (random 50) + 1
  ; time to complete the negotation
  set deadline (random max-offer-duration) + 1
  ; calculate initial cost
  let ini_cost 0
  ifelse object = "gold"
    ; gold
    [ set ini_cost (gold-value * quantity) ]
  [ifelse object = "incense"
    ; incense
    [ set ini_cost (incense-value * quantity) ]
    ; myrrh
    [set ini_cost (myrrh-value * quantity) ]
  ]
  ; update the current offer ;
  set ini_cost (ini_cost * (bank-initial-percent / 100))
  set current-offer (list object quantity ini_cost "none")
  set initial-market-value ini_cost
  set marketValue ini_cost
end

; Update value of the market ;
to update-market
  ; update gold ;
  let variation get-variation gold-volatility
  set gold-value (gold-value + variation)
  if gold-value < 0 [ set gold-value 0]

  ; update incense ;
  set variation get-variation incense-volatility
  set incense-value (incense-value + variation)
  if incense-value < 0 [ set incense-value 0 ]

  ; update myrrh ;
  set variation get-variation myrrh-volatility
  set myrrh-value (myrrh-value + variation)
  if myrrh-value < 0 [ set myrrh-value 0 ]

  ; update marketValue ;
  let object (item 0 current-offer)
  let quantity (item 1 current-offer)
  ifelse object = "gold"
    [ set marketValue (gold-value * quantity) ]
  [ifelse object = "incense"
    [ set marketValue (incense-value * quantity) ]
    [ set marketValue (myrrh-value * quantity) ]
  ]
end

; Updates all the elements related with the auction house ;
to update-auction
  ; update best offer ;
  let best-offer (item 2 current-offer)
  ; update deadline ;
  set deadline (deadline - 1)
  ; check if finish ;
  if deadline < 1 [
    ; give the object to the winner ;
    ask turtles[
      if who = (item 3 current-offer)
      [
        set money (money - (item 2 current-offer))
        let object (list (item 0 current-offer) (item 1 current-offer) (bid))
        set bag fput object bag
      ]
      ; reset max-bid ;
      set max-bid -1
      ; reset bid ;
      set bid -1
    ]
  ]
end

; It returns a value inside of (-rang, rang)
to-report get-variation [rang]
  let plus (random rang)
  let minus (random rang) * -1
  report (plus + minus)
end

; It returns the current value of one element ;
to-report get-element-value [name]
  ifelse name = "gold"
  [report gold-value]
  [ifelse name = "incense"
    [report incense-value]
    [report myrrh-value]
  ]
end

to-report my-random-float [a]
  let plus (random-float a)
  let minus (random-float a) * -1
  report (plus + minus)
end
@#$#@#$#@
GRAPHICS-WINDOW
122
13
270
162
-1
-1
4.242424242424242
1
10
1
1
1
0
1
1
1
-16
16
-16
16
1
1
1
ticks
30.0

BUTTON
29
26
92
59
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
32
109
95
142
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
20
68
106
101
NIL
next-step
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
13
185
287
386
objects value / unity
time
value
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"gold" 1.0 0 -2674135 true "" "plot gold-value"
"incense" 1.0 0 -13840069 true "" "plot incense-value"
"myrrh" 1.0 0 -14454117 true "" "plot myrrh-value"

SLIDER
17
407
190
440
gold-volatility
gold-volatility
1
50
4.0
1
1
NIL
HORIZONTAL

SLIDER
17
451
189
484
incense-volatility
incense-volatility
1
50
10.0
1
1
NIL
HORIZONTAL

SLIDER
17
494
189
527
myrrh-volatility
myrrh-volatility
1
50
20.0
1
1
NIL
HORIZONTAL

MONITOR
391
21
472
66
marketValue
marketValue
17
1
11

MONITOR
485
21
552
66
Best bid
item 2 current-offer
2
1
11

PLOT
317
183
681
397
Average Money of each breed
time
money
0.0
10.0
0.0
10000.0
true
true
"" ""
PENS
"cows" 1.0 0 -8431303 true "" "let average 0\nask cows [\n  set average (average + money)\n]\nset average (average / (count cows))\nplot average"
"hoomans" 1.0 0 -16777216 true "" "let average 0\nask hoomans [\n  set average (average + money)\n]\nset average (average / (count hoomans))\nplot average"
"alliens" 1.0 0 -13840069 true "" "let average 0\nask alliens [\n  set average (average + money)\n]\nset average (average / (count alliens))\nplot average"
"average" 1.0 0 -2674135 true "" "plot money-average"

SLIDER
341
449
513
482
initial-money
initial-money
100
10000
5000.0
500
1
NIL
HORIZONTAL

MONITOR
286
22
382
67
ini MarketValue
initial-market-value
2
1
11

SLIDER
338
493
512
526
bank-initial-percent
bank-initial-percent
10
100
65.0
5
1
%
HORIZONTAL

SLIDER
342
409
513
442
taxes-increment
taxes-increment
1.1
5
1.5
0.1
1
NIL
HORIZONTAL

TEXTBOX
837
19
1062
55
HOOMAN CONTROLLER \n (With Random Interval) 
15
0.0
1

SLIDER
649
19
821
52
hooman-bag-capacity
hooman-bag-capacity
0
10
3.0
1
1
NIL
HORIZONTAL

SLIDER
649
58
821
91
hooman-min-money
hooman-min-money
0
2000
300.0
10
1
NIL
HORIZONTAL

SLIDER
649
135
821
168
hooman-max-percent
hooman-max-percent
1
5
1.1
0.1
1
NIL
HORIZONTAL

SLIDER
827
60
1071
93
hooman-win-percent-gold
hooman-win-percent-gold
0
5
1.05
0.05
1
NIL
HORIZONTAL

SLIDER
827
96
1020
129
hooman-win-percent-incense
hooman-win-percent-incense
0
5
1.1
0.05
1
NIL
HORIZONTAL

SLIDER
827
132
1023
165
hooman-win-percent-myrrh
hooman-win-percent-myrrh
0
5
1.25
0.05
1
NIL
HORIZONTAL

SLIDER
648
96
820
129
hooman-panic-level
hooman-panic-level
0
2000
110.0
10
1
NIL
HORIZONTAL

SWITCH
529
453
663
486
taxes-percent
taxes-percent
0
1
-1000

SLIDER
530
411
702
444
percent-of-taxes
percent-of-taxes
0
50
21.0
1
1
NIL
HORIZONTAL

SWITCH
526
492
677
525
distribute-system
distribute-system
0
1
-1000

SLIDER
209
491
316
524
tax-frequency
tax-frequency
1
50
25.0
1
1
NIL
HORIZONTAL

PLOT
685
183
943
396
Average total contribution
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"cows" 1.0 0 -6459832 true "" "let average 0\nask cows [\n  set average (average + total-contribution)\n]\nset average (average / (count cows))\nplot average"
"hoomans" 1.0 0 -16645118 true "" "let average 0\nask hoomans [\n  set average (average + total-contribution)\n]\nset average (average / (count hoomans))\nplot average"
"allien" 1.0 0 -13840069 true "" "let average 0\nask alliens [\n  set average (average + total-contribution)\n]\nset average (average / (count alliens))\nplot average"
"0" 1.0 0 -2674135 true "" "plot 0"

MONITOR
288
76
375
121
cows
count cows
17
1
11

MONITOR
388
76
464
121
alliens
count alliens
17
1
11

MONITOR
488
76
556
121
hoomans
count hoomans
17
1
11

SLIDER
713
414
951
447
fading-collected-percent
fading-collected-percent
0
1
0.21
0.01
1
NIL
HORIZONTAL

MONITOR
229
424
307
469
NIL
raw-taxes
2
1
11

PLOT
949
183
1209
395
Population Analysis
NIL
NIL
0.0
3.0
0.0
20.0
true
true
"set-histogram-num-bars 3" ""
PENS
"rich" 1.0 1 -13840069 true "" "let l []\nask turtles [\n  if(class = \"rich\")[set l fput 2 l]\n]\nhistogram l"
"poor" 1.0 1 -2674135 true "" "let l []\nask turtles [\n  if(class = \"poor\")[set l fput 0 l]\n]\nhistogram l"
"average" 1.0 1 -13345367 true "" "let l []\nask turtles [\n  if(class = \"average\")[set l fput 1 l]\n]\nhistogram l"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

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
NetLogo 6.0
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
0
@#$#@#$#@
