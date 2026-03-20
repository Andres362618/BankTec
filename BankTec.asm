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
    ACTIVE equ 00h ; Cuenta activa
    INACTIVE equ 0FFh ; Cuenta inactiva
    
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

leer_string proc ; DI = offset del buffer
    push ax ; Guardar registros usados
    push bx ; Guardar registros usados
    push cx ; Guardar registros usados
    push dx ; Guardar registros usados
    push si ; Guardar registros usados
    xor cx, cx ; Contador de caracteres ingresados

read_loop: ; Lee un carácter
    mov ah, 01h ; INT 21h función 01 = leer carácter
    int 21h ; Carácter leído en AL

    cmp al, 13 ; Enter
    je read_done  
    cmp al, 8 ; Backspace
    je read_back

    cmp cx, 19 ; Limite de 20 caracteres (0-19)
    jge read_loop ; Si se excede el límite, ignora el carácter

    mov [di], al ; Guarda el carácter en el buffer
    inc di ; Mueve el puntero del buffer
    inc cx ; Incrementa el contador de caracteres
    jmp read_loop ; Continúa leyendo el siguiente carácter

read_back: ; Maneja backspace
    cmp cx, 0 ; Si no hay caracteres para borrar, ignora
    je read_loop ; Si hay caracteres, borra el último
    dec di ; Mueve el puntero del buffer hacia atrás
    dec cx ; Decrementa el contador de caracteres
    jmp read_loop ; Continúa leyendo el siguiente carácter

read_done: ; Termina la cadena con un byte 0
    mov al, 0 ; Carácter nulo para terminar la cadena
    mov [di], al ; Termina la cadena

    pop si ; Recuperar registros usados
    pop dx ; Recuperar registros usados
    pop cx ; Recuperar registros usados
    pop bx ; Recuperar registros usados
    pop ax ; Recuperar registros usados
    ret
leer_string endp ; Fin de leer_string

; ============================================================================
; PROCEDIMIENTO: leer_numero_id
; Salida: DX:AX = número leído
; Nota: Convierte ASCII a número
; ============================================================================

leer_numero_id proc ; Salida: DX:AX = número leído
    push bx ; Guardar registros usados
    push cx ; Guardar registros usados
    push di ; Guardar registros usados
    push si ; Guardar registros usados
    
    mov di, offset inputBuffer ; Configura DI para apuntar al buffer de entrada
    call leer_string ; Lee la cadena de entrada al buffer
     
    xor ax, ax ; Limpia AX para acumular el número
    xor dx, dx ; Limpia DX para acumular la parte alta del número (si es necesario)
    mov si, offset inputBuffer ; Configura SI para recorrer el buffer de entrada
    
convert_loop: ; Lee cada carácter y conviértelo a número
    xor cx, cx ; Limpia CX para usarlo como registro temporal
    mov cl, [si]  ; Lee el siguiente carácter del buffer
    cmp cl, 0  ; Si es el final de la cadena, termina la conversión
    je convert_done ; Si no es un dígito válido, error
    
    cmp cl, '0' ; Verifica que el carácter sea un dígito
    jl convert_error ; Si es menor que '0', error
    cmp cl, '9' ; Verifica que el carácter sea un dígito
    jg convert_error ; Si es mayor que '9', error
    
    sub cl, '0' ; Convierte ASCII a número

    push ax ; Guardar parte baja del número antes de multiplicar

    mov ax, dx ; Multiplicar parte alta por 10
    mov bx, 10 ; Multiplicador
    mul bx ; AX = parte alta * 10, resultado en DX:AX
    mov dx, ax ; Parte alta = parte alta * 10
    pop ax ; Recuperar parte baja
    push dx ; Guardar parte alta antes de multiplicar parte baja
    mul bx ; Parte baja = parte baja * 10
    add ax, cx ; AX += dígito
    pop bx ; Recuperar parte alta del número
    adc dx, bx ; Suma con carry para parte alta

    jc convert_error ; Si hay overflow, error
    
    inc si ; Avanza al siguiente carácter
    jmp convert_loop ; Continúa el ciclo para el siguiente carácter
    
convert_error: ; Si hay un error de conversión, retorna 0
    mov ax, 0 ; Retorna 0
    mov dx, 0 ; Retorna 0
    jmp convert_done ; Salta a la limpieza y retorno
    
convert_done: ; Limpia la pila y retorna con el número en DX:AX
    pop si ; Recuperar registros usados
    pop di ; Recuperar registros usados
    pop cx ; Recuperar registros usados
    pop bx ; Recuperar registros usados
    ret
leer_numero_id endp ; Fin de leer_numero_id

; ============================================================================
; PROCEDIMIENTO: leer_numero_saldo
; Salida: DX:AX = número leído
; Nota: Convierte ASCII a número
; ============================================================================

leer_numero_saldo proc ; Salida: DX:AX = número leído
    push bx ; Guardar registros usados
    push cx ; Guardar registros usados
    push di ; Guardar registros usados
    push si ; Guardar registros usados
    
    mov di, offset inputBuffer ; Configura DI para apuntar al buffer de entrada
    call leer_string ; Lee la cadena de entrada al buffer
    
    xor ax, ax ; Limpia AX para acumular la parte baja del número
    xor dx, dx ; Limpia DX para acumular la parte alta del número (si es necesario)
    mov si, offset inputBuffer ; Configura SI para recorrer el buffer de entrada
    
convert_loop_saldo: ; Lee cada carácter y conviértelo a número, manejando el punto decimal
    xor cx, cx ; Limpia CX para usarlo como registro temporal
    mov cl, [si] ; Lee el siguiente carácter del buffer
    cmp cl, 0 ; Si es el final de la cadena, termina la conversión
    je convert_decimal ; Si no es un dígito válido o un punto decimal, error
    
    cmp cl, '.' ; Verifica si es el punto decimal
    je skip_decimal_point ; Si es un punto decimal, salta a la parte decimal
    cmp cl, '0'  ; Verifica que el carácter sea un dígito
    jl convert_error_saldo ; Si es menor que '0', error
    cmp cl, '9' ; Verifica que el carácter sea un dígito
    jg convert_error_saldo ; Si es mayor que '9', error
    

    sub cl, '0' ; Convierte ASCII a número    

    push ax ; Guardar parte baja del número antes de multiplicar
    mov ax, dx ; Multiplicar parte alta por 10
    mov bx, 10 ; Multiplicador
    mul bx ; AX = parte alta * 10, resultado en DX:AX
    mov dx, ax ; Parte alta = parte alta * 10
    pop ax ; Recuperar parte baja
    push dx ; Guardar parte alta antes de multiplicar parte baja
    mul bx ; Parte baja = parte baja * 10
    add ax, cx ; AX += dígito
    pop bx ; Recuperar parte alta del número
    adc dx, bx ; Suma con carry para parte alta

    jc convert_error_saldo ; Si hay overflow, error
    
    inc si ; Avanza al siguiente carácter
    jmp convert_loop_saldo ; Continúa el ciclo para el siguiente carácter

skip_decimal_point: ; Si es un punto decimal, salta a la parte decimal
    inc si ; Saltar el punto decimal

convert_decimal: ; Si se encuentra un punto decimal, ahora se procesan los dígitos decimales
    ; Leer parte decimal (hasta 4 dígitos)
    xor cx, cx ; Limpia CX para usarlo como contador de dígitos decimales
    mov cx, 0 ; Contador de dígitos decimales

decimal_loop: ; Lee cada dígito decimal y conviértelo a número
    push cx ; Guardar contador de decimales
    xor cx, cx ; Limpia CX para usarlo como registro temporal
    mov cl, [si]  ; Lee el siguiente carácter del buffer
    cmp cl, 0 ; Si es el final de la cadena, tratamos como '0' para los decimales faltantes
    jne not_end_of_decimal ; Si no es el final de la cadena, verifica que sea un dígito válido
    mov cl, '0' ; Si es el final de la cadena, tratamos como '0' para los decimales faltantes
    dec si ; No avanzamos el puntero para que el próximo ciclo vuelva a leer el mismo byte (que es 0)
    
not_end_of_decimal: ; Verifica que el carácter sea un dígito
    cmp cl, '0' ; Verifica que el carácter sea un dígito
    jl convert_error_saldo_decimal ; Si es menor que '0', error
    cmp cl, '9' ; Verifica que el carácter sea un dígito
    jg convert_error_saldo_decimal ; Si es mayor que '9', error
    
    sub cl, '0' ; Convierte ASCII a número

    push ax ; Guardar parte baja del número antes de multiplicar
    mov ax, dx ; Multiplicar parte alta por 10
    mov bx, 10 ; Multiplicador
    mul bx ; AX = parte alta * 10, resultado en DX:AX
    mov dx, ax ; Parte alta = parte alta * 10
    pop ax ; Recuperar parte baja
    push dx ; Guardar parte alta antes de multiplicar parte baja
    mul bx ; Parte baja = parte baja * 10
    add ax, cx ; AX += dígito
    pop bx ; Recuperar parte alta del número
    adc dx, bx ; Suma con carry para parte alta

    jc convert_error_saldo_decimal ; Si hay carry, error
    
    pop cx ; Recuperar contador de decimales
    inc cx ; Incrementa contador de dígitos decimales
    inc si ; Avanza al siguiente carácter
    cmp cx, 4 ; Solo permitimos hasta 4 dígitos decimales
    jl decimal_loop ; Continúa el ciclo para el siguiente dígito decimal
    jmp convert_done_saldo ; Si se ingresan más de 4 dígitos decimales, ignoramos el resto

convert_error_saldo_decimal: ; Si hay un error de conversión en la parte decimal, retorna 0
    pop ax ; Limpiar contador de decimales de la pila
convert_error_saldo: ; Si hay un error de conversión, retorna 0
    mov ax, 0 ; Retorna 0 si error
    mov dx, 0 ; Retorna 0 si error
    jmp convert_done_saldo ; Salta a la limpieza y retorno
    
convert_done_saldo: ; Limpia la pila y retorna con el número en DX:AX
    pop si ; Recuperar registros usados
    pop di ; Recuperar registros usados
    pop cx ; Recuperar registros usados
    pop bx ; Recuperar registros usados
    ret
leer_numero_saldo endp ; Fin de leer_numero_saldo

; ============================================================================
; PROCEDIMIENTO: imprimir_numero_id
; Entrada: DX:AX = número a imprimir
; Nota: Convierte número a ASCII
; ============================================================================

imprimir_numero_id proc ; Entrada: DX:AX = número a imprimir
    push ax ; Guardar registros usados
    push bx ; Guardar registros usados
    push cx ; Guardar registros usados
    push dx ;
    
    mov cx, 0 ; Contador de dígitos impresos
    
divide_loop:
    push dx ; Guarda parte alta antes de dividir
    mov bx, 10 ; Divisor para obtener el dígito menos significativo
    div bx ; Parte baja = parte baja / 10, residuo en DX
    pop bx ; Recupera parte alta
    push dx ; Guarda residuo
    push ax ; Guarda parte baja antes de dividir
    mov ax, bx ; Carga parte alta en AX para parte alta / 10
    mov bx, 10 ; Divisor para obtener el siguiente dígito
    xor dx, dx ; Limpia DX antes de dividir
    div bx ; Parte alta = parte alta / 10, residuo en DX
    push ax ; Guarda parte alta después de dividir
    mov ax, dx ; Carga residuo en AX para convertir a dígito
    mov bx, 010000d ; Multiplicador para reconstruir el número original
    mul bx ; Multiplica el dígito por 10 para sumarlo a la parte alta
    pop bx ; Recupera parte alta después de multiplicar el dígito
    pop ax ; Recupera parte baja original
    add ax, dx ; Suma el residuo para obtener el dígito actual
    mov dx, bx ; Actualiza parte alta con el resultado de la división

    inc cx ; Incrementa el contador de dígitos impresos
    cmp dx, 0 ; Si la parte alta aún tiene dígitos, continúa dividiendo
    jne divide_loop ; Si la parte alta es 0, verifica si la parte baja aún tiene dígitos
    cmp ax, 0 ; Si la parte baja aún tiene dígitos, continúa dividiendo
    jne divide_loop ; Si ambos son 0, termina la división
    
print_loop: ; Imprime los dígitos en orden inverso (del último al primero)
    pop ax ; Recupera el dígito actual
    add al, '0' ; Convierte a ASCII
    mov dl, al ; Prepara el dígito para imprimir
    mov ah, 02h ; INT 21h función 02 = imprimir carácter
    int 21h ; Imprime el dígito
    loop print_loop ; Repite hasta que se hayan impreso todos los dígitos
    
    pop dx ; Recuperar registros usados
    pop cx ; Recuperar registros usados
    pop bx ; Recuperar registros usados
    pop ax ; Recuperar registros usados
    ret
imprimir_numero_id endp ; Fin de imprimir_numero_id

; ============================================================================
; PROCEDIMIENTO: imprimir_numero_saldo
; Entrada: DX:AX = número a imprimir con formato decimal (4 dígitos decimales)
; Nota: Convierte número a ASCII
; ============================================================================

imprimir_numero_saldo proc ; Entrada: DX:AX = número a imprimir con formato decimal (4 dígitos decimales)
    push ax ; Guardar registros usados
    push bx ; Guardar registros usados
    push cx ; Guardar registros usados
    push dx ; Guardar registros usados
    push si ; Guardar registros usados
    
    
    xor si, si ; Contador de digitos apilados
    
divide_loop_saldo:
    push ax ; Guardar parte baja original
    mov ax, dx ; Dividir parte alta entre 10
    xor dx, dx ; Limpia DX antes de dividir
    mov bx, 10 ; Divisor para obtener el dígito menos significativo
    div bx ; AX = cociente alto, DX = residuo alto
    mov cx, ax ; Guardar nuevo high word
    pop ax ; Recuperar parte baja original
    div bx ; Divide (residuo_alto:parte_baja) entre 10
    push dx ; Guardar digito (residuo final)
    mov dx, cx ; Actualizar high word del cociente

    inc si ; Incrementa el contador de dígitos apilados
    cmp dx, 0 ; Si la parte alta aún tiene dígitos, continúa dividiendo
    jne divide_loop_saldo ; Si la parte alta es 0, verifica si la parte baja aún tiene dígitos
    cmp ax, 0 ; Si la parte baja aún tiene dígitos, continúa dividiendo
    jne divide_loop_saldo ; Si ambos son 0, termina la división
    
padding_loop: ; Imprime ceros a la izquierda si es necesario para asegurar formato decimal
    cmp si, 5 ; Asegura que siempre haya 1 entero + 4 decimales
    jge print_loop_saldo ; Si ya hay suficientes dígitos, comienza a imprimir
    mov ax, 0 ; Rellenar con ceros a la izquierda
    push ax ; Rellenar con ceros a la izquierda
    inc si ; Incrementa el contador de dígitos apilados
    
    jmp padding_loop ; Continúa el ciclo de padding hasta tener suficientes dígitos

print_loop_saldo: ; Imprime los dígitos en orden inverso (del último al primero)
    cmp si, 4 ; Imprimir punto decimal antes de 4 digitos finales
    jne print_digit ; Si no es el momento de imprimir el punto decimal, imprime el dígito
    mov dl, '.' ; Imprime el punto decimal
    mov ah, 02h ; INT 21h función 02 = imprimir carácter
    int 21h ; Imprime el punto decimal

print_digit: ; Imprime el dígito actual
    pop ax ; Recupera el dígito actual
    add al, '0' ; Convierte a ASCII
    mov dl, al ; Prepara el dígito para imprimir
    mov ah, 02h ; INT 21h función 02 = imprimir carácter
    int 21h ; Imprime el dígito
    dec si ; Decrementa el contador de dígitos apilados
    jnz print_loop_saldo ; Repite hasta que se hayan impreso todos los dígitos
    
    pop si ; Recuperar registros usados
    pop dx ; Recuperar registros usados
    pop cx ; Recuperar registros usados
    pop bx ; Recuperar registros usados
    pop ax ; Recuperar registros usados
    ret 
imprimir_numero_saldo endp ; Fin de imprimir_numero_saldo

; ============================================================================
; PROCEDIMIENTO: buscar_cuenta
; Entrada: DX:AX = ID de cuenta
; Salida: SI = offset de la cuenta en memoria, CF = 0 si encontrado
; ============================================================================

buscar_cuenta proc ; Entrada: DX:AX = ID de cuenta
    push ax ; Guardar registros usados
    push bx ; Guardar registros usados
    push cx ; Guardar registros usados
    push dx ; Guardar registros usados

    mov si, offset accounts ; Configura SI para recorrer el arreglo de cuentas
    xor cx, cx ; contador de cuentas

search_loop: ; Recorre las cuentas buscando el ID
    cmp cx, [account_count] ; Si se han revisado todas las cuentas, termina la búsqueda
    jge search_not_found ; Si no se ha encontrado el ID, CF = 1

    mov bx, [si + ID_OFFSET] ; Carga parte baja del ID de la cuenta actual
    cmp bx, ax ; Compara con parte baja del ID buscado
    jne next_entry ; Si no coincide, pasa a la siguiente cuenta
    mov bx, [si + ID_OFFSET + 2] ; Carga parte alta del ID de la cuenta actual
    cmp bx, dx ; Compara con parte alta del ID buscado
    jne next_entry ; Si no coincide, pasa a la siguiente cuenta

    clc ; Si se encuentra el ID, CF = 0 y SI ya apunta a la cuenta
    jmp search_end ; Termina la búsqueda

next_entry: ; Si no coincide, pasa a la siguiente cuenta
    add si, account_size ; Mueve SI al siguiente registro de cuenta
    inc cx ; Incrementa el contador de cuentas
    jmp search_loop ; Continúa buscando

search_not_found: ; Si no se encuentra el ID, CF = 1
    stc

search_end: ; Limpia la pila y retorna con SI apuntando a la cuenta (si encontrada) o sin cambios (si no encontrada)
    pop dx ; Recuperar registros usados
    pop cx ; Recuperar registros usados
    pop bx ; Recuperar registros usados
    pop ax ; Recuperar registros usados
    ret
buscar_cuenta endp ; Fin de buscar_cuenta

; ============================================================================
; PROCEDIMIENTO: validar_id_unico
; Entrada: DX:AX = ID a validar
; Salida: CF = 0 si único (OK), CF = 1 si duplicado
; ============================================================================

validar_id_unico proc ; Entrada: DX:AX = ID a validar
    push ax ; Guardar registros usados
    push bx ; Guardar registros usados
    push cx ; Guardar registros usados
    push dx ; Guardar registros usados
    push si ; Guardar registros usados

    mov si, offset accounts ; Configura SI para recorrer el arreglo de cuentas
    xor cx, cx ; contador de cuentas

check_loop: ; Recorre las cuentas buscando el ID
    cmp cx, [account_count] ; Si se han revisado todas las cuentas, el ID es único
    jge check_unique ; Si no se ha encontrado el ID, CF = 0

    mov bx, [si + ID_OFFSET] ; Carga parte baja del ID de la cuenta actual
    cmp bx, ax ; Compara con parte baja del ID a validar
    jne next_check ; Si no coincide, pasa a la siguiente cuenta
    mov bx, [si + ID_OFFSET + 2] ; Carga parte alta del ID de la cuenta actual
    cmp bx, dx ; Compara con parte alta del ID a validar
    jne next_check ; Si no coincide, pasa a la siguiente cuenta

    ; Duplicado
    stc ; Si se encuentra el ID, CF = 1
    jmp check_end ; Termina la validación

next_check: ; Si no coincide, pasa a la siguiente cuenta
    add si, account_size ; Mueve SI al siguiente registro de cuenta
    inc cx ; Incrementa el contador de cuentas
    jmp check_loop; Continúa buscando

check_unique: ; Si se revisaron todas las cuentas y no se encontró el ID, es único
    clc ; CF = 0

check_end: ; Limpia la pila y retorna con CF indicando si el ID es único o no
    pop si ; Recuperar registros usados
    pop dx ; Recuperar registros usados
    pop cx ; Recuperar registros usados
    pop bx ; Recuperar registros usados
    pop ax ; Recuperar registros usados
    ret
validar_id_unico endp ; Fin de validar_id_unico

; ============================================================================
; PROCEDIMIENTO: crear_cuenta
; Entrada: BX:AX = ID, DI = buffer nombre, DX:CX = saldo
; Salida: CF = 0 si éxito, CF = 1 si error, AX = código de error (1=max cuentas, 2=ID duplicado, 3=saldo negativo)
; ============================================================================

crear_cuenta proc ; Entrada: BX:AX = ID, DI = buffer nombre, DX:CX = saldo
    push bx ; Guardar parte alta del ID
    push cx ; Guardar parte baja del saldo
    push dx ; Guardar parte alta del saldo
    push si ; Guardar registros usados
    push di ; Guardar registros usados
    
    ; Guardar saldo en la pila
    push dx ; Guardar parte alta del saldo
    push cx ; Guardar parte baja del saldo
    

    ; Guardar el ID en la pila
    push bx ; Guardar parte alta del ID
    push ax ; Guardar parte baja del ID

    ; Validación 1: Número máximo de cuentas
    mov bx, [account_count] ; Carga el número actual de cuentas
    cmp bx, max_accounts ; Compara con el máximo permitido
    jge crear_error_max ; Si se ha alcanzado el máximo, CF = 1 y código de error 1
    
    ; Validación 2: ID no es cero
    cmp ax, 0 ; Compara parte baja del ID con 0
    jne continue_validations ; Si parte baja no es 0, continúa con la siguiente validación
    cmp dx, 0 ; Compara parte alta del ID con 0
    je crear_error_id ; Si ambas partes del ID son 0, es inválido, CF = 1 y código de error 2

continue_validations: ; Si el ID no es cero, continúa con la siguiente validación

    ; Validación 3: ID no repetido
    call validar_id_unico ; Si el ID no es único, CF = 1 y código de error 2
    jc crear_error_id ; Si el ID es único, continúa con la siguiente validación 

    ; Calcular offset en memoria
    mov si, offset accounts ; Configura SI para apuntar al inicio del arreglo de cuentas
    mov bx, [account_count] ; Carga el número actual de cuentas
    mov ax, bx ; Multiplica el número de cuentas por el tamaño de cada cuenta para obtener el offset
    mov bx, account_size ; Tamaño de cada cuenta
    mul bx ; AX = offset en bytes para la nueva cuenta
    add si, ax ; SI ahora apunta al lugar donde se debe crear la nueva cuenta

    ; Recuperar el ID original
    pop dx ; Parte baja del ID
    mov [si + ID_OFFSET], dx ; Guardar parte baja del ID en la cuenta
    pop dx ; Parte alta del ID
    mov [si + ID_OFFSET + 2], dx ; Guardar parte alta del ID en la cuenta

    mov bx, di ; BX apunta al buffer del nombre ingresado
    mov di, si ; DI apunta al inicio de la cuenta en memoria
    add di, NAME_OFFSET ; Mueve DI al offset del nombre dentro de la cuenta
    xor dx, dx ; Contador de caracteres copiados para el nombre

copy_name_loop: ; Copia el nombre del buffer a la cuenta, asegurando no exceder 20 caracteres
    mov al, [bx] ; Lee el siguiente carácter del nombre
    cmp al, 0 ; Si es el final de la cadena, termina de copiar
    je copy_done ; Si no es el final de la cadena, verifica que no se exceda el límite de 20 caracteres
    cmp dx, 20 ; Verifica que no se exceda el límite de 20 caracteres para el nombre
    jge copy_done ; Si se excede el límite, termina de copiar

    mov [di], al ; Copia el carácter al campo de nombre de la cuenta
    inc bx ; Avanza al siguiente carácter del nombre
    inc di ; Avanza al siguiente byte en el campo de nombre de la cuenta
    inc dx ; Incrementa el contador de caracteres copiados
    jmp copy_name_loop ; Continúa copiando el siguiente carácter del nombre

copy_done:
    ; Rellenar espacios (si es necesario)
    cmp dx, 20 ; Verifica si se copiaron menos de 20 caracteres para el nombre
    jge skip_spaces ; Si ya se copiaron 20 caracteres, no es necesario rellenar espacios

fill_spaces: ; Rellena con espacios el resto del campo de nombre si se copiaron menos de 20 caracteres
    mov al, ' ' ; Carácter de espacio para rellenar
    mov [di], al ; Rellena el byte actual con un espacio
    inc di ; Avanza al siguiente byte en el campo de nombre de la cuenta
    inc dx ; Incrementa el contador de caracteres copiados
    cmp dx, 20 ; Verifica si se han rellenado 20 caracteres en total
    jl fill_spaces ; Si no se han rellenado 20 caracteres, continúa rellenando

skip_spaces: ; Si ya se copiaron 20 caracteres, salta el ciclo de relleno de espacios
    pop cx ; Recuperar parte baja del saldo
    pop dx ; Recuperar parte alta del saldo
    mov [si + BALANCE_OFFSET], cx ; Guardar parte baja del saldo en la cuenta
    mov [si + BALANCE_OFFSET + 2], dx ; Guardar parte alta del saldo en la cuenta
    
    mov al, ACTIVE ; Establecer estado de la cuenta como activa
    mov [si + STATUS_OFFSET], al ; Guardar estado en la cuenta
    
    inc [account_count] ; Incrementar el contador de cuentas
    
    clc 
    jmp crear_end ; Cuenta creada exitosamente, CF = 0
    
crear_error_max:
    pop ax ; Limpiar parte baja del ID de la pila
    pop ax ; Limpiar parte alta del ID de la pila
    pop ax ; Limpiar parte baja del saldo de la pila
    pop ax ; Limpiar parte alta del saldo de la pila
    xor ax, ax ; Limpiar AX para retornar solo el código de error
    mov al, 1 ; código de error: número máximo de cuentas alcanzado
    stc
    jmp crear_end ; Termina el procedimiento con error
    
crear_error_id:
    pop ax ; Limpiar parte baja del ID de la pila
    pop ax ; Limpiar parte alta del ID de la pila
    pop ax ; Limpiar parte baja del saldo de la pila
    pop ax ; Limpiar parte alta del saldo de la pila    
    xor ax, ax ; Limpiar AX para retornar solo el código de error
    mov al, 2 ; código de error: ID duplicado
    stc
    jmp crear_end ; Termina el procedimiento con error
    
crear_error_balance:
    pop ax ; Limpiar parte baja del ID de la pila
    pop ax ; Limpiar parte alta del ID de la pila
    pop ax ; Limpiar parte baja del saldo de la pila
    pop ax ; Limpiar parte alta del saldo de la pila
    xor ax, ax ; Limpiar AX para retornar solo el código de error
    mov al, 3 ; código de error: saldo negativo
    stc

crear_end: ; Limpia la pila y retorna con CF indicando éxito o error y AX con el código de error si hubo uno
    pop di ; Recuperar registros usados
    pop si ; Recuperar registros usados
    pop dx ; Recuperar registros usados
    pop cx ; Recuperar registros usados
    pop bx ; Recuperar registros usados
    ret
crear_cuenta endp ; Fin de crear_cuenta

; ============================================================================
; PROCEDIMIENTO: consultar_saldo
; Entrada: DX:AX = ID de cuenta a buscar
; Salida: DX:AX = saldo, CF = 0 si encontrado
; ============================================================================

consultar_saldo proc ; Entrada: DX:AX = ID de cuenta a buscar
    push bx ; Guardar registros usados
    push cx ; Guardar registros usados
    push si ; Guardar registros usados
    
    call buscar_cuenta ; Busca la cuenta por ID, SI apunta a la cuenta si se encuentra, CF = 0 si encontrado
    jc consultar_error ; Si no se encuentra la cuenta, CF = 1 y salta a error
    
    ; Si encontrado, SI ya apunta a la cuenta
    mov ax, [si + BALANCE_OFFSET] ; Carga parte baja del saldo
    mov dx, [si + BALANCE_OFFSET + 2] ; Carga parte alta del saldo
    clc ; CF = 0 para indicar que se encontró la cuenta
    jmp consultar_end ; Termina el procedimiento con éxito
    
consultar_error: ; Si no se encuentra la cuenta, CF = 1
    stc
    
consultar_end: ; Limpia la pila y retorna con DX:AX = saldo (si encontrado) o sin cambios (si no encontrado) y CF indicando el resultado
    pop si ; Recuperar registros usados
    pop cx ; Recuperar registros usados
    pop bx ; Recuperar registros usados
    ret
consultar_saldo endp ; Fin de consultar_saldo

; ============================================================================
; PROCEDIMIENTO: procesar_crear_cuenta
; Entrada: ninguna
; Salida: ninguna
; Nota: Maneja menú y ciclos para crear cuenta
; ============================================================================

procesar_crear_cuenta proc
    push ax ; Guardar registros usados
    push bx ; Guardar registros usados
    push cx ; Guardar registros usados
    push dx ; Guardar registros usados
    push si ; Guardar registros usados 
    push di ; Guardar registros usados

    ; Verificar límite de cuentas
    mov bx, [account_count] ; Carga el número actual de cuentas
    cmp bx, max_accounts ; Compara con el máximo permitido
    jl crear_proseguir ; Si no se ha alcanzado el máximo, continúa con el proceso de creación

    mov ah, 09h ; Imprimir mensaje de error por límite de cuentas alcanzado
    mov dx, offset msg_error_max ; Mensaje de error por límite de cuentas alcanzado
    int 21h ; Imprime el mensaje de error
    jmp crear_fin ; Termina el procedimiento

crear_proseguir: ; Si no se ha alcanzado el máximo, continúa con el proceso de creación

    ; Imprimir "Nombre: "
    mov ah, 09h  ; Función 09h de INT 21h = imprimir cadena
    mov dx, offset msg_name ; Mensaje "Nombre: "
    int 21h ; Imprime el mensaje para solicitar el nombre
    
    ; Leer nombre
    mov di, offset nameBuffer ; Configura DI para apuntar al buffer de nombre
    call leer_string ; Lee el nombre ingresado por el usuario al buffer
    
    ; Imprimir "ID: "
    mov ah, 09h ; Función 09h de INT 21h = imprimir cadena
    mov dx, offset msg_id ; Mensaje "ID: "
    int 21h ; Imprime el mensaje para solicitar el ID
    
    ; Leer ID
    call leer_numero_id ; Lee el ID ingresado por el usuario, resultado en DX:AX
    push ax ; Guardar parte baja del ID para validación posterior
    push dx ; Guardar ID para validación posterior
    
    ; Imprimir "Saldo: "
    mov ah, 09h ; Función 09h de INT 21h = imprimir cadena
    mov dx, offset msg_balance ; Mensaje "Saldo: "
    int 21h ; Imprime el mensaje para solicitar el saldo
    
    ; Leer saldo
    call leer_numero_saldo ; Lee el saldo ingresado por el usuario, resultado en DX:AX
    mov cx, ax ; Guardar saldo en DX:CX
    
    ; Llamar crear_cuenta con validaciones
    pop bx ; Recuperar parte alta del ID para crear_cuenta
    pop ax ; Recuperar parte baja del ID para crear_cuenta
    mov di, offset nameBuffer ; DI apunta al buffer del nombre para crear_cuenta
    call crear_cuenta ; Crea la cuenta con ID en BX:AX, nombre en DI, saldo en DX:CX, resultado en CF y AX con código de error si hubo uno
    jc crear_fallido ; Si hubo un error en la creación de la cuenta, CF = 1 y AX tiene el código de error
    
    ; Éxito: imprimir mensaje
    mov ah, 09h ; Función 09h de INT 21h = imprimir cadena
    mov dx, offset msg_success ; Mensaje de éxito al crear la cuenta
    int 21h ; Imprime el mensaje de éxito
    jmp crear_fin ; Termina el procedimiento
    
crear_fallido:
    ; Determinar cuál fue el error
    cmp al, 1 ; Código de error 1 = número máximo de cuentas alcanzado
    je mostrar_error_max ; Si el error fue por límite de cuentas, muestra el mensaje correspondiente
    cmp al, 3 ; Código de error 3 = saldo negativo
    je mostrar_error_balance ; Si el error fue por saldo negativo, muestra el mensaje correspondiente

mostrar_error_id: ; Código de error 2 = ID duplicado o inválido
    mov ah, 09h ; Función 09h de INT 21h = imprimir cadena
    mov dx, offset msg_error_id ; Mensaje de error por ID duplicado o inválido
    int 21h ; Imprime el mensaje de error por ID
    jmp fin_error ; Termina el procedimiento después de mostrar el error

mostrar_error_max: ; Código de error 1 = número máximo de cuentas alcanzado
    mov ah, 09h ; Función 09h de INT 21h = imprimir cadena
    mov dx, offset msg_error_max ; Mensaje de error por límite de cuentas alcanzado
    int 21h ; Imprime el mensaje de error por límite de cuentas
    jmp fin_error ; Termina el procedimiento después de mostrar el error
 
mostrar_error_balance: ; Código de error 3 = saldo negativo
    mov ah, 09h ; Función 09h de INT 21h = imprimir cadena
    mov dx, offset msg_error_balance ; Mensaje de error por saldo negativo
    int 21h ; Imprime el mensaje de error por saldo negativo

fin_error: ; Termina el procedimiento después de mostrar el error

crear_fin: ; Limpia la pila y retorna
    pop di ; Recuperar registros usados
    pop si ; Recuperar registros usados
    pop dx ; Recuperar registros usados
    pop cx ; Recuperar registros usados
    pop bx ; Recuperar registros usados
    pop ax ; Recuperar registros usados
    ret
procesar_crear_cuenta endp ; Fin de procesar_crear_cuenta

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