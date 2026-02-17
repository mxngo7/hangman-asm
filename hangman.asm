; constants

SYS_READ equ 0
SYS_WRITE equ 1
SYS_EXIT equ 60

STDIN equ 0
STDOUT equ 1
STDERR equ 2

section .data
    enter_word_prompt db "Enter Word: "
    enter_word_prompt_length equ $-enter_word_prompt
    enter_guess_prompt db "Enter Guess: "
    enter_guess_prompt_length equ $-enter_guess_prompt
    invalid_input db "Invalid Input! Please enter one character."
    invalid_input_length equ $-invalid_input
    attempts_left_text db " Attempts Left!"
    attempts_left_text_length equ $-attempts_left_text
    out_of_attempts_text db "Out of attempts!"
    out_of_attempts_text_length equ $-out_of_attempts_text
    letter_already_guessed_text db "Letter Already Guessed! "
    letter_already_guessed_text_length equ $-letter_already_guessed_text
    win_text db "You won! The word was "
    win_text_length equ $-win_text
    on_win_attempts_left_text_1 db "You had "
    on_win_attempts_left_text_1_length equ $-on_win_attempts_left_text_1
    on_win_attempts_left_text_2 db " attempt left"
    on_win_attempts_left_text_2_length equ $-on_win_attempts_left_text_2
    on_win_attempts_left_text_3 db " attempts left"
    on_win_attempts_left_text_3_length equ $-on_win_attempts_left_text_3
    underscore db "_"
    underscore_length equ $-underscore
    newline db 10
    newline_length equ $-newline
    itoa_buffer times 1024 db 0
    clear_command db "/bin/clear", 0
    argv dq clear_command, 0
    env db "TERM=xterm-256color", 0
    envp dq env, 0

section .bss
    word_input resb 256
    guess_input resb 256
    seen_letters resb 26

section .text
global _start

_start:     
    mov r12, 5
    
    mov rax, enter_word_prompt
    mov rdi, enter_word_prompt_length
    call print

    mov rax, word_input
    mov rdi, 256
    call input

    call clear

    mov rax, word_input
    call to_lowercase

    mainloop:
        mov rax, r12
        call itoa
        mov rax, itoa_buffer
        mov rdi, 64
        call print
        mov rax, attempts_left_text
        mov rdi, attempts_left_text_length
        call print
        call print_newline

        mov rax, enter_guess_prompt
        mov rdi, enter_guess_prompt_length
        call print

        mov rax, guess_input
        mov rdi, 256
        call input

        cmp rax, 2
        je input_valid

        call clear

        mov rax, invalid_input
        mov rdi, invalid_input_length
        call print
        call print_newline
        
        vpxor ymm0, ymm0, ymm0
        mov rdi, guess_input
        mov rcx, 8
        clear_guess_input_loop:
        vmovdqu [rdi], ymm0
        add rdi, 32
        dec rcx
        jnz clear_guess_input_loop
        jmp mainloop
        
        input_valid:
        call clear
        mov rax, [guess_input]
        call has_seen_letter
        cmp rax, 1
        je letter_already_seen
        
        mov rax, [guess_input]
        call letter_in_word
        cmp rax, 1
        je letter_is_in_word
        dec r12
        cmp r12, 0
        je out_of_attempts
        jmp letter_is_in_word

        letter_already_seen:
        mov rax, letter_already_guessed_text
        mov rdi, letter_already_guessed_text_length
        call print
        call print_newline

        letter_is_in_word:
        mov rax, [guess_input]
        call append_seen_letter

        call check_win_condition
        cmp rax, 1
        je on_win

        call print_seen_letters

        jmp mainloop
    
    xor rax, rax
    call exit

; itoa(rax value)
itoa:
    mov rbx, 10
    lea rdi, [itoa_buffer+32]
    mov byte [rdi], 0

    itoa_loop:
        xor rdx, rdx
        dec rdi
        div rbx
        add rdx, '0'
        mov [rdi], dl
        cmp rax, 0
        jne itoa_loop
        mov rax, rdi

    ret

; print(rax string, rdi length) -> void
print:
    mov rsi, rax
    mov rdx, rdi
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    syscall
    ret

; newline() -> void
print_newline:
    mov rax, newline
    mov rdi, newline_length
    call print
    ret

; input(rax buffer, rdi length) -> rax length
input:
    mov rsi, rax
    mov rdx, rdi
    mov rax, SYS_READ
    mov rdi, STDIN
    syscall
    ret

