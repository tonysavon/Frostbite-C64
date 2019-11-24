.plugin "se.triad.kickass.CruncherPlugins"

.const p0start = $02
.var p0current = p0start
.function reservep0(n)
{
	.var result = p0current
	.eval p0current = p0current + n
	.return result	
}

.const sid = LoadSid("..\sid\Frostbite_C64.sid")
.pc = $2a00 "sid"
.fill sid.size,sid.getData(i)

.label loaderbitmap = $c000

.const KOALA_TEMPLATE = "C64FILE, Bitmap=$0000, ScreenRam=$1f40, ColorRam=$2328, BackgroundColor = $2710"
.var kla = LoadBinary("../gfx/loader.kla", KOALA_TEMPLATE)

.var shorekla = LoadBinary("../gfx/shore.kla", KOALA_TEMPLATE)
.var shorekla2 = LoadBinary("../gfx/shoredark2.kla", KOALA_TEMPLATE)

.const menulevel = reservep0(1)
.const messagemode = reservep0(1)
.const music_on = reservep0(1)
.const key_clock = reservep0(1)
.const hud_clock = reservep0(1)

.const herox = reservep0(2)	//subchars + chars
.const heroy = reservep0(1)	//pixels. temporary variable, doesn't really always keep hero y 
.const herof = reservep0(3)	//hero frame, one per hw sprite. We could use only one, but this pushes calculations outside of the irq and makes implementation of sequences easier
.const heroc = reservep0(3)	//same
.const herostatus = reservep0(1) 
.const herolane = reservep0(1) //0-5 0 = shore

.const jumpclock = reservep0(1)

.const jumpspeed = reservep0(1)
.const walkspeed = reservep0(1)

.const lives = reservep0(1)
.const level = reservep0(1)

.const igloo_size = reservep0(1)

.const bearf = reservep0(1) //bear frame. In this case, we just use one pointer for the top-lef sprites. the remaining frames will be +1.. +3
.const bearc = reservep0(2) //bear colors


.const score = reservep0(6)
.const timer_value = reservep0(3) //2 digits, plus frames of time unit. One time unit both on the A8 and vcs version is exactly 128 frames
								  //this is big-endian, unlike the other multi-byte values
.const clock = reservep0(1)
.const frameflag = reservep0(1)

.const ghostd01f = reservep0(1)
.const mustredraw = reservep0(1)  //sometimes we don't need to redraw the screen upon starting a new level. 
								  //Screen must only be redrawn when starting a new game or moving between night and day or viceversa

.var p0tmp = reservep0(8)

.var sprtmp = reservep0(1)

.const scrn = $4000

.macro setirq(addr,line)
{
		lda #<addr
		sta $fffe
		lda #>addr
		sta $ffff
		lda #line
		sta $d012
}



.pc = $0801 
:BasicUpstart($0820)


.pc = $0820 "main"

			sei
			lda #$35
			sta $01
			
			jsr showpic
			
			jsr waitbutton
				
			lda #$0b
			sta $d011
	
			lda #$01
			sta menulevel			
			
	splashloop:
			jsr splash

			lda menulevel
			
			sta level
								
			jsr vsync
			lda #$0b
			sta $d011
		
			lda #1
			sta mustredraw	
			
			jsr init_screen_mode
			
			jsr init_game
					
			jsr clear_irq
			
			:setirq(irq_top, 8) 
			lda #$1b
			sta $d011
			
			
			cli
			
		levelloop:
			jsr bear.off
		
			jsr environment.init
			
		
		lifeloop:
			jsr init_level //also sets speed and slab offset
		
			ldx #3
		!:	jsr enemies.clear_enemylane
			jsr enemies.deploy
			dex
			bpl !-
		
			
			lda level
			cmp #3
			bcs !bear+
			jmp !nobear+
		!bear:	
			sbc #1
			and #4
			beq !day+
			jmp !night+
			
		!day:
			
			:blithp(src_day_bear,bear_sprites,12)
			lda #7
			sta bearc
			lda #1
			sta bearc + 1
			jmp !dep+
		!night:	
	
			:blithp(src_night_bear,bear_sprites,12)
			lda #$0c
			sta bearc
			lda #$0b
			sta bearc + 1
			
			!dep:
			
			.for (var layer = 0; layer < 2; layer++) 
				.for (var frame = 0; frame < 6; frame++)
					.for (var halve = 0; halve < 2; halve++)
						:flipspr(bear_sprites + layer * 6 * 128 + frame * 128 + halve * 64, bear_sprites + 12 * 128 + layer * 6 * 128 + frame * 128 + (1-halve) * 64)
			
			jsr bear.deploy
			
		!nobear:
						
			jsr timer.init
			jsr hero.init
			jsr hud_init
			
			
			jsr get_ready
			
		gameloop:
			jsr framevsync

			jmp test_game_events	//this could break the loop, so we jmp.
			return_from_test_game_events:
			jsr controls
			jsr environment.update
			jsr enemies.update
			jsr bear.update
			
			jsr hero.update
			jsr timer.tick
				
			inc clock
			jmp gameloop
			
			
			
.macro test_object_collision(enemy0_active, offset_h0)
{
			lda enemy0_active,x
			beq !en1+
			ldy	offset_h0,x
			cpy herox + 1
			beq !hit+
			dey
			cpy herox + 1
			beq !hit+
			jmp !en1+
		!hit:	
			lda enemies.enemylane.type,x
			cmp #ENEMY2CHARS //fish
			beq !fish+
			cmp #ENEMY2CHARS + 4
			beq !fish+
		 !deadlyenemy:
		 	
		 	lda herostatus
		 	ora #STATUS_STUCK
		 	sta herostatus
		 	ldx #$ff
			jmp !en1+
		 	
		!fish:
			
			lda #0
			sta enemy0_active,x
			jsr enemies.redraw_enemylane
			lda #2
			jsr add_score_xx
			
			:sfx(SFX_FISH)
			
			ldx #$ff //signal exit
		!en1:				
}			


