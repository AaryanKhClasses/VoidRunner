global main

extern SDL_Init
extern SDL_CreateWindow
extern SDL_DestroyWindow
extern SDL_Delay
extern SDL_Quit

section .data
    window_title db "Void Runner", 0
    SDL_INIT_VIDEO equ 0x00000020 ; SDL_INIT_VIDEO flag for SDL_Init
    SDL_WINDOW_SHOWN equ 0x00000004 ; SDL_WINDOW_SHOWN flag for SDL_CreateWindow
    SDL_WINDOWPOS_CENTERED equ 0x2FFF0000 ; SDL_WINDOWPOS_CENTERED constant for window position

section .text
main:
    push rbp
    mov rbp, rsp
    sub rsp, 16 ; allocate space for local variables

    mov edi, SDL_INIT_VIDEO
    call SDL_Init
    test eax, eax
    jnz .quit

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

    mov edi, 3000
    call SDL_Delay

    mov rdi, [rbp - 8] ; load window pointer
    call SDL_DestroyWindow

.quit:
    call SDL_Quit
    xor eax, eax ; return 0
    mov rsp, rbp
    pop rbp
    ret
