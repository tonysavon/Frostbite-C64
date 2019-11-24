
// Some random notes from the Reverse engineering process of the original game
// There's MUCH more, but most of the stuff I RE-ed has been put down in code straight away

/*
Night and day last 4 levels each

level 0-3 is day
4-7 is night
8-11 is day
and so on

Enemies are one per lane for the first levels
Then they go like
1,2,2,3 enemies for the first, second, third, fourth level of each lane

Hero walk speed is constant and does not depend on the level

Slab speed increases at every level

hero jump speed is always higher than slab scroll speed. Check code for the actual function.

For the firstlevel a slab transition takes ~1152 frames. Roughly 3 seconds on PAL.
which means 3.6 frames for a single pixel scroll.
initial speed must be %00001000
at level 16, slabs are 4 times faster, which gives us an indication of the speed function.

speed = %00001000 *  (level / 4)

We don't want the speed to be higher than 1 char per second for char objects in the screen, 
so the enemies top speed will be %11111111 which means that the slab top speed must be capped 
to %11000000. Which means that speed is only increasing for 48 levels, then it must settle.
Looking at the original code, this seems to be the case there as well.

Finally, these numbers have to be adjusted for the higher pixel density of the Commodore 64,
in order to preserve exactly the same "feeling" of the original. 
The resulting speed-tables are in the code.

Animated slab are animated at constant speed, regardless of the scroll speed.
A complete animation looop 0..8..1 lasts exactly 256 frames.   


The safe spot:
it's the left end side of the shore. It only works if you jump STRAIGHT UP from the first lane. 
This is a noticeable case of a bug turned into feature. Frostbite behaves like that because 
the shore and the lanes have a slightly different X-range. 
when jumping from the first lane to the shore you can therefore jump to an x-offset position 
you'd not be normally entitled to walk to, coming from a shore.
This "bug" is not there in the C64 version, because of the different control logic, so I had to
"implement" it. The hero status byte has a special STATUS_SAFESPOT flag that indicates that the
hero is standing on the safe spot, which activates the code to simulate the bug.

Enemies:
starting from level 6 (second night stage) crabs and shells do pauses. They pause for 64 frames 
and then go for 64 frames, in turns. All shells pause when the crab moves and vice-versa


This is the number of enemies per lane according to the level

01:	1
02:	2
03:	2
04:	1
05: 1
06: 2
07: 2
08: 3
09: 1
10: 2
11: 2
12: 3
13: 1
14: 2
15: 2
16: 3


so it's 1,2,2,1 for the first block of 4 levels, and then it goes 1,2,2,3 forever.


slab type: 0 = regular, 1 = cracking, 2 = long

01: 0
02: 2
03: 0
04: 2
05: 0
06: 1
07: 0
08: 1
09: 0
10: 1
11: 0
12: 1
13: 0
14: 1
15: 0
16: 1
17: 0
18:	1
19: 0
20: 1

so it's 0,2,0,2 and then it's 0,1 forever