test_game_events:
{			

			//additional controls
				lda key_clock
				beq !skp+
				dec key_clock
			!skp:

				lda hud_clock
				beq !skp+
				
				dec hud_clock
				bne !skp+
				
				lda #[empty_sprite & $3fff] / 64
				sta irq_top.note_sprf + 1
				
			!skp:	
			
				//check keypress for various things, such as pause or music on/off
				lda $dc01
				cmp #239
				bne !skp+

				jsr  pause
				lda #255
				
			!skp:
			
				cmp #253
				bne !skp+
				
				jsr toggle_music
			
				
			!skp:		


			//test if level complete
			//for a level to be complete, we need igloo_size = 16, hero_lane = 0 and a certain x position 		
	!next:		
			lda igloo_size
			cmp #16
			bne !next+
			
			lda herolane
			bne !next+
			
			lda herox + 1
			cmp #30
			bne !next+
			
			lda #STATUS_JUMPING
			bit herostatus
			bne !next+
			
			lda controls.backup
			and #%00000001
			bne !next+
			
			//level up!
			jmp end_of_level_sequence
			
	!next:
			//various deadly scenarios
			//1. tst if we are in the water
			
			lda #STATUS_JUMPING
			bit herostatus
			beq !nojmp+
			jmp !next+
		!nojmp:
			ldx herolane
			bne !noshore+
			jmp !next+
		!noshore:
			dex
			
			
			lda ghostd01f
			and #%10000000
			bne !nodrown+
		
			jmp death_by_drowning
				
	!nodrown:
			// test if we hit an object

			:test_object_collision(enemies.enemylane.enemy0_active, enemies.enemylane.offset_h0)
			cpx #$ff
			bne !skp+
			jmp !next+
		!skp:	
			:test_object_collision(enemies.enemylane.enemy1_active, enemies.enemylane.offset_h1)
			cpx #$ff
			bne !skp+
			jmp !next+
		!skp:	
			:test_object_collision(enemies.enemylane.enemy2_active, enemies.enemylane.offset_h2)
			//cpx #$ff
			//bne !skp+
			//jmp !next+
		
			//2second death scenario: time out	
	!next:	
			lda timer_value
			bpl !next+
		
			jmp frozen_to_death
				
	!next:			
	
			//third and last death scenario: Bear
			lda bear.active
			beq !next+
	
			lda herolane
			bne !next+
			
			lda #STATUS_JUMPING
			bit herostatus
			bne !next+
			
			lda herox
			clc
			adc #%10000000
			lda herox + 1
			adc #0
			cmp bear.xpos + 1
			bmi !next+
			
			lda herox + 1
			sec
			sbc #4
			cmp bear.xpos + 1
			bpl !next+
			
			jmp death_by_bear
		
			//test if a we cleared a slab, as report	
	!next:
			lda #STATUS_CLEARED_SLAB
			bit herostatus
			beq !next+

			ldx environment.slabcleared
			
			lda #1
			sta environment.slablane.status,x

			lda igloo_size
			cmp #16
			beq !skip_score+
			
			lda level
			cmp #9
			bcc !skp+
			lda #9
				
		!skp:
			jsr add_score_x
			
			jsr environment.build_igloo
			inc igloo_size
				
			lda #16
			sta environment.slablane.resetclock
		!skip_score:	
			lda #$FF - STATUS_CLEARED_SLAB
			and herostatus
			sta herostatus
			
			lda music_on
			bne !skp+		//this effect can't be played if music on as it kills the jump effect
			:sfx(SFX_LANDING)
			!skp:
			
	!next:		

			jmp return_from_test_game_events
}


game_over:
{
	
			lda #4			//end jingle
			jsr sid.init 
		
			lda #0
			sta heroy
			sta herolane
			sta herostatus
			
			lda #[empty_sprite & $3fff] / 64
			sta herof
			sta herof + 1
			sta herof + 2
			
			
			lda #1
			sta messagemode
		!l:	
			jsr environment.update
			jsr enemies.update
			jsr bear.update
			
			jsr vsync
			inc clock
			lda #%00010000
			bit $dc00
			bne !l-
			
			jmp splashloop
			
}

get_ready:
{
			lda #2
			sta messagemode
			ldx #96
		!:	jsr wait_frames
			
			lda #0
			sta messagemode
			rts
			
}

death_by_bear:
{
	
			lda clock
			and #%11111110
			sta clock //prevents bear from switching direction
			
			lda bear.speed
			sta savesp + 1
			
			
			lda #%00111000
			sta bear.speed	
			
			ldx bear.xpos + 1
			inx
			cpx herox + 1
			
			bcc !chase_right+
			
			//chase left
			lda #STATUS_MOVING | STATUS_DIRECTION
			sta herostatus
				
			lda #1
			sta bear.direction

		!:		
			jsr bear.update
			jsr hero.update

			lda controls.walkframe
			clc
			adc #8
			cmp #5*32
			bcc !skp+
			lda #0
		!skp:
			sta controls.walkframe
					
			lda herox
			sec
			sbc #%01000000
			sta herox
			lda herox + 1
			sbc #0
			sta herox + 1
			cmp #$fd
			beq !done+
			
			jsr framevsync
			inc clock
			lda clock
			and #$7
			bne !skp+
			:sfx(SFX_BEAR)
		!skp:
			jmp !-
		
		!chase_right:
			
			//chase right
			lda #STATUS_MOVING
			sta herostatus
				
			lda #0
			sta bear.direction
		
		!:		
			jsr bear.update
			jsr hero.update

			lda controls.walkframe
			clc
			adc #8
			cmp #5*32
			bcc !skp+
			lda #0
		!skp:
			sta controls.walkframe
					
			lda herox
			clc
			adc #%01000000
			sta herox
			lda herox + 1
			adc #0
			sta herox + 1
			cmp #39
			beq !done+
			
			jsr framevsync
			inc clock
			lda clock
			and #$7
			bne !skp+
			:sfx(SFX_BEAR)
		!skp:
			jmp !-
			
		
		
		!done:
	savesp:	lda #0
			sta bear.speed
			
			jmp death
			
.byte clock
}

death_by_drowning:
{
			//:B2_DECRUNCH(drown_sprites_src)
			
			:blithp(src_drown_sprites,drown_sprites,3)
			lda #[drown_sprites & $3fff] / 64
			sta herof
			lda #[drown_sprites & $3fff] / 64 + 2
			sta herof + 1
			lda #[drown_sprites & $3fff] / 64 + 4
			sta herof + 2
	
			:sfx(SFX_SPLASH)
					
			ldy #20
		!l:	
			ldx #4
			jsr wait_frames
			jsr d_shift
			
			inc herof
			inc herof + 1
			inc herof + 2
			ldx #4
			jsr wait_frames
			jsr d_shift
			
		
			dec herof
			dec herof + 1
			dec herof + 2
				
			dey
			beq !done+
			jmp !l-	
			
		!done:
			jmp death	
			
			
		d_shift:	
			ldx #57
		!:	
			.for (var i = 0; i < 6; i ++)
			{
				lda 64 * i + drown_sprites + 0,x
				sta 64 * i + drown_sprites + 3,x
				lda 64 * i + drown_sprites + 1,x
				sta 64 * i + drown_sprites + 4,x
				lda 64 * i + drown_sprites + 2,x
				sta 64 * i + drown_sprites + 5,x
			}			
			
			dex
			dex
			dex
			bpl !-	
			rts
}

