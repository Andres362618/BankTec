.model small
.stack 200h

.data
    ; Estructura de cuenta: 4 (ID) + 20 (nombre) + 4 (saldo) + 1 (estado)
    ; Total: 29 bytes por cuenta
    accounts db 290 dup(0) ; Espacio para 10 cuentas
    account_count dw 0 ; Cantidad de cuentas creadas, independiente del estado
    max_accounts equ 10 ; Máximo de cuentas
    account_size equ 29 ; Tamaño de estructura cuenta
    
    ; Offsets dentro de la estructura
    ID_OFFSET equ 0  ; 4 bytes
    NAME_OFFSET equ 4 ; 20 bytes
    BALANCE_OFFSET equ 24 ; 4 bytes
    STATUS_OFFSET equ 28 ; 1 byte (00=Activa, FF=Inactiva)
    
    ; Estados
    ACTIVE equ 00h
    INACTIVE equ 0FFh
    
    ; Mensajes
    ; Opciones del menú
    msg_menu db 13,10,'===== SISTEMA BANCARIO =====',13,10 
             db '1. Crear Cuenta',13,10
             db '2. Depositar dinero',13,10
             db '3. Retirar dinero',13,10
             db '4. Consultar Saldo',13,10
             db '5. Mostrar Reporte General',13,10
             db '6. Desactivar Cuenta',13,10
             db '7. Salir',13,10
             db 'Opcion: $'
    
    ; Mensajes para crear cuenta
    msg_name db 13,10,'Nombre de la cuenta: $'
    msg_balance db 'Saldo inicial: $'
    msg_id db 'ID de la cuenta: $'
    msg_success db ' cuenta creada exitosamente.',13,10,'$'
    msg_error_id db 'Error: ID ya existe o ID es inválido.',13,10,'$'
    msg_error_balance db 'Error: Saldo debe ser >= 0.',13,10,'$'
    msg_error_max db 13,10,'Error: Maximo de cuentas alcanzado.',13,10,'$'
    msg_error_not_found db 'Error: Cuenta no encontrada.',13,10,'$'
    msg_query_id db 13,10,'Ingrese ID de cuenta a consultar: $'
    msg_current_balance db 'Saldo actual: $'
    msg_account_active db ' - Cuenta Activa',13,10,'$'

    inputBuffer db 10,0,10 dup(0) ; Buffer para entrada (max 8 dígitos)
    nameBuffer db 21 dup(0) ; Buffer para nombre (20 + terminador)

    ; Mensajes para desactivar cuenta
    msg_disable_account db 13,10,'Ingrese ID de cuenta a desactivar: $'
    msg_success_disable db 'Cuenta desactivada exitosamente.',13,10,'$'

    ; Mensajes para reporte general
    msg_report_title db 13,10,'===== REPORTE GENERAL =====',13,10,'$'
    msg_report_active db 'Total de cuentas activas: $'
    msg_report_inactive db 13,10,'Total de cuentas inactivas: $'
    msg_report_total db 13,10,'Saldo total del banco: $'
    msg_report_max db 13,10,'Cuenta con mayor saldo - ID: $'
    msg_report_min db 13,10,'Cuenta con menor saldo - ID: $'
    msg_report_balance db ' | Saldo: $'
    msg_report_no_max db 13,10,'Cuenta con mayor saldo: N/A$'
    msg_report_no_min db 13,10,'Cuenta con menor saldo: N/A$'
    msg_newline db 13,10,'$'

    ; Variables auxiliares para reporte
    report_active_count dw 0
    report_inactive_count dw 0

    report_total_low dw 0
    report_total_high dw 0

    report_max_id_low dw 0
    report_max_id_high dw 0
    report_max_balance_low dw 0
    report_max_balance_high dw 0

    report_min_id_low dw 0
    report_min_id_high dw 0
    report_min_balance_low dw 0
    report_min_balance_high dw 0

    ; Mensajes para depositar y retirar
    msg_deposit_account db 13,10,'Ingrese ID de cuenta para depositar: $'
    msg_withdraw_account db 13,10,'Ingrese ID de cuenta para retirar: $'
    msg_deposit_amount db 13,10,'Monto a depositar: $'
    msg_withdraw_amount db 13,10,'Monto a retirar: $'
    msg_error_inactive db 'Error: Cuenta inactiva.',13,10,'$'
    msg_error_too_much_on_account db 'Error: Saldo excede el límite.',13,10,'$'
    msg_success_deposit db 'Depósito exitoso.',13,10,'$'
    msg_success_withdraw db 'Retiro exitoso.',13,10,'$'

.code

; ============================================================================
; PROCEDIMIENTO: leer_string
; Entrada: DI = offset del buffer donde guardar la cadena
; Salida: buffer lleno con la cadena ingresada (terminada en 0)
; Nota: Permite edición básica (backspace) y limita a 16 caracteres
; ============================================================================

leer_string proc
    push ax
    push bx
    push cx
    push dx
    push si
    xor cx, cx

read_loop:
    mov ah, 01h
    int 21h

    cmp al, 13 
    je read_done
    cmp al, 8
    je read_back

    cmp cx, 19
    jge read_loop

    mov [di], al
    inc di
    inc cx
    jmp read_loop

read_back:
    cmp cx, 0
    je read_loop
    dec di
    dec cx
    jmp read_loop

read_done:
    mov al, 0
    mov [di], al

    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
leer_string endp

; ============================================================================
; PROCEDIMIENTO: leer_numero_id
; Salida: DX:AX = número leído
; Nota: Convierte ASCII a número
; ============================================================================

leer_numero_id proc
    push bx
    push cx
    push di
    push si
    
    mov di, offset inputBuffer
    call leer_string
    
    xor ax, ax
    xor dx, dx
    mov si, offset inputBuffer
    
convert_loop:
    xor cx, cx
    mov cl, [si] 
    cmp cl, 0 
    je convert_done
    
    cmp cl, '0' 
    jl convert_error
    cmp cl, '9'
    jg convert_error
    
    sub cl, '0' ; Convierte ASCII a número


    

    push ax ; Guardar parte baja del número antes de multiplicar
    ; Multiplicar parte alta por 10
    mov ax, dx
    mov bx, 10
    mul bx
    mov dx, ax ; Parte alta = parte alta * 10
    pop ax ; Recuperar parte baja
    push dx ; Guardar parte alta antes de multiplicar parte baja
    mul bx ; Parte baja = parte baja * 10
    add ax, cx ; AX += dígito
    pop bx ; Recuperar parte alta del número
    adc dx, bx ; Suma con carry para parte alta

    jc convert_error ; Si hay overflow, error
    
    inc si
    jmp convert_loop
    
convert_error:
    mov ax, 0 ; Retorna 0 si error
    mov dx, 0
    jmp convert_done
    
convert_done:
    pop si
    pop di
    pop cx
    pop bx
    ret
leer_numero_id endp

; ============================================================================
; PROCEDIMIENTO: leer_numero_saldo
; Salida: DX:AX = número leído
; Nota: Convierte ASCII a número
; ============================================================================

leer_numero_saldo proc
    push bx
    push cx
    push di
    push si
    
    mov di, offset inputBuffer
    call leer_string
    
    xor ax, ax
    xor dx, dx
    mov si, offset inputBuffer
    
convert_loop_saldo:
    xor cx, cx
    mov cl, [si] 
    cmp cl, 0 
    je convert_decimal
    
    cmp cl, '.'
    je skip_decimal_point
    cmp cl, '0' 
    jl convert_error_saldo
    cmp cl, '9'
    jg convert_error_saldo
    

    sub cl, '0' ; Convierte ASCII a número    

    push ax ; Guardar parte baja del número antes de multiplicar
    ; Multiplicar parte alta por 10
    mov ax, dx
    mov bx, 10
    mul bx
    mov dx, ax ; Parte alta = parte alta * 10
    pop ax ; Recuperar parte baja
    push dx ; Guardar parte alta antes de multiplicar parte baja
    mul bx ; Parte baja = parte baja * 10
    add ax, cx ; AX += dígito
    pop bx ; Recuperar parte alta del número
    adc dx, bx ; Suma con carry para parte alta

    jc convert_error_saldo ; Si hay overflow, error
    
    inc si
    jmp convert_loop_saldo

skip_decimal_point:
    inc si ; Saltar el punto decimal
convert_decimal:
    ; Leer parte decimal (hasta 4 dígitos)
    xor cx, cx
    mov cx, 0 ; Contador de dígitos decimales
decimal_loop:
    push cx ; Guardar contador de decimales
    xor cx, cx
    mov cl, [si] 
    cmp cl, 0 
    jne not_end_of_decimal
    mov cl, '0' ; Si es el final de la cadena, tratamos como '0' para los decimales faltantes
    dec si ; No avanzamos el puntero para que el próximo ciclo vuelva a leer el mismo byte (que es 0)
    
not_end_of_decimal:
    cmp cl, '0' 
    jl convert_error_saldo_decimal
    cmp cl, '9'
    jg convert_error_saldo_decimal
    
    sub cl, '0' ; Convierte ASCII a número

    push ax ; Guardar parte baja del número antes de multiplicar
    ; Multiplicar parte alta por 10
    mov ax, dx
    mov bx, 10
    mul bx
    mov dx, ax ; Parte alta = parte alta * 10
    pop ax ; Recuperar parte baja
    push dx ; Guardar parte alta antes de multiplicar parte baja
    mul bx ; Parte baja = parte baja * 10
    add ax, cx ; AX += dígito
    pop bx ; Recuperar parte alta del número
    adc dx, bx ; Suma con carry para parte alta

    jc convert_error_saldo_decimal ; Si hay carry, error
    
    pop cx ; Recuperar contador de decimales
    inc cx
    inc si
    cmp cx, 4 ; Solo permitimos hasta 4 dígitos decimales
    jl decimal_loop
    jmp convert_done_saldo

convert_error_saldo_decimal:
    pop ax ; Limpiar contador de decimales de la pila
convert_error_saldo:
    mov ax, 0 ; Retorna 0 si error
    mov dx, 0
    jmp convert_done_saldo
    
convert_done_saldo:
    pop si
    pop di
    pop cx
    pop bx
    ret
leer_numero_saldo endp



; ============================================================================
; PROCEDIMIENTO: imprimir_numero_id
; Entrada: DX:AX = número a imprimir
; Nota: Convierte número a ASCII
; ============================================================================

imprimir_numero_id proc
    push ax
    push bx
    push cx
    push dx
    
    
    mov cx, 0
    
divide_loop:
    push dx ; Guarda parte alta antes de dividir
    mov bx, 10
    div bx ; Parte baja = parte baja / 10, residuo en DX
    pop bx ; Recupera parte alta
    push dx ; Guarda residuo
    push ax ; Guarda parte baja antes de dividir
    mov ax, bx ; Carga parte alta en AX para parte alta / 10
    mov bx, 10
    xor dx, dx ; Limpia DX antes de dividir
    div bx 
    push ax ; Guarda parte alta después de dividir
    mov ax, dx ; Carga residuo en AX para convertir a dígito
    mov bx, 010000d
    mul bx ; Multiplica el dígito por 10 para sumarlo a la parte alta
    pop bx ; Recupera parte alta después de multiplicar el dígito
    pop ax ; Recupera parte baja original
    add ax, dx ; Suma el residuo para obtener el dígito actual
    mov dx, bx ; Actualiza parte alta con el resultado de la división

    inc cx
    cmp dx, 0
    jne divide_loop
    cmp ax, 0
    jne divide_loop
    
print_loop:
    pop ax
    add al, '0' ; Convierte a ASCII
    mov dl, al
    mov ah, 02h ; INT 21h función 02 = imprimir carácter
    int 21h
    loop print_loop
    
    pop dx
    pop cx
    pop bx
    pop ax
    ret
imprimir_numero_id endp

; ============================================================================
; PROCEDIMIENTO: imprimir_numero_saldo
; Entrada: DX:AX = número a imprimir con formato decimal (4 dígitos decimales)
; Nota: Convierte número a ASCII
; ============================================================================

imprimir_numero_saldo proc
    push ax
    push bx
    push cx
    push dx
    push si
    
    
    xor si, si ; Contador de digitos apilados
    
divide_loop_saldo:
    push ax ; Guardar parte baja original
    mov ax, dx ; Dividir parte alta entre 10
    xor dx, dx
    mov bx, 10
    div bx ; AX = cociente alto, DX = residuo alto
    mov cx, ax ; Guardar nuevo high word
    pop ax ; Recuperar parte baja original
    div bx ; Divide (residuo_alto:parte_baja) entre 10
    push dx ; Guardar digito (residuo final)
    mov dx, cx ; Actualizar high word del cociente

    inc si
    cmp dx, 0
    jne divide_loop_saldo
    cmp ax, 0
    jne divide_loop_saldo
    
padding_loop:
    cmp si, 5 ; Asegura que siempre haya 1 entero + 4 decimales
    jge print_loop_saldo
    mov ax, 0
    push ax ; Rellenar con ceros a la izquierda
    inc si
    
    jmp padding_loop

print_loop_saldo:
    cmp si, 4 ; Imprimir punto decimal antes de 4 digitos finales
    jne print_digit
    mov dl, '.'
    mov ah, 02h ; INT 21h función 02 = imprimir carácter
    int 21h

print_digit:
    pop ax
    add al, '0' ; Convierte a ASCII
    mov dl, al
    mov ah, 02h ; INT 21h función 02 = imprimir carácter
    int 21h
    dec si
    jnz print_loop_saldo
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
imprimir_numero_saldo endp



; ============================================================================
; PROCEDIMIENTO: buscar_cuenta
; Entrada: DX:AX = ID de cuenta
; Salida: SI = offset de la cuenta en memoria, CF = 0 si encontrado
; ============================================================================

buscar_cuenta proc
    push ax
    push bx
    push cx
    push dx

    mov si, offset accounts
    xor cx, cx ; contador de cuentas

search_loop:
    cmp cx, [account_count]
    jge search_not_found

    mov bx, [si + ID_OFFSET]
    cmp bx, ax
    jne next_entry
    mov bx, [si + ID_OFFSET + 2]   
    cmp bx, dx
    jne next_entry

    clc
    jmp search_end

next_entry:
    add si, account_size
    inc cx
    jmp search_loop

search_not_found:
    stc

search_end:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
buscar_cuenta endp

; ============================================================================
; PROCEDIMIENTO: validar_id_unico
; Entrada: DX:AX = ID a validar
; Salida: CF = 0 si único (OK), CF = 1 si duplicado
; ============================================================================

validar_id_unico proc
    push ax
    push bx
    push cx
    push dx
    push si

    mov si, offset accounts
    xor cx, cx          ; contador de cuentas
    ; DX debe contener la parte alta del ID (0 si ID <= 0xFFFF)

check_loop:
    cmp cx, [account_count]
    jge check_unique

    mov bx, [si + ID_OFFSET]        ; low word
    cmp bx, ax
    jne next_check
    mov bx, [si + ID_OFFSET + 2]    ; high word
    cmp bx, dx
    jne next_check

    ; Duplicado
    stc
    jmp check_end

next_check:
    add si, account_size
    inc cx
    jmp check_loop

check_unique:
    clc

check_end:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
validar_id_unico endp

; ============================================================================
; PROCEDIMIENTO: crear_cuenta
; Entrada: BX:AX = ID, DI = buffer nombre, DX:CX = saldo
; Salida: CF = 0 si éxito, CF = 1 si error, AX = código de error (1=max cuentas, 2=ID duplicado, 3=saldo negativo)
; ============================================================================

crear_cuenta proc
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Guardar saldo en la pila
    push dx ; Guardar parte alta del saldo
    push cx ; Guardar parte baja del saldo
    

    ; Guardar el ID en la pila
    push bx ; Guardar parte alta del ID
    push ax ; Guardar parte baja del ID

    ; Validación 1: Número máximo de cuentas
    mov bx, [account_count]
    cmp bx, max_accounts
    jge crear_error_max
    
    ; Validación 2: ID no es cero
    cmp ax, 0
    jne continue_validations
    cmp dx, 0
    je crear_error_id

continue_validations:
    ; Validación 3: ID no repetido
    call validar_id_unico
    jc crear_error_id

    

    ; Calcular offset en memoria
    mov si, offset accounts
    mov bx, [account_count]
    mov ax, bx
    mov bx, account_size
    mul bx
    add si, ax

    ; Recuperar el ID original
    pop dx ; Parte baja del ID
    mov [si + ID_OFFSET], dx
    pop dx ; Parte alta del ID
    mov [si + ID_OFFSET + 2], dx

    mov bx, di
    mov di, si
    add di, NAME_OFFSET
    xor dx, dx ;

copy_name_loop:
    mov al, [bx]
    cmp al, 0
    je copy_done
    cmp dx, 20
    jge copy_done

    mov [di], al
    inc bx
    inc di
    inc dx
    jmp copy_name_loop

copy_done:
    ; Rellenar espacios (si es necesario)
    cmp dx, 20
    jge skip_spaces

fill_spaces:
    mov al, ' '
    mov [di], al
    inc di
    inc dx
    cmp dx, 20
    jl fill_spaces

skip_spaces:
    pop cx ; Recuperar parte baja del saldo
    pop dx ; Recuperar parte alta del saldo
    mov [si + BALANCE_OFFSET], cx
    mov [si + BALANCE_OFFSET + 2], dx
    
    mov al, ACTIVE
    mov [si + STATUS_OFFSET], al
    
    inc [account_count]
    
    clc 
    jmp crear_end
    
crear_error_max:
    pop ax ; Limpiar parte baja del ID de la pila
    pop ax ; Limpiar parte alta del ID de la pila
    pop ax ; Limpiar parte baja del saldo de la pila
    pop ax ; Limpiar parte alta del saldo de la pila
    xor ax, ax
    mov al, 1
    stc
    jmp crear_end
    
crear_error_id:
    pop ax ; Limpiar parte baja del ID de la pila
    pop ax ; Limpiar parte alta del ID de la pila
    pop ax ; Limpiar parte baja del saldo de la pila
    pop ax ; Limpiar parte alta del saldo de la pila    
    xor ax, ax
    mov al, 2 ; código de error: ID duplicado
    stc
    jmp crear_end
    
crear_error_balance:
    pop ax ; Limpiar parte baja del ID de la pila
    pop ax ; Limpiar parte alta del ID de la pila
    pop ax ; Limpiar parte baja del saldo de la pila
    pop ax ; Limpiar parte alta del saldo de la pila
    xor ax, ax
    mov al, 3 ; código de error: saldo negativo
    stc

crear_end:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    ret
crear_cuenta endp

; ============================================================================
; PROCEDIMIENTO: consultar_saldo
; Entrada: DX:AX = ID de cuenta a buscar
; Salida: DX:AX = saldo, CF = 0 si encontrado
; ============================================================================

consultar_saldo proc
    push bx
    push cx
    push si
    
    call buscar_cuenta 
    jc consultar_error
    
    ; Si encontrado, SI ya apunta a la cuenta
    mov ax, [si + BALANCE_OFFSET]
    mov dx, [si + BALANCE_OFFSET + 2]
    clc
    jmp consultar_end
    
consultar_error:
    stc
    
consultar_end:
    pop si
    pop cx
    pop bx
    ret
consultar_saldo endp

; ============================================================================
; PROCEDIMIENTO: procesar_crear_cuenta
; Entrada: ninguna
; Salida: ninguna
; Nota: Maneja menú y ciclos para crear cuenta
; ============================================================================

procesar_crear_cuenta proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Verificar límite de cuentas
    mov bx, [account_count]
    cmp bx, max_accounts
    jl crear_proseguir

    mov ah, 09h
    mov dx, offset msg_error_max
    int 21h
    jmp crear_fin

crear_proseguir:

    ; Imprimir "Nombre: "
    mov ah, 09h 
    mov dx, offset msg_name
    int 21h
    
    ; Leer nombre
    mov di, offset nameBuffer
    call leer_string
    
    ; Imprimir "ID: "
    mov ah, 09h
    mov dx, offset msg_id
    int 21h
    
    ; Leer ID
    call leer_numero_id
    push ax
    push dx ; Guardar ID para validación posterior


    
    ; Imprimir "Saldo: "
    mov ah, 09h
    mov dx, offset msg_balance
    int 21h
    
    ; Leer saldo
    call leer_numero_saldo
    mov cx, ax ; Guardar saldo en DX:CX
    
    ; Llamar crear_cuenta con validaciones
    pop bx ; Recuperar parte alta del ID para crear_cuenta
    pop ax ; Recuperar parte baja del ID para crear_cuenta
    mov di, offset nameBuffer
    call crear_cuenta
    jc crear_fallido
    
    ; Éxito: imprimir mensaje
    mov ah, 09h
    mov dx, offset msg_success
    int 21h
    jmp crear_fin
    
crear_fallido:
    ; Determinar cuál fue el error
    cmp al, 1
    je mostrar_error_max
    cmp al, 3
    je mostrar_error_balance
    ; por defecto: ID duplicado

mostrar_error_id:
    mov ah, 09h
    mov dx, offset msg_error_id
    int 21h
    jmp fin_error

mostrar_error_max:
    mov ah, 09h
    mov dx, offset msg_error_max
    int 21h
    jmp fin_error

mostrar_error_balance:
    mov ah, 09h
    mov dx, offset msg_error_balance
    int 21h

fin_error:

crear_fin:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
procesar_crear_cuenta endp


; ============================================================================
; PROCEDIMIENTO: procesar_depositar
; Entrada: ninguna
; Salida: ninguna
; Nota: 
; ============================================================================
procesar_depositar proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    ; Imprimir "Ingrese ID: "
    mov ah, 09h
    mov dx, offset msg_deposit_account
    int 21h
    ; Leer ID
    call leer_numero_id
    call buscar_cuenta
    jc cuenta_no_encontrada

    ; Verificar que la cuenta esté activa
    mov al, [si + STATUS_OFFSET]
    cmp al, ACTIVE
    jne cuenta_no_encontrada

    ; Leer monto a depositar
    mov ah, 09h
    mov dx, offset msg_deposit_amount
    int 21h
    call leer_numero_saldo

    ; Verificar que el nuevo saldo no exceda 0xFFFFFFFF
    mov bx, [si + BALANCE_OFFSET] ; saldo actual (low word)
    mov cx, [si + BALANCE_OFFSET + 2] ; saldo actual (high word)
    
    add ax, bx ; nuevo saldo low
    adc dx, cx ; nuevo saldo high (considera carry)   

    jc depositar_fallido ; Si hay carry, falla (saldo > 0xFFFFFFFF)


depositar_exito:
    mov [si + BALANCE_OFFSET], ax
    mov [si + BALANCE_OFFSET + 2], dx 

    mov ah, 09h
    mov dx, offset msg_success_deposit
    int 21h
    jmp fin_depositar

depositar_fallido:
    mov ah, 09h
    mov dx, offset msg_error_too_much_on_account
    int 21h
    jmp fin_depositar

cuenta_no_encontrada:
    mov ah, 09h
    mov dx, offset msg_error_not_found
    int 21h
    
fin_depositar:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    ret
procesar_depositar endp


; ============================================================================
; PROCEDIMIENTO: procesar_retirar
; Entrada: ninguna
; Salida: ninguna
; Nota: 
; ============================================================================
procesar_retirar proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    ; Imprimir "Ingrese ID: "
    mov ah, 09h
    mov dx, offset msg_withdraw_account
    int 21h
    ; Leer ID
    call leer_numero_id
    call buscar_cuenta
    jc cuenta_no_encontrada_retirar

    ; Verificar que la cuenta esté activa
    mov al, [si + STATUS_OFFSET]
    cmp al, ACTIVE
    jne cuenta_no_encontrada_retirar

    ; Leer monto a retirar
    mov ah, 09h
    mov dx, offset msg_withdraw_amount
    int 21h
    call leer_numero_saldo

    mov bx, [si + BALANCE_OFFSET] ; saldo actual (low word)
    mov cx, [si + BALANCE_OFFSET + 2] ; saldo actual (high word)
    
    sub bx, ax ; nuevo saldo low
    sbb cx, dx ; nuevo saldo high (considera borrow)   

    jo retirar_fallido ; Si hay overflow, falla
    jc retirar_fallido ; Si hay carry, falla (saldo > 0xFFFFFFFF)


retirar_exito:
    mov [si + BALANCE_OFFSET], bx
    mov [si + BALANCE_OFFSET + 2], cx
    
    mov ah, 09h
    mov dx, offset msg_success_withdraw
    int 21h
    jmp fin_retirar

retirar_fallido:
    mov ah, 09h
    mov dx, offset msg_error_too_much_on_account
    int 21h
    jmp fin_retirar

cuenta_no_encontrada_retirar:
    mov ah, 09h
    mov dx, offset msg_error_not_found
    int 21h
    
fin_retirar:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax

    ret
procesar_retirar endp

; ============================================================================
; PROCEDIMIENTO: procesar_consultar_saldo
; Entrada: ninguna
; Salida: ninguna
; Nota: Busca cuenta por ID y muestra saldo
; ============================================================================
procesar_consultar_saldo proc
    push ax
    push bx
    push cx
    push dx
    
    ; Imprimir "Ingrese ID: "
    mov ah, 09h
    mov dx, offset msg_query_id
    int 21h
    
    ; Leer ID
    call leer_numero_id

    ; Buscar and consultar
    call consultar_saldo
    jc consultar_fallido
    
    ; Éxito: mostrar saldo
    push ax
    push dx
    mov ah, 09h
    mov dx, offset msg_current_balance
    int 21h
    pop dx
    pop ax
    call imprimir_numero_saldo 

    mov ah, 09h
    mov dx, offset msg_account_active
    int 21h
    jmp consultar_fin
    
consultar_fallido:
    mov ah, 09h
    mov dx, offset msg_error_not_found
    int 21h
    
consultar_fin:
    pop dx
    pop cx
    pop bx
    pop ax
    ret
procesar_consultar_saldo endp

; ============================================================================
; PROCEDIMIENTO: procesar_mostrar_reporte
; Entrada: ninguna
; Salida: ninguna
; Nota: Recorre todas las cuentas creadas y muestra el reporte general
; ============================================================================
procesar_mostrar_reporte proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Inicializar acumuladores y contadores
    mov word ptr [report_active_count], 0
    mov word ptr [report_inactive_count], 0
    mov word ptr [report_total_low], 0
    mov word ptr [report_total_high], 0

    ; Mostrar título
    mov ah, 09h
    mov dx, offset msg_report_title
    int 21h

    ; Si no hay cuentas creadas, mostrar reporte vacío
    mov cx, [account_count]
    cmp cx, 0
    jne reporte_con_datos

    ; Activas = 0
    mov ah, 09h
    mov dx, offset msg_report_active
    int 21h
    xor dx, dx
    xor ax, ax
    call imprimir_numero_id

    ; Inactivas = 0
    mov ah, 09h
    mov dx, offset msg_report_inactive
    int 21h
    xor dx, dx
    xor ax, ax
    call imprimir_numero_id

    ; Total = 0.0000
    mov ah, 09h
    mov dx, offset msg_report_total
    int 21h
    xor dx, dx
    xor ax, ax
    call imprimir_numero_saldo

    ; No hay mayor ni menor
    mov ah, 09h
    mov dx, offset msg_report_no_max
    int 21h

    mov ah, 09h
    mov dx, offset msg_report_no_min
    int 21h

    mov ah, 09h
    mov dx, offset msg_newline
    int 21h
    jmp reporte_fin

reporte_con_datos:
    mov si, offset accounts

    ; Inicializar mayor y menor con la primera cuenta
    mov ax, [si + ID_OFFSET]
    mov [report_max_id_low], ax
    mov [report_min_id_low], ax

    mov ax, [si + ID_OFFSET + 2]
    mov [report_max_id_high], ax
    mov [report_min_id_high], ax

    mov ax, [si + BALANCE_OFFSET]
    mov [report_max_balance_low], ax
    mov [report_min_balance_low], ax

    mov ax, [si + BALANCE_OFFSET + 2]
    mov [report_max_balance_high], ax
    mov [report_min_balance_high], ax

    mov cx, [account_count]
    mov si, offset accounts

reporte_loop:
    ; Contar activas e inactivas
    cmp byte ptr [si + STATUS_OFFSET], ACTIVE
    je cuenta_activa

    inc word ptr [report_inactive_count]
    jmp estado_listo

cuenta_activa:
    inc word ptr [report_active_count]

estado_listo:
    ; Cargar saldo actual en DX:AX
    mov ax, [si + BALANCE_OFFSET]
    mov dx, [si + BALANCE_OFFSET + 2]

    ; Acumular saldo total
    add word ptr [report_total_low], ax
    adc word ptr [report_total_high], dx

    ; Comparar con mayor saldo
    mov bx, [report_max_balance_high]
    cmp dx, bx
    ja actualizar_max
    jb revisar_min

    mov bx, [report_max_balance_low]
    cmp ax, bx
    ja actualizar_max

revisar_min:
    ; Comparar con menor saldo
    mov bx, [report_min_balance_high]
    cmp dx, bx
    jb actualizar_min
    ja siguiente_cuenta

    mov bx, [report_min_balance_low]
    cmp ax, bx
    jb actualizar_min
    jmp siguiente_cuenta

actualizar_max:
    mov [report_max_balance_low], ax
    mov [report_max_balance_high], dx

    mov bx, [si + ID_OFFSET]
    mov [report_max_id_low], bx
    mov bx, [si + ID_OFFSET + 2]
    mov [report_max_id_high], bx
    jmp siguiente_cuenta

actualizar_min:
    mov [report_min_balance_low], ax
    mov [report_min_balance_high], dx

    mov bx, [si + ID_OFFSET]
    mov [report_min_id_low], bx
    mov bx, [si + ID_OFFSET + 2]
    mov [report_min_id_high], bx

siguiente_cuenta:
    add si, account_size
    loop reporte_loop

    ; =========================
    ; Imprimir resultados
    ; =========================

    ; Total de activas
    mov ah, 09h
    mov dx, offset msg_report_active
    int 21h
    xor dx, dx
    mov ax, [report_active_count]
    call imprimir_numero_id

    ; Total de inactivas
    mov ah, 09h
    mov dx, offset msg_report_inactive
    int 21h
    xor dx, dx
    mov ax, [report_inactive_count]
    call imprimir_numero_id

    ; Saldo total del banco
    mov ah, 09h
    mov dx, offset msg_report_total
    int 21h
    mov ax, [report_total_low]
    mov dx, [report_total_high]
    call imprimir_numero_saldo

    ; Cuenta con mayor saldo
    mov ah, 09h
    mov dx, offset msg_report_max
    int 21h
    mov ax, [report_max_id_low]
    mov dx, [report_max_id_high]
    call imprimir_numero_id

    mov ah, 09h
    mov dx, offset msg_report_balance
    int 21h
    mov ax, [report_max_balance_low]
    mov dx, [report_max_balance_high]
    call imprimir_numero_saldo

    ; Cuenta con menor saldo
    mov ah, 09h
    mov dx, offset msg_report_min
    int 21h
    mov ax, [report_min_id_low]
    mov dx, [report_min_id_high]
    call imprimir_numero_id

    mov ah, 09h
    mov dx, offset msg_report_balance
    int 21h
    mov ax, [report_min_balance_low]
    mov dx, [report_min_balance_high]
    call imprimir_numero_saldo

    mov ah, 09h
    mov dx, offset msg_newline
    int 21h

reporte_fin:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
procesar_mostrar_reporte endp


; ============================================================================
; PROCEDIMIENTO: procesar_desactivar_cuenta
; Entrada: ninguna
; Salida: ninguna
; Nota: Busca una cuenta por ID y la marca como inactiva
; ============================================================================
procesar_desactivar_cuenta proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Pedir ID de la cuenta
    mov ah, 09h
    mov dx, offset msg_disable_account
    int 21h

    ; Leer ID
    call leer_numero_id

    ; Buscar cuenta
    call buscar_cuenta
    jc desactivar_no_encontrada

    ; Verificar si ya está inactiva
    mov al, [si + STATUS_OFFSET]
    cmp al, INACTIVE
    je desactivar_ya_inactiva

    ; Cambiar estado a inactiva
    mov byte ptr [si + STATUS_OFFSET], INACTIVE

    ; Mensaje de éxito
    mov ah, 09h
    mov dx, offset msg_success_disable
    int 21h
    jmp desactivar_fin

desactivar_ya_inactiva:
    mov ah, 09h
    mov dx, offset msg_error_inactive
    int 21h
    jmp desactivar_fin

desactivar_no_encontrada:
    mov ah, 09h
    mov dx, offset msg_error_not_found
    int 21h

desactivar_fin:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
procesar_desactivar_cuenta endp

; ============================================================================
; PROCEDIMIENTO PRINCIPAL
; ============================================================================
main:
    mov ax, @data
    mov ds, ax
    
    mov ax, @data
    mov es, ax
    
main_loop:
    ; Mostrar menú
    mov ah, 09h
    mov dx, offset msg_menu
    int 21h
    
    ; Leer opción
    mov ah, 01h
    int 21h

    cmp al, '1'
    je opcion_crear
    cmp al, '2'
    je opcion_depositar
    cmp al, '3'
    je opcion_retirar
    cmp al, '4'
    je opcion_consultar
    cmp al, '5'
    je opcion_reporte
    cmp al, '6'
    je opcion_desactivar
    cmp al, '7'
    je opcion_salir
    
    jmp main_loop

opcion_crear:
    call procesar_crear_cuenta
    jmp main_loop
    
opcion_depositar:
    call procesar_depositar
    jmp main_loop

opcion_retirar:
    call procesar_retirar
    jmp main_loop

opcion_consultar:
    call procesar_consultar_saldo
    jmp main_loop

opcion_reporte:
    call procesar_mostrar_reporte
    jmp main_loop

opcion_desactivar:
    call procesar_desactivar_cuenta
    jmp main_loop
    
opcion_salir:
    mov ah, 4Ch
    mov al, 0
    int 21h
    
end main