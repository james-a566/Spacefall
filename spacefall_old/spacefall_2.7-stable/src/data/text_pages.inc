.segment "CODE"

; ------------------------------------------------------------
; Title_DrawPrompt_Manual
; Call only during render-off safe block (like START block now)
; ------------------------------------------------------------
Title_DrawPrompt_Manual:
  jsr TextQ_Clear

  lda #<Str_PressStart
  sta ptr0
  lda #>Str_PressStart
  sta ptr0+1

  lda #$22
  ldx #$4B          ; $224B PRESS START spot
  jsr TextQ_QueueStrZ

  jsr TextQ_End
  jsr TextQ_Flush_ManualVRAM
  rts

; ------------------------------------------------------------
; Text_DrawPage_Manual (SAFE)
; - ptr1 -> page table: [hi][lo][ptrLo][ptrHi] ... [00]
; - Rendering MUST already be off
; ------------------------------------------------------------
Text_DrawPage_Manual:
  jsr TextQ_Clear

  lda #$00
  sta page_y

@next:
  ldy page_y
  lda (ptr1),y          ; hi
  beq @done
  sta textq_hi
  iny

  lda (ptr1),y          ; lo
  sta textq_lo
  iny

  lda (ptr1),y          ; str lo
  sta ptr0
  iny
  lda (ptr1),y          ; str hi
  sta ptr0+1
  iny

  ; save updated cursor BEFORE calling anything
  sty page_y

  lda textq_hi
  ldx textq_lo
  jsr TextQ_QueueStrZ    ; (this may clobber Y — fine now)

  jmp @next

@done:
  jsr TextQ_End
  jsr TextQ_Flush_ManualVRAM
  rts

