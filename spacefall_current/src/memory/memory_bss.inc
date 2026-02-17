; ============================================================
; [BSS] BSS 
; ============================================================
.segment "BSS"

bossbar_dirty:         .res 1   ; needs redraw
bossbar_visible:       .res 1   ; 0/1

bossbar_buf:          .res BOSSBAR_LEN



catch_frac_chance:  .res 1
catch_final_chance: .res 1

intro_page:  .res 1
intro_timer: .res 1


banner_built: .res 1
tutorial_built: .res 1
gameover_built: .res 1


intro_built: .res 1     ; 0=needs VRAM build, 1=done

hud_digits_buf: .res 5     ; for 5 digits (HI or SCORE)
hud_hearts_buf: .res 19    

; ---- Text queue buffer ----
textq_buf: .res TEXTQ_BUF_SIZE

title_built: .res 1   ; 0 = needs VRAM build, 1 = already built



; ---- Game state machine ----
game_state:       .res 1

; ---- Player ----
player_x:         .res 1
player_y:         .res 1
player_cd:        .res 1

; ---- Player bullets ----
bul_alive:        .res BULLET_MAX
bul_x:            .res BULLET_MAX
bul_y:            .res BULLET_MAX
bul_y_prev:       .res BULLET_MAX

; ---- misc core ----
gun_side:         .res 1
rng_lo:           .res 1
rng_hi:           .res 1
score_lo:         .res 1
score_hi:         .res 1
score_work_lo:    .res 1
score_work_hi:    .res 1
lives:            .res 1
invuln_timer:     .res 1
player_attr:      .res 1
good_flash_timer: .res 1

; ---- Score digits ----
score_d0:         .res 1
score_d1:         .res 1
score_d2:         .res 1
score_d3:         .res 1
score_d4:         .res 1

score_x_cur:      .res 1
tmp_xcur:         .res 1

; ---- Enemies ----
ENEMY_MAX = 5

ene_alive:   .res ENEMY_MAX
ene_x:       .res ENEMY_MAX
ene_y:       .res ENEMY_MAX
ene_y_prev:  .res ENEMY_MAX
ene_type:    .res ENEMY_MAX
obj_kind:    .res ENEMY_MAX
ene_variant: .res ENEMY_MAX

ene_spd:     .res ENEMY_MAX
ene_dx:      .res ENEMY_MAX
ene_hp:      .res ENEMY_MAX
ene_timer:   .res ENEMY_MAX
ene_score:   .res ENEMY_MAX

; ---- Catch object state ----
catch_spawn_cd: .res 1    ; kept even if redundant with catch_cd

catch_alive: .res CATCH_MAX
catch_x:     .res CATCH_MAX
catch_y:     .res CATCH_MAX
catch_type:  .res CATCH_MAX
catch_tile:  .res CATCH_MAX
catch_attr:  .res CATCH_MAX

; ---- Level control vars ----
level_idx:        .res 1
level_spawn_cd:   .res 1
level_enemy_spd:  .res 1
level_thrB:       .res 1
level_thrC:       .res 1
level_thrD:       .res 1
level_thrE:       .res 1

boss_time_lo:     .res 1
boss_time_hi:     .res 1

boss_timer_lo:    .res 1
boss_timer_hi:    .res 1
level_banner:     .res 1

; ---- Boss ----
boss_alive:       .res 1
boss_x:           .res 1
boss_y:           .res 1
boss_hp:          .res 1
boss_hp_max:      .res 1
boss_flash:       .res 1
boss_fire_cd:     .res 1

boss_dx:          .res 1
boss_dy:          .res 1

bossbul_alive:    .res BOSS_BULLET_MAX
bossbul_x:        .res BOSS_BULLET_MAX
bossbul_y:        .res BOSS_BULLET_MAX
bossbul_y_prev:   .res BOSS_BULLET_MAX
bossbul_dx:       .res BOSS_BULLET_MAX
bossbul_dy:       .res BOSS_BULLET_MAX

boss_pattern:     .res 1
boss_phase_flags: .res 1
boss_sweep_idx:   .res 1
boss_sweep_dir:   .res 1

boss_bigshot_pulse: .res 1
boss_shake_timer:   .res 1
boss_shake_dx:      .res 1
boss_shake_dy:      .res 1

boss_burst_left:  .res 1
boss_burst_gap:   .res 1

boss_phase:       .res 1
boss_phase_t0:    .res 1
boss_phase_t1:    .res 1
boss_phase_t2:    .res 1

boss_fire_cd_reload: .res 1
boss_move_mode:      .res 1

; ---- HUD (BG tiles) ----
hud_dirty:      .res 1

hi_d0:          .res 1
hi_d1:          .res 1
hi_d2:          .res 1
hi_d3:          .res 1
hi_d4:          .res 1

; ---- Extra gameplay ----
gun_jam_timer:          .res 1

level_catch_good_thr:   .res 1
level_catch_cap:        .res 1
enemy_cd:               .res 1    ; kept even if redundant with level_enemy_cd
level_catch_cd4:        .res 1

ene_flash:              .res ENEMY_MAX
catch_pickup_flash:     .res 1
jam_flash_timer:        .res 1

noise_lock_timer: .res 1


player_kb_timer: .res 1    ; frames remaining
player_kb_dx:    .res 1    ; signed (-1 or +1)
player_kb_dy:    .res 1    ; usually +1 (down) or 0

prev_game_state: .res 1
tutorial_timer:  .res 1
tutorial_visible:.res 1
tutorial_dirty:  .res 1   ; 1 = NMI should draw/clear
play_entered:    .res 1

tutorial_done: .res 1   ; 0 = not shown this run, 1 = already shown

fill_buf: .res 64        ; max fill length (match your cap)

