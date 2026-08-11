global main

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

section .data
    window_title db "Void Runner", 0

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

section .bss
    event resb 56

    player_x resd 1
    player_y resd 1
    player_w resd 1
    player_h resd 1
    
    key_up resb 1
    key_down resb 1
    key_left resb 1
    key_right resb 1

section .text
main:
    ; ! Function Prologue
    push rbp
    mov rbp, rsp
    sub rsp, 32 ; allocate space for local variables

    ; Stack Layout:
    ; [rbp - 8]  : SDL_Window*
    ; [rbp - 16] : SDL_Renderer*
    ; [rbp - 32] : SDL_Rect

    ; ! Init Player
    mov dword [rel player_x], 375
    mov dword [rel player_y], 275
    mov dword [rel player_w], 50
    mov dword [rel player_h], 50

    ; ! Initialize SDL
    mov edi, SDL_INIT_VIDEO
    call SDL_Init
    test eax, eax
    jnz .quit

    ; ! Create Window
    lea rdi, [rel window_title]
    mov esi, SDL_WINDOWPOS_CENTERED
    mov edx, SDL_WINDOWPOS_CENTERED
    mov ecx, 800 ; width
    mov r8d, 600 ; height
    mov r9d, SDL_WINDOW_SHOWN
    call SDL_CreateWindow
    test rax, rax
    jz .quit
    mov [rbp - 8], rax ; store window pointer

    ; ! Create Renderer
    mov rdi, rax
    mov esi, -1 ; renderer index (-1 for first available)
    xor edx, edx ; flags (0 for no flags)
    call SDL_CreateRenderer
    test rax, rax
    jz .destroy_window
    mov [rbp - 16], rax ; store renderer pointer

.game_loop:

.poll_events:
    lea rdi, [rel event]
    call SDL_PollEvent
    test eax, eax
    jz .render

    ; ! Check Event Type
    mov eax, [rel event]
    cmp eax, SDL_QUIT
    je .quit

    cmp eax, SDL_KEYDOWN
    je .key_down

    cmp eax, SDL_KEYUP
    je .key_up
    jmp .update

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
    cmp byte [rel key_up], 0
    je .check_down
    sub dword [rel player_y], 4

.check_down:
    cmp byte [rel key_down], 0
    je .check_left
    add dword [rel player_y], 4

.check_left:
    cmp byte [rel key_left], 0
    je .check_right
    sub dword [rel player_x], 4

.check_right:
    cmp byte [rel key_right], 0
    je .render
    add dword [rel player_x], 4

.render:
    ; ! Clear Screen
    mov rdi, [rbp - 16] ; load renderer pointer
    mov esi, 0 ; red
    mov edx, 0 ; green
    mov ecx, 0 ; blue
    mov r8d, 255 ; alpha
    call SDL_SetRenderDrawColor
    mov rdi, [rbp - 16] ; load renderer pointer
    call SDL_RenderClear

    ; ! Build SDL_Rect for Player
    mov eax, [rel player_x]
    mov [rbp - 32], eax ; SDL_Rect.x
    mov eax, [rel player_y]
    mov [rbp - 28], eax ; SDL_Rect.y
    mov eax, [rel player_w]
    mov [rbp - 24], eax ; SDL_Rect.w
    mov eax, [rel player_h]
    mov [rbp - 20], eax ; SDL_Rect.h

    ; ! Set Draw Color for Player
    mov rdi, [rbp - 16] ; load renderer pointer
    mov esi, 255 ; red
    mov edx, 255 ; green
    mov ecx, 255 ; blue
    mov r8d, 255 ; alpha
    call SDL_SetRenderDrawColor

    ; ! Draw Player Rectangle
    mov rdi, [rbp - 16] ; load renderer pointer
    lea rsi, [rbp - 32] ; load address of SDL_Rect
    call SDL_RenderFillRect

    ; ! Present Renderer
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
