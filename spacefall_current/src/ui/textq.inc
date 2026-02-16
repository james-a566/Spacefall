.segment "CODE"


; ------------------------------------------------------------
; TextQ_Reset
; Back-compat entrypoint: keep callers working.
; ------------------------------------------------------------
TextQ_Reset:
  ; fallthrough (or jmp) to the real clear routine
  ; (choose one style and stick with it)
  jmp TextQ_Clear


; ------------------------------------------------------------
; TextQ_Clear
; Real implementation
; ------------------------------------------------------------
TextQ_Clear:
  lda #$00
  sta textq_r
  sta textq_w
  rts


; A = byte to push
TextQ_PushByte:
  ldx textq_w
  cpx #TEXTQ_BUF_SIZE
  bcs @drop
  sta textq_buf,x
  inx
  stx textq_w
@drop:
  rts

; ------------------------------------------------------------
; TextQ_QueueBlanks
; Inputs: A=hi, X=lo, Y=len  (len must be <= BLANK_MAX_LEN)
; Queues Y blank tiles to the VRAM write queue.
; ------------------------------------------------------------
TextQ_QueueBlanks:
  pha                    ; save hi
  txa
  pha                    ; save lo
  tya
  pha                    ; save len

  lda #<BlinkBlanks
  sta ptr0
  lda #>BlinkBlanks
  sta ptr0+1

  pla
  tay                    ; restore len
  pla
  tax                    ; restore lo
  pla                    ; restore hi

  jsr TextQ_QueueWrite
  rts



TextQ_QueueWrite:
  sta textq_hi
  stx textq_lo
  sty textq_len

  ; required = 3 + len
  tya
  clc
  adc #3
  sta tmp0
  jsr TextQ_CanFit
  bcc @drop_cmd

  ; push header
  lda textq_hi
  jsr TextQ_PushByte
  lda textq_lo
  jsr TextQ_PushByte
  lda textq_len
  jsr TextQ_PushByte

  ; push data
  ldy #$00
@data:
  cpy textq_len
  bcs @done
  lda (ptr0),y
  jsr TextQ_PushByte
  iny
  bne @data
@done:
  rts

@drop_cmd:
  rts


TextQ_End:
  lda #$00
  jsr TextQ_PushByte   ; hi
  lda #$00
  jsr TextQ_PushByte   ; lo
  lda #$00             ; LEN MUST BE ZERO
  jsr TextQ_PushByte
  rts


; ------------------------------------------------------------
; TextQ_Flush_ManualVRAM
; - Flushes queued commands to PPU right now (NOT NMI)
; - Call only with rendering OFF and during vblank-safe window
; Uses: A,X,Y
; ------------------------------------------------------------
TextQ_Flush_ManualVRAM:
  ldy #$00
  sty textq_r

@next_cmd:
  ldy textq_r
  cpy textq_w
  beq @done

  ; hi
  lda textq_buf,y
  iny
  sta textq_hi

  ; lo
  lda textq_buf,y
  iny
  sta textq_lo

  ; len
  lda textq_buf,y
  iny
  tax
  beq @done_cmds         ; len=0 end marker

  ; set PPUADDR
  lda PPUSTATUS
  lda textq_hi
  sta PPUADDR
  lda textq_lo
  sta PPUADDR

@write:
  lda textq_buf,y
  sta PPUDATA
  iny
  dex
  bne @write

  sty textq_r
  jmp @next_cmd

@done_cmds:
  ; reset queue after flushing
  jsr TextQ_Clear
@done:
  rts


; ------------------------------------------------------------
; TextQ_NMI_Flush
; - Drains queued VRAM write commands safely in NMI
; - Command: hi, lo, len, data[len]
; - End marker: len=0
; - Processes whole commands only (no partial command writes)
; - Uses: A,X,Y, tmp0,tmp1
; ------------------------------------------------------------
TextQ_NMI_Flush:
  ldy textq_r
  cpy textq_w
  beq @done

  lda #$00
  sta tmp0              ; tmp0 = bytes_used this NMI

