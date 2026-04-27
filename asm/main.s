.section __TEXT,__text,regular,pure_instructions
.build_version macos, 14, 0
.globl _main
.p2align 2

_main:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    mov x19, x0
    mov x20, x1

    cmp x19, #2
    b.lt L_no_args

    ldr x0, [x20, #8]
    adrp x1, L_help_long@PAGE
    add x1, x1, L_help_long@PAGEOFF
    bl _strcmp
    cbz w0, L_help

    ldr x0, [x20, #8]
    adrp x1, L_help_short@PAGE
    add x1, x1, L_help_short@PAGEOFF
    bl _strcmp
    cbz w0, L_help

    bl _launch_shell_helper
    b L_done

L_no_args:
    adrp x0, L_usage@PAGE
    add x0, x0, L_usage@PAGEOFF
    bl _puts
    mov w0, #1
    b L_done

L_help:
    adrp x0, L_usage@PAGE
    add x0, x0, L_usage@PAGEOFF
    bl _puts
    mov w0, #0

L_done:
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.p2align 2
_launch_shell_helper:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!
    stp x23, x24, [sp, #-16]!

    mov x21, x19
    mov x22, x20

    add x0, x21, #2
    lsl x0, x0, #3
    bl _malloc
    cbz x0, L_malloc_failed
    mov x23, x0

    adrp x0, L_shell@PAGE
    add x0, x0, L_shell@PAGEOFF
    str x0, [x23]

    bl _helper_path
    str x0, [x23, #8]

    mov x24, #1
L_copy_args:
    cmp x24, x21
    b.ge L_args_done
    ldr x3, [x22, x24, lsl #3]
    add x4, x24, #1
    str x3, [x23, x4, lsl #3]
    add x24, x24, #1
    b L_copy_args

L_args_done:
    add x4, x21, #1
    str xzr, [x23, x4, lsl #3]

    adrp x0, L_shell@PAGE
    add x0, x0, L_shell@PAGEOFF
    mov x1, x23
    bl _execvp

    adrp x0, L_exec_failed@PAGE
    add x0, x0, L_exec_failed@PAGEOFF
    bl _perror
    mov w0, #1
    b L_launch_done

L_malloc_failed:
    adrp x0, L_malloc_failed_msg@PAGE
    add x0, x0, L_malloc_failed_msg@PAGEOFF
    bl _perror
    mov w0, #1

L_launch_done:
    ldp x23, x24, [sp], #16
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.p2align 2
_helper_path:
    stp x29, x30, [sp, #-16]!
    mov x29, sp
    stp x19, x20, [sp, #-16]!
    stp x21, x22, [sp, #-16]!

    adrp x0, L_exe_size@PAGE
    add x0, x0, L_exe_size@PAGEOFF
    mov w1, #4096
    str w1, [x0]

    adrp x0, L_exe_path@PAGE
    add x0, x0, L_exe_path@PAGEOFF
    adrp x1, L_exe_size@PAGE
    add x1, x1, L_exe_size@PAGEOFF
    bl __NSGetExecutablePath
    cbnz w0, L_helper_fallback

    adrp x0, L_exe_path@PAGE
    add x0, x0, L_exe_path@PAGEOFF
    adrp x1, L_real_path@PAGE
    add x1, x1, L_real_path@PAGEOFF
    bl _realpath
    cbz x0, L_use_exe_path
    mov x19, x0
    b L_prepare_helper_path

L_use_exe_path:
    adrp x19, L_exe_path@PAGE
    add x19, x19, L_exe_path@PAGEOFF

L_prepare_helper_path:
    adrp x20, L_helper_path_buf@PAGE
    add x20, x20, L_helper_path_buf@PAGEOFF
    mov x21, xzr
    mov x22, xzr

L_find_slash:
    ldrb w2, [x19, x21]
    cbz w2, L_copy_dir
    cmp w2, #47
    csel x22, x21, x22, eq
    add x21, x21, #1
    cmp x21, #4095
    b.lt L_find_slash

L_copy_dir:
    cbz x22, L_helper_fallback
    add x21, x22, #1
    mov x3, xzr

L_copy_prefix:
    cmp x3, x21
    b.ge L_append_suffix_start
    ldrb w4, [x19, x3]
    strb w4, [x20, x3]
    add x3, x3, #1
    b L_copy_prefix

L_append_suffix_start:
    adrp x5, L_helper_suffix@PAGE
    add x5, x5, L_helper_suffix@PAGEOFF
    mov x6, xzr

L_append_suffix:
    ldrb w7, [x5, x6]
    strb w7, [x20, x3]
    cbz w7, L_helper_done
    add x3, x3, #1
    add x6, x6, #1
    cmp x3, #4095
    b.lt L_append_suffix
    mov w7, wzr
    strb w7, [x20, #4095]
    b L_helper_done

L_helper_fallback:
    adrp x20, L_helper_fallback_path@PAGE
    add x20, x20, L_helper_fallback_path@PAGEOFF

L_helper_done:
    mov x0, x20
    ldp x21, x22, [sp], #16
    ldp x19, x20, [sp], #16
    ldp x29, x30, [sp], #16
    ret

.section __TEXT,__cstring,cstring_literals
L_usage:
    .asciz "asm-agent: an Apple Silicon assembly CLI that talks to an AI helper\n\nUsage:\n  asm-agent \"your prompt\"\n  asm-agent chat\n  asm-agent history\n  asm-agent reset\n  asm-agent --help\n\nEnvironment:\n  OPENAI_API_KEY or AI_API_KEY  API key used by the helper\n  OPENAI_MODEL                  Optional model override\n  ASM_AGENT_STATE               Optional memory file path\n  ASM_AGENT_MOCK_RESPONSE       Optional offline test response"
L_help_long:
    .asciz "--help"
L_help_short:
    .asciz "-h"
L_shell:
    .asciz "/bin/sh"
L_helper_suffix:
    .asciz "../helper/agent.sh"
L_helper_fallback_path:
    .asciz "helper/agent.sh"
L_exec_failed:
    .asciz "execvp /bin/sh"
L_malloc_failed_msg:
    .asciz "malloc"

.section __DATA,__data
.p2align 2
L_exe_size:
    .long 4096

.section __DATA,__bss
.p2align 4
L_exe_path:
    .space 4096
L_real_path:
    .space 4096
L_helper_path_buf:
    .space 4096
