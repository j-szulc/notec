global notec
    SYS_READ equ 0
    SYS_WRITE equ 1
    SYS_EXIT equ 60

    STDOUT equ 1
    STDIN equ 0

    GIFT_READY equ -1

extern debug

section .bss
rv: resq N ; rendezvous
rvMutex: resq 1
roomMutex: resq 1
gift1: resq 1 ; gift from the smaller id notec
gift2: resq 1 ; gift from the bigger id notec


%macro init 0
    push rbp
    push rbx
    push r12
    push r13
    push r14
    push r15
    mov rbp, rsp
    xor rbx, rbx
    xor r12, r12
    xor r13, r13
    mov r14, rdi
    mov r15, rsi

    ;; INITIAL STACK FRAME:
    ;; ... parent stack ...
    ;; RBP
    ;; RBX
    ;; R12
    ;; R13
    ;; R14
    ;; R15 <- RBP

    ;; RESERVED REGISTERS:
    ;; rbx == temporary rsp backup
    ;; r12 == currentByte
    ;; r13 == numberEnteringMode
    ;; r14 == n
    ;; r15 == calc

%endmacro

%macro readByte 1
    mov %1, [r15]
    add r15, 1
%endmacro

%macro mult8 2 ; mult8 a,b means (qword)a<-(qword)a*(qword)b
    mov rax, %1
    xor rdx, rdx
    mov rcx, %2
    mul rcx
    mov %1, rax
%endmacro

%macro add8 2 ; add qwords via a layover at rax
    mov rax, %2
    add %1, rax
%endmacro

;%macro print 2 ; print size whatToPrint
;   mov rax, SYS_WRITE
;   mov rdi, STDOUT
;   mov rsi, %2
;   mov rdx, %1
;   syscall
;%endmacro

%macro set8 2 ; set8 a b does mov8 [a], b via a layover at rax,
    mov rax, %1
    mov rdx, %2
    mov qword [rax], rdx
%endmacro

%macro get8 2 ; get8 a b does mov8 a, [b] via a layover at rax
    mov rdx, %2
    mov %1, qword [rdx]
%endmacro

%macro getNotecAddress 2 ; get address of notec %2 in rv table into %1
    mov %1, %2
    mult8 %1, 8
    add8 %1, rv
%endmacro

%macro lockMutex 1
    mov rdi, %1
    call lock_
%endmacro

%macro unlockMutex 1
    set8 %1, 0
%endmacro

%macro jeq 3
    get8 rcx, %1
    cmp rcx, %2
    je %3
%endmacro

%macro jneq 3
    get8 rcx, %1
    cmp rcx, %2
    jne %3
%endmacro

%macro assert 2
    ;jneq %1, %2, exitFailure
%endmacro

section .text
notec:
    init
mainloop:
    readByte r12
    and r12, 0xFF
zero:
    cmp r12, 0
    je exitSuccess
equals:
    cmp r12, '='
    jne plus

    call ensureCommandMode
    jmp mainloop

plus:
    cmp r12, '+'
    jne asteriks

    call ensureCommandMode
    pop r8
    pop r9
    add r8, r9
    push r8
    jmp mainloop

asteriks:
    cmp r12, '*'
    jne minus

    call ensureCommandMode
    pop r8
    pop r9
    mult8 r8, r9
    push r8
    jmp mainloop

minus:
    cmp r12, '-'
    jne ampersand

    call ensureCommandMode
    pop r8
    pop r9
    sub r8, r9
    push r8
    jmp mainloop

ampersand:
    cmp r12, '&'
    jne pipe

    call ensureCommandMode
    pop r8
    pop r9
    and r8, r9
    push r8
    jmp mainloop

pipe:
    cmp r12, '|'
    jne hat

    call ensureCommandMode
    pop r8
    pop r9
    or r8, r9
    push r8
    jmp mainloop

hat:
    cmp r12, '^'
    jne tilda

    call ensureCommandMode
    pop r8
    pop r9
    xor r8, r9
    push r8
    jmp mainloop

tilda:
    cmp r12, '~'
    jne Z

    call ensureCommandMode
    pop r8
    not r8
    push r8
    jmp mainloop

Z:
    cmp r12, 'Z'
    jne Y

    call ensureCommandMode
    pop r8
    jmp mainloop

Y:
    cmp r12, 'Y'
    jne X

    call ensureCommandMode
    pop r8
    push r8
    push r8
    jmp mainloop