@try_cmd:
  ldy textq_r
  cpy textq_w
  beq @done

  ; Peek command header
  lda textq_buf,y       ; hi
  sta textq_hi
  iny
  lda textq_buf,y       ; lo
  sta textq_lo
  iny
  lda textq_buf,y       ; len
  tax
  beq @end_marker       ; len=0 => done

  ; total bytes this command will consume in queue = 3 + len
  txa
  clc
  adc #3
  sta tmp1              ; tmp1 = cmd_size

  ; if bytes_used + cmd_size > BUDGET, stop this frame
  lda tmp0
  clc
  adc tmp1
  cmp #TEXTQ_FLUSH_BUDGET
  bcc @do_cmd
  beq @do_cmd
  rts                   ; leave for next NMI

@do_cmd:
  ; commit bytes_used += cmd_size
  lda tmp0
  clc
  adc tmp1
  sta tmp0

  ; advance a working index to start of data
  ldy textq_r
  iny                   ; skip hi
  iny                   ; skip lo
  iny                   ; skip len  => Y now at first data byte

  ; set PPUADDR
  lda PPUSTATUS
  lda textq_hi
  sta PPUADDR
  lda textq_lo
  sta PPUADDR

@write_data:
  lda textq_buf,y
  sta PPUDATA
  iny
  dex
  bne @write_data

  ; update read pointer to next command
  sty textq_r
  jmp @try_cmd

@end_marker:
  jsr TextQ_Clear       ; reset queue entirely
@done:
  rts

; ------------------------------------------------------------
; TextQ_QueueStrZ (SAFE)
; - A = hi, X = lo, ptr0 -> 00-terminated tile string
; ------------------------------------------------------------
TextQ_QueueStrZ:
  sta textq_hi
  stx textq_lo

  ldy #$00
@count:
  lda (ptr0),y
  beq @got_len
  iny
  cpy #64              ; CAP: max 64 chars
  bcc @count
@got_len:
  sty textq_len

  lda textq_hi
  ldx textq_lo
  ldy textq_len
  jsr TextQ_QueueWrite
  rts

; ------------------------------------------------------------
; TextQ_QueueWriteZ
; - Queues a VRAM write for a 0-terminated string at (ptr0)
; - Inputs: A=hi, X=lo, ptr0=str
; - Uses: Y, tmp0
; ------------------------------------------------------------
TextQ_QueueWriteZ:
  sta textq_hi
  stx textq_lo

  ; tmp0 = len
  ldy #$00
@count:
  lda (ptr0),y
  beq @count_done
  iny
  bne @count
@count_done:
  sty tmp0

  ; queue header: hi, lo, len
  lda textq_hi
  jsr TextQ_PushByte
  lda textq_lo
  jsr TextQ_PushByte
  lda tmp0
  jsr TextQ_PushByte

  ; queue data bytes
  ldy #$00
@data:
  cpy tmp0
  bcs @done
  lda (ptr0),y
  jsr TextQ_PushByte
  iny
  bne @data

@done:
  rts

; ------------------------------------------------------------
; TextQ_QueueFill
; - Queue a VRAM write that fills LEN bytes with the same tile.
; INPUT:
;   A = VRAM hi
;   X = VRAM lo
;   Y = len
;   tmp0 = fill byte (tile id)
; ------------------------------------------------------------
TextQ_QueueFill:
  sta textq_hi
  stx textq_lo
  sty textq_len

  lda textq_hi
  jsr TextQ_PushByte
  lda textq_lo
  jsr TextQ_PushByte
  lda textq_len
  jsr TextQ_PushByte

  ldy textq_len
  beq @done

@loop:
  lda tmp0
  jsr TextQ_PushByte
  dey
  bne @loop

@done:
  rts


; ------------------------------------------------------------
; TextQ_CanFit
; Input: A = required bytes
; Output: C=1 if can fit, C=0 if not
; Clobbers: X
; ------------------------------------------------------------
TextQ_CanFit:
  ldx textq_w
  txa
  clc
  adc #$00            ; A = textq_w (kept simple if you want)
  ; We want: textq_w + required <= TEXTQ_BUF_SIZE
  ; So: required <= TEXTQ_BUF_SIZE - textq_w
  lda #TEXTQ_BUF_SIZE
  sec
  sbc textq_w         ; A = remaining
  ; Compare remaining (A) with required (in tmp0)
  cmp tmp0
  bcs @yes
  clc
  rts
@yes:
  sec
  rts
