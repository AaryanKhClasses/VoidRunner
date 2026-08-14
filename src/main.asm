global main

extern printf
extern SDL_Init
extern SDL_CreateWindow
extern SDL_DestroyWindow
extern SDL_CreateRenderer
extern SDL_DestroyRenderer
extern SDL_PollEvent
extern SDL_SetRenderDrawColor
extern SDL_RenderClear
extern SDL_RenderFillRect
extern SDL_RenderPresent
extern SDL_Delay
extern SDL_Quit

%macro LOG 1
    push rax
    push rcx
    push rdx
    push rsi
    push r8
    push r9
    push r10
    push r11
    lea rdi, [rel %1]
    call debug_log
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rax
%endmacro

%macro LOG_INT 2
    push rax
    push rcx
    push rdx
    push rsi
    push r8
    push r9
    push r10
    push r11
    lea rdi, [rel %1]
    mov esi, %2
    call debug_log_int
    pop r11
    pop r10
    pop r9
    pop r8
    pop rsi
    pop rdx
    pop rcx
    pop rax
%endmacro

section .data
    window_title db "Void Runner", 0

    ; ! SDL Constants
    SDL_INIT_VIDEO equ 0x00000020
    SDL_WINDOW_SHOWN equ 0x00000004
    SDL_WINDOWPOS_CENTERED equ 0x2FFF0000

    SDL_QUIT equ 0x100
    SDL_KEYDOWN equ 0x300
    SDL_KEYUP equ 0x301

    SDLK_w equ 119
    SDLK_a equ 97
    SDLK_s equ 115
    SDLK_d equ 100

    ; ! Window Dimensions
    WINDOW_WIDTH equ 1080
    WINDOW_HEIGHT equ 720
    HUD_HEIGHT equ 120
    GAME_HEIGHT equ WINDOW_HEIGHT - HUD_HEIGHT

    ; ! Debug Logging
    DEBUG_ENABLED equ 1
    debug_prefix db "[DEBUG] ", 0
    fmt_debug db "[DEBUG] %s", 10, 0
    fmt_debug_int db "[DEBUG] %s: %d", 10, 0
    fmt_debug_hex db "[DEBUG] %s: 0x%08x", 10, 0
    msg_game_started db "Game started", 0

    ; ! Wall Struct:
    ; +0    x
    ; +4    y
    ; +8    w
    ; +12   h
    wall_count equ 3
    walls:
        dd 150, 50, 200, 40
        dd 50, 160, 200, 40
        dd 500, 500, 200, 40

    ; ! Enemy Struct:
    ; +0    x
    ; +4    y
    ; +8    w
    ; +12   h
    ; +16   speed
    ; +20   alive
    ENEMY_WIDTH equ 30
    ENEMY_HEIGHT equ 30
    ENEMY_SIZE equ 24
    ENEMY_SPEED equ 2
    enemy_count equ 3
    enemies:
        dd 100, 100, ENEMY_WIDTH, ENEMY_HEIGHT, ENEMY_SPEED, 1
        dd 650, 100, ENEMY_WIDTH, ENEMY_HEIGHT, ENEMY_SPEED, 1
        dd 400, 500, ENEMY_WIDTH, ENEMY_HEIGHT, ENEMY_SPEED, 1
    
    ; ! Player Properties
    PLAYER_MAX_HEALTH equ 100
    PLAYER_DAMAGE equ 10
    DAMAGE_COOLDOWN equ 500

    ; ! Game State
    GAME_PLAYING equ 1
    GAME_OVER equ 0

section .bss
    event resb 56

    player_x resd 1
    player_y resd 1
    player_w resd 1
    player_h resd 1
    player_health resd 1
    player_damage_cooldown resd 1
    key_up resb 1
    key_down resb 1
    key_left resb 1
    key_right resb 1

    candidate_x resd 1
    candidate_y resd 1
    enemy_candidate_x resd 1
    enemy_candidate_y resd 1

    enemy_index resd 1
    wall_index resd 1

    candidate_rect resd 4
    enemy_rect resd 4
    player_rect resd 4

    game_state resd 1

