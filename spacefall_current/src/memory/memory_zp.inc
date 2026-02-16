; ============================================================
; [ZP] ZEROPAGE — EXACT SYMBOL SET (no deletions / no renames)
; ============================================================

.segment "ZEROPAGE"

player_blink_timer: .res 1   ; 0=off, >0 frames remaining


ppuctrl_shadow: .res 1
page_y: .res 1

level_thrFrac:  .res 1
level_thrFinal: .res 1


; ---- Text queue pointers ----
textq_w:     .res 1          ; write index
textq_r:     .res 1          ; read index (used later for NMI flush)
textq_hi:    .res 1
textq_lo:    .res 1
textq_len:   .res 1


; ---- Music ----
music_cur:        .res 1   ; current song id ($FF = none)
current_music:    .res 1   ; 

; ---- SFX (square) ----
sfx_ptr_lo: .res 1
sfx_ptr_hi: .res 1
sfx_hold:   .res 1
sfx_active: .res 1

; ---- Input (legacy + current) ----
buttons:        .res 1
buttons_prev:   .res 1

pad1:           .res 1
pad1_prev:      .res 1
pad1_new:       .res 1

; ---- State-entry / UI flags that are touched a lot ----
title_inited:         .res 1
player_hit_lock:      .res 1
boss_sfx_cd:          .res 1

paused_prev_state:    .res 1
pause_inited:         .res 1

; ---- Frame sync ----
nmi_ready:            .res 1
frame_lo:             .res 1
frame_hi:             .res 1

; ---- Title / UI state (BG toggles) ----
first_run:            .res 1
press_visible:        .res 1
title_visible:        .res 1
gameover_visible:     .res 1
gameover_blink_timer: .res 1
gameover_blink_phase: .res 1
screen_flash_timer:   .res 1
boss_hp_clear_pending:.res 1

draw_test_active:     .res 1
draw_test_done:       .res 1

; ---- Scratch ----
tmp:  .res 1
tmp0: .res 1
tmp1: .res 1
tmp2: .res 1
tmp3: .res 1
tmp4: .res 1
tmp5: .res 1
tmp6: .res 1
tmp7: .res 1
tmp8: .res 1
tmp9: .res 1

ptr0:  .res 2
ptr1:  .res 2

hit_src_x: .res 1


; ---- Debug controls ----
debug_force_type: .res 1
debug_mode:       .res 1

; ---- enemy spawns ----
spawn_cd:       .res 1
level_enemy_cd: .res 1

; ---- catch spawns ----
catch_cd:       .res 1
level_catch_cd: .res 1

; ---- jam + catch lifetime ----
jam_timer:        .res 1
level_jam_frames: .res 1

catch_life_timer: .res 1
level_catch_life: .res 1
catch_active:     .res 1

; ---- Pause overlay ----
pause_dirty:  .res 1
pause_show:   .res 1

; ---- Noise SFX ----
sfxn_ptr_lo: .res 1
sfxn_ptr_hi: .res 1
sfxn_hold:   .res 1
sfxn_active: .res 1

shield_timer: .res 1

boss_intro_timer: .res 1
boss_intro_built: .res 1
bossintro_text_cleared: .res 1