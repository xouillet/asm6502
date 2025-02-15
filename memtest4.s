;
; MACROS
;
; Initialize address with START
    macro INI_ADDRS
    LDA START
    STA ADDRS
    LDA START+1
    STA ADDRS+1
    endm

; Increment address
    macro INC_ADDRSC
    INC ADDRS
    BNE .SKIP_HI
    INC ADDRS+1
.SKIP_HI:
    LDA END
    CMP ADDRS
    BNE .EXIT2
    LDA END+1
    CMP ADDRS+1
.EXIT2:
    endm

; Set test pattern
; only for tests 4 and 5 (address in address tests), make addres High or Low 
; equal to pattern
; test 4 is LSB of address
; test 5 is MSB of address
; 
  macro SET_PATRN
    CPY    #4
    BNE    .TEST5
    LDA    ADDRS
    STA    TEST_PATRN 
.TEST5:
    CPY    #5
    BNE    .EXIT1
    LDA    ADDRS+1
    STA    TEST_PATRN 
.EXIT1:
  endm

;
; Zero page locations
;
    org    $EB
START:       word  $0900    ; USER ENTERS START OF MEMORY RANGE min is 38
END:         word  $BFFF    ; USER ENTERS END OF MEMORY RANGE
    org    $FA
ADDRS:       word  0        ; 2 BYTES - ADDRESS OF MEMORY
TEST_PATRN:  byte  0        ; 1 BYTE - CURRENT TEST PATTERN
PASSES:      byte  0        ;NUMBER of PASSES

;START:       .byte $0,$0a    ; USER ENTERS START OF MEMORY RANGE min is 38
;END:         .byte $0,$40    ; USER ENTERS END OF MEMORY RANGE
;ADDRS:       .byte $0,$0     ; 2 BYTES - ADDRESS OF MEMORY
;TEST_PATRN:  .byte 0         ; 1 BYTE - CURRENT TEST PATTERN
;PASSES:      .byte $0        ;NUMBER of PASSES

;
; Start of program
;

; Start at $800 for apple 2
    *=$900

; TESTS TYPE
;    0 = all zeros
;    1 = all ones
;    2 = floating 1s
;    3 = floating 0s
;    4 = address in address (LS 8 address bits)
;    5 = adddress in address(MS 8 address bits)
;

MEM_TEST:
    LDA #$00
    STA PASSES     ; start at pass 0

REPEAT:
    LDA #$00
    TAY              ; TEST # in REG Y
    TAX              ; X must be zero
    STA TEST_PATRN   ; first pass all zeros

NX_PASS:
    INI_ADDRS

LOOP1:
    SET_PATRN        ; sets up TEST_PATRN for address in address test
    LDA TEST_PATRN
    STA (ADDRS, X)   ; STORE PATTERN
    LDA (ADDRS, X)   ; READ (save result of read in case of error)
    CMP TEST_PATRN   ; CHECK
    BNE LOOP_ERR2    ; branch if error ??
    INC_ADDRSC       ; increment address
    BNE LOOP1 

CK_PATRN:
    INI_ADDRS

LOOP2:
    SET_PATRN       ; sets up TEST_PATRN for address in address test
    LDA (ADDRS, X)  ; READ  (save result of read in case of error)
    CMP TEST_PATRN  ; CHECK
LOOP_ERR2:
    BNE LOOP_ERR    ; branch if error
    INC_ADDRSC
    BNE LOOP2

; Test finished
    CPY    #0        ; test 0 - all zeros complete
    BNE    CHK_TEST1


    LDA    #$ff
NX_TEST:
    STA    TEST_PATRN
    INY    ; move to next test 
NX_PASS3:
NX_PASS1:
NX_PASS2:
    JMP    NX_PASS
    
CHK_TEST1:
    CPY    #1        ; all ones complete?
    BNE    CHK_TEST2
    LDA    #$01
    BNE    NX_TEST    ; always

CHK_TEST2:
    CPY    #2        ; floating 1s in progress or done
    BNE    CHK_TEST3
;
; pass of test 2 complete - 8 passes in all with 1 in each bit position
;
    ASL    TEST_PATRN        ; shift left - zero to LSB- MSB to CARRY
    BCC    NX_PASS1
;
; all test 2 passes complete - prepase for test 3
;
    LDA    #$7F
    BNE    NX_TEST        ;always branch

CHK_TEST3:        ;floating zeros in progress or done
    CPY    #3
    BNE    CHK_TEST4
;
; pass of test 3 complete - 8 passes in all with 0 in each bit position
;
    SEC            
    ROR    TEST_PATRN    ; rotate right - Carry to MSB, LSB to Carry
    BCS    NX_PASS2    ; keep going until zero bit reaches carry

NXT_ADDR_TEST:
    INY            ; move to test 4 or 5 - address in address
    BNE    NX_PASS3    ; aways
;
; ADDRESS IN ADDRESS tests - two test only make one pass each
;
CHK_TEST4:
    CPY    #4        ; address in address (low done)?
    BEQ    NXT_ADDR_TEST    ; if test 4 done, start test 5

; test 5 complete - we have finished a complete pass
TESTDONE:            ; print done and stop
    LDA    #'P'
    JSR    WRITE
    LDA    #'A'
    JSR    WRITE
    LDA    #'S'
    JSR    WRITE
    LDA    #'S'
    JSR    WRITE
    JSR    SPACE
    INC    PASSES
    LDA    PASSES
    JSR    TBYT
    JSR    PRINT_CRLF
    nop
    nop
    nop    
    jmp    REPEAT

; Output the error INFO and STOP    
; TEST#, ADDRESS, PATTERN, ERROR
LOOP_ERR:
    PHA
    TYA              ; test # is in Y
    JSR     TBYT      ; test #
    JSR     SPACE
    LDA     ADDRS + $01
    JSR     TBYT      ; OUTPUT ADDRS HI
    LDA     ADDRS
    JSR     TBYT      ; OUTPUT ADDRS LO
    JSR     SPACE
    LDA     TEST_PATRN
    JSR     TBYT      ; OUTPUT EXPECTED
    JSR     SPACE
    PLA
    JSR     TBYT      ; OUTPUT ACTUAL
    JSR     PRINT_CRLF

FINISHED:
    brk
    nop
    nop

; ROUTINE TO WRITE AN ASCII CHAR.
WRITE:
    ORA    #$80   
    JSR    $fdf0
    RTS

; PRINT HEX BYTE
TBYT:
    PHA
    LSR
    LSR
    LSR
    LSR
    AND     #$0F
    ORA     #$30    
    CMP     #$3A
    BCC     WRT
    ADC     #$06

WRT:
    JSR    WRITE
    PLA
    AND     #$0F
    ORA     #$30
    CMP     #$3A
    BCC     WRT2
    ADC     #$06
WRT2:
    JSR    WRITE
    RTS

; ROUTINE TO OUTPUT CRLF
PRINT_CRLF:
    LDA     #$0D
    JSR    WRITE
    LDA     #$0A
    JSR    WRITE
    RTS


; SPACE = OUTPUT 1 SPACE
SPACE:
    LDA     #' '
    JSR    WRITE
    RTS