frozen_to_death:
{
			lda #6 
			sta heroc
			lda #14
			sta heroc + 1
			lda #3
			sta heroc + 2
			
			ldx #32
			jsr wait_frames
			
			jmp death
			
}

death:
{
			dec lives
		
			ldx #32
			jsr wait_frames
			
			lda lives
			beq !go+
			
			lda #$02
			ldx music_on
			bne !skp+
			lda #$03
		!skp:	
			jsr sid.init
	!noinit:		
			jmp lifeloop
			
	!go:	jmp game_over
}

end_of_level_sequence:
{
			//first thing, lets center the player
			lda #%10000000 - 1
			sta herox 

			lda #[crawl_sprites & $3fff] / 64
			sta herof + 1
			
			lda #[empty_sprite & $3fff] / 64		
			sta herof
			sta herof + 2
			
			
			//color time white
			jsr color_hud_area
		
			:sfx(SFX_JUMP)
				
		!:	
			ldx #8
			jsr wait_frames
			inc herof + 1
			lda herof + 1
			cmp #[crawl_sprites & $3fff] / 64 + 7
			bne !-
			
			lda #[empty_sprite & $3fff] / 64
			sta herof + 1
			
			lda level
			cmp #10
			bcc !ok+
			lda #9
		!ok:	
			sta igscr + 1
			sta tmscr + 1
			jsr add_score_x
			ldx #6
			jsr wait_frames
			
			
		!:	jsr environment.break_igloo
		
			:sfx(SFX_IGLOO)
		
	igscr:	lda #$00
			jsr add_score_x

			ldx #6
			jsr wait_frames
			lda igloo_size
			bne !-
		
			//now add score for the remaining time
			lda timer_value		
			bmi !next+
		!:	
			lda timer_value
			ora timer_value + 1
			beq !next+
			
			:sfx(SFX_BONUS)
			
	tmscr:	lda #0
			jsr add_score_x
			
			dec timer_value + 1
			bpl !upd+
			lda #9
			sta timer_value + 1
			dec timer_value 
		
		!upd:
			jsr timer.update	
	
			ldx #5
			jsr wait_frames
			
			jmp !-	
			
		!next:
			inc level
			
			ldx #0
		
			lda level
			sec
			sbc #1
			and #3
			bne !skp+
			inx		
		!skp:
			stx mustredraw	
			jmp levelloop
}

init_game:
{
			
			lda #4
			sta lives
					
			lda #0
			
			sta messagemode
			sta frameflag
	
			ldx #5
		!:	sta score,x
			dex
			bpl !-

			lda #0
			sta key_clock
	
			lda #127
			sta hud_clock
			
			lda #[note_sprites & $3fff] / 64 + 0
			sta irq_top.note_sprf + 1
			
			lda #1
			sta music_on
					
			jsr set_sfx_routine
			
			lda #2
			jsr sid.init
			
			rts
}


init_level:
{

			jsr bear.off

			ldx level
			dex
			cpx #48
			bcc !skp+
			
			ldx #47
			
		!skp:
		
			lda jumpspeed_table,x
			sta jumpspeed
			
			lda enemyspeed_table,x
			sta enemies.enemylane.speed
			
			sta bear.speed
			
			lda slabspeed_table,x
			sta environment.slablane.speed
			
				
			
			lda #%00110000
			sta walkspeed
								
			lda #%00000000
			sta environment.slablane.offset_l + 0
			lda #%01000000
			sta environment.slablane.offset_l + 1
			lda #%10000000
			sta environment.slablane.offset_l + 2
			lda #%11000000
			sta environment.slablane.offset_l + 3
			
			lda #24
			sta environment.slablane.offset_h + 0
			sta environment.slablane.offset_h + 2
			
			lda #0
			sta environment.slablane.offset_h + 1
			sta environment.slablane.offset_h + 3
			
			lda #0
			ldx #3
		!:	
			sta environment.slablane.status,x		
			dex
			bpl !-
					
			lda #1
			sta environment.slablane.direction + 0
			sta environment.slablane.direction + 2
			lda #0
			sta environment.slablane.direction + 1
			sta environment.slablane.direction + 3
					
			lda level
			cmp #4
			bne !skp+
							//1,2,2,1  1,2,2,3... check notes
			lda #1
			jmp !str+
		!skp:
			sec
			sbc #1
			and #3
			tax
			
			lda enemiesn_table,x
			
		!str:
			sta enemies.enemylane.enemiesperlane
		
			
			lda level
			sec
			sbc #1
			
			and #1
			
			ldx level
			cpx #5
			bcs !str+
			
			asl
				
		!str:
			sta environment.slabtype	
					
			ldx #3
		!:	jsr environment.redraw_slab
			dex
			bpl !-
							
			rts		
			
		
// Speed table for various actors in the game.
// Speed doesn't increse after level 48 (but good luck getting there!)	
slabspeed_table:
.fill 48 , %00001000 * (i / 4.0 + 1.0)

jumpspeed_table:
.fill 48 , %00001000 * (i / 4.0 + 2.0) * 1.6

enemyspeed_table:
.fill 48 , %00001000 * (i / 4.0 + 1.0) * 1.5
			
// Number of enemies per row, per level.			
enemiesn_table:
.byte 1,2,2,3
}

.import source "environment.asm"
.import source "hero.asm"
.import source "controls.asm"
.import source "hud.asm"
.import source "enemies.asm"
.import source "misc.asm"
.import source "splash.asm"
.import source "sfx.asm"


init_screen_mode:
{
			lda #$02
			sta $dd00
			lda #%00001110 //screen at $4000, chars at $7800
			sta $d018
			lda #$06
			sta $d021
			lda #$00
			sta $d020
			lda #$d0
			sta $d016
						
			
			ldx #0

		!:	lda #9 + 0
			sta $d800,x
			sta $d900,x
			sta $da00,x
			sta $db00,x
			lda #0
			sta scrn + $000,x
			sta scrn + $100,x
			sta scrn + $200,x
			sta scrn + $300,x
	
			inx
			bne !-
	
			rts
}


.macro irq_enemy_x(n)
{
			lda	enemies.enemylane.type + n
			sec
			sbc #ENEMY0CHARS
			lsr
			lsr
			lsr
			tax
			
			lda enemies.enemycolor0,x
			sta $d022
			lda enemies.enemycolor1,x
			sta $d023
			
			!scroll:
			lda enemies.enemylane.offset_l + n
			lsr
			lsr
			lsr
			lsr
			lsr
			
			//eor #%111
			ora #$d0
			sta $d016
}

