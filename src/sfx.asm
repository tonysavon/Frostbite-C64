.macro sfx(sfx_id)
{
			ldx #sfx_id
			jsr sfx_play
}


set_sfx_routine:
{
			lda music_on
			bne !on+
			
			lda #<play_no_music
			sta sfx_play.sfx_routine + 1
			
			lda #>play_no_music
			sta sfx_play.sfx_routine + 2
			rts
			
		!on:
			lda #<play_with_music
			sta sfx_play.sfx_routine + 1
			
			lda #>play_with_music
			sta sfx_play.sfx_routine + 2
			rts	
}

sfx_play:
{			
	sfx_routine:
			jmp play_with_music
}


//when sid is not playing, we can use any of the channels to play effects
play_no_music:
{

			lda wavetable_l,x
			ldy wavetable_h,x
			ldx channel
			dex
			bpl !skp+			
			ldx #2
		!skp:
			stx channel
			pha
			lda times7,x
			tax
			pla
			jmp sid.init + 6			
			
channel:
.byte 2
times7:
.fill 3, 7 * i			
}


play_with_music:
{
			lda wavetable_l,x
			ldy wavetable_h,x
			ldx #7 * 2
			jmp sid.init + 6
			rts
}


// Only 7 different effects, but let's make them count :-)
.label SFX_LANDING = 0
.label SFX_JUMP = 1
.label SFX_IGLOO = 2
.label SFX_BONUS = 3
.label SFX_FISH = 4
.label SFX_SPLASH = 5
.label SFX_BEAR = 6

sfx_jump:
.import binary "../sfx/jump.snd"


sfx_igloo:
.import binary "../sfx/igloo.snd"


sfx_bonus:
.import binary "../sfx/bonus.snd"


sfx_fish:
.import binary "../sfx/eating.snd"


sfx_landing:
.import binary "../sfx/landing.snd"


sfx_splash:
.import binary "../sfx/splash.snd"

sfx_bear:
.import binary "../sfx/bear.snd"


wavetable_l:
.byte <sfx_landing, <sfx_jump, <sfx_igloo,  <sfx_bonus, <sfx_fish, <sfx_splash, <sfx_bear

wavetable_h:
.byte >sfx_landing, >sfx_jump, >sfx_igloo,  >sfx_bonus, >sfx_fish, >sfx_splash, >sfx_bear