section .text
main:
    push rbp
    mov rbp, rsp
    sub rsp, 32 ; allocate space for local variables

    ; Stack Layout:
    ; [rbp - 8]  : SDL_Window*
    ; [rbp - 16] : SDL_Renderer*
    ; [rbp - 32] : SDL_Rect

    ; Init Player
    mov dword [rel player_x], WINDOW_WIDTH / 2 - 25
    mov dword [rel player_y], WINDOW_HEIGHT / 2 - 25
    mov dword [rel player_w], 50
    mov dword [rel player_h], 50
    mov dword [rel player_health], PLAYER_MAX_HEALTH
    mov dword [rel player_damage_cooldown], 0
    mov dword [rel game_state], GAME_PLAYING

    ; Initialize SDL
    mov edi, SDL_INIT_VIDEO
    call SDL_Init
    test eax, eax
    jnz .quit

    ; Create Window
    lea rdi, [rel window_title]
    mov esi, SDL_WINDOWPOS_CENTERED
    mov edx, SDL_WINDOWPOS_CENTERED
    mov ecx, WINDOW_WIDTH ; width
    mov r8d, WINDOW_HEIGHT ; height
    mov r9d, SDL_WINDOW_SHOWN
    call SDL_CreateWindow
    test rax, rax
    jz .quit
    mov [rbp - 8], rax ; store window pointer

    ; Create Renderer
    mov rdi, rax
    mov esi, -1 ; renderer index (-1 for first available)
    xor edx, edx ; flags (0 for no flags)
    call SDL_CreateRenderer
    test rax, rax
    jz .destroy_window
    mov [rbp - 16], rax ; store renderer pointer

    LOG msg_game_started

    .game_loop:

    .poll_events:
        lea rdi, [rel event]
        call SDL_PollEvent
        test eax, eax
        jz .update

        ; Check Event Type
        mov eax, [rel event]
        cmp eax, SDL_QUIT
        je .quit

        cmp eax, SDL_KEYDOWN
        je .key_down

        cmp eax, SDL_KEYUP
        je .key_up
        jmp .poll_events

        .key_down:
            mov eax, [rel event + 20]
            cmp eax, SDLK_w
            je .set_key_up
            cmp eax, SDLK_s
            je .set_key_down
            cmp eax, SDLK_a
            je .set_key_left
            cmp eax, SDLK_d
            je .set_key_right
            jmp .poll_events

            .set_key_up:
                mov byte [rel key_up], 1
                jmp .poll_events
            .set_key_down:
                mov byte [rel key_down], 1
                jmp .poll_events
            .set_key_left:
                mov byte [rel key_left], 1
                jmp .poll_events
            .set_key_right:
                mov byte [rel key_right], 1
                jmp .poll_events

        .key_up:
            mov eax, [rel event + 20]
            cmp eax, SDLK_w
            je .clear_key_up
            cmp eax, SDLK_s
            je .clear_key_down
            cmp eax, SDLK_a
            je .clear_key_left
            cmp eax, SDLK_d
            je .clear_key_right
            jmp .poll_events

            .clear_key_up:
                mov byte [rel key_up], 0
                jmp .poll_events
            .clear_key_down:
                mov byte [rel key_down], 0
                jmp .poll_events
            .clear_key_left:
                mov byte [rel key_left], 0
                jmp .poll_events
            .clear_key_right:
                mov byte [rel key_right], 0
                jmp .poll_events

        .update:
            ; Horizontal Movement
            mov eax, [rel player_x]
            cmp byte [rel key_left], 0
            je .check_move_right
            sub eax, 4

            .check_move_right:
                cmp byte [rel key_right], 0
                je .store_candidate_x
                add eax, 4

            .store_candidate_x:
                mov [rel candidate_x], eax
                mov eax, [rel player_y]
                mov [rel candidate_y], eax
                ; Check Horizontal Collision
                call check_collision
                test eax, eax
                jnz .horizontal_blocked
                mov eax, [rel candidate_x] ; No Collision
                mov [rel player_x], eax

            .horizontal_blocked:
                ; Vertical Movement
                mov eax, [rel player_y]
                cmp byte [rel key_up], 0
                je .check_move_down
                sub eax, 4

            .check_move_down:
                cmp byte [rel key_down], 0
                je .store_candidate_y
                add eax, 4

            .store_candidate_y:
                mov [rel candidate_y], eax
                mov eax, [rel player_x]
                mov [rel candidate_x], eax
                call check_collision
                test eax, eax
                jnz .vertical_blocked
                mov eax, [rel candidate_y] ; No Collision
                mov [rel player_y], eax

            .vertical_blocked:
                ; Screen Boundaries
                cmp dword [rel player_x], 0
                jge .check_right_boundary
                mov dword [rel player_x], 0

            .check_right_boundary:
                cmp dword [rel player_x], WINDOW_WIDTH - 50
                jle .check_top_boundary
                mov dword [rel player_x], WINDOW_WIDTH - 50

            .check_top_boundary:
                cmp dword [rel player_y], 0
                jge .check_bottom_boundary
                mov dword [rel player_y], 0

            .check_bottom_boundary:
                cmp dword [rel player_y], GAME_HEIGHT - 50
                jle .update_enemies
                mov dword [rel player_y], GAME_HEIGHT - 50

        .update_enemies:
            call update_enemies
            jmp .render

    .render:
        ; Clear Screen
        mov rdi, [rbp - 16] ; load renderer pointer
        mov esi, 0 ; red
        mov edx, 0 ; green
        mov ecx, 0 ; blue
        mov r8d, 255 ; alpha
        call SDL_SetRenderDrawColor
        mov rdi, [rbp - 16] ; load renderer pointer
        call SDL_RenderClear

        ; Draw Walls
        mov rdi, [rbp - 16] ; load renderer pointer
        mov esi, 120 ; red
        mov edx, 120 ; green
        mov ecx, 120 ; blue
        mov r8d, 255 ; alpha
        call SDL_SetRenderDrawColor
        mov dword [rel wall_index], 0 ; reset wall index

        .draw_walls:
            mov ecx, [rel wall_index]
            cmp ecx, wall_count
            jge .prepare_draw_enemies
            mov eax, ecx
            shl eax, 4
            lea rdx, [rel walls]
            add rdx, rax

            mov eax, [rdx] ; wall.x
            mov [rbp - 32], eax ; SDL_Rect.x
            mov eax, [rdx + 4] ; wall.y
            mov [rbp - 28], eax ; SDL_Rect.y
            mov eax, [rdx + 8] ; wall.w
            mov [rbp - 24], eax ; SDL_Rect.w
            mov eax, [rdx + 12] ; wall.h
            mov [rbp - 20], eax ; SDL_Rect.h

            mov rdi, [rbp - 16] ; load renderer pointer
            lea rsi, [rbp - 32] ; load address of SDL_Rect
            call SDL_RenderFillRect
            inc dword [rel wall_index]
            jmp .draw_walls

        ; Draw Enemies
        .prepare_draw_enemies:
            mov rdi, [rbp - 16] ; load renderer pointer
            mov esi, 255 ; red
            mov edx, 60 ; green
            mov ecx, 60 ; blue
            mov r8d, 255 ; alpha
            call SDL_SetRenderDrawColor
            mov dword [rel enemy_index], 0 ; reset enemy index

        .draw_enemies:
            mov ecx, [rel enemy_index]
            cmp ecx, enemy_count
            jge .draw_player
            mov eax, ecx
            imul eax, ENEMY_SIZE
            lea rdx, [rel enemies]
            add rdx, rax

            cmp dword [rdx + 20], 0 ; check if enemy is alive
            je .draw_next_enemy

            mov eax, [rdx] ; enemy.x
            mov [rbp - 32], eax ; SDL_Rect.x
            mov eax, [rdx + 4] ; enemy.y
            mov [rbp - 28], eax ; SDL_Rect.y
            mov eax, [rdx + 8] ; enemy.w
            mov [rbp - 24], eax ; SDL_Rect.w
            mov eax, [rdx + 12] ; enemy.h
            mov [rbp - 20], eax ; SDL_Rect.h

            mov rdi, [rbp - 16] ; load renderer pointer
            lea rsi, [rbp - 32] ; load address of SDL_Rect
            call SDL_RenderFillRect

            .draw_next_enemy:
                inc dword [rel enemy_index]
                jmp .draw_enemies

        .draw_player:
            ; Build SDL_Rect for Player
            mov eax, [rel player_x]
            mov [rbp - 32], eax ; SDL_Rect.x
            mov eax, [rel player_y]
            mov [rbp - 28], eax ; SDL_Rect.y
            mov eax, [rel player_w]
            mov [rbp - 24], eax ; SDL_Rect.w
            mov eax, [rel player_h]
            mov [rbp - 20], eax ; SDL_Rect.h

            ; Set Draw Color for Player
            mov rdi, [rbp - 16] ; load renderer pointer
            mov esi, 255 ; red
            mov edx, 255 ; green
            mov ecx, 255 ; blue
            mov r8d, 255 ; alpha
            call SDL_SetRenderDrawColor

            ; Draw Player Rectangle
            mov rdi, [rbp - 16] ; load renderer pointer
            lea rsi, [rbp - 32] ; load address of SDL_Rect
            call SDL_RenderFillRect

            ; Present Renderer
            mov rdi, [rbp - 16] ; load renderer pointer
            call SDL_RenderPresent
            mov edi, 16 ; delay in milliseconds
            call SDL_Delay
            jmp .game_loop

    .quit_game:
        mov rdi, [rbp - 16] ; load renderer pointer
        call SDL_DestroyRenderer

    .destroy_window:
        mov rdi, [rbp - 8] ; load window pointer
        call SDL_DestroyWindow

    .quit:
        call SDL_Quit
        xor eax, eax ; return 0
        mov rsp, rbp
        pop rbp
        ret

