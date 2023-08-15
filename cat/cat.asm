;; cat 99 bytes (default features) by elijah629 on elijah629/small32
;; 
;; nasm -fbin cat.asm -o cat;chmod +x cat;
;; cat file1 file2 ...

;; Configure optional features below, this will effect binary size. The reccommended options are on by default.
close_file              equ 1	; closes the fd
handle_errors           equ 1	; exits on error
set_error_code          equ 0	; when exiting on error, set error code to -1 ( only used when handle_errors is true )

BITS    32
org     0x08048000

ehdr:
        db      0x7F, "ELF"	; e_ident
s1:
_start:
        dec     esi             ; used in loop, size variable. setting here so no repeated negatives
        add     esp, 8          ; skip argc + first argv
arg:
        pop     ebx             ; exit if ebx is NULL
        test    ebx, ebx        ;
        jz      exit            ; since ebx is NULL, exit code is 0 ( NULL ). Therefore, we dont have to set it ( unless error codes are on ).

        push    ebx             ; save filename

        jmp open
s1size       equ     $ - s1
times 12 - s1size db 0          ; 12 byte normal padding

        dw      2               ; e_type
        dw      3               ; e_machine
      
s2:   ; dd      0               ; e_version     UNCHECKED
exit:
        push 1
        jmp exit2
s2size equ $ - s2
times 4 - s2size db 0
        dd      _start		; e_entry
        dd      phdr - $$	; e_phoff
s3:
open:
        push 5                  ; open() system call
        pop eax                 ;
      ; mov     ebx, ebx	; filename, already in ebx
        xor     ecx, ecx        ; set mode 0, read mode
        int     80h

        %if handle_errors
                jmp handle_error
        %else
                jmp print
        %endif
      ; dd      0		; e_shoff 	UNCHECKED
      ; dd      0		; e_flags 	UNCHECKED
      ; dw      0		; e_ehsize 	UNCHECKED
s3size equ $ - s3
times 10 - s3size db 0		; 10 byte normal padding
        dw      phdrsize	; e_phentsize
phdr:
        dd      1               ; e_phnum, p_type
      ; dw      0		; e_shentsize	UNCHECKED
      ; dw      0		; e_shnum	UNCHECKED
      ; dw      0		; e_shstrndx	UNCHECKED
        dd      0		; p_offset
        dd      $$              ; p_vaddr
      ; dd      0               ; p_paddr	UNCHECKED
s4:
exit2:
        pop     eax
        int     80h
s4size equ $ - s4
times 4 - s4size db 0
        dd      filesize        ; p_filesz
        dd      filesize        ; p_memsz
        dd      5               ; p_flags
s5:   ; dd      0               ; p_align       UNCHECKED
print:
        ; fs is in eax
        mov     ecx, eax        ; move fd into sendfile
        jmp     print2
s5size equ $ - s5
times 4 - s5size db 0

phdrsize      equ     $ - phdr

%if handle_errors
handle_error:
        test    eax, eax
        jns     print           ; no error

        %if set_error_code
              ; push	-1
              ; pop	ebx
                mov	bl, -1 	; linux only looks at the last 8 bits in error codes
        %endif
        jmp exit
%endif

print2:
        ; fd is in eax
        mov     al, 0xbb        ; sendfile() system call
        push    1               ; STDOUT
        pop     ebx             ;

      ; xor     edx, edx       ; Offset, NULL (0) means file offset is used and incremented, edx is 0 throughout entire program so this is fine to not set

        ; esi is already -1
        ; esi: Size. -1 reads all of it? no psuedo files though ( ie. /dev/random )

        int     80h

        ; fd is in ecx

%if close_file
        ; close file
        mov     ebx, ecx        ; move fd into close
        push    6               ; close() system call
        pop     eax             ;
        int     80h
%endif

        pop     ebx             ; take filename back
        jmp     arg             ; repeat

filesize equ $ - $$