.macro irq_slab_x(n)
{
			ldx environment.slablane.status + n
			
			lda environment.slabcolor0,x
			sta $d022
			lda environment.slabcolor1,x
			sta $d023
			

		!scroll:
			lda environment.slablane.offset_l + n
			lsr
			lsr
			lsr
			lsr
			lsr
			
			eor #%111
			ora #$d0
			sta $d016
}


// Irq-split handlers
// They mostly handle bg and mc color change and the scroll for the enemies and slabs lanes
// This game is quite raster-split intensive


// Sets HUD sprits and plays music
irq_top:
{
			sta savea + 1
			stx savex + 1
			sty savey + 1
			
			jsr random_


 skycolor:	lda #$0e
			sta $d021
				
			lda #$d0
			sta $d016 //reset screen
			
			
			jsr sid.play
					
			lda #$00
			sta $d022
			lda #$00
			sta $d023
			
			lda #$ff
			sta $d01c

			lda #$00
			sta $d025
			lda #$0f
			sta $d026
			
			lda #%00001111
			sta $d015
			lda #0
			sta $d010
			
			
			lda #48
			sta $d001
			sta $d003
			sta $d005
			sta $d007

			lda #36
			
			sta $d000
			sta $d002
			sta $d004
		
			lda #132
			sta $d006
			

			lda #[hud_lives & $3fff] / 64 + 0
			sta scrn + $3f8 + 0
			lda #[hud_lives & $3fff] / 64 + 1
			sta scrn + $3f8 + 1
			lda #[hud_lives & $3fff] / 64 + 2
			sta scrn + $3f8 + 2
			
	note_sprf:		
			lda #[note_sprites & $3fff] / 64
			sta scrn + $3f8 + 3

			lda #7 
			sta $d027
			lda #8
			sta $d027 + 1
			lda #10
			sta $d027 + 2
				
			lda #2
			sta $d027 + 3
			
			
			lsr $d019
			:setirq(irq_movetobmp, 51 + 19 - 3)
	savea:	lda #$00
	savex:	ldx #$00
	savey:	ldy #$00
	
			rti
}


// Switches to BMP mode for the shore
// Places game sprites
// Draws $d021 rasterbars for the sky effect 

irq_movetobmp:
{

			sta savea + 1
			stx savex + 1
			sty savey + 1			
			
			lda #%11111111
			sta $d01c
			
			lda #%00000111 //hero always on
			sta $d015
			
			lda #%10000000
			sta $d010
			
			
			//igloo door
			
			lda igloo_size
			cmp #16
			bne !skp+
			
			lda #%10000111
			sta $d015
			
		!skp:
			
			lda #[door_sprite & $3fff] / 64 
			sta scrn + $3f8 + 7 // door
			
			lda #16
			sta $d000 + 7 * 2
			lda #86
			sta $d001 + 7 * 2
			
			lda $d011
			ora #$28
			//lda #$3b
			sta $d011 	//bitmap mode, plus restore border
			lda #%00001000
			sta $d018
			

			lda level
			sec
			sbc #1
			and #4
			bne !night+
			
			//day
			lda #0
			sta $d027 + 7
			jmp !bear+
			
		!night:
			ldx #2
			lda random_.random
			and #%00001111
			beq !skp+
			ldx #7
		!skp:	
			stx $d027 + 7	
		!bear:	
			//bear
			lda bear.active
			beq !skp+ //no bear	
			
			lda $d015
			ora #%01111000
			sta $d015
			
			ldx bearf
			stx scrn + $3f8 + 3
			inx
			stx scrn + $3f8 + 4
			inx
			stx scrn + $3f8 + 5
			inx
			stx scrn + $3f8 + 6
			
			lda bearc //#7 //0c
			sta $d027 + 3
			sta $d027 + 4
			
			lda bearc + 1 //#1 //0b
			sta $d027 + 5
			sta $d027 + 6
			
			lda bear.xpos
			clc
			adc #0
			sta sprtmp
			lda bear.xpos + 1
			adc #3 //3 chars = 24 pixels, which is left border size
			
			asl sprtmp
			rol 
			asl sprtmp
			rol
			asl sprtmp
			rol
			
			sta $d000 + 3 * 2
			sta $d000 + 5 * 2
			
			lda #0
			sta sprtmp
		
			bcc !noov+
			lda $d010
			ora #%00101000
			sta $d010		
			
			lda #1
			sta sprtmp
		!noov:
			
			lda $d000 + 3 * 2
			clc
			adc #24
			sta $d000 + 4 * 2
			sta $d000 + 6 * 2	
			
			lda sprtmp
			adc #0
			beq !noov+
				
			lda $d010
			ora #%01010000
			sta $d010
		!noov:
			
			lda #96
			sta $d001 + 3 * 2
			sta $d001 + 4 * 2	
			sta $d001 + 5 * 2
			sta $d001 + 6 * 2
			
		!skp:	
			//hero
			lda heroc //#7
			sta $d027 + 0
			lda heroc + 1 //#8
			sta $d027 + 1
			lda heroc + 2 //#10
			sta $d027 + 2
			
			
		
			lda herox
			clc
			adc #0
			sta sprtmp
			lda herox + 1
			adc #3 //3 chars = 24 pixels, which is left border size
			
			asl sprtmp
			rol 
			asl sprtmp
			rol
			asl sprtmp
			rol
			
			sta $d000
			sta $d002
			sta $d004
		
			bcc !skp+
			lda $d010
			ora #%00000111
			sta $d010		
		
		!skp:
		
			//clc
				
			lda herof
			sta scrn + $3f8 + 0
		
			lda herof + 1 //adc #9
			sta scrn + $3f8 + 1	
			
			lda herof + 2 //adc #9
			sta scrn + $3f8 + 2
			
			
			ldx herolane
			lda hero_y_offset,x
			
			sta heroy //temporary value
			
			lda #STATUS_JUMPING
			bit herostatus
			beq !skp+
			
			ldx jumpclock
			
			lda #STATUS_YDIRECTION
			bit herostatus
			beq !jumpdown+
			
			lda heroy
			sec
			sbc jump_trajectory_up,x
			//sta heroy 
			jmp !str+
		!jumpdown:	
			
			lda heroy
			sec
			sbc  jump_trajectory_down,x
			jmp !str+
		!skp:
		
			lda heroy	
		!str:	
			sta $d001
			sta $d003
			sta $d005
						
			
			// gradient for the sky rasterbars		


			lda #51 + 25 - 1 
		!:	cmp $d012
			bcs !-

			
			lda gradient_frame
			and #%11110000
			tay
			
		.for (var i = 0; i < 12; i++)
		{	
		
			.if (((i + 1 + 51 + 25) & 7) == %011) //badline
			{
				ldx gradient,y
			
				.fill 21, $ea //nop
				iny
				stx $d021
			}
			else
			{
				ldx gradient,y
				iny
				lda $d012
			!:	cmp $d012
				beq !-
				stx $d021
			}	
		}
			
			lda gradient_frame
			clc
			adc #2 
			cmp #6 * 16
			bcc !skp+
			lda #0
		!skp:
			sta gradient_frame
			
		!skp:	
					
pondcolor:	lda #$06
			sta $d021
	
			lsr $d019
			:setirq(irq_sea, 51 + 72 - 3)
	savea:	lda #$00
	savex:	ldx #$00
	savey:	ldy #$00
			rti
			
gradient_frame:
.byte 0
}



