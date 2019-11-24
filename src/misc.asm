//blits a number of half pages from src to dst
.macro blithp(src,dst,n)
{
		ldx #127
	!:
		.for (var i = 0; i < n; i++)
		{
			lda src + 128 * i,x
			sta dst + 128 * i,x
		}
		dex
		.if (n < 20)
		{
			bpl !-
		}
		else	//prevent branch distance error 
		{
			bmi !+
			jmp !-
		!:
		}
		
}


//32 bit random number generator
random_:
{
			asl random
			rol random+1
			rol random+2
			rol random+3
			bcc nofeedback
			lda random
			eor #$b7
			sta random
			lda random+1
			eor #$1d
			sta random+1
			lda random+2
			eor #$c1
			sta random+2
			lda random+3
			eor #$04
			sta random+3
		nofeedback:
			rts

random: .byte $ff,$ff,$ff,$ff
}


// Waits fire button full press-depress cycle
waitbutton:
{
		!:	jsr vsync
			
			lda  $dc00
			and #%00010000
			bne !-
			
			
		!:	jsr vsync
		
			lda $dc00
			and #%00010000
			beq !-
			
			rts	
}

vsync:
{
			bit $d011
			bmi *-3
			bit $d011
			bpl *-3
			rts
}

framevsync:
{

			!:	lda frameflag
			beq !-
			lda #0
			sta frameflag
			rts
}			

erase_sid:
{
			ldx #$1f
			lda #0
		!:	sta $d400,x
			dex
			bpl !-
			rts
}
			
// Flips a sprite horizontally
// https://codebase64.org/doku.php?id=base:sprite_mirror

.macro flipspr(src,dst)
{
			lda #<src
			sta mirror_sprite.src1 + 1
			lda #>src
			sta mirror_sprite.src1 + 2
						
			lda #<dst
			sta mirror_sprite.dst1 + 1
			lda #>dst
			sta mirror_sprite.dst1 + 2
			jsr mirror_sprite
}


mirror_sprite:
{
//initialization
			ldy mirror_sprite.src1 + 1
			iny 
			sty mirror_sprite.src2 + 1
			iny
			sty mirror_sprite.src3 + 1
				
			ldy mirror_sprite.dst1 + 1
			iny 
			sty mirror_sprite.dst2 + 1
			iny
			sty mirror_sprite.dst3 + 1

			ldy mirror_sprite.src1 + 2
			sty mirror_sprite.src2 + 2
			sty mirror_sprite.src3 + 2

			ldy mirror_sprite.dst1 + 2
			sty mirror_sprite.dst2 + 2
			sty mirror_sprite.dst3 + 2

	
			
							
			ldx #$3c //bottom left byte offset
	!:		
						
	src1:	ldy $e000,x
			lda sprmir,y
	src3:	ldy $e002,x	
	dst3:	sta $e002,x
			lda sprmir,y
	dst1:	sta $e000,x

	src2:	ldy $e001,x
			lda sprmir,y
	dst2:	sta $e001,x
			
			txa
			axs #$03 //dex * 3. We save 2 cycles.
				
			bpl !-

			rts
}

// The following table is for multicolor sprites. Changes for hires sprites are trivial.
sprmir:
.fill 256, ((i & %00000011) << 6) | ((i & %00001100) << 2) | ((i & %00110000) >> 2) | ((i & %11000000) >> 6)

			