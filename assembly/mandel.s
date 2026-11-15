#include "customasm_mamba_rules.s"
#include "ascii.s"
#align 32

;r1 = x0
;r2 = y0
;r3 = x
;r4 = y
;r5 = i
;r6 = x^2
;r7 = y^2
MULTR
LLI R1,0x7FFF ;Load SP with address 7FFF as bottom
SSPR R1 ;Set Stack Pointer Register from R1

LLI R1,0x0000 ;Load .0000 into R1 (6.26 fixed point)
LUI R1,0xf800 ;Load -2.000 into R1 (6.26 fixed point)
LLI R2,0xe148 ;Load 1.12 into R2 (6.26 fixed point)
LUI R2,0x047a ;Load 1.12 into R2 (6.26 fixed point) 

RESETI:
	ADDI R13,R0,0x0000 ;Load 4/512 to R13
	LUI R13,0x0008 ;Load 4/512 to R13
	ADD R1,R1,R13 ;Add 4/512 to x0
	ADDI R5,R0,64 ;Reset i to 64
	ADDI R3,R0,0 ;Reset x
	ADDI R4,R0,0 ;Reset y
	ADDI R6,R0,0 ;Reset x^2
	ADDI R7,R0,0 ;Reset y^2
	ADDI R14,R0,0 ;Load 0 into R14 lower
	LUI R14,0x0800 ;Load 2 into R14 higher for comparison against 2
	BRLT R1,R14,ITERATION ;If x0 < 2 then go to iteration
	CALL NEWLINE ;If x0 >= 2 then go to new line

ITERATION:
	ADD R8,R6,R7 ;Sum squared values
	ADDI R15,R0,0xFFFF ;Mask upper bit to 0
	LUI R15,0x7FFF ;Mask upper bit to 0
	AND R8,R8,R15 ;Mask upper bit to 0
	LLI R9,0 ;Load 0 into lower part of register
	LUI R9,0x1000 ;Load 4 into whole number (6.26 fixed point)
	BRLTEQ R9,R8,ESCAPED ;If 4 < x^2 + y^2 then branch to escape function
	BREQ R5,R0,ITERMAX ;If 64 iterations have passed, did not escape
	
	ADD R14,R3,R0
	ADD R15,R3,R0
	CALL MULTQ26 ;Square R3 (x)
	ADD R6,R14,R0

	ADD R14,R4,R0
	ADD R15,R4,R0
	CALL MULTQ26 ;Square R4
	ADD R7,R14,R0
	
	ADD R14,R3,R0
	ADD R15,R4,R0
	CALL MULTQ26 ;Multiply R3 and R4
	ADD R8,R14,R0

	SHLI R8,R8,1 ;T = X * Y * 2
	ADD R4,R8,R2 ;Y = T + Y0
	SUB R3,R6,R7 ;x = X^2 - Y^2
	ADD R3,R3,R1 ;x = x + X0
	SUBI R5,R5,1 ;I = I - 1
	JUMPREL ITERATION ;Go to top of while loop

ESCAPED:
	;CALL TX_WAIT ;Wait for UART to finish transmission
	;ADDI R8,R5,0x20 ;Add 0x20 and remaining loop count to find output character
	;SRI 0xFFF0,R8 ;Send character
	JUMPREL RESETI ;Reset iteration
ITERMAX:
	;CALL TX_WAIT ;Wait for UART to finish transmission
	;LLI R8,95 ;Load '_' as the character
	;SRI 0xFFF0,R8 ;Send underscore
	JUMPREL RESETI ;Reset iteration

TX_WAIT:
	PUSH R11
	PUSH R12
LOOP_TX:
	LRI R12,0xFFF8 ;Load status register into R12
	ANDI R11,R12,0x2 ;Mask status register to bit 1
	BRNEQ R11,R0,LOOP_TX ;If it is not 0, then loop
	POP R12
	POP R11
	RET
	
NEWLINE:
;r1 = x0
;r2 = y0
ADDI R1,R0,0 ;Set X0 to beginning of line
LUI R1,0xF800 ;^^^
LLI R15,0xf5c3 ;Set Y0 to Y0-0.05
LUI R15,0x0008 
SUB R2,R2,R15 ;Do subtraction
LLI R15,0xe148 ;Load 1.12 into R15 (6.26 fixed point)
LUI R15,0x047a ;Load 1.12 into R15 (6.26 fixed point) 
ADD R15,R15,R2
BRLT R15,R0,INFINITELOOP ;If y0 + 1.12 < 0 then infinite loop

;CALL TX_WAIT ;Wait to send character
;ADDI R8,R0,LF ;Send newline
;SRI 0xFFF0,R8 
;CALL TX_WAIT ;Wait to send character
;ADDI R8,R0,CR ;Send carraige return
;SRI 0xFFF0,R8
RET

INFINITELOOP:
	GPTIMER R1,0
	GPTIMER R2,1 ;Instruction counter
	GPTIMER R3,2 ;Cycle counter
	GPTIMER R5,0 ;Stall counter
	CALL TX_WAIT
	ADDI R4,R0,CR
	SRI 0xFFF0,R4

	CALL TX_WAIT
	ADDI R4,R0,LF
	SRI 0xFFF0,R4

	CALL TX_WAIT
	ADDI R4,R0,C
	SRI 0xFFF0,R4
	
	CALL TX_WAIT
	ADDI R4,R0,Y
	SRI 0xFFF0,R4

	CALL TX_WAIT
	ADDI R4,R0,C
	SRI 0xFFF0,R4
	
	CALL TX_WAIT
	ADDI R4,R0,COLON
	SRI 0xFFF0,R4
	
	CALL TX_WAIT
	ADDI R4,R0,SP
	SRI 0xFFF0,R4
	
	ADDI R4,R3,0
	CALL OUTPUT_COUNTER

	CALL TX_WAIT
	ADDI R4,R0,CR
	SRI 0xFFF0,R4

	CALL TX_WAIT
	ADDI R4,R0,LF
	SRI 0xFFF0,R4

	CALL TX_WAIT
	ADDI R4,R0,I
	SRI 0xFFF0,R4
	
	CALL TX_WAIT
	ADDI R4,R0,N
	SRI 0xFFF0,R4

	CALL TX_WAIT
	ADDI R4,R0,S
	SRI 0xFFF0,R4
	
	CALL TX_WAIT
	ADDI R4,R0,COLON
	SRI 0xFFF0,R4
	
	CALL TX_WAIT
	ADDI R4,R0,SP
	SRI 0xFFF0,R4
	
	ADDI R4,R2,0
	CALL OUTPUT_COUNTER
	
	CALL TX_WAIT
	ADDI R4,R0,CR
	SRI 0xFFF0,R4

	CALL TX_WAIT
	ADDI R4,R0,LF
	SRI 0xFFF0,R4

	CALL TX_WAIT
	ADDI R4,R0,S
	SRI 0xFFF0,R4
	
	CALL TX_WAIT
	ADDI R4,R0,T
	SRI 0xFFF0,R4

	CALL TX_WAIT
	ADDI R4,R0,L
	SRI 0xFFF0,R4
	
	CALL TX_WAIT
	ADDI R4,R0,COLON
	SRI 0xFFF0,R4
	
	CALL TX_WAIT
	ADDI R4,R0,SP
	SRI 0xFFF0,R4
	
	ADDI R4,R5,0
	CALL OUTPUT_COUNTER

LOOP:
	JUMPREL LOOP



MULTQ26:
	AND R13,R14,R15
	ROTLI R13,R13,1
	ANDI R13,R13,1
	BRNEQ R13,R0,FLIPSIGN ;If a[31] AND b[31] then flip sign

	LLI R13,0x0000
	LUI R13,0x8000
	AND R13,R14,R13
	BRNEQ R13,R0,FLIPA ;Invert A
	
	LLI R13,0x0000
	LUI R13,0x8000
	AND R13,R15,R13
	BRNEQ R13,R0,FLIPB ;Invert B

MULT:
        MULTW R14,R14,R15 ;Multiply R14 and R15 into R14
	RHMULT R14
	SHLI R14,R14,6
	MULTR ;Reset multiplier accumulator
        RET

FLIPSIGN:
	NOT R14,R14
	ADDI R14,R14,1
	NOT R15,R15
	ADDI R15,R15,1

	MULTW R14,R14,R15 ;Multiply R14 and R15 into R14
	RHMULT R14
	SHLI R14,R14,6
	MULTR
	RET

FLIPA:
	NOT R14,R14
	ADDI R14,R14,1

	MULTW R14,R14,R15 ;Multiply R14 and R15 into R14
	RHMULT R14
	SHLI R14,R14,6
	NOT R14,R14
	ADDI R14,R14,1
	MULTR
	RET

FLIPB:
	NOT R15,R15
	ADDI R15,R15,1

	MULTW R14,R14,R15 ;Multiply R14 and R15 into R14
	RHMULT R14
	SHLI R14,R14,6
	NOT R14,R14
	ADDI R14,R14,1
	MULTR
	RET

OUTPUT_COUNTER:
	PUSH R1
	PUSH R2
	ADDI R1,R0,31
OUTPUT_COUNTER_LOOP:
	BRNEQ R1,R0,OUTPUT_LOGIC
	POP R2
	POP R1
	RET
OUTPUT_LOGIC:
	ROTLI R4,R4,1
	ANDI R2,R4,0x1
	ADDI R2,R2,0x30
	CALL TX_WAIT
	SRI 0xFFF0,R2
	SUBI R1,R1,1
	JUMPREL OUTPUT_COUNTER_LOOP
