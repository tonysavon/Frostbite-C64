hud_init:
{
				
				jsr color_hud_area

				lda #DEGREECHAR
				sta scrn + 40 + 22 
				
				lda level
				cmp #20
				bcc !skp+
				
				lda #FISHCHARS
				sta scrn + 40 + 10
				lda #FISHCHARS + 1
				sta scrn + 40 + 11
	
					
			!skp:
					
				jsr timer.update
				
				jsr put_lives
				jmp put_score
				
				rts
				
				
				
}

// We have a separate jsr for this, because it's not only used by the initializer
color_hud_area:
{

		
				lda #1
				ldx #39
			!:
				sta $d800,x
				sta $d800 + 40,x
				sta $d800 + 80,x
				dex
				bpl !-
				
				lda #9
				//time
				sta $d800 + 40 + 18
				sta $d800 + 40 + 19
				sta $d800 + 40 + 20
				sta $d800 + 40 + 21
				//degree
				sta $d800 + 40 + 22
				
				//lives
				sta $d800 + 40 + 6
				sta $d800 + 40 + 7
				
				//fish
				sta $d800 + 40 + 10
				sta $d800 + 40 + 11
				
				ldx #13
			!:	sta $d800 + 40 + 24,x
				dex
				bpl !-
	
				//if it's day, erase the stars. otherwise draw them
				lda level
				sec
				sbc #1
				and #4
				beq !day+
				
				//night
				ldx #119
			!:	lda starmap,x
				beq !skp+
				sta scrn,x	
			!skp:
				dex
				bpl !-
						
				jmp !next+
					
				
			!day:
				lda #0
				ldx #119
			!:	ldy starmap,x
				beq !skp+
				sta scrn,x
			!skp:
				dex
				bpl !-	
			!next:	
				rts
}

// Adds A * 100  to the score, so 100 to 900 in steps of 100
add_score_xx:
{
			ldx #3
			jmp add_score_x.opt
}

// Adds A * 10 to the score, so 10 to 90 in steps of 10. 
add_score_x:
{
			ldx #4
opt:		ldy #0 //flag for extralives
		!:	clc
			adc score,x
			sta score,x
			cmp #$0a
			bcc !done+
			sbc #$0a
			sta score,x
			lda #1
			cpx #2
			bne !skp+
			
			iny

		!skp:	
			dex 
			bpl !- 
		//overflow!
			lda #9
			sta score
			sta score + 1
			sta score + 2
			sta score + 3
			sta score + 4
			sta score + 5
			
			jsr put_score
			jmp game_over //this is the good gameover!

		!done:
			
			cpy #0
			beq !skp+
		
			lda lives
			cmp #10
			bcs !skp+
			inc lives
			jsr put_lives
		!skp:	
			//jmp put_score  //it's up next anyway 
}


put_score:
{
			
				ldx #0
				ldy #0
				
			!:	
				lda score,x
				asl	//also clears carry, because score digits are < 128
				adc #1
				sta scrn + 40 + 2 + 24,y 
				iny
				adc #1
				sta scrn + 40 + 2 + 24,y
				iny
				inx
				cpx #6 //this will also clear the carry
				bne !-
				
				rts
				
}


put_lives: 
{

				lda lives
				asl
				sec
				sbc #1
				sta scrn + 40 + 6
				clc
				adc #1
				sta scrn + 40 + 7
				rts
}


timer:
{
	init:
				lda #49
				sta timer_value + 2
				lda #5
				sta timer_value + 1
				lda #4
				sta timer_value + 0	
				
				rts
				
	tick:				
				lda timer_value
				bpl !skp+
				rts
				
			!skp:	

				dec timer_value + 2
				bmi !underflow+
				
				lda timer_value 
				bne !skp+
				
				//if less than 10 seconds, we must blink
				lda timer_value + 2
				and #31
				tax
				lda mcgradient,x
				sta $d800 + 40 + 18
				sta $d800 + 40 + 19
				sta $d800 + 40 + 20
				sta $d800 + 40 + 21
				rts
				 
			!underflow:		
				lda #49
				sta timer_value + 2
				
				dec timer_value + 1
				bpl update
				
				lda #9
				sta timer_value + 1
				dec timer_value + 0
				bpl update
				
				// timer_value <0 means time is up. We check this elsewhere, we just don't update the screen
								
			!skp:
				rts
				
update:

				lda timer_value
				bpl !skp+
				
				lda #0
				sta timer_value + 1
			!skp:	
				asl	//clears the carry as this is < 128
				adc #1
				sta scrn + 40 + 18
				adc #1
				sta scrn + 40 + 19
				
				lda timer_value + 1
				asl	//clears the carry as this is < 128
				adc #1
				sta scrn + 40 + 20
				adc #1
				sta scrn + 40 + 21
								
				rts
				
				
.const mcgradientlist = List().add($00+8, $02+8, $04+8,$04+4, $05+8,$05+8, $03+8,$03+8,$03+8, $07+8,$07+8,$07+8,$07+8, $01+8,$01+8,$01+8,$01+8)
mcgradient:

.fill 15,mcgradientlist.get(15-i)
.fill 17,mcgradientlist.get(i)								
}			
