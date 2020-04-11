example::sum_iter:
        cmp     rdi, 2
        jb      .LBB2_1
        lea     rax, [rdi - 2]
        lea     rcx, [rdi - 3]
        mul     rcx
        mov     r8, rax
        mov     rsi, rdx
        lea     rcx, [rdi - 4]
        mul     rcx
        imul    ecx, esi
        shld    rsi, r8, 63
        lea     rsi, [rsi + 4*rsi]
        add     edx, ecx
        shld    rdx, rax, 63
        movabs  rcx, 6148914691236517206
        imul    rcx, rdx
        lea     rax, [rsi + 4*rdi]
        add     rax, -7
        add     rax, rcx
        ret
.LBB2_1:
        xor     eax, eax
        ret