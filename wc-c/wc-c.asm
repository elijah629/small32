;; wc-c 164 bytes by elijah629 on elijah629/small32
;; 
;; nasm -fbin wc-c.asm -o wc-c;chmod +x wc-c;
;; wc-c file

; Constants
STATX_SIZE              equ 0x200

AT_FDCWD                equ -100
AT_SYMLINK_NOFOLLOW     equ 0x100
AT_STATX_SYNC_AS_STAT   equ 0x000
AT_NO_AUTOMOUNT         equ 0x800
FLAGS                   equ AT_STATX_SYNC_AS_STAT | AT_SYMLINK_NOFOLLOW | AT_NO_AUTOMOUNT

BITS 32
            org     0x08048000 ; 32 bit elf

ehdr:                                                 ; Elf32_Ehdr
            db      0x7F, "ELF"
s1:
_start:
    add     esp, 4 * 2          ; Skip argc + filename
    pop     ecx                 ; file path to read
statx1:
    sub     esp, statx_size
    jmp statx2
s1_size      equ     $ - s1
times 12 - s1_size db 0      ; 12 byte normal padding
                dw      2                               ;   e_type
                dw      3                               ;   e_machine

                dd      1                               ;   e_version   UNCHECKED

                dd      _start                          ;   e_entry
                dd      phdr - $$                       ;   e_phoff
                ; dd      0                               ;   e_shoff       UNCHECKED
                ; dd      0                               ;   e_flags       UNCHECKED
                ; dw      ehdrsize                        ;   e_ehsize      UNCHECKED
s2:
itoa2:
    ; sneaky push trick, since we need to make the buffer ( esp, stack pointer ) filled with 10 zero bytes,
    ; we can use DWORD + DWORD + WORD = 10 bytes. This is signifigantly smaller than `push 0` 10 times

    ; in x64 you could use QWORD instead of 2x DWORD
    ; if we could, in x80, TWORD would be the only one needed

    push    DWORD 0             ; 4 +
    push    DWORD 0             ; 4 +
    push    WORD  0             ; 2 = 10 

    jmp itoa3
s2_size     equ     $ - s2
times 10 - s2_size db 0
                dw      phdrsize                        ;   e_phentsize

        phdr:                                           ; Elf32_Phdr
                dd      1                               ;   e_phnum + p_type
                ; dw      0                               ;   e_shentsize UNCHECKED, LINUX WILL FILL IN
                ; dw      0                               ;   e_shnum     UNCHECKED, LINUX WILL FILL IN
                ; dw      0                               ;   e_shstrndx  UNCHECKED, LINUX WILL FILL IN

  ehdrsize      equ     $ - ehdr
  
                ; dd      1                             ;   p_type
                dd      0                               ;   p_offset
                dd      $$                              ;   p_vaddr

                ; dd      $$                              ;   p_paddr       UNCHECKED
s3:
itoa3:
    push `\n` ; add newline
    jmp itoa4
s3_size     equ     $ - s3
times 4 - s3_size db 0

                dd      filesize                        ;   p_filesz
                dd      filesize                        ;   p_memsz
                dd      5                               ;   p_flags

                ; dd      0x1000                          ;   p_align       UNCHECKED
s4:
itoa4:
    mov     ebx, esp
    jmp itoa5
s4_size     equ     $ - s4
times 4 - s4_size db 0
                
  
  phdrsize      equ     $ - phdr

struc statx_timestamp
    .tv_sec resb 8
    .tv_nsec resb 4
    .__reserved resb 4
endstruc

struc statx
        .stx_mask                resb 4
        .stx_blksize             resb 4
        .stx_attributes          resb 8
        .stx_nlink               resb 4   
        .stx_uid                 resb 4   
        .stx_gid                 resb 4   
        .stx_mode                resb 2     

       .__spare0                 resb 2

        .stx_ino                 resb 8     
        .stx_size                resb 8 
        .stx_blocks              resb 8
        .stx_attributes_mask     resb 8
        .stx_atime               resb statx_timestamp_size ; Last access
        .stx_btime               resb statx_timestamp_size ; Creation
        .stx_ctime               resb statx_timestamp_size ; Last status change
        .stx_mtime               resb statx_timestamp_size ; Last modification

        .stx_rdev_major          resb 4      ; Major ID
        .stx_rdev_minor          resb 4      ; Minor ID

        .stx_dev_major           resb 4      ; Major ID
        .stx_dev_minor           resb 4      ; Minor ID

        .stx_mnt_id              resb 8      ; Mount ID

        .stx_dio_mem_align       resb 4
        .stx_dio_offset_align    resb 4

        .__spare3                resb 8 * 12
endstruc

; 10 is the maximum possible digits in a u32, one more for the newline
itoabuf_len equ 11

statx2:
    mov     eax, 0x17f          ; statx() syscall
    mov     ebx, AT_FDCWD       ; dirfd
    ; mov   ecx, ecx            ; pathname
    mov     edx, FLAGS          ; flags
    mov     esi, STATX_SIZE     ; mask
    mov     edi, esp            ; statxbuf
    int     80h
    ; jmp itoa1


itoa1:
; itoa
    mov     eax, [esp + statx.stx_size]
    add     esp, statx_size
    jmp itoa2

itoa5:
    sub     esp, itoabuf_len - 1

    mov     cx, 10 ; divisor

    do_while:                   ; do {
        ; divide eax by 10
        ; edx to upper eax
        
        mov     edx, eax
        shr     edx, 16         ; eax upper

        ; mov eax, eax          ; setting upper 16 bits is pointless, we are only reading lower 0xFFFF ( ax ) anyways

        div     cx              ; / 10

        ; ax has the quotient
        ; dx has the remainder

        sub     ebx, 1          ; Go back by one in the buffer
        
        add     dl, "0"         ; Convert 0-9 to "0"-"9"
        mov     [ebx], dl

        and     eax, 0x0000FFFF ; Zero upper 16 bits of eax

        test     eax, eax       ; } while (x)
        jnz      do_while       ;
    ; end_do_while

    ; print

    push    4                   ; write() syscall
    pop     eax

    push    1                   ; STDOUT fd
    pop     ebx

    mov     ecx, esp            ; buf
    mov     edx, itoabuf_len    ; count
    int     80h 

exit:
    ; exit() syscall
    xchg    eax, ebx            ; ebx has 1 in it already, reuse, somehow xchg is 1 byte smaller than mov and `push BYTE + pop`
    xor     ebx, ebx            ; success exit code
    int     80h

filesize      equ     $ - $$