// Back to charmode
// Places the collision sprite.
// We can't use regular collision with the main sprite(s) to understand whether the hero is standing on something
// because the pseudo-3d nature of ice blocks. 
// Bounding box approach is also not viable, because of the way the slabs animate.
// But pixel-perfect accuracy is required here, we use a fourth invisible sprite which has the same color of the sea
// and a lower priority than chars. This sprite has the shape of an imaginary poligon in the same pseudo-3d of 
// the ice blocks. Something like this:
// 
//   *******
//  *******
// *******
//
// Despite its invisible nature, this sprite will still trigger HW collision detection.

irq_sea:
{
			sta savea + 1
			stx savex + 1
	
			lda #$06
			sta $d021
						
			lda herolane
			beq !skp+
			
			lda #STATUS_JUMPING
			bit herostatus
			bne !skp+
			
			//place the collision sprite
			//first, clear the $d01f flag
			bit $d01f
			lda #[collision_sprite & $3fff] / 64
			sta scrn + $3f8 + 7
			lda $d000
			sta $d000 + 7 * 2
			ldx $d001
			//inx
			stx $d001 + 7 * 2
			lda $d010
			and #%01111111
			sta $d010
			lsr
			bcc !nof+
			lda $d010
			ora #%10000000
			sta $d010
			
		!nof:	
			lda #%10000111
			sta $d015	
			lda #%10000000
			sta $d01b
			lda #%01111111
			sta $d01c
			lda #$06
			sta $d027 + 7
			
		!skp:			
								
			lda #51 + 72
		!:	cmp $d012
			bcs !-
			
			lda #%00001110
			sta $d018
				
			lda $d011
			and #$ff - $20	
			//lda #$1b
			sta $d011
			
			:irq_enemy_x(0)
			
			lda messagemode
			bne !msg+
	
			jmp !skp+

			!msg:
			ldx #152
			
			.for (var i = 0; i < 8; i++)
			{
				lda #87 + 24 * i
				stx $d001 + i * 2	
			}
	
			
			lda #3
			.for (var i = 0; i < 8; i++)
			{
				sta $d027 + i
			}
						
			lda messagemode
									
			asl
			asl
			asl
			
			adc #[gogr_sprites & $3fff] / 64 -8 + 7 
			ldx #7
			sec
		!:	sta scrn + $3f8 , x
			sbc #1
			dex
			bpl !-
			
			lda #0
			sta $d010
			lda #$ff
			sta $d015

			lda #1
			sta $d025
			lda #14
			sta $d026
			
			
			.var xoff = 103
			
			lda messagemode
			cmp #1
			beq !go+
			
			//get ready
			.for (var i = 0; i < 3; i++)
			{
				lda #xoff
				sta $d000 + i * 2 
				.eval xoff = xoff + 20
			}	
			.eval xoff = xoff + 12
			
			.for (var i = 3; i < 8; i++)
			{
				lda #xoff
				sta $d000 + i * 2 
				.eval xoff = xoff + 20
			}
			jmp !skp+
			
		!go:
			//get ready
			.eval xoff = 103
			.for (var i = 0; i < 4; i++)
			{
				lda #xoff
				sta $d000 + i * 2 
				.eval xoff = xoff + 20
			}	
			.eval xoff = xoff + 12
			
			.for (var i = 4; i < 8; i++)
			{
				lda #xoff
				sta $d000 + i * 2 
				.eval xoff = xoff + 20
			}
		!skp:	
			lsr $d019
			:setirq(irq_slab_0, 51 + 88 + 32 * 0)
savea:		lda #$00
savex:		ldx #$00
			rti
}

irq_slab_0:
{
			sta savea + 1
			stx savex + 1
			
			:irq_slab_x(0)
			
			lsr $d019
			:setirq(irq_enemy_1, 51 + 88 + 32 * 0 + 16)
			
	savea:	lda #$00
	savex:	ldx #$00
			
			rti
}

irq_enemy_1:
{
			sta savea + 1
			stx savex + 1
			
			:irq_enemy_x(1)
			
			lsr $d019
			:setirq(irq_slab_1, 51 + 88 + 32 * 1)
			
	savea:	lda #$00
	savex:	ldx #$00
			
			rti
}

irq_slab_1:
{
			sta savea + 1
			stx savex + 1
			:irq_slab_x(1)
			lsr $d019
			:setirq(irq_enemy_2, 51 + 88 + 32 * 1 + 16)
			
	savea:	lda #$00
	savex:	ldx #$00
			
			rti
}

irq_enemy_2:
{
			sta savea + 1
			stx savex + 1
			
			:irq_enemy_x(2)
			
			lsr $d019
			:setirq(irq_slab_2, 51 + 88 + 32 * 2)
			
	savea:	lda #$00
	savex:	ldx #$00
			
			rti
}

irq_slab_2:
{
			sta savea + 1
			stx savex + 1
			:irq_slab_x(2)
			lsr $d019
			:setirq(irq_enemy_3, 51 + 88 + 32 * 2 + 16)
			
	savea:	lda #$00
	savex:	ldx #$00
			
			rti
}

irq_enemy_3:
{
			sta savea + 1
			stx savex + 1
			
			:irq_enemy_x(3)
			
			lsr $d019
			:setirq(irq_slab_3, 51 + 88 + 32 * 3)
			
	savea:	lda #$00
	savex:	ldx #$00
			
			rti
}

irq_slab_3:
{
			sta savea + 1
			stx savex + 1
			:irq_slab_x(3)
			
			lsr $d019
			:setirq(irq_logo, $f9)
	savea:	lda #$00
	savex:	ldx #$00
	
			rti
}

// Opens bottom border and places the activision logo, which is made of several sprites