X:
    cmp r12, 'X'
    jne NN

    call ensureCommandMode
    pop r8
    pop r9
    push r8
    push r9
    jmp mainloop

NN:
    cmp r12, 'N'
    jne n

    call ensureCommandMode
    push N
    jmp mainloop

n:
    cmp r12, 'n'
    jne g

    call ensureCommandMode
    push r14
    jmp mainloop

g:
    cmp r12, 'g'
    jne W

    call ensureCommandMode
    mov rdi, r14
    mov rsi, rsp
    mov rbx, rsp
    and rsp, -16
    call debug
    mov rsp, rbx
    mult8 rax, 8
    add rsp, rax
    jmp mainloop

W:
    cmp r12, 'W'
    jne number09

    call ensureCommandMode

    ;; nie zaimplementowano!!!
    ;;jmp exitFailure

    pop r8

    ;;;;;lea r10, [rv+8*r14]
    getNotecAddress r10, r14
    lockMutex rvMutex
    assert r10, 0
    inc r8
    set8 r10, r8
    unlockMutex rvMutex
    dec r8
    ;;;;;;lea r10, [rv+8*r8]
    getNotecAddress r10, r8

    inc r14
WtrySync:
    lockMutex rvMutex
    jeq r10, r14, WsyncSuccess
    unlockMutex rvMutex
    jmp WtrySync
WsyncSuccess:
    set8 r10, 0
    unlockMutex rvMutex
    dec r14
    ; met
    cmp r14, r8
    jg Wbigger
    jl Wsmaller
    jmp exitFailure
Wsmaller:
    lockMutex roomMutex
    getNotecAddress r10, r8

    pop r9
    assert gift1, 0
    set8 gift1, r9
    lockMutex rvMutex
    assert r10, 0
    set8 r10, GIFT_READY
    unlockMutex rvMutex

    getNotecAddress r10, r14
WsmallerWaitForGift:
    lockMutex rvMutex
    jeq r10, GIFT_READY, WsmallerGotGift
    unlockMutex rvMutex
    jmp WsmallerWaitForGift
WsmallerGotGift:
    set8 r10, 0
    unlockMutex rvMutex
    get8 r9, gift2
    set8 gift2, 0
    push r9

    unlockMutex roomMutex

    jmp mainloop
Wbigger:
    ; must wait for Wsmaller to reserve the room, signaled by ROOM_READY in rv[n]
    ;;;;;;;;;;;lea r10, [rv+8*r14]
    getNotecAddress r10, r14
WbiggerWaitForGift:
    lockMutex rvMutex
    jeq r10, GIFT_READY, WbiggerGotGift
    unlockMutex rvMutex
    jmp WbiggerWaitForGift
WbiggerGotGift:
    set8 r10, 0
    unlockMutex rvMutex
    pop r9
    set8 gift2, r9
    get8 r9, gift1
    set8 gift1, 0
    push r9

    getNotecAddress r10, r8
    lockMutex rvMutex
    assert r10, 0
    set8 r10, GIFT_READY
    unlockMutex rvMutex

    jmp mainloop

number09:
    cmp r12, '0'
    jl numberaf
    cmp r12, '9'
    jg numberaf
    sub r12, '0'
    call numberMode
    jmp mainloop
numberaf:
    cmp r12, 'a'
    jl numberAF
    cmp r12, 'f'
    jg numberAF
    sub r12, 'a'
    call numberMode
    jmp mainloop
numberAF:
    cmp r12, 'A'
    jl exitFailure
    cmp r12, 'F'
    jg exitFailure
    sub r12, 'A'
    call numberMode
    jmp mainloop
jmp exitFailure
numberMode:
    pop r8
    cmp r13, 1
    je numberModeAlready
    push r12
    jmp numberModeReturn
numberModeAlready:
    pop r9
    mult8 r9, 16
    add r9, r12
    push r9
numberModeReturn:
    mov r13, 1
    push r8
    ret
ensureCommandMode:
    mov r13, 0
    ret
lock_: ; rdi - adres mutexa
    mov rax, 1
    xchg [rdi], rax
    cmp rax, 0
    jne lock_
    ret
exitFailure:
    mov rax, -1
    jmp exit
exitSuccess:
    pop rax
    jmp exit
exit:
    mov rsp, rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    ret