; src/system/nmi

.segment "CODE"

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

  ; ---- OAM DMA ----
  lda #$00
  sta OAMADDR
  lda #>OAM_BUF
  sta OAMDMA

  ; ---- VRAM updates ----
  jsr TextQ_NMI_Flush

  ; ---- HUD ----
  lda game_state
  cmp #STATE_PLAY
  beq @do_hud
  cmp #STATE_BOSS
  beq @do_hud
  cmp #STATE_PAUSE
  beq @do_hud
  jmp @skip_hud

@do_hud:
  jsr HUD_NMI_Update

@skip_hud:

  ; ---- Pause overlay update ----
  lda pause_dirty
  beq :+
    jsr Pause_NMI_Update
:

  ; ---- Flash / grayscale ----
  lda #PPUMASK_BG_SPR
  ldx screen_flash_timer
  beq @mask_ready

  dec screen_flash_timer
  lda screen_flash_timer
  cmp #FLASH_GRAY_CUTOFF
  bcc @mask_ready

  lda #PPUMASK_BG_SPR
  ora #%00000001

@mask_ready:
  sta PPUMASK

  ; ---- hard reset scroll every frame ----
  lda PPUSTATUS
  lda #$00
  sta PPUSCROLL
  sta PPUSCROLL

  lda ppuctrl_shadow
  and #%11111100
  sta ppuctrl_shadow
  sta PPUCTRL

  lda #$01
  sta nmi_ready

  ; ---- RESTORE REGISTERS LAST ----

  ; Restore registers LAST.
  ; Do not add logic after this point unless it preserves A/X/Y itself.
  pla
  tay
  pla
  tax
  pla

  rti

IRQ:
  rti