irq_logo:
{
			sta savea + 1
			stx savex + 1
	
			lda #1
			sta frameflag //display has been drawn
					
			lda $d01f
			sta ghostd01f //save the spr-bg collision register
		
			lda #$00
			sta $d01b //restore priority
			
			lda $d011
			and #$ff - 8 - $80	
			//lda #$13
			sta $d011	//border off
			
			lda #$ff
			sta $d015
			
			//place logo at $ff
			lda #%00001000
			sta $d01c
			
			lda #$0
			sta $d010
			
			lda #[logo_bars & $3fff] / 64
			sta scrn + $3f8 + 3
			lda #[logo_bars & $3fff] / 64 + 1
			sta scrn + $3f8 + 4
			lda #[logo_bars & $3fff] / 64 + 2
			sta scrn + $3f8 + 5
			lda #[logo_bars & $3fff] / 64 + 3
			sta scrn + $3f8 + 6
			
			ldx #1
			
			.for (var i = 0; i < 3; i++)
			{
				lda #[logo_sprites & $3fff] / 64 + i
				sta scrn + $3f8 + i
				stx $d027 + i
			}
			
			lda #2
			sta $d027 + 3
			lda #8
			sta $d025
			lda #7
			sta $d026
			lda #5
			sta $d027 + 4
			lda #3
			sta $d027 + 5
			lda #6
			sta $d027 + 6
			
			
			lda #$ff
			.for (var i = 0; i < 7; i++)
			sta $d001 + i * 2
				
			.for (var i = 0; i < 3; i++)
			{
				lda #24 + 160 - 36 + 24 * i
				sta $d000 + i * 2
			}
					
	
			lda #24 + 160 - 36 - 8
			sta $d000 + 3 * 2
			sta $d000 + 4 * 2
			sta $d000 + 5 * 2
			sta $d000 + 6 * 2
				
		
			
			lsr $d019
			:setirq(irq_top, 8)
			
	savea:	lda #$00
	savex:	ldx #$00

			rti
}

// Switches music on or off, sets the SFX handler accordingly
toggle_music:
{

				lda key_clock
				beq !skp+
				rts
				
			!skp:
				
				lda #$3f
				sta key_clock
					
				jsr erase_sid

	
				lda music_on 
				beq !switch_on+
				
				//switch off
				
				lda #0
				sta music_on
				
				lda #5	//mute tune
				jsr sid.init 
				
				lda #[note_sprites & $3fff] / 64 + 1 // crossed note
				
				jmp !next+
			!switch_on:	
			
				lda #1
				sta music_on
			
				lda #$0f
				sta $d418
				
				lda #1 //music on, no level-start
				jsr sid.init
				
				lda #[note_sprites & $3fff] / 64 //full note
				
			!next:	
				sta irq_top.note_sprf + 1
				lda #127
				sta hud_clock

				jsr set_sfx_routine
				rts
				
}


pause:
{
			!:	jsr framevsync
				lda $dc01
				cmp #239
				beq !-
				
			!:	jsr framevsync
				lda $dc01
				cmp #239
				bne !-
				
			!:	jsr framevsync
				lda $dc01
				cmp #239
				beq !-
					
				rts
}

clear_irq:
{
				lda #$7f                    //CIA interrupt off
				sta $dc0d
				sta $dd0d
				lda $dc0d
				lda $dd0d
				
				lda #$01                    //Raster interrupt on
				sta $d01a
				lsr $d019
				rts
}


wait_frames:
{
		!:		jsr vsync
				dex
				bne !-
				rts
}

.macro LoadSprite(pic,x0,y0,bg,col1,col2,col3)
{
	.var p = LoadPicture(pic,List().add(bg,col1,col2,col3)) //bg,mc1,spritecolor,mc2
	.for (var y = y0; y < y0 + 21; y++)
		.for (var x = x0; x < x0 + 3; x++)
			.byte p.getMulticolorByte(x,y)
	.byte col1 
}

.pc = $4400 "sprites"
hero_sprites:
.for (var s = 0; s < 7; s++)
	:LoadSprite("..\gfx\hero.png", 3 * s, 0, $ffffff,$000000,$D5DF7C,$b3b3b3)
	
.for (var s = 0; s < 7; s++)
	:LoadSprite("..\gfx\hero.png", 3 * s, 0, $ffffff,$000001,$99692D,$b3b3b1)

.for (var s = 0; s < 7; s++)
	:LoadSprite("..\gfx\hero.png", 3 * s, 0, $ffffff,$000001,$C18178,$b3b3b1)
	
//mirror
.for (var s = 8; s >= 2; s--)
	:LoadSprite("..\gfx\hero.png", 3 * s, 24, $ffffff,$000000,$D5DF7C,$b3b3b3)

.for (var s = 8; s >= 2; s--)
	:LoadSprite("..\gfx\hero.png", 3 * s, 24, $ffffff,$000001,$99692D,$b3b3b1)

.for (var s = 8; s >= 2; s--)
	:LoadSprite("..\gfx\hero.png", 3 * s, 24, $ffffff,$000001,$C18178,$b3b3b1)	


crawl_sprites:
.import binary "..\gfx\crawl.bin"	

//empty frames, for the source sprites to be copied
drown_sprites:
.fill 6 * 64 , 0
		
collision_sprite:
.fill 57,0

.byte %00000011,%11111111,%11000000
.byte %00000111,%11111111,%11100000
.byte 0


empty_sprite:
.fill 64,0	
	
door_sprite:
.import binary "..\gfx\door.bin"	


hud_lives:
	:LoadSprite("..\gfx\hero.png", 0, 48, $ffffff,$000000,$D5DF7C,$b3b3b3)
	
	:LoadSprite("..\gfx\hero.png", 0, 48, $ffffff,$000001,$99692D,$b3b3b1)

	:LoadSprite("..\gfx\hero.png", 0, 48, $ffffff,$000001,$C18178,$b3b3b1)


note_sprites:
.import binary "..\gfx\note.bin"

// 4 sprites for each bear frame.
// walk pattern is 6 frames
// total: 48 sprites
// We don't really place the sprites here, we just "allocate" memory for them.
// Sprite data will be blitted when needed
bear_sprites:
.fill 6*8*64,0

	
.pc = $6d00 "more sprites"
logo_bars:
	.import binary "..\gfx\logo_bars.bin"
	
logo_sprites:

.var logopic = LoadPicture("..\gfx\logo_top.png",List().add($000000, $ffffff)) // bg,color
.for (var s = 0; s < 3; s++)
{
	.for (var y=0; y<21; y++)
		.for (var x=0; x<3; x++)
			.byte logopic.getSinglecolorByte(x + s * 3,y) 
	.byte 0
}	

// Game Over and Get Ready Sprites.
// Some chars duplicated, but who cares? Cruncher will take care of that
gogr_sprites:
.for (var y = 0; y < 2; y++)
	.for(var x = 0; x < 8; x++)
		:LoadSprite("..\gfx\gogr.png", x * 3, 21 * y, $3E31A2, $FFFFFF, $7ABFC7,$7C70DA)


// Allocate memory for the shore bitmap
.pc = $6000 "bitmap"
.fill 9 * 320, 0

.fill 1 * 320, 0 //margin for switching mode
	
.pc = $7800 "chars"
chars:

//empychar
.fill 8,0

//digits
digits:
.const digitpic = LoadPicture("..\gfx\digits_shadow.png", List().add($0000ff,$000000,$000001,$ffffff)) // bg,mc1,charcolor,mc2
.for (var c = 0; c < 20; c++)
	.for (var b = 0; b < 8; b++)
		.byte digitpic.getMulticolorByte(c,b) 

.label DEGREECHAR = (* - chars) / 8
.const degreepic = LoadPicture("..\gfx\degree_icon.png", List().add($0000ff,$000000,$000001,$ffffff)) // bg,mc1,mc2,charcolor
.for (var b = 0; b < 8; b++)
	.byte degreepic.getMulticolorByte(0,b) 		
	
	
.label FISHCHARS = (* - chars) / 8
.const fishpic = LoadPicture("..\gfx\fish_icon.png", List().add($0000ff,$000000,$000001,$ffffff)) // bg,mc1,charcolor,mc2
.for (var c = 0; c < 2; c++)
	.for (var b = 0; b < 8; b++)
		.byte fishpic.getMulticolorByte(c,b) 

.label STARCHARS = (* - chars) / 8
starchars:
.const stc_ = LoadBinary("..\gfx\stars.imap")
//unfortunately, for charmaps larger than 32 chars, pixcen decides to assign the empty char to char 32 ($20). 
//We want it to be zero, therefore we need to swap char 0 and 32
.var stc = List()
.for (var i = 0; i < stc_.getSize(); i++)
	.eval stc.add(stc_.get(i))

.for (var i = 0; i < 8; i++)
{
	.eval stc.set(i + 32 * 8,stc.get(i))
	.eval stc.set(i , 0)
}

.fill stc.size() - 8, stc.get(i + 8)	

		
.align 64  // 8 char (64 bytes) aligned.

.label ENEMY0CHARS = (* - chars) / 8
enemy0:	//bird
.fill 32,0
.fill 32,0 //left

.label ENEMY1CHARS = (* - chars) / 8
enemy1: //crab
.fill 32,0
.fill 32,0 //left

.label ENEMY2CHARS = (* - chars) / 8
enemy2: //fish
.fill 32,0
.fill 32,0 //left

.label ENEMY3CHARS = (* - chars) / 8
enemy3: //shell
.fill 32,0		
.fill 32,0 //left	

		
slab0chars:
.const s0c = LoadBinary("..\gfx\platform0.imap")
.fill s0c.getSize() - 8, s0c.get(i + 8)

slab1chars:
.const s1c_ = LoadBinary("..\gfx\platform1.imap")

//unfortunately, for charmaps larger than 32 chars, pixcen decides to assign the empty char to char 32 ($20). we want it to be zero.
//therefore we need to swap char 0 and 32
.var s1c = List()
.for (var i = 0; i < s1c_.getSize(); i++)
	.eval s1c.add(s1c_.get(i))

.for (var i = 0; i < 8; i++)
{
	.eval s1c.set(i + 32 * 8,s1c.get(i))
	.eval s1c.set(i , 0)
}

.fill s1c.size() - 8, s1c.get(i + 8)	

//ghost byte of vic bank $4000-$7fff. This must be $ff for open border color to be black
.pc = $7fff
.byte $ff

.pc = $8000 "slab maps"
slab0map:
.const s0m = LoadBinary("..\gfx\platform0.iscr")
slab0map0:
.fill 40, s0m.get(i) == 0 ? 0 : s0m.get(i) -1 + (slab0chars-chars) / 8
.fill 40, s0m.get(i) == 0 ? 0 : s0m.get(i) -1 + (slab0chars-chars) / 8
slab0map1:
.fill 40, s0m.get(i + 40) == 0 ? 0 : s0m.get(i + 40) -1 + (slab0chars-chars) / 8
.fill 40, s0m.get(i + 40) == 0 ? 0 : s0m.get(i + 40) -1 + (slab0chars-chars) / 8


//we need to swap references to char 0 and 32.
.const s1m_ = LoadBinary("..\gfx\platform1.iscr")
.var s1m = List()
.for (var i = 0; i < s1m_.getSize(); i++)
	.eval s1m.add(s1m_.uget(i) == 0 ? 32 : s1m_.uget(i) == 32 ? 0 : s1m_.uget(i))
	
//and now we have 9 frames for each of the charlines.
slab1map0:
.for (var frame = 0; frame < 9; frame++)
	.for (var r = 0; r < 2; r++)
		.fill 40, s1m.get(i + 0 + 80 * frame) == 0 ? 0 : s1m.get(i + 0 + 80 * frame) -1 + (slab1chars-chars) / 8
slab1map1:
.for (var frame = 0; frame < 9; frame++)
	.for (var r = 0; r < 2; r++)
		.fill 40, s1m.get(i + 40 + 80 * frame) == 0 ? 0 : s1m.get(i + 40 + 80 * frame) -1 + (slab1chars-chars) / 8


.pc = * "starmap"		
		
starmap:
//we need to swap references to char 0 and 32.
.const stm_ = LoadBinary("..\gfx\stars.iscr")
.var stm = List()
.for (var i = 0; i < stm_.getSize(); i++)
	.eval stm.add(stm_.uget(i) == 0 ? 32 : stm_.uget(i) == 32 ? 0 : stm_.uget(i))

.fill stm.size(),stm.get(i) == 0 ? 0 : stm.get(i) - 1 + (starchars - chars)	/ 8	
		

.label target_scenery_data = loaderbitmap

.label brick_pattern = target_scenery_data

.label shorecolordata = brick_pattern + 8*4

.label shorescreendata = shorecolordata + 6*40

.label shorebitmapdata = shorescreendata + 6*40

.label gradient = shorebitmapdata + 6 * 320


.align 16	
.pc = * "source scenery data"
src_day_data:
{
//	.pc = brick_pattern	
	.fill 8*4, shorekla.getBitmap(9 * 320 + i)
	
//	.pc = shorecolordata
	.fill 6 * 40, shorekla.getColorRam(i) 

//	.pc = shorescreendata
	.fill 6 * 40, shorekla.getScreenRam(i) 

//	.pc = shorebitmapdata
	.fill 6 * 320, shorekla.getBitmap(i)
	
//	.pc = gradient
	.byte 04,04,14,14,10,10,03,03,07,07,01
	.align 16
	
	.byte 04,14,10,14,10,10,03,03,07,07,01
	.align 16
	
	.byte 04,14,10,14,10,03,10,07,07,07,01
	.align 16
	
	.byte 04,14,10,14,10,03,10,07,01,07,01
	.align 16
	
	.byte 04,04,14,14,10,03,10,07,01,07,01
	.align 16
	
	.byte 04,04,14,14,10,10,03,03,01,07,01
	.align 16
}

src_night_data:
{
//	.pc = brick_pattern	
	.fill 8*4, shorekla2.getBitmap(9 * 320 + i)
	
//	.pc = shorecolordata
	.fill 6 * 40, shorekla2.getColorRam(i) 

//	.pc = shorescreendata
	.fill 6 * 40, shorekla2.getScreenRam(i) 

//	.pc = shorebitmapdata
	.fill 6 * 320, shorekla2.getBitmap(i)
	
	//.pc = gradient
	.byte 06,00,06,04,06,04,14,10,03,07,01
	.align 16
	
	.byte 06,04,06,04,14,04,14,10,03,07,01
	.align 16
	
	.byte 06,04,06,04,14,10,03,10,03,07,01
	.align 16
	
	.byte 06,04,06,04,14,10,03,07,01,07,01
	.align 16
	
	.byte 06,00,06,04,14,10,03,07,01,07,01
	.align 16
	
	.byte 06,00,06,04,06,14,03,10,01,07,01
	.align 16
}


.pc = $f180 "enemy frame data"
.macro loadframes(file,n,row,colors)
{
	.var pic = LoadPicture(file,colors)
	.for (var frame = 0; frame < n; frame++)
		.for (var cy = 0; cy < 2; cy++)
			.for (var x = 0; x < 2; x++)
				.for (var y = 0; y < 8; y++)
					.byte pic.getMulticolorByte(frame * 2 + x, row * 16 + cy * 8 + y)
}

//bird
enemybmp0r:
:loadframes("..\gfx\bird.png",2,0,List().add($483AAA,$000000,$99692D,$ffffff))
enemybmp0l:
:loadframes("..\gfx\bird.png",2,1,List().add($483AAA,$000000,$99692D,$ffffff))

//crab
enemybmp1r:
:loadframes("..\gfx\crab.png",10,0,List().add($483AAA,$924A40,$C18178,$ffffff))

//fish
enemybmp2r:
:loadframes("..\gfx\fish.png",10,0,List().add($483AAA,$72B14B,$B3EC91,$ffffff))
enemybmp2l:
:loadframes("..\gfx\fish.png",10,1,List().add($483AAA,$72B14B,$B3EC91,$ffffff))

//shell
enemybmp3r:
:loadframes("..\gfx\shell.png",10,0,List().add($483AAA,$99692D,$D5DF7C,$ffffff))



.pc = $e400 "bear sprites"
src_day_bear:
{

	//right
	.for (var s = 0; s < 6; s++)
	{
		:LoadSprite("..\gfx\bear2.png", 6 * s, 8 + 24, $483AAA, $000001, $D5DF7C,$000002)
		:LoadSprite("..\gfx\bear2.png", 6 * s + 3, 8 + 24, $483AAA, $000000, $D5DF7C,$000002)
	
		:LoadSprite("..\gfx\bear2.png", 6 * s, 8 + 24, $483AAA, $000000, $ffffff,$b3b3b3)
		:LoadSprite("..\gfx\bear2.png", 6 * s + 3, 8 + 24, $483AAA, $000000, $ffffff,$b3b3b3)
	}

	// we don't store left-facing sprites. We can just compute them by mirroring the previous set
	
	/*
	//left
	.for (var s = 0; s < 6; s++)
	{
		:LoadSprite("..\gfx\bear2.png", 6 * s, 8, $483AAA, $000001, $D5DF7C,$000002)
		:LoadSprite("..\gfx\bear2.png", 6 * s + 3, 8, $483AAA, $000000, $D5DF7C,$000002)
	
		:LoadSprite("..\gfx\bear2.png", 6 * s, 8, $483AAA, $000000, $ffffff,$b3b3b3)
		:LoadSprite("..\gfx\bear2.png", 6 * s + 3, 8, $483AAA, $000000, $ffffff,$b3b3b3)
	}
	*/
}

src_night_bear:
{
	//right
	.for (var s = 0; s < 6; s++)
	{
		:LoadSprite("..\gfx\darkbear.png", 6 * s, 8 + 24, $483AAA, $000001, $8A8A8A,$000002)
		:LoadSprite("..\gfx\darkbear.png", 6 * s + 3, 8 + 24, $483AAA, $000000, $8A8A8A,$000002)
	
		:LoadSprite("..\gfx\darkbear.png", 6 * s, 8 + 24, $483AAA, $000000, $606060,$b3b3b3)
		:LoadSprite("..\gfx\darkbear.png", 6 * s + 3, 8 + 24, $483AAA, $000000, $606060,$b3b3b3)
	}

/*	
	//left
	.for (var s = 0; s < 6; s++)
	{
		:LoadSprite("..\gfx\darkbear.png", 6 * s, 8, $483AAA, $000001, $8A8A8A,$000002)
		:LoadSprite("..\gfx\darkbear.png", 6 * s + 3, 8, $483AAA, $000000, $8A8A8A,$000002)
	
		:LoadSprite("..\gfx\darkbear.png", 6 * s, 8, $483AAA, $000000, $606060,$b3b3b3)
		:LoadSprite("..\gfx\darkbear.png", 6 * s + 3, 8, $483AAA, $000000, $606060,$b3b3b3)
	}
*/
}


src_drown_sprites:
{
	.for (var s = 7; s < 9; s++)
		:LoadSprite("..\gfx\hero.png", 3 * s, 0, $ffffff,$000000,$D5DF7C,$b3b3b3)
		
	.for (var s = 7; s < 9; s++)
		:LoadSprite("..\gfx\hero.png", 3 * s, 0, $ffffff,$000001,$99692D,$b3b3b1)
	
	.for (var s = 7; s < 9; s++)
		:LoadSprite("..\gfx\hero.png", 3 * s, 0, $ffffff,$000001,$C18178,$b3b3b1)
}


.pc = $3400 + 40 * 17 "credits"

.text "             Adaptation by              "
.text "                                        "
.text "         A. Savona : Code               "
.text "            S. Day : Graphics           "
.text "          S. Cross : Music, Sfx         "
.text "                                        "

.text "Joystick up / down : Selects level -    "
.text "       Fire button : Starts game        "

.pc = $b400 "splash screen scr"
.import binary "..\gfx\credits.scr"
.pc = $a000 "splash screen map"
.const scm = LoadBinary("..\gfx\credits.map")
.fill 16 * 320, scm.get(i)


.pc = loaderbitmap "loader bmp"
.fill 8000, kla.getBitmap(i)
.pc = $b800 "loader col"
.fill 1000, kla.getColorRam(i)
.pc = $e000 "loader scr"
.fill 1000, kla.getScreenRam(i)
