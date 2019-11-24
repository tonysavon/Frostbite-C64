enemies:
{

	plot_frame:
	{			ldy #31
			!:	
		src:	lda enemybmp0r,y
		dst:	sta enemy0,y
				dey
				bpl !-
				
				rts
	}	
	
	//load x with lane

	deploy:		
	
	
				//select enemy type. Levels 1 and 2 it's only fish or birds.
				//from level 2 onwards it's all of them
				
				lda random_.random,x
				and #%00011100			//this generates a random enemy type 0-3 (bit 3-4) and a random direction (bit2)
				ldy level
				cpy #3
				bcs !all+
				and #%00010100			//if level is 1 or 2, only birds (enemy type 0) and fishes (enemy type 2) are allowed
			!all:
				clc
				adc #ENEMY0CHARS
				sta enemylane.type,x
				lsr
				lsr
				lsr
				lda #0
				rol
				sta enemylane.direction,x
				
				ldy enemylane.enemiesperlane
				
				lda enemylane.direction,x
				beq !r+
				
				//if we are going left, we start from 64 - 8 - 4 = 52
				lda random_.random,x
				anc #%00000011
				adc #52
				jmp !str+
				//right, we start from -12
			!r:	
				lda random_.random,x
				anc #%00000011
				adc #-12
				
			!str:				
				//lda #20 //p0tmp + 3
				sta enemylane.offset_h0,x
				
				clc
				
				adc #4
				sta enemylane.offset_h2,x
				
				adc #4
				sta enemylane.offset_h1,x
				
				lda #0
				sta enemylane.enemy1_active,x
				sta enemylane.enemy2_active,x
				
				lda #1
				sta enemylane.enemy0_active,x
				dey
				beq !next+
				sta enemylane.enemy1_active,x
				
				dey
				beq !next+
				sta enemylane.enemy2_active,x
				
			!next:
				
				rts
	
				
	update:
	{
				jsr movelanes
	
				
				//if the enemy is stuck, we also move the enemy accordingly
				
				lda #STATUS_STUCK
				bit herostatus
				beq !next+
				
				ldx herolane
				dex
				
				lda enemylane.moved,x
				beq !next+
				
				lda enemylane.direction,x
				beq !right+
				lda herox
				sec
				sbc enemylane.speed
				sta herox
				lda herox + 1
				sbc #0
				sta herox + 1
				jmp !next+
				
			!right:
				lda herox
				clc
				adc enemylane.speed
				sta herox
				lda herox + 1
				adc #0
				sta herox + 1
				
				
			!next:	
				lda clock
				
				and #%00000111
				bne !next+
				
				//animate the bird right
				lda enemyclock0
				and #%00001000
				asl
				asl
				adc #<enemybmp0r
				sta plot_frame.src + 1
				lda #>enemybmp0r
				adc #0
				sta plot_frame.src + 2
				
				lda #<enemy0
				sta plot_frame.dst + 1
				lda #>enemy0
				sta plot_frame.dst + 2
				jsr plot_frame
				jmp !incandexit+
				
			!next:	
				cmp #1
				bne !next+
				//animate the bird left
				lda enemyclock0
				and #%00001000
				asl
				asl
				adc #<enemybmp0l
				sta plot_frame.src + 1
				lda #>enemybmp0l
				adc #0
				sta plot_frame.src + 2
				
				lda #<[enemy0 + 32]
				sta plot_frame.dst + 1
				lda #>[enemy0 + 32]
				sta plot_frame.dst + 2
				jsr plot_frame
				jmp !incandexit+
				
				
				
			!next:	
				cmp #2
				bne !next+
				
				//animate the crab right
				lda enemyclock1
				and #%11111000
				asl
				asl
				sta p0tmp
				lda #0
				rol
				sta p0tmp + 1
				
				clc
				lda p0tmp
				adc #<enemybmp1r
				sta plot_frame.src + 1
				lda #>enemybmp1r
				adc p0tmp + 1
				sta plot_frame.src + 2
				
				lda #<enemy1
				sta plot_frame.dst + 1
				lda #>enemy1
				sta plot_frame.dst + 2
				jsr plot_frame
				jmp !incandexit+
				
			!next:	
				cmp #3
				bne !next+
				//animate the crab left. No specific animation at the moment, so we use the right frame to plot to the left chars
				
				lda enemyclock1
				and #%11111000
				asl
				asl
				sta p0tmp
				lda #0
				rol
				sta p0tmp + 1
				
				clc
				lda p0tmp
				adc #<enemybmp1r
				sta plot_frame.src + 1
				lda #>enemybmp1r
				adc p0tmp + 1
				sta plot_frame.src + 2
				
				lda #<[enemy1 + 32]
				sta plot_frame.dst + 1
				lda #>[enemy1 + 32]
				sta plot_frame.dst + 2
				jsr plot_frame
				
				jmp !incandexit+
				
		
			!next:	
				cmp #4
				bne !next+
				
				//animate the fish right
				lda enemyclock1
				and #%11111000
				asl
				asl
				sta p0tmp
				lda #0
				rol
				sta p0tmp + 1
				
				clc
				lda p0tmp
				adc #<enemybmp2r
				sta plot_frame.src + 1
				lda #>enemybmp2r
				adc p0tmp + 1
				sta plot_frame.src + 2
				
				lda #<enemy2
				sta plot_frame.dst + 1
				lda #>enemy2
				sta plot_frame.dst + 2
				jsr plot_frame
				jmp !incandexit+
				
			!next:	
				cmp #5
				bne !next+
				//animate the fish left. 
				
				lda enemyclock1
				and #%11111000
				asl
				asl
				sta p0tmp
				lda #0
				rol
				sta p0tmp + 1
				
				clc
				lda p0tmp
				adc #<enemybmp2l
				sta plot_frame.src + 1
				lda #>enemybmp2l
				adc p0tmp + 1
				sta plot_frame.src + 2
				
				lda #<[enemy2 + 32]
				sta plot_frame.dst + 1
				lda #>[enemy2 + 32]
				sta plot_frame.dst + 2
				jsr plot_frame
				
				jmp !incandexit+
				
			!next:		
					
				cmp #6
				bne !next+
				
				//animate the shell right
				lda enemyclock1
				and #%11111000
				asl
				asl
				sta p0tmp
				lda #0
				rol
				sta p0tmp + 1
				
				clc
				lda p0tmp
				adc #<enemybmp3r
				sta plot_frame.src + 1
				lda #>enemybmp3r
				adc p0tmp + 1
				sta plot_frame.src + 2
				
				lda #<enemy3
				sta plot_frame.dst + 1
				lda #>enemy3
				sta plot_frame.dst + 2
				jsr plot_frame
				jmp !incandexit+
				
			!next:	
				cmp #7
				bne !next+
				//animate the shell left. same frames of the shell right
				
				lda enemyclock1
				and #%11111000
				asl
				asl
				sta p0tmp
				lda #0
				rol
				sta p0tmp + 1
				
				clc
				lda p0tmp
				adc #<enemybmp3r
				sta plot_frame.src + 1
				lda #>enemybmp3r
				adc p0tmp + 1
				sta plot_frame.src + 2
				
				lda #<[enemy3 + 32]
				sta plot_frame.dst + 1
				lda #>[enemy3 + 32]
				sta plot_frame.dst + 2
				jsr plot_frame
				
				jmp !incandexit+
			
			
			!next:
			
			!incandexit:
				
				inc enemyclock0
				lda enemyclock0
				cmp #8 * 2
				bne !skp+
				
				lda #0
				sta enemyclock0
				
			!skp:
			
				inc enemyclock1
				lda enemyclock1
				cmp #8 * 10
				bne !skp+
				
				lda #0
				sta enemyclock1
			
			!skp:
				
				rts
	}			
				
	
	movelanes:
	{	
	
				ldx #0	//counter on enemylanes
				
			!sloop:
				lda #0
				sta enemylane.moved,x
				//if it's crab or shell, and we are on level 6+, then they alternate on/off every 64 frames. See notes.asm
				
				lda level
				cmp #6
				bcc !domove+
			
				lda enemylane.type,x
				cmp #ENEMY1CHARS
				bcc !domove+
				cmp #ENEMY2CHARS
				bcc !crab+
				cmp #ENEMY3CHARS
				bcc !domove+
				
				//it's a shell
				
			!shell:
				lda clock
				and #64
				beq !domove+
				jmp !next+
			!crab:
				lda clock
				and #64
				bne !domove+
				jmp !next+
				
			!domove:		
				lda #1
				sta enemylane.moved,x
			
				lda enemylane.direction,x
				bne !left+
					
				//right
				lda enemylane.offset_l,x
				clc
				adc enemylane.speed
				sta enemylane.offset_l,x
				bcc !next+
						
				inc enemylane.offset_h0,x
				
				lda enemylane.offset_h0,x
				cmp #52
				bmi !skp+
				//if the leftmost enemy offsets, we respawn
				
				jsr deploy
				jmp !next+
			!skp:	
				inc enemylane.offset_h1,x
				
	
				inc enemylane.offset_h2,x

				jsr redraw_enemylane
				jmp !next+
			
			!left:
				lda enemylane.offset_l,x
				sec
				sbc enemylane.speed
				sta enemylane.offset_l,x
				bcs !next+
				
				lda #$fe		
				dcp enemylane.offset_h0,x
				bne !skp+
				lda #63
				sta enemylane.offset_h0,x
				
			!skp:
				lda #$fe
				dcp enemylane.offset_h1,x
				bne !skp+
				//lda #63
				//sta enemylane.offset_h1,x
				//if the rightmost enemy undeflows, we respawn
				jsr deploy
				jmp !next+
				
			!skp:
				lda #$fe
				dcp enemylane.offset_h2,x
				bne !skp+
				lda #63
				sta enemylane.offset_h2,x			
				
			!skp:
			
				jsr redraw_enemylane
				
			
			!next:
			
				inx
				cpx #4
				beq !done+
				jmp !sloop-
			!done:		
				rts
	}
	
	//load x with the lane number
	
	clear_enemylane:
	{
				lda enemylane_dest_off.lo,x
				sta clr + 1
				lda enemylane_dest_off.hi,x
				sta clr + 2
				
				lda #0
				
				ldy #79
				
		clr:	sta scrn + 9 * 40,y	
				dey
				bpl clr
				rts
	}
	
	//load x with lane, x must be preserved
	
	redraw_enemylane:
	{
	
				jsr clear_enemylane
			
				
				lda enemylane.enemy0_active,x
				bne !active+
				jmp !next_enemy+
			!active:	
				lda enemylane_dest_off.lo,x
				sta p0tmp
				lda enemylane_dest_off.hi,x
				sta p0tmp + 1

				lda enemylane.type,x
				
				ldy enemylane.offset_h0,x
				bmi !skp+
				
				cpy #39
				bcs !next_enemy+
				sta (p0tmp),y
			!skp:
		
				clc
				adc #1
				iny
				bmi !skp+
				cpy #39
				bcs !skp+
				sta (p0tmp),y
			!skp:				
				pha
				lda p0tmp
				clc
				adc #40
				sta p0tmp
				lda p0tmp + 1
				adc #0
				sta p0tmp + 1	
				pla
				clc
				adc #1
				dey
				bmi !skp+
			
				sta (p0tmp),y
			!skp:
				clc
				adc #1
				iny
				bmi !skp+
				sta (p0tmp),y
			!skp:				
				
		!next_enemy:
		

		
				lda enemylane.enemy1_active,x
				bne !active+
				jmp !next_enemy+
			!active:	
				lda enemylane_dest_off.lo,x
				sta p0tmp
				lda enemylane_dest_off.hi,x
				sta p0tmp + 1

				lda enemylane.type,x
				
				ldy enemylane.offset_h1,x
				bmi !skp+
				
				cpy #39
				bcs !next_enemy+
				sta (p0tmp),y
			!skp:
				clc
				adc #1
				iny
				bmi !skp+
							
				sta (p0tmp),y
			!skp:				
				pha
				lda p0tmp
				clc
				adc #40
				sta p0tmp
				lda p0tmp + 1
				adc #0
				sta p0tmp + 1	
				pla
				clc
				adc #1
				dey
				bmi !skp+
			
				sta (p0tmp),y
			!skp:
				clc
				adc #1
				iny
				bmi !skp+
				sta (p0tmp),y
			!skp:				
				
		!next_enemy:
		
		
		
		
		
		lda enemylane.enemy2_active,x
				bne !active+
				jmp !next_enemy+
			!active:	
				lda enemylane_dest_off.lo,x
				sta p0tmp
				lda enemylane_dest_off.hi,x
				sta p0tmp + 1

				lda enemylane.type,x
				
				ldy enemylane.offset_h2,x
				bmi !skp+
				
				cpy #39
				bcs !next_enemy+
				sta (p0tmp),y
			!skp:
				clc
				adc #1
				iny
				bmi !skp+
				sta (p0tmp),y
			!skp:				
				pha
				lda p0tmp
				clc
				adc #40
				sta p0tmp
				lda p0tmp + 1
				adc #0
				sta p0tmp + 1	
				pla
				clc
				adc #1
				dey
				bmi !skp+
			
				sta (p0tmp),y
			!skp:
				clc
				adc #1
				iny
				bmi !skp+
				sta (p0tmp),y
			!skp:				
				
		!next_enemy:
		
		
				rts
	}
	
	enemylane_dest_off:
			.lohifill 4, scrn + 9 * 40 + i * 160 
	
	enemylane:
	{
				offset_l:				//in subchars
					.byte 0,0,0,0
			
				offset_h0:				//in chars
					.byte 0,0,0,0
		
				offset_h1:				//for the second enemy. low byte is shared with the others
					.byte 0,0,0,0
					
				offset_h2:				//for the third enemy. low byte is shared with the others
					.byte 0,0,0,0	
				
				enemy0_active:
					.byte 0,0,0,0
				
				enemy1_active:
					.byte 0,0,0,0		
					
				enemy2_active:
					.byte 0,0,0,0	
					
				direction:
					.byte 0,0,0,0						
				
				moved:
					.byte 0,0,0,0		//reports that a movement took place. for crab and shell enemies it's possible to take "pauses". In that case this is zero.	
										//otherwise it's 1. When the hero is stuck, this is used to implement dragging to death 
				type:
					.byte 0,0,0,0		//0 = bird, 1 = crab, 2 = fish, 3 = shell	
					
				speed:
					.byte %00100000
				enemiesperlane:
					.byte 1	
	}							
	
	
	enemycolor0:
	.byte 00, 02, 05, 08
	enemycolor1:
	.byte 08, 10, 13, 07
	
	enemyclock0:	//for 2 frames
	.byte 0	
	enemyclock1:
	.byte 0			//for 10 frames
	
	
	
	
}

