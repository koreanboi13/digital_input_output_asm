.org $000
  JMP reset

.org INT0addr
   JMP INT0_HANDLER
.org INT1addr
   JMP INT1_HANDLER

.def TMP = R18
.def OP = R19    ;используется как счетчик циклов
.def FLAG = R20
.def _X= R22 
.def _Y = R23
.def INVERT_Y = R21
.def _Z = R24
.def NULL = R25

reset:
  ; настройка исходных значений
   CLR NULL ; 0x00
   CLR OP ; 0x00

  ; настройка портов ввода-вывода
   SER TMP ; 0xFF
   OUT DDRA, TMP ; Вывод
   OUT DDRB, TMP ; Вывод

   CLR TMP
   OUT DDRC, TMP  ;Ввод
   ;OUT PORTC, TMP  
  
   LDI  TMP, 0b01110011
   OUT DDRD, TMP  ; PD7,PD2, PD3 - ВВОД ,  остальное вывод 

   OUT PORTD, NULL   ; просто занулить покайфу
   SBI PORTD,  4  ;установка начального значения x на 1
   
   LDI _X,  0x1 ;
   LDI _Y, 0x73      ; 0111.0011
   LDI INVERT_Y, 0x8C  ; 1000.1100

  ; Установка вершины стека в конец ОЗУ
   LDI TMP, HIGH(RAMEND) ; Старшие разряды адреса
   OUT SPH, TMP
   LDI TMP, LOW(RAMEND) ; Младшие разряды адреса
   OUT SPL, TMP


   LDI _Z, 2
   LDI R16, 0
   LDI R17, 0
   MOV TMP, _Z
   RCALL EEPROM_write
  

   LDI R16, 0    ; Загружаем адрес первой ячейки
   LDI R17, 0    ; EEPROM 
   RCALL  EEPROM_read   ; вызываем процедуру чтения.
   MOV _Z, TMP
   CALL INT_ON

LOOP:
  OUT PORTA, _Y
  OUT PORTB , INVERT_Y
  CALL PORTD_OUT

  SBIC PIND,7
  CALL read_number

  TST _X ; Если _X = 0 тогда мы не переходим в offset, чтоб огонек стоял на месте 
  IN TMP,SREG
  SBRS TMP,1 
  CALL offset
  
  LDI FLAG, 3
  LDI OP, 4
   
  CPSE _Z, FLAG 
  MOV OP, _Z

DELAY_LOOP:
  
  CALL delay
  DEC OP
  BRNE DELAY_LOOP

  JMP LOOP 



PORTD_OUT:
  CLR TMP
  OUT PORTD,TMP

  SBRC _Z,1
  SBI PORTD,1
  SBRC _Z ,0 
  SBI PORTD,0

  SBRC _X, 7
  SBI PORTD,6 
  CPI _X, -3  
  BREQ OUT_THREE
  CPI _X, 3
  BREQ OUT_THREE
  CPI _X, -2  
  BREQ OUT_TWO
  CPI _X, 2
  BREQ OUT_TWO

  CPI _X, -1 
  BREQ OUT_ONE
  CPI _X, 1
  BREQ OUT_ONE
   RET

OUT_ONE:
  SBI PORTD, 4
  CBI PORTD, 5
  RET

OUT_TWO:
  CBI PORTD, 4
  SBI PORTD, 5
  RET

OUT_THREE:
  SBI PORTD, 4
  SBI PORTD, 5
  RET 


INT_ON:
  LDI TMP, 0x0F   ; 0000.1111(ЕСЛИ ЧТО ПОМЕНЯТЬ НА 0A)
  OUT MCUCR, TMP   ; Настройка прерываний int0 и int1 на условие 0/1
  LDI TMP, 0xC0   ; 1100.0000
  OUT GICR, TMP   ; Разрешение прерываний int0 и int1
  CLR TMP
  OUT GIFR, TMP   ;   Предотвращение срабатывания int0 и int1 при включении прерываний
  SEI
  RET


read_number:    ; считывание операнда
  SBIS PIND, 7    ; Пропуск следующей команды, если бит в порту установлен
  RET
  
  IN TMP, PINC
  CP TMP, NULL    ; PINC = 0?
  breq read_number ; если PINC = 0 считывание операции

read_PORTC:
  call delay    ; ожидание нажатия комбинации кнопок
  IN TMP, PINC
  CP TMP, NULL
  breq stop_reading 
  mov _Y, TMP
  SER TMP      ; 0xFF
  mov INVERT_Y, _Y
  EOR INVERT_Y,TMP  ; ислючающее или
  jmp read_PORTC


stop_reading:        ; обеспечение однократного ввода
  SBIS PIND, 7    ; Пропуск следующей команды, если бит в порту установлен
  RET
  JMP stop_reading


EEPROM_read:  
  SBIC EECR, EEWE    ; Ждем пока будет завершена прошлая запись.
  RJMP EEPROM_read      ; также крутимся в цикле.
  OUT EEARL, R16    ; загружаем адрес нужной ячейки
  OUT EEARH, R17     ; его старшие и младшие байты
  SBI EECR, EERE     ; Выставляем бит чтения
  IN TMP, EEDR     ; Забираем из регистра данных результат

  RET

EEPROM_write:  
  SBIC EECR,EEWE    ; Ждем готовности памяти к записи. Крутимся в цикле
  RJMP EEPROM_Write     ; до тех пор пока не очистится флаг EEWE
  ;CLI          ; Затем запрещаем прерывания.
  OUT EEARL, R16     ; Загружаем адрес нужной ячейки
  OUT EEARH, R17      ; старший и младший байт адреса
  OUT EEDR, TMP     ; и сами данные, которые нам нужно загрузить
  SBI EECR, EEMWE    ; взводим предохранитель
  SBI EECR, EEWE    ; записываем байт
  ;SEI         ; разрешаем прерывания
  RET

INT0_HANDLER:
   INC _X
   LDI TMP, 4
   CPSE _X, TMP
   RETI
   LDI _X, -3
   RETI

   
INT1_HANDLER:
   INC _Z


   LDI R16, 0
   LDI R17, 0
   MOV TMP, _Z
   RCALL EEPROM_write

   LDI TMP, 4
   CPSE _Z, TMP
   RETI

   LDI _Z, 1 

   LDI R16, 0
   LDI R17, 0
   MOV TMP, _Z
   RCALL EEPROM_write

   RETI


offset:
    MOV TMP,_Y
	MOV FLAG,TMP
    MOV OP, _X
    SBRC _X, 7  ; если 3 бит = 0 пропуск след команды
    CALL LEFT_RUNNER
    SBRS _X, 7  ; если 3 бит = 1 пропуск след команды
    CALL RIGHT_RUNNER
	MOV _Y, TMP


	MOV TMP, INVERT_Y
	MOV FLAG,TMP
	MOV OP, _X
	SBRC _X, 7  ; если 3 бит = 0 пропуск след команды
	CALL LEFT_RUNNER
	SBRS _X, 7  ; если 3 бит = 1 пропуск след команды
	CALL RIGHT_RUNNER
	MOV INVERT_Y, TMP

  
	RET
;Потестить мб керри флаг все руинит если че на две функции
 LEFT_RUNNER:  
  ROL FLAG
  ROL TMP
  INC OP
  BRNE LEFT_RUNNER
  RET
  

RIGHT_RUNNER:
  ROR FLAG
  ROR TMP
  DEC OP
  BRNE RIGHT_RUNNER
  RET


delay: ; задержка 0.25 мс
   LDI R31, 10
   LDI R30, 111
   LDI R29, 11

delay_sub:
   DEC R29
   BRNE delay_sub
   DEC R30
   BRNE delay_sub
   DEC R31
   BRNE delay_sub
   NOP
   RET
