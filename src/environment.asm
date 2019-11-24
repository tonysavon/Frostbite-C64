environment:
{
	init:
	{
				
				ldx #3
			!:	jsr enemies.clear_enemylane
				dex
				bpl !-
				
				lda #0
				sta igloo_size
		
				lda mustredraw
				bne !skp+
				jmp !noredraw+
				
			!skp:
			
				jsr vsync
				and #$0b
				sta $d011
				
				lda level
				sec
				sbc #1
				and #4
				bne !night+
				jmp !day+
					
			!night:
			
				
				blithp(src_night_data,target_scenery_data,21)
				
				lda #0
				sta irq_top.skycolor + 1
				
				lda #$00
				
				sta irq_movetobmp.pondcolor + 1
				
				jmp !next+
			
			!day:
				
				blithp(src_day_data,target_scenery_data,21)
				
				lda #14
				sta irq_top.skycolor + 1
				
				lda #$06
				sta irq_movetobmp.pondcolor + 1
				//jmp !next+
				
			!next:
			
				ldx #240
			!:	lda shorecolordata -1,x
				sta $d800 + 3 * 40 -1,x
				lda shorescreendata -1,x
				sta scrn + 3 * 40 -1,x
				dex
				bne !-
				
				:blithp(shorebitmapdata, $6000 + 320 * 3,15)
				
				jsr vsync
				lda #$1b
				sta $d011
					
			!noredraw:	
				

				rts
	}
		
	
	
	update:
	{
				jsr moveslabs
				
				//check if the hero is standing on a slab and move him accordingly, unless it's stuck.
				lda #STATUS_STUCK | STATUS_JUMPING
				bit herostatus
				bne !next+
								
				ldx herolane
				beq !next+	//don't move when on the shore
				
				dex
				lda slablane.direction,x
				beq !right+
				lda herox
				sec
				sbc slablane.speed
				sta herox
				lda herox + 1
				sbc #0
				sta herox + 1
				jmp !next+
				
			!right:
				lda herox
				clc
				adc slablane.speed
				sta herox
				lda herox + 1
				adc #0
				sta herox + 1
				
		!next:
				rts
	}
		

	//decrease igloo size by one unit
	break_igloo:
	{
				ldx igloo_size
				beq !done+
				dex
				stx igloo_size
				
				lda brick_offset.hi,x
				sta p0tmp + 1
				lda brick_offset.lo,x
				sta p0tmp
				
				clc
				adc #<[shorebitmapdata - ($6000 + 3 * 320)]
				sta p0tmp + 2
				lda p0tmp + 1
				adc #>[shorebitmapdata - ($6000 + 3 * 320)]
				sta p0tmp + 3
					
				lda brick_size,x
				sta p0tmp + 4 
				
				ldy brick_parity,x
					
			!:	
				.for (var i = 0; i < 4; i++)
				{
					lda (p0tmp + 2),y
				 	sta (p0tmp),y
					iny
				}

				iny
				iny
				iny
				iny
				
				dec p0tmp + 4
				bne !-
			
			!skp:
			!done:	
				rts
				
				
	}
	
	
	//grows igloo by one unit
	build_igloo:
	{
				ldx igloo_size
				cpx #15
				
				bcs !done+
				
				lda brick_offset.lo,x
				sta p0tmp
				lda brick_offset.hi,x
				sta p0tmp + 1
				//(p0tmp) destination offset on screen
				lda brick_size,x
				sta p0tmp + 2 
				
				ldy brick_parity,x
					
			!:	
				.for (var i = 0; i < 4; i++)
				{
					lda brick_pattern,y
				 	sta (p0tmp),y
					//inx  
					iny
				}

				iny
				iny
				iny
				iny
				
				dec p0tmp + 2
				bne !-
			
			!skp:
			!done:	
				rts
	}	
	
	.var bolist = List().add(
				$6000 + 28 * 8 + 5 * 320,
				$6000 + 30 * 8 + 5 * 320,
				$6000 + 32 * 8 + 5 * 320,
				$6000 + 34 * 8 + 5 * 320,
				
				$6000 + 28 * 8 + 5 * 320,
				$6000 + 30 * 8 + 5 * 320,
				$6000 + 32 * 8 + 5 * 320,
				$6000 + 34 * 8 + 5 * 320,
				
				$6000 + 28 * 8 + 4 * 320,
				$6000 + 30 * 8 + 4 * 320,
				$6000 + 32 * 8 + 4 * 320,
				$6000 + 34 * 8 + 4 * 320,
				
				$6000 + 29 * 8 + 4 * 320,
				$6000 + 32 * 8 + 4 * 320,
				
				$6000 + 30 * 8 + 3 * 320
				)
				
				
	brick_offset:
	.lohifill bolist.size(),bolist.get(i)
	
	brick_size:
	.fill 12,2 
	.byte 3,3
	.byte 4
	
	brick_parity:
	.byte 4,4,4,4, 0,0,0,0,  4,4,4,4,  0,0,  4
	
	moveslabs:
	{
				lda slablane.resetclock
				beq !skp+
				
				dec slablane.resetclock
				bne !skp+
				
				lda slablane.status + 0
				and slablane.status + 1
				and slablane.status + 2
				and slablane.status + 3
				
				beq !skp+
				
				lda igloo_size
				cmp #16
				beq !skp+
				
				lda #0
				sta slablane.status + 0
				sta slablane.status + 1
				sta slablane.status + 2
				sta slablane.status + 3
				
				
			!skp:
	
				ldx #0	//counter on slabs
			!sloop:
				
				lda slablane.direction,x
				beq !right+
					
				//left
				lda slablane.offset_l,x
				clc
				adc slablane.speed
				sta slablane.offset_l,x
				bcc !next+
						
				inc slablane.offset_h,x
				lda slablane.offset_h,x
				cmp #40
				bcc !skp+
				sbc #40
				sta slablane.offset_h,x
				
			!skp:
				jsr redraw_slab
				jmp !next+
			
			!right:
				lda slablane.offset_l,x
				sec
				sbc slablane.speed
				sta slablane.offset_l,x
				bcs !next+
						
				dec slablane.offset_h,x
				bpl !skp+
				lda #39
				sta slablane.offset_h,x
				
				!skp:
				jsr redraw_slab
				//jmp !next+
			
			!next:
				inx
				cpx #4
				bne !sloop-
				
				rts
				
	}
			
	//draws lane x. x must be preserved
	redraw_slab:
	{	
				lda dest_off.lo,x
				sta dest0 + 1
				lda dest_off.hi,x
				sta dest0 + 2
				
				lda dest0 + 1
				clc
				adc #40
				sta dest1 + 1
				lda dest0 + 2
				adc #0
				sta dest1 + 2
				
				//check the source
				lda slabtype
				bne !t1+
			
				lda #<slab0map0
				sta src0l + 1
				
				lda #>slab0map0
				sta src0h + 1
					
				lda #<slab0map1
				sta src1l + 1
				
				lda #>slab0map1
				sta src1h + 1
				
				jmp !nxt+
				
			!t1:	
				
				cmp #1
				bne !t2+
				
				
				lda clock
				lsr
				lsr
				lsr
				lsr //0..15
				
				tay
				lda pingpongslab1map0.lo,y
				sta src0l + 1
				lda pingpongslab1map0.hi,y
				sta src0h + 1
				
				lda pingpongslab1map1.lo,y
				sta src1l + 1
				lda pingpongslab1map1.hi,y
				sta src1h + 1
				jmp !nxt+
				
			!t2:	
				lda #<[slab1map0 + 80 * 7]
				sta src0l + 1
				
				lda #>[slab1map0 + 80 * 7]
				sta src0h + 1
					
				lda #<[slab1map1 + 80 * 7]
				sta src1l + 1
				
				lda #>[slab1map1 + 80 * 7]
				sta src1h + 1
				
				jmp !nxt+
			
			!nxt:				
				lda slablane.offset_h,x
				clc
		src0l:	adc #<slab0map0
				sta src0 + 1
		src0h:	lda #>slab0map0
				adc #0
				sta src0 + 2
				
				lda slablane.offset_h,x
				clc
		src1l:	adc #<slab0map1
				sta src1 + 1
		src1h:	lda #>slab0map1
				adc #0
				sta src1 + 2
							
				ldy #39
		src0:	lda slab0map0,y
		dest0:	sta scrn + 8 * 40,y
				
		src1:	lda slab0map1,y
		dest1:	sta scrn + 9 * 40,y		
					
				dey
				bpl src0

				rts
				
			dest_off:
			.lohifill 4, scrn + 11 * 40 + i * 160 	
			
			.const pp = List().add(0,1,2,3,4,5,6,7,8,7,6,5,4,3,2,1)
			
			pingpongslab1map0:
			.lohifill 16, slab1map0 + 80 * pp.get(i)
			
			pingpongslab1map1:
			.lohifill 16, slab1map1 + 80 * pp.get(i)
			
	}
	
	slabcolor0:
				//d022
				.byte 3
				.byte 14
	slabcolor1:
				.byte 1
				.byte 3
			
				
	slabtype:
				.byte 0 
	
	slabcleared:
				.byte 0						
	slablane:
	{
				offset_l:				//in subchars
					.byte 0,0,0,0
				offset_h:				//in chars
					.byte 0,0,0,0
		
				direction:
					.byte 0,1,0,1						
				
				status:
					.byte 0,0,0,0		//0 = clear, 1 = reversed	
					
				speed:
					.byte 0
					
				resetclock:
					.byte 0
	}
		
}