; ! Function: rects_overlap
; Checks if two rectangles overlap using Axis-Aligned Bounding Box (AABB) collision detection.
; Args:
;   rdi: pointer to rect1
;   rsi: pointer to rect2
; Rect Layout:
;   0: x, 4: y, 8: w, 12: h
; Returns:
;   eax: 1 if rects overlap, 0 otherwise
rects_overlap:
    ; rect1.right > rect2.left
    mov eax, [rdi] ; rect1.x
    add eax, [rdi + 8] ; rect1.x + rect1.w
    cmp eax, [rsi] ; rect2.x
    jle .no_collision

    ; rect1.left < rect2.right
    mov eax, [rsi] ; rect2.x
    add eax, [rsi + 8] ; rect2.x + rect2.w
    cmp [rdi], eax ; rect1.x
    jge .no_collision

    ; rect1.bottom > rect2.top
    mov eax, [rdi + 4] ; rect1.y
    add eax, [rdi + 12] ; rect1.y + rect1.h
    cmp eax, [rsi + 4] ; rect2.y
    jle .no_collision

    ; rect1.top < rect2.bottom
    mov eax, [rsi + 4] ; rect2.y
    add eax, [rsi + 12] ; rect2.y + rect2.h
    cmp [rdi + 4], eax ; rect1.y
    jge .no_collision

    mov eax, 1 ; collision detected
    ret

    .no_collision:
        xor eax, eax ; no collision
        ret

; ! Function: check_collision
; Checks if the candidate position collides with any wall
; Returns:
;   eax: 1 if collision detected, 0 otherwise
check_collision:
    mov dword [rel wall_index], 0 ; wall index = 0

    .wall_loop:
        mov ecx, [rel wall_index]
        cmp ecx, wall_count
        jge .no_collision

        mov eax, [rel candidate_x]
        mov [rel candidate_rect + 0], eax ; candidate_rect.x
        mov eax, [rel candidate_y]
        mov [rel candidate_rect + 4], eax ; candidate_rect.y
        mov eax, [rel player_w]
        mov [rel candidate_rect + 8], eax ; candidate_rect.w
        mov eax, [rel player_h]
        mov [rel candidate_rect + 12], eax ; candidate_rect.h

        mov eax, ecx
        shl eax, 4
        lea rsi, [rel walls]
        add rsi, rax

        lea rdi, [rel candidate_rect]
        call rects_overlap
        test eax, eax
        jnz .collision
        inc dword [rel wall_index]
        jmp .wall_loop
    
    .collision:
        mov eax, 1 ; collision detected
        ret

    .no_collision:
        xor eax, eax ; no collision
        ret

; ! Function: update_enemies
; Moves every alive enemy towards the player.
update_enemies:
    push rbx
    push r12
    push r13
    xor r12d, r12d ; enemy index = 0

    .enemy_loop:
        cmp r12d, enemy_count
        jge .done

        ; Calculate candidate position for the enemy
        mov eax, r12d
        imul eax, ENEMY_SIZE
        lea r13, [rel enemies]
        add r13, rax

        cmp dword [r13 + 20], 0 ; check if enemy is alive
        je .next_enemy

        ; Horizontal Movement
        mov eax, [r13 + 0] ; enemy.x
        cmp eax, [rel player_x]
        jge .enemy_left_checked

        add eax, [r13 + 16] ; enemy.x + speed
        mov [rel enemy_candidate_x], eax
        jmp .horizontal_candidate_ready

        .enemy_left_checked:
            cmp eax, [rel player_x]
            jle .horizontal_candidate_ready
            sub eax, [r13 + 16] ; enemy.x - speed
            mov [rel enemy_candidate_x], eax

        .horizontal_candidate_ready:
            mov eax, [r13 + 0]
            cmp eax, [rel player_x]
            je .keep_enemy_x
            jmp .check_enemy_x

        .keep_enemy_x:
            mov [rel enemy_candidate_x], eax
        .check_enemy_x:
            mov eax, [r13 + 4] ; enemy.y
            mov [rel enemy_candidate_y], eax

            ; Build candidate enemy rectangle
            mov eax, [rel enemy_candidate_x]
            mov [rel enemy_rect + 0], eax ; enemy_rect.x
            mov eax, [rel enemy_candidate_y]
            mov [rel enemy_rect + 4], eax ; enemy_rect.y
            mov eax, [r13 + 8] ; enemy.w
            mov [rel enemy_rect + 8], eax ; enemy_rect.w
            mov eax, [r13 + 12] ; enemy.h
            mov [rel enemy_rect + 12], eax ; enemy_rect.h

            call enemy_hits_wall
            test eax, eax
            jnz .horizontal_blocked

            mov eax, [rel enemy_candidate_x]
            mov [r13 + 0], eax ; update enemy.x

        .horizontal_blocked:
            ; Vertical Movement
            mov eax, [r13 + 4] ; enemy.y
            cmp eax, [rel player_y]
            jge .enemy_above_checked
            add eax, [r13 + 16] ; enemy.y + speed
            mov [rel enemy_candidate_y], eax
            jmp .vertical_candidate_ready

        .enemy_above_checked:
            cmp eax, [rel player_y]
            jle .vertical_candidate_ready
            sub eax, [r13 + 16] ; enemy.y - speed
            mov [rel enemy_candidate_y], eax
            jmp .vertical_candidate_ready
        
        .vertical_candidate_ready:
            mov eax, [r13 + 4]
            cmp eax, [rel player_y]
            je .keep_enemy_y
            jmp .check_enemy_y
        
        .keep_enemy_y:
            mov [rel enemy_candidate_y], eax
        .check_enemy_y:
            mov eax, [r13 + 0] ; enemy.x
            mov [rel enemy_candidate_x], eax

            ; Build candidate enemy rectangle
            mov eax, [rel enemy_candidate_x]
            mov [rel enemy_rect + 0], eax ; enemy_rect.x
            mov eax, [rel enemy_candidate_y]
            mov [rel enemy_rect + 4], eax ; enemy_rect.y
            mov eax, [r13 + 8] ; enemy.w
            mov [rel enemy_rect + 8], eax ; enemy_rect.w
            mov eax, [r13 + 12] ; enemy.h
            mov [rel enemy_rect + 12], eax ; enemy_rect.h

            call enemy_hits_wall
            test eax, eax
            jnz .vertical_blocked
            mov eax, [rel enemy_candidate_y]
            mov [r13 + 4], eax ; update enemy.y

        .vertical_blocked:
            cmp dword [r13 + 0], 0
            jge .enemy_right_boundary
            mov dword [r13 + 0], 0

        .enemy_right_boundary:
            mov eax, WINDOW_WIDTH
            sub eax, [r13 + 8] ; WINDOW_WIDTH - enemy.w
            cmp [r13 + 0], eax
            jle .enemy_top_boundary
            mov [r13 + 0], eax
        .enemy_top_boundary:
            cmp dword [r13 + 4], 0
            jge .enemy_bottom_boundary
            mov dword [r13 + 4], 0
        .enemy_bottom_boundary:
            mov eax, WINDOW_HEIGHT
            sub eax, [r13 + 12] ; WINDOW_HEIGHT - enemy.h
            cmp [r13 + 4], eax
            jle .next_enemy
            mov [r13 + 4], eax
        
    .next_enemy:
        inc r12d
        jmp .enemy_loop
    .done:
        pop r13
        pop r12
        pop rbx
        ret

; ! Function: enemy_hits_wall
; Checks if the candidate enemy position collides with any wall
; Returns:
;   eax: 1 if collision detected, 0 otherwise
enemy_hits_wall:
    mov dword [rel wall_index], 0 ; wall index = 0
    .wall_loop:
        mov ecx, [rel wall_index]
        cmp ecx, wall_count
        jge .no_collision

        mov eax, ecx
        shl eax, 4
        lea rsi, [rel walls]
        add rsi, rax
        lea rdi, [rel enemy_rect]

        call rects_overlap
        test eax, eax
        jnz .collision
        inc dword [rel wall_index]
        jmp .wall_loop

    .collision:
        mov eax, 1 ; collision detected
        ret

    .no_collision:
        xor eax, eax ; no collision
        ret

; ! Function: debug_log
; Logs a debug message to the console.
; Args:
;   rdi: pointer to the message string
debug_log:
    %if DEBUG_ENABLED
        push rbp
        mov rbp, rsp
        mov rsi, rdi ; message string
        lea rdi, [rel fmt_debug]
        xor eax, eax ; no floating point arguments
        call printf
        pop rbp
    %endif
        ret

; ! Function: debug_log_int
; Logs a debug message with an integer value to the console.
; Args:
;   rdi: pointer to the message string
;   rsi: integer value
debug_log_int:
    %if DEBUG_ENABLED
        push rbp
        mov rbp, rsp
        mov rdx, rsi ; integer value
        mov rsi, rdi ; message string
        lea rdi, [rel fmt_debug_int]
        xor eax, eax ; no floating point arguments
        call printf
        pop rbp
    %endif
        ret
