controls:
{

				lda $dc00
				
				sta controls.backup

				lda #STATUS_STUCK
				bit herostatus
				beq !canmove+
				
				//the hero is stuck. the enemy move part has already moved it, 
				//so let's just switch to the check boundaries status
				jmp !check_boundaries+ 
				
			
			!canmove:	
				lda controls.backup								
				jsr readjoy

				//fist thing, check fire
				bcs !clearfire+
				
				//fire.
				
				lda firebusy
				bne !nofire+
				
				lda #1
				sta firebusy
				
				lda herostatus
				and #STATUS_JUMPING
				bne !nofire+
				
				lda herolane
				beq !nofire+
				
				//reverse the flow of the current slab
				
				tax
				dex
				lda #0
				sta environment.slablane.status,x
				lda environment.slablane.direction,x
				eor #1
				sta environment.slablane.direction,x
								
				lda igloo_size
				cmp #16
				beq !skp+
				jsr environment.break_igloo
				
				!skp:
				jmp !next+
				
			!clearfire:
				lda #0
				sta firebusy
				
			!nofire:
				cpy #0
				beq !testx+
				
				
				lda #STATUS_JUMPING
				bit herostatus
				bne !testx+
				
		
				//lda herostatus
				//ora #STATUS_JUMPING
				//sta herostatus
				lda #$00
				sta jumpclock
				
				cpy #$ff
				beq !up+
				
			!down:
				lda herolane
				cmp #4
				beq !testx+
				
				lda herostatus

				ora #STATUS_JUMPING
				
				and #$ff - STATUS_YDIRECTION - STATUS_SAFESPOT
				sta herostatus
			
				stx svx + 1
				:sfx(SFX_JUMP)
				
				jmp svx
				//jmp !testx+
						
			!up:
				lda herolane
				beq !testx+
				
				lda herostatus
				ora #STATUS_YDIRECTION | STATUS_JUMPING
				sta herostatus
				
				stx svx + 1
				:sfx(SFX_JUMP)
				
				//jmp !testx+	
			
			svx: ldx #0
			!testx:	
				//if we are in safespot, we can only move vertically
				lda #STATUS_SAFESPOT
				bit herostatus
				beq !skp+
				jmp !no_horizontal_movement+
			!skp:
				cpx #0
				bne !skp+
				lda herostatus
				and #$ff - STATUS_MOVING
				sta herostatus
				lda #0
				sta walkframe
				jmp !no_horizontal_movement+
			!skp:	
				lda herostatus
				ora #STATUS_MOVING
				sta herostatus
				
				lda walkspeed
				sta p0tmp
				
				lda #STATUS_JUMPING
				bit herostatus
				beq !skp+
				
				lda jumpspeed
				sta p0tmp
				
			!skp:	
				cpx #1
				beq !right+
				//left
				lda herostatus
				ora #STATUS_DIRECTION
				sta herostatus		
				
				lda herox
				sec
				sbc p0tmp //walkspeed
				sta herox
				lda herox + 1
				sbc #0
				sta herox + 1
				
				jmp !wf+
			
			!right:
				lda herostatus
				and #$ff - STATUS_DIRECTION
				sta herostatus
				
				lda herox
				clc
				adc p0tmp //walkspeed
				sta herox
				lda herox + 1
				adc #0
				sta herox + 1	
				
			!wf:
			
				lda walkspeed
				lsr
				lsr
				lsr // /8
				clc
				adc walkframe
				sta walkframe
				
				cmp #5*32
				bcc !next+
				lda #0
				sta walkframe
				
				
				jmp !next+
					
		!no_horizontal_movement:
		!next:
		
		
	
				//refine boundaries etc
				lda #STATUS_JUMPING
				bit herostatus
				beq !next+
			
				inc jumpclock
				lda jumpclock
				cmp #24
				bne !next+
				
				lda herostatus
				and #$ff - STATUS_JUMPING
				sta herostatus
				
				and #STATUS_YDIRECTION
				beq !down+
				//up
				dec herolane
				beq !testsafespot+ //!next+
				jmp !opt+
				
			!testsafespot:
				lda herox 
				clc
				adc #%01000000
				lda herox + 1
				adc #0
				
				bne !next+
				
				lda #%11000000
				sta herox
				lda #0
				sta herox + 1
				lda herostatus
				and #$ff - STATUS_DIRECTION - STATUS_MOVING
				ora #STATUS_SAFESPOT
				sta herostatus
				jmp !next+	
				
			!down:
				inc herolane
			!opt:	
				ldx herolane
				dex
				
				//align the subpixel amounts, so we don't "slide"
				lda environment.slablane.offset_l,x
				and #%00011111
				sta p0tmp + 3
				lda herox
				and #%11100000
				ora p0tmp + 3
				sta herox
				
				
				
				lda environment.slablane.status,x
				bne !next+
				
				//we can potentially build the igloo and assign some score
				//but we can't do it here, because the player might have landed in the water
				//so let's assign this to a variable

				lda #STATUS_CLEARED_SLAB
				ora herostatus
				sta herostatus
				stx environment.slabcleared

			!next:
			
			!check_boundaries:
			
				lda #STATUS_SAFESPOT
				bit herostatus
				bne !dontcheck+
			
				lda #0
				sta p0tmp
				
				lda herolane 
				bne !skp+
				lda #1
				sta p0tmp
				
			!skp:
				lda herox + 0
				sec
				sbc #%10000000
				lda herox + 1
				sbc #0	
				
				cmp p0tmp
				bpl !ok+
				
				lda #%10000000
				sta herox 
				lda p0tmp
				sta herox + 1
				
			!ok:
				cmp #37
				bcc !ok+	
				lda #37
				sta herox + 1
				lda #0
				sta herox 
			!ok:	
			!dontcheck:
				rts
				
				
firebusy:
.byte 0				
walkframe:
.byte 0
backup:
.byte 0
}

readjoy:
{
		
		djrrb:	ldy #0        
				ldx #0       
				lsr           
				bcs djr0      
				dey          
		djr0:	lsr           
				bcs djr1      
				iny           
		djr1:	lsr           
				bcs djr2      
				dex           
		djr2:	lsr           
				bcs djr3      
				inx           
		djr3:	lsr           
				rts
}					