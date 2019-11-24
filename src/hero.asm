.label STATUS_MOVING		= %00000001
.label STATUS_DIRECTION 	= %00000010
.label STATUS_JUMPING		= %00000100
.label STATUS_YDIRECTION	= %00001000
.label STATUS_STUCK			= %00010000
.label STATUS_SAFESPOT		= %00100000
.label STATUS_CLEARED_SLAB	= %01000000


hero:
{
			init:
				lda #0
				sta herox
				lda #10
				sta herox + 1
				
				lda #0
				sta herolane
				
				sta jumpclock
							
	
				lda #0
				sta herostatus
				
				lda #[hero_sprites & $3fff] / 64
				sta herof
				
				lda #[hero_sprites & $3fff] / 64 + 7
				sta herof + 1
				
				lda #[hero_sprites & $3fff] / 64 + 14
				sta herof + 2
				
				lda #7 
				sta heroc
				lda #8
				sta heroc + 1
				lda #10
				sta heroc + 2
				
				rts				
				
			update:
				lda herostatus
				and #STATUS_JUMPING
				beq !nojump+
				
				ldx #[hero_sprites & $3fff] / 64 + 6
				lda jumpclock
				cmp #16
				bcc !skp+
				ldx #[hero_sprites & $3fff] / 64 + 0
			!skp:
				jmp !flipandstore+
				
				
			!nojump:
				lda #STATUS_MOVING
				bit herostatus
				beq !still+	
				
			!walking:
				lda controls.walkframe	
				lsr
				lsr
				lsr
				lsr
				lsr //32
				clc
				adc #[hero_sprites & $3fff] / 64
				tax
				jmp !flipandstore+
				
			!still:
				ldx #[hero_sprites & $3fff] / 64
				jmp !flipandstore+	
			
				
			!flipandstore:
				lda #STATUS_DIRECTION
				bit herostatus
				beq !store+
				txa
				clc
				adc #7*3
				tax
				
			!store:
				txa	
				sta herof
				clc
				adc #7
				sta herof + 1
				adc #7
				sta herof + 2
				rts	
}

.var trajectory = List()
.for (var i = 0; i < 24; i++)
	.eval trajectory.add(36.0 * sin (((PI / 1.4) * i) / 24.0))
	
jump_trajectory_up:
.fill 24, trajectory.get(i)

jump_trajectory_down:
.fill 24, trajectory.get(23-i) - 32


hero_y_offset:
.fill 5, 92 + 32 * i