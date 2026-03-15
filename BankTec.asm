.model small
.stack 200h

.data
    ; Estructura de cuenta: 4 (ID) + 20 (nombre) + 4 (saldo) + 1 (estado)
    ; Total: 29 bytes por cuenta
    accounts db 290 dup(0) ; Espacio para 10 cuentas
    account_count dw 0 ; Cantidad de cuentas activas
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
             db '2. Consultar Saldo',13,10 
             db '3. Salir',13,10
             db 'Opcion: $'
    
    ; Mensajes para crear cuenta
    msg_name db 13,10,'Nombre de la cuenta: $'
    msg_balance db 'Saldo inicial: $'
    msg_id db 'ID de la cuenta: $'
    msg_success db ' cuenta creada exitosamente.',13,10,'$'
    msg_error_id db 'Error: ID ya existe.',13,10,'$'
    msg_error_balance db 'Error: Saldo debe ser >= 0.',13,10,'$'
    msg_error_max db 13,10,'Error: Maximo de cuentas alcanzado.',13,10,'$'
    msg_error_not_found db 'Error: Cuenta no encontrada.',13,10,'$'
    msg_query_id db 13,10,'Ingrese ID de cuenta a consultar: $'
    msg_current_balance db 'Saldo actual: $'
    msg_account_active db ' - Cuenta Activa',13,10,'$'
    
    inputBuffer db 10,0,10 dup(0) ; Buffer para entrada (max 8 dígitos)
    nameBuffer db 21 dup(0) ; Buffer para nombre (20 + terminador)

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
; PROCEDIMIENTO: leer_numero
; Salida: AX = número leído
; Nota: Convierte ASCII a número
; ============================================================================

leer_numero proc
    push bx
    push cx
    push dx
    push di
    push si
    
    mov di, offset inputBuffer
    call leer_string
    
    xor ax, ax
    mov si, offset inputBuffer
    
convert_loop:
    mov cl, [si] 
    cmp cl, 0 
    je convert_done
    
    cmp cl, '0' 
    jl convert_error
    cmp cl, '9'
    jg convert_error
    
    sub cl, '0' ; Convierte ASCII a número
    mov dx, ax
    mov bx, 10
    mul bx ; AX = AX * 10
    add al, cl ; AX += dígito
    
    inc si
    jmp convert_loop
    
convert_error:
    mov ax, 0 ; Retorna 0 si error
    
convert_done:
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    ret
leer_numero endp

; ============================================================================
; PROCEDIMIENTO: imprimir_numero
; Entrada: AX = número a imprimir
; Nota: Convierte número a ASCII
; ============================================================================

imprimir_numero proc
    push ax
    push bx
    push cx
    push dx
    
    mov bx, 10
    mov cx, 0
    
divide_loop:
    xor dx, dx
    div bx
    push dx ; Guarda residuo
    inc cx
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
imprimir_numero endp

; ============================================================================
; PROCEDIMIENTO: buscar_cuenta
; Entrada: AX = ID de cuenta
; Salida: SI = offset de la cuenta en memoria, CF = 0 si encontrado
; ============================================================================

buscar_cuenta proc
    push ax
    push bx
    push cx
    push dx

    mov si, offset accounts
    xor cx, cx
    xor dx, dx

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
; Entrada: AX = ID a validar
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
; Entrada: AX = ID, DI = buffer nombre, CX = saldo
; Salida: CF = 0 si éxito, CF = 1 si error
; ============================================================================

crear_cuenta proc
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Validación 1: Número máximo de cuentas
    mov bx, [account_count]
    cmp bx, max_accounts
    jge crear_error_max
    
    ; Validación 2: ID no repetido
    xor dx, dx
    call validar_id_unico
    jc crear_error_id
    
    ; Validación 3: Saldo >= 0
    cmp cx, 0
    jl crear_error_balance

    ; Guardar el ID en la pila
    push ax

    ; Calcular offset en memoria
    mov si, offset accounts
    mov bx, [account_count]
    mov ax, bx
    mov bx, account_size
    mul bx
    add si, ax

    ; Recuperar el ID original
    pop dx

    mov [si + ID_OFFSET], dx
    mov word ptr [si + ID_OFFSET + 2], 0 

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
    mov [si + BALANCE_OFFSET], cx
    mov word ptr [si + BALANCE_OFFSET + 2], 0 
    
    mov al, ACTIVE
    mov [si + STATUS_OFFSET], al
    
    inc [account_count]
    
    clc 
    jmp crear_end
    
crear_error_max:
    mov al, 1
    stc
    jmp crear_end
    
crear_error_id:
    mov al, 2 ; código de error: ID duplicado
    stc
    jmp crear_end
    
crear_error_balance:
    mov al, 3 ; código de error: saldo negativo
    stc

crear_end:
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret
crear_cuenta endp

; ============================================================================
; PROCEDIMIENTO: consultar_saldo
; Entrada: AX = ID de cuenta a buscar
; Salida: AX = saldo, CF = 0 si encontrado
; ============================================================================

consultar_saldo proc
    push bx
    push cx
    push si
    
    call buscar_cuenta 
    jc consultar_error
    
    ; Si encontrado, SI ya apunta a la cuenta
    mov ax, [si + BALANCE_OFFSET]
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
    call leer_numero
    mov bx, ax ; Guardar ID en BX
    
    ; Imprimir "Saldo: "
    mov ah, 09h
    mov dx, offset msg_balance
    int 21h
    
    ; Leer saldo
    call leer_numero
    mov cx, ax ; Guardar saldo en CX
    
    ; Llamar crear_cuenta con validaciones
    mov ax, bx
    xor dx, dx
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
    call leer_numero
    xor dx, dx

    ; Buscar and consultar
    call consultar_saldo
    jc consultar_fallido
    
    ; Éxito: mostrar saldo
    push ax
    mov ah, 09h
    mov dx, offset msg_current_balance
    int 21h
    pop ax

    call imprimir_numero 

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
    je opcion_consultar
    cmp al, '3'
    je opcion_salir
    
    jmp main_loop
    
opcion_crear:
    call procesar_crear_cuenta
    jmp main_loop
    
opcion_consultar:
    call procesar_consultar_saldo
    jmp main_loop
    
opcion_salir:
    mov ah, 4Ch
    mov al, 0
    int 21h
    
end main