; to_lowercase(rax buffer, rdi length) -> rax new_buffer, r8 length
to_lowercase:
    mov r8, rax

    buffer_loop:
        cmp byte [r8], 97
        jge skip_lowercase
        add byte [r8], 32
        skip_lowercase:
        inc r8
        cmp byte [r8], 10
        jne buffer_loop

    sub r8, rax
    ret

; letter_in_word(rax letter) -> rax letter_in_word
letter_in_word:
    mov rcx, rax
    xor rax, rax
    xor r9, r9

    word_loop:
        mov bl, [word_input+r9]
        cmp cl, bl
        jne letter_not_in_word

        mov rax, 1
        jmp word_loop_break

        letter_not_in_word:

        inc r9
        cmp r9, r8
        jnge word_loop
    word_loop_break:

    ret

; print_seen_letters() -> void
print_seen_letters:
    xor r9, r9

    word_loop_2:
        mov bl, [word_input+r9]
        movzx rax, bl
        call has_seen_letter

        cmp rax, 0
        je letter_not_seen
        
        push rbx

        mov rax, rsp
        mov rdi, 1
        call print

        pop rbx

        jmp letter_seen
        letter_not_seen:
        mov rax, underscore
        mov rdi, underscore_length
        call print
        letter_seen:
        inc r9
        cmp r9, r8
        jnge word_loop_2

    call print_newline
    ret

; has_seen_letter(rax letter) -> rax letter_seen
has_seen_letter:
    mov rcx, rax
    xor rax, rax
    xor r11, r11

    seen_letter_loop:
        mov bl, [seen_letters+r11]
        cmp cl, bl
        jne not_seen
        mov rax, 1
        jmp seen_letter_loop_break
        not_seen:
        inc r11
        cmp r11, 26
        jnge seen_letter_loop
    seen_letter_loop_break:
    ret

; append_seen_letter(rax letter) -> rax letter
append_seen_letter:
    mov rcx, rax
    call has_seen_letter
    cmp rax, 1
    je already_seen
    
    xor r10, r10
    seen_letter_loop_2:
        cmp byte [seen_letters+r10], 0
        jne not_empty_character
        
        mov [seen_letters+r10], rcx
        jmp seen_letter_loop_2_break

        not_empty_character:
        inc r10
        cmp r10, 26
        jnge seen_letter_loop_2
    seen_letter_loop_2_break:
    already_seen:
    mov rax, rcx
    ret

; check_win_condition() -> rax has_won
check_win_condition:
    xor r10, r10

    win_condition_loop:
        mov rax, [word_input+r10]
        call has_seen_letter

        cmp rax, 1
        je letter_seen_2
        xor rax, rax
        jmp win_condition_loop_break

        letter_seen_2:
        inc r10
        cmp r10, r8
        jnge win_condition_loop
    win_condition_loop_break:
    
    ret

; out_of_attempts() -> noreturn
out_of_attempts:
    mov rax, out_of_attempts_text
    mov rdi, out_of_attempts_text_length
    call print
    call print_newline

    call exit

; on_win() -> noreturn
on_win:
    call check_win_condition
    cmp rax, 1
    je has_won
    mov rax, 1
    call exit
    has_won:
    mov rax, win_text
    mov rdi, win_text_length
    call print

    mov rax, word_input
    mov rdi, r8
    call print

    call print_newline

    mov rax, on_win_attempts_left_text_1
    mov rdi, on_win_attempts_left_text_1_length
    call print

    mov rax, r12
    call itoa

    mov rax, itoa_buffer
    mov rdi, 64
    call print

    cmp r12, 1
    jne plural

    mov rax, on_win_attempts_left_text_2
    mov rdi, on_win_attempts_left_text_2_length
    call print

    jmp win_exit
    plural:

    mov rax, on_win_attempts_left_text_3
    mov rdi, on_win_attempts_left_text_3_length
    call print

    win_exit:
    call print_newline
    
    xor rax, rax
    call exit

; clear() -> void
clear:
    mov rax, 57
    syscall

    cmp rax, 0
    je child

    mov rdi, rax
    mov rax, 61
    xor rsi, rsi
    xor rdx, rdx
    syscall

    ret

    child:
        mov rax, 59
        mov rdi, clear_command
        mov rsi, argv
        mov rdx, envp
        syscall

        mov rax, 1
        call exit

; exit(rax code) -> noreturn
exit:
    mov rdi, rax
    mov rax, SYS_EXIT
    syscall