//the bear switchs direction at a specific point in time, apparently every 64 frames, regardless of the speed
bear:
{
			deploy:
					lda #1
					sta active
					lda #32
					sta xpos + 1
					lda #0
					sta xpos + 0
					
					lda #[bear_sprites & $3fff] / 64 + 24
					sta bearf
					
					lda #1
					sta direction
					
					lda #0
					sta stepframe
					
					rts
					
			off:
					lda #0
					sta active
					rts
			
			update:
							
					lda direction
					beq !right+
					
					
				//left:
					//first, check if we can go
					lda xpos + 1
					cmp #3
					bcc !next+
					
					lda xpos
					sec
					sbc speed
					sta xpos
					lda xpos + 1
					sbc #0
					sta xpos + 1	
					
					jmp !opt+
				!right:
					
					lda xpos + 1
					cmp #34
					bcs !next+
					
					lda xpos
					clc
					adc speed
					sta xpos
					lda xpos + 1
					adc #0
					sta xpos + 1	
				!opt:
				
					lda speed
					lsr
					lsr
					clc
					adc stepframe
			
					cmp #%11000000 //6 << 
						
					bcc !skp+
					
					lda #0
				!skp:	
					sta stepframe
					
					lsr
					lsr
					lsr
					//lsr
					//lsr
					and #%11111100
					
					clc
					adc #[bear_sprites & $3fff] / 64
					sta bearf
					
					lda direction
					beq !skp+
					
					lda bearf
					adc #24
					sta bearf
					
				!skp:
				
				!next:
				
					//check if we must change direction
					lda clock
					and #63
					
					bne !next+
					
					//our chance to change direction
					
					lda xpos + 1
					clc
					adc #1
					cmp herox + 1
					
					bcc !right+
					
					//left
					lda #1
					jmp !opt+
					
				!right:
					lda #0
				!opt:
					sta direction
					
				!next:
					
					
					
				!next:	
					rts
					
active:
.byte 0			
speed:
.byte 0
direction:
.byte 0

stepframe:
.byte 0

xpos:
.byte 0,0
flipping: // this is a counter
.byte 0					
}