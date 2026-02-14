.segment "CODE"

; ----------------------------
; [NMI]
; ----------------------------

NMI:
  pha
  txa
  pha
  tya
  pha


  inc frame_lo
  bne :+
    inc frame_hi
:

jsr NextRand


; ---- OAM DMA (typical) ----
  lda #$00
  sta OAMADDR
  lda #>OAM_BUF     ; high byte of the actual buffer location
  sta OAMDMA

  
 jsr TextQ_NMI_Flush


  lda game_state
  cmp #STATE_PLAY
  beq @do_hud
  cmp #STATE_BOSS
  beq @do_hud
  ; allow HUD during pause
   cmp #STATE_PAUSE
  ;beq @do_hud
  jmp @skip_hud

@do_hud:
  jsr HUD_NMI_Update
@skip_hud:



  lda screen_flash_timer      ; screen_flash_timer: nonzero => temporarily force palette/brightness effect
  beq @flash_off

  dec screen_flash_timer

; grayscale while timer >= FLASH_GRAY_CUTOFF
  lda screen_flash_timer
  cmp #FLASH_GRAY_CUTOFF
  bcs @flash_gray

@flash_normal:
  lda #PPUMASK_BG_SPR
  sta PPUMASK
  jmp @flash_done

@flash_gray:
  lda #PPUMASK_BG_SPR
  ora #%00000001      ; grayscale
  sta PPUMASK
  jmp @flash_done

@flash_off:
  lda #PPUMASK_BG_SPR
  sta PPUMASK

@flash_done:




    jsr Pause_NMI_Update



  pla
  tay
  pla
  tax
  pla

  ; --- hard reset scroll every frame ---
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  ; Keep nametable bits from elsewhere if you want? (you clear them here)
  lda ppuctrl_shadow
  and #%11111100          ; clear NT bits only
  ora #%10000000
  sta ppuctrl_shadow
  sta PPUCTRL





; now tell the main loop the frame is ready
lda #$01
sta nmi_ready

  rti


IRQ:
  rti

