IOY0 EQU 3000H
AD0809 EQU IOY0 + 00H
INTR_IVADD EQU 01C8H
INTR_OCW1 EQU 0A1H
INTR_OCW2 EQU 0A0H
INTR_IM EQU 0FBH

IOY1 EQU 3040H  ;片选 I0Y1 对应的端口始地址
MY8255_A EQU IOY1 + 00H * 4 ;8255 的 A 口地址
MY8255_B EQU IOY1 + 01H * 4 ;8255 的 B 口地址
MY8255_C EQU IOY1 + 02H * 4 ;8255 的 C 口地址
MY8255_MODE EQU IOY1 + 03H * 4 ;8255 的控制寄存器地址
DATA SEGMENT
CS_BAK DW ?
IP_BAK DW ?
IM_BAK DB ?
AFTER_FILT DB 1
TEMP DB 10 DUP(0)
TABLE DB 3FH,06H,5BH,4FH,66H,6DH,7DH,07H,7FH,6FH
STRI DB  "AD0809:INO $"
BEFORE_FILT DB 10 DUP(0)
DATA ENDS

STACKI SEGMENT STACK
DW 256 DUP (?)
STACKI ENDS


;函数段
CODE4FUNCTION SEGMENT
    ASSUME CS:CODE4FUNCTION,DS:DATA,SS:STACKI
START0:
DISPLAY7SEG PROC FAR ;将存储在AFTER_FILT的滤波后数据处理,实现数据转化为十进制,并显示S
PUSH AX
PUSH BX
PUSH CX
PUSH DX
PUSH SI
PUSH DI
PUSH BP

MOV AL, AFTER_FILT ;将8位二进制数转化为3位10进制数
MOV DL, 10
MOV CX, 3
MOV DI, -1
DIVMOD:LEA SI, TEMP
INC DI
DIV DL
ADD SI, DI
MOV [SI],AH
LOOP DIVMOD


MOV AL, 0FEH ;1111 1110
MOV CX, 3
L1:
PUSH DX
PUSH AX
MOV DX, MY8255_A
OUT DX, AL
CALL DISPLAY_NUMBER
ROL AL, 1
POP AX
POP DX
LOOP L1

POP BP
POP DI
POP SI
POP DX
POP CX
POP BX
POP AX
RET 
DISPLAY7SEG ENDP


DISPLAY_NUMBER PROC ;从TEMP列表中取10进制数,实现数字的显示,同时不破坏
MOV CX ,1000H
MOV DI, -1
SHOW_A_DIGIT:INC DI
LEA SI, TEMP
ADD SI, DI
MOV AL, [SI] ;AL为一个十进制数字
LEA BX, TABLE
MOV AH, 0
ADD BX, AX
MOV AL, [BX]
MOV DX,MY8255_B
OUT DX,AL
RET
DISPLAY_NUMBER ENDP


CODE4FUNCTION ENDS
END START0




CODE SEGMENT
ASSUME CS:CODE, DS:DATA
START :
MOV DX ,MY8255_MODE
MOV AL ,80H
OUT DX, AL
MOV AX , DATA
MOV DS , AX


;配置中断
CLI
MOV AX, 0000H
MOV ES, AX
MOV DI, INTR_IVADD
MOV AX, ES:[DI]
MOV IP_BAK, AX
MOV AX , OFFSET MYISR
MOV ES:[DI] , AX
ADD DI, 2
MOV AX , ES :[CDI]
MOV CS_BAK , AX
MOV AX , SEG MYISR
MOV ES:[DI] , AX
MOV DX, INTR_OCW1
IN AL, DX
MOV IM_BAK, AL
AND AL, INTR_IM
OUT DX, AL
STI



WAIT1:
MOV CX, 10 ;采样10次
MOV SI, -1
LOOPI : LEA BX, BEFORE_FILT
INC SI
MOV DX , AD0809
OUT DX , AL
CALL DALLY
MOV DX, OFFSET STR1
MOV AH , 9
INT 21H
MOV DX , AD0809
IN AL , DX
ADD BX, SI
MOV [BX], AL
LOOP LOOPI
CALL FILTER

MOV AL, AFTER_FILT
CMP AL, 8FH
JNB INTERRUPT

PUSH CX  ;数码管显示
MOV CX, 65535
SHOW:
CALL FAR PTR DISPLAY7SEG
LOOP SHOW
POP CX

MOV AL, AFTER_FILT
MOV CH , AL
AND AL , 0F0H
MOV CL , 04H
SHR AL , CL
CMP AL , 09H
JG A1
ADD AL , 30H
JMP A2
A1:ADD AL , 37H
A2 :
MOV DL , AL
MOV AH , 02H
INT 21H
MOV AL, CH
AND AL , 0FH
CMP AL , 09H
JG A3
ADD AL, 30H
JMP A4
A3:
ADD AL, 37H
A4:MOV DL , AL
MOV AH , 02H
INT 21H
MOV DL , 0DH
MOV AH , 02H
INT 21H
MOV AH , 1
INT 16H
JZ LOOPI
QUIT: MOV X , 4C00H
INT 21H


DALLY PROC NEAR ;延时程序
PUSH CX
PUSH AX
MOV CX , 4000H
D1:MOV AX , 0600H
D2:DEC AX
JNZ D2
LOOP DI
POP AX
POP CX
RET
DALLY ENDP

INTERRUPT:
CLI
MOV AX, 0000H
MOV ES, AX
MOV DI , INTR_IVADD
MOV AX , IP_BAK
MOV ES:[DI] , AX
ADD DI , 2
MOV AX , CS_BAK
MOV ES:[DI] , AX
MOV DX , INTR_OCW1
MOV AL , IM_BAK
OUT DX , AL
STI
MOV DL, 21H
MOV AL, 05H
INT 21H
MOV AX, 4C00H ;返回DOS界面
INT 21H




FILTER PROC NEAR ;10次取平均数
PUSH CX
PUSH AX 
PUSH BX
PUSH DX
MOV DX, BEFORE_FILT
MOV CX, 10
MOV AX, -1

LOOP_FILTER:
LEA BX, BEFORE_FILT
INC AX
ADD BX, AX
ADD DX, [BX]
SHR DX, 1
LOOP LOOP_FILTER
MOV AFTER_FILT,DX

POP DX
POP BX
POP AX
POP CX
RET
FILTER ENDP



CODE ENDS

END START