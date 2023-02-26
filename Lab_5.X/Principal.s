; Archivo:					    main.S
; Dispositivo:					    PIC16F887
; Autor:					    Adrian Schwendener
; Compilador:					    pic-as (v2.30), MPLABX v5.40
;
; Programa:					    Contadores de 4 bits
; Hardware:					    LEDs en el puerto A
;
; Creado:					    19 feb, 2023
; Última modificación:				    20 feb, 2023


PROCESSOR 16F887
#include <xc.inc>

; configuration word 1
 CONFIG FOSC=INTRC_NOCLKOUT			    // Oscilador Interno sin salidas
 CONFIG WDTE=OFF				    // WDT disabled (reinicio repetitivo del pic)
 CONFIG PWRTE=OFF				    // PWRT enabled (espera de 72ms al iniciar)
 CONFIG MCLRE=OFF				    // El pin de MCLR se utiliza como I/O
 CONFIG CP=OFF					    // Sin protección de código
 CONFIG CPD=OFF					    // Sin protección de datos

 CONFIG BOREN=OFF				    // Sin reinicio cuando el voltaje de alimentacién baja de 4V
 CONFIG IESO=OFF				    // Reinicio sin cambio de reloj de interno a externo
 CONFIG FCMEN=OFF				    // Cambio de reloj externo a interno en caso de fallo
 CONFIG LVP=OFF					    // Programación en bajo voltaje permitida

; configuration word 2
 
 CONFIG WRT=OFF					    // Proteccién de autoescritura por el programa desactivada
 CONFIG BOR4V=BOR40V				    // Reinicio abajo de 4V, (BOR21V=2.1V)

 PSECT udata_bank0				    ; common memory
	w_temp:			DS 1		    ; 1 byte
	s_temp:		        DS 1		    ; 1 byte
	nibble:			DS 2
	display:		DS 3
	banderas:		DS 1
	contador:		DS 1
	
	unidades:		DS 1
	decenas:		DS 1
	centenas:		DS 1
;----------------------vector reset----------------------------

 PSECT resVect, class=CODDE, abs, delta=2

ORG				00h		    ; posición 0000h para el reset

resetVec:
	PAGESEL			main
	goto			main

 PSECT code, delta=2, abs

ORG				100h		    ; posición para el código

;----------------------vector interruption----------------------------

PSECT code, class = CODE, delta = 2

ORG				0x0004
    
PUSH:
        MOVWF			w_temp		    ; guardar W en variable
        SWAPF			STATUS, 0	    ; cambiar nibles de STATUS
	MOVWF			s_temp		    ; y guardarlo en variable
	
INTERRUPT:
	BTFSC			INTCON, 0	    ; chequear bandera del PORTB
	call			bcont		    ; llamar funcion
		
	BTFSC			INTCON, 2	    ; chequear bandera tmr0
	call			display_var	    ; llamar funcion
		
POP:
	SWAPF			s_temp, 0	    ; regresar nibles del STATUS
	MOVWF			STATUS		    ; al estado original en STATUS
	SWAPF			w_temp, 1	    ; cambiar nibles del W y
	SWAPF			w_temp, 0	    ; regresarlos a W sin alterar STATUS
	RETFIE

;----------------------------tablas------------------------------
PSECT TABLA, class = code, delta=2, abs
ORG 200h    ; posición para el código

table:
	clrf			PCLATH
	bsf			PCLATH, 1
	andlw			0x0f
	addwf			PCL		    ; segun el W, elegir instruccion	    
			    ; 76543210		      mapeo
			    ;DPGFEDABC		      mapeo
	RETLW		    0B00111111		    ; 0
	RETLW		    0B00000011		    ; 1
	RETLW		    0B01011110		    ; 2
	RETLW		    0B01001111		    ; 3
	RETLW		    0B01100011		    ; 4
	RETLW		    0B01101101		    ; 5
	RETLW		    0B01111101		    ; 6
	RETLW		    0B00000111		    ; 7
	RETLW		    0B01111111		    ; 8
	RETLW		    0B01100111		    ; 9
	RETLW		    0B01110111		    ; A
	RETLW		    0B01111001		    ; B
	RETLW		    0B00111100		    ; C
	RETLW		    0B01011011		    ; D
	RETLW		    0B01111100		    ; E
	RETLW		    0B01110100		    ; F

;------------------------configuración--------------------------

main:
	BANKSEL		    ANSEL		    ; banco donde se encuentra ANSEL
	clrf		    ANSEL		    ; pines digitales
	clrf		    ANSELH
	
	BANKSEL		    TRISA		    ; banco donde se encuentra TRISA
	movlw		    0B00000111		    ; prescaler a 256
	movwf		    OPTION_REG		    
		
	movlw		    0B10101000		    ; int globales, portb y tmr0 activadas
	movwf		    INTCON
	
	movlw		    0B00000011		    ; pull up interno en B0 y B1
	movwf		    WPUB
	
	movlw		    0B00000011		    ; on-change int en B0 y B1
	movwf		    IOCB
	
	clrf		    TRISA		    ; port A, C y D como salidas
	clrf		    TRISC
	clrf		    TRISD
	movlw		    0B00000011
	movwf		    TRISB		    ; port B0 y B1 como entradas
	
	BANKSEL		    PORTA		    ; banco donde se encuentra PORTA
	movlw		    216			    ; (para 10ms)
	movwf		    TMR0
	
	clrf		    PORTA		    ; limpiar puertos al iniciar
	clrf		    PORTB
	clrf		    PORTC
	clrf		    PORTD
	
;--------------------------loop principal------------------------

loop:
	movf		    PORTA, W
	movwf		    contador
	
	call		    separar_nibbles
	call		    preparar_displays			
	
	clrf		    centenas
	clrf		    decenas
	clrf		    unidades

	call		    Centenas
	call		    Decenas
	call		    Unidades
	
	goto		    loop		    ; loop forever

;-----------------------------sub rutinas--------------------------

bcont:
	BTFSS		    PORTB, 0		    ; si se apacho B0
	incf		    PORTA, 1		    ; sumar PORTA
	
	BTFSS		    PORTB, 1		    ; si se apacho B1
	decf		    PORTA, 1		    ; restar PORTA
    	
	BCF		    INTCON, 0		    ; se limpia la bandera de int del PortB
	
	return
	
display_var:
	BCF		    INTCON, 2		    ; resetear int del tmr0
	movlw		    216
	movwf		    TMR0		    ; resetear tiempo del tmr0

	clrf		    PORTD
	
	btfsc		    banderas, 2
	goto		    display_2
	btfsc		    banderas, 1
	goto		    display_1
	btfsc		    banderas, 0
	goto		    display_0
	
	
display_0:
	movf		    display, W
	movwf		    PORTC
	bsf		    PORTD,  2
	
	bcf		    banderas, 0
	bsf		    banderas, 1
	
	return
	
display_1:
	movf		    display+1, W
	movwf		    PORTC
	bsf		    PORTD, 1
	
	bcf		    banderas, 1
	bsf		    banderas, 2
	
	return

display_2:
	movf		    display+2, W
	movwf		    PORTC
	bsf		    PORTD,  0
	
	bcf		    banderas, 2
	bsf		    banderas, 0
	
	return

Centenas:
	movlw		    100
	subwf		    contador, F
	incf		    centenas
	btfsc		    STATUS, 0
	goto		    $-4
	decf		    centenas
	movlw		    100
	addwf		    contador, F
	
	return
	
Decenas:
	movlw		    10
	subwf		    contador, F
	incf		    decenas
	btfsc		    STATUS, 0
	goto		    $-4
	decf		    decenas
	movlw		    10
	addwf		    contador, F
	
	return
    
Unidades:
	movlw		    1
	subwf		    contador, F
	incf		    unidades
	btfsc		    STATUS, 0
	goto		    $-4
	decf		    unidades
	movlw		    1
	addwf		    contador, F
	
	return
    
separar_nibbles:
	movlw		    0x0F
	andwf		    contador, W
	movwf		    nibble
	
	movlw		    0xF0
	andwf		    contador, W
	movwf		    nibble+1
	swapf		    nibble+1, F 
	
	return

preparar_displays:
	movf		    unidades, W
	call		    table
	movwf		    display
    
	movf		    decenas, W
	call		    table
	movwf		    display+1
	
	movf		    centenas, W
	call		    table
	movwf		    display+2

	return
	
END


