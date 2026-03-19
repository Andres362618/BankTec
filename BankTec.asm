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

leer_string proc ; DI = offset buffer
; Guardar registros usados
    push ax 
    push bx
    push cx
    push dx
    push si
    xor cx, cx ; Contador de caracteres leídos

read_loop: ; Leer un carácter
    mov ah, 01h ; Función 01h = leer carácter 
    int 21h ; AL = carácter leído

    ; Manejar caracteres especiales
    cmp al, 13 ; Enter
    je read_done 
    cmp al, 8 ; Espacio
    je read_back

    cmp cx, 19 ; Limitar a 20 caracteres (0-19)
    jge read_loop

    ; Guardar carácter en buffer
    mov [di], al ; Guardar en buffer
    inc di ; Avanzar puntero
    inc cx ; Incrementar contador
    jmp read_loop ; Continuar leyendo

; Manejar espacio
read_back:
    cmp cx, 0 ; Si no hay caracteres, ignorar backspace
    je read_loop ; Si hay caracteres, retroceder
    dec di ; Retroceder puntero
    dec cx ; Decrementar contador
    jmp read_loop ; Continuar leyendo

; Finalizar cadena con 0
read_done:
    mov al, 0 ; Terminador de cadena
    mov [di], al ; Guardar terminador

    ; Restaurar registros
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

; Lee una cadena de dígitos, la convierte a número y la devuelve en AX
leer_numero proc
    push bx
    push cx
    push dx
    push di
    push si
    
    ; Imprimir mensaje de entrada
    mov di, offset inputBuffer ; Usar inputBuffer para leer la cadena
    call leer_string ; Leer la cadena de dígitos
    
    ; Convertir cadena a número
    xor ax, ax ; Limpiar AX para acumular el número
    mov si, offset inputBuffer ; SI apunta al inicio de la cadena

; Loop de conversión    
convert_loop:
    mov cl, [si] ; Leer carácter actual
    cmp cl, 0 ; Verificar si es el final de la cadena
    je convert_done ; Si no es el final, verificar si es un dígito

    ; Validar que el carácter sea un dígito (0-9)
    cmp cl, '0' 
    jl convert_error ; Si es menor que '0', no es un dígito
    cmp cl, '9'
    jg convert_error ; Si es mayor que '9', no es un dígito
    
    sub cl, '0' ; Convierte ASCII a número
    mov dx, ax ; Guardar el número acumulado antes de multiplicar
    mov bx, 10 ; Preparar multiplicación por 10
    mul bx ; AX = AX * 10
    add al, cl ; AX += dígito
    
    inc si ; Avanzar al siguiente carácter
    jmp convert_loop ; Continuar con el siguiente carácter
    
convert_error:
    mov ax, 0 ; Retorna 0 si error

; Restaurar registros    
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

; Imprime el número en AX como una cadena de dígitos
imprimir_numero proc
    push ax
    push bx
    push cx
    push dx
    
    mov bx, 10 ; Base decimal
    mov cx, 0 ; Contador de dígitos

divide_loop: ; Dividir el número por 10 para extraer dígitos
    xor dx, dx ; Limpiar DX para la división
    ; AX = número actual, después de la división AX = número / 10, DX = residuo (dígito)
    div bx 
    push dx ; Guarda residuo
    inc cx
    cmp ax, 0
    jne divide_loop
    
print_loop:
    pop ax ; Recupera el dígito
    add al, '0' ; Convierte a ASCII
    mov dl, al ; DL = carácter a imprimir
    mov ah, 02h ; INT 21h función 02 = imprimir carácter
    int 21h ; Imprime el dígito
    loop print_loop ; Repite hasta imprimir todos los dígitos
    
    ; Restaurar registros
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

; Busca la cuenta por ID. Si la encuentra, SI apunta a la cuenta y CF=0. Si no, CF=1.
buscar_cuenta proc
    push ax ; Guardar el ID a buscar
    push bx ; Guardar registros usados
    push cx ; contador de cuentas
    push dx ; parte alta del ID

    mov si, offset accounts ; SI apunta al inicio del arreglo de cuentas
    xor cx, cx ; contador de cuentas
    xor dx, dx ; DX debe contener la parte alta del ID

search_loop:
    cmp cx, [account_count] ; Comparar con la cantidad de cuentas activas
    jge search_not_found ; Si se recorrieron todas las cuentas, no se encontró

    mov bx, [si + ID_OFFSET] ; Obtener la parte baja del ID de la cuenta actual
    cmp bx, ax ; Comparar con la parte baja del ID buscado
    jne next_entry ; Si no coincide, pasar a la siguiente cuenta
    mov bx, [si + ID_OFFSET + 2] ; Obtener la parte alta del ID de la cuenta actual
    cmp bx, dx ; Comparar con la parte alta del ID buscado
    jne next_entry ; Si ambas partes coinciden, se encontró la cuenta

    ; Cuenta encontrada, SI ya apunta a la cuenta
    clc
    jmp search_end

; Continuar buscando en la siguiente cuenta
next_entry:
    add si, account_size ; Avanzar al siguiente registro de cuenta
    inc cx ; Incrementar contador de cuentas
    jmp search_loop ; Repetir el proceso

; Si no se encontró la cuenta después de revisar todas las cuentas activas
search_not_found:
    stc ; Indicar que no se encontró la cuenta

; Restaurar registros y retornar
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

; Valida que el ID en AX (y DX para parte alta) no exista ya en las cuentas activas. Si es único, CF=0. Si ya existe, CF=1.
validar_id_unico proc
    push ax ; Guardar el ID a validar
    push bx ; Guardar registros usados
    push cx ; contador de cuentas
    push dx ; parte alta del ID
    push si ; Guardar SI para recorrer cuentas

    mov si, offset accounts ; SI apunta al inicio del arreglo de cuentas
    xor cx, cx ; contador de cuentas

check_loop: ; Recorrer las cuentas activas para comparar el ID
    cmp cx, [account_count] ; Comparar con la cantidad de cuentas activas
    jge check_unique ; Si se recorrieron todas las cuentas, el ID es único

    mov bx, [si + ID_OFFSET] ; Obtener la parte baja del ID de la cuenta actual
    cmp bx, ax ; Comparar con la parte baja del ID a validar
    jne next_check ; Si no coincide, pasar a la siguiente cuenta
    mov bx, [si + ID_OFFSET + 2] ; Obtener la parte alta del ID de la cuenta actual
    cmp bx, dx ; Comparar con la parte alta del ID a validar
    jne next_check ; Si ambas partes coinciden, el ID ya existe, es un duplicado

    ; Duplicado
    stc ; Indicar que el ID no es único
    jmp check_end ; Si no se encontró un duplicado después de revisar todas las cuentas activas, el ID es único

next_check: ; Continuar buscando en la siguiente cuenta
    add si, account_size ; Avanzar al siguiente registro de cuenta
    inc cx ; Incrementar contador de cuentas
    jmp check_loop ; Repetir el proceso

check_unique: ; El ID es único, no se encontró ningún duplicado
    clc ; Indicar que el ID es único

; Restaurar registros y retornar
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

; Crea una cuenta con el ID en AX, nombre en DI, y saldo en CX. Realiza validaciones y guarda la cuenta en memoria si es válida. Si hay error, CF=1 y AL indica el tipo de error (1=max cuentas, 2=ID duplicado, 3=saldo negativo).
crear_cuenta proc 
    ; Guardar registros usados
    push ax 
    push bx
    push cx
    push dx
    push si
    push di
    
    ; Validación 1: Número máximo de cuentas
    mov bx, [account_count] ; Obtener la cantidad actual de cuentas
    cmp bx, max_accounts ; Comparar con el máximo permitido
    jge crear_error_max ; Si se alcanzó el máximo, saltar a error
    
    ; Validación 2: ID no repetido
    xor dx, dx ; Asegurar que DX esté limpio para validar ID completo (parte alta)
    call validar_id_unico ; Si el ID no es único, CF=1 y se salta a error
    jc crear_error_id ; Si el ID es único, CF=0 y se continúa con la creación de la cuenta
    
    ; Validación 3: Saldo >= 0
    cmp cx, 0 ; Comparar el saldo con 0
    jl crear_error_balance ; Si el saldo es negativo, saltar a error

    ; Guardar el ID en la pila
    push ax

    ; Calcular offset en memoria
    mov si, offset accounts ; SI apunta al inicio del arreglo de cuentas
    mov bx, [account_count] ; Obtener la cantidad actual de cuentas para calcular el offset
    mov ax, bx ; AX = número de cuentas actuales
    mov bx, account_size ; Tamaño de cada cuenta
    mul bx ; AX = offset para la nueva cuenta
    add si, ax ; SI ahora apunta al lugar donde se guardará la nueva cuenta

    ; Recuperar el ID original
    pop dx

    mov [si + ID_OFFSET], dx ; Guardar la parte baja del ID
    mov word ptr [si + ID_OFFSET + 2], 0 ; Guardar la parte alta del ID (en este caso, siempre 0)

    mov bx, di ; BX apunta al buffer del nombre
    mov di, si ; DI apunta al lugar donde se guardará la cuenta
    add di, NAME_OFFSET ; Ajustar DI para apuntar al campo de nombre dentro de la cuenta
    xor dx, dx ; DX se usará como contador de caracteres copiados

copy_name_loop: ; Copiar el nombre del buffer a la cuenta
    mov al, [bx] ; Leer un carácter del buffer de nombre
    cmp al, 0 ; Verificar si es el terminador de cadena
    je copy_done ; Si es el terminador, se ha copiado todo el nombre
    cmp dx, 20 ; Verificar si se ha alcanzado el límite de 20 caracteres para el nombre
    jge copy_done ; Si se ha alcanzado el límite, terminar de copiar (se truncará el nombre)

    mov [di], al ; Copiar el carácter al campo de nombre de la cuenta
    inc bx ; Avanzar al siguiente carácter del buffer de nombre
    inc di ; Avanzar al siguiente espacio en el campo de nombre de la cuenta
    inc dx ; Incrementar el contador de caracteres copiados
    jmp copy_name_loop ; Repetir para el siguiente carácter

copy_done: ; Si el nombre es menor a 20 caracteres, rellenar con espacios hasta completar los 20 caracteres
    cmp dx, 20 ; Verificar si se copiaron menos de 20 caracteres
    jge skip_spaces ; Si ya se copiaron 20 caracteres, no es necesario rellenar con espacios

fill_spaces: ; Rellenar con espacios hasta completar los 20 caracteres del nombre
    mov al, ' ' ; Carácter de espacio
    mov [di], al ; Rellenar con espacio
    inc di ; Avanzar al siguiente espacio en el campo de nombre de la cuenta
    inc dx ; Incrementar el contador de caracteres rellenados
    cmp dx, 20 ; Verificar si se han rellenado 20 caracteres en total
    jl fill_spaces ; Si no se han rellenado 20 caracteres, continuar rellenando

skip_spaces: ; Continuar con el resto de la creación de la cuenta
    mov [si + BALANCE_OFFSET], cx ; Guardar el saldo
    mov word ptr [si + BALANCE_OFFSET + 2], 0 ; Guardar la parte alta del saldo (en este caso, siempre 0)
    
    mov al, ACTIVE ; Guardar el estado de la cuenta como activa
    mov [si + STATUS_OFFSET], al ; Guardar el estado de la cuenta
    
    inc [account_count] ; Incrementar el contador de cuentas activas

    ; Cuenta creada exitosamente
    clc 
    jmp crear_end ; Salir del procedimiento con éxito
    
crear_error_max: ; Si se alcanzó el número máximo de cuentas, establecer CF=1 y AL=1 para indicar este error
    mov al, 1 ; código de error: máximo de cuentas alcanzado
    stc ; Indicar que hubo un error
    jmp crear_end ; Salir del procedimiento con error
    
crear_error_id: ; Si el ID ya existe, establecer CF=1 y AL=2 para indicar este error
    mov al, 2 ; código de error: ID duplicado
    stc ; Indicar que hubo un error
    jmp crear_end ; Salir del procedimiento con error
    
crear_error_balance: ; Si el saldo es negativo, establecer CF=1 y AL=3 para indicar este error
    mov al, 3 ; código de error: saldo negativo
    stc ; Indicar que hubo un error

; Restaurar registros y retornar
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

; Busca la cuenta por ID y devuelve el saldo en AX. Si no se encuentra, CF=1.
consultar_saldo proc ; Guardar registros usados
    push bx ; Guardar registros usados
    push cx ; contador de cuentas
    push si ; SI se usará para recorrer cuentas
    
    call buscar_cuenta ; Buscar la cuenta por ID, SI apunta a la cuenta si se encuentra, CF=0 si encontrado
    jc consultar_error ; Si no se encontró la cuenta, saltar a error
    
    ; Si encontrado, SI ya apunta a la cuenta
    mov ax, [si + BALANCE_OFFSET] ; Cargar el saldo en AX
    clc ; Indicar que se encontró la cuenta y se obtuvo el saldo exitosamente
    jmp consultar_end ; Salir del procedimiento con éxito
    
consultar_error: ; Si no se encontró la cuenta, establecer CF=1 para indicar este error
    stc ; Indicar que hubo un error (cuenta no encontrada)
    
consultar_end: ; Restaurar registros y retornar
    pop si ; Restaurar registros usados 
    pop cx ; contador de cuentas
    pop bx ; Restaurar registros usados
    ret
consultar_saldo endp

; ============================================================================
; PROCEDIMIENTO: procesar_crear_cuenta
; Entrada: ninguna
; Salida: ninguna
; Nota: Maneja menú y ciclos para crear cuenta
; ============================================================================

; Procesa la opción de crear cuenta, solicitando datos al usuario, validando y mostrando mensajes de éxito o error
procesar_crear_cuenta proc ; Guardar registros usados
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    ; Verificar límite de cuentas
    mov bx, [account_count] ; Obtener la cantidad actual de cuentas
    cmp bx, max_accounts ; Comparar con el máximo permitido
    jl crear_proseguir ; Si no se ha alcanzado el máximo, continuar con el proceso de creación

    mov ah, 09h ; Imprimir mensaje de error por máximo de cuentas alcanzado
    mov dx, offset msg_error_max ; Cargar dirección del mensaje de error
    int 21h ; Mostrar mensaje de error
    jmp crear_fin ; Salir del procedimiento

crear_proseguir: ; Continuar con el proceso de creación de cuenta

    ; Imprimir "Nombre: "
    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_name ; Cargar dirección del mensaje de solicitud de nombre
    int 21h ; Mostrar mensaje de solicitud de nombre
    
    ; Leer nombre
    mov di, offset nameBuffer ; DI apunta al buffer donde se guardará el nombre
    call leer_string ; Leer el nombre ingresado por el usuario
    
    ; Imprimir "ID: "
    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_id ; Cargar dirección del mensaje de solicitud de ID
    int 21h ; Mostrar mensaje de solicitud de ID
    
    ; Leer ID
    call leer_numero ; Leer el ID ingresado por el usuario, resultado en AX
    mov bx, ax ; Guardar ID en BX
    
    ; Imprimir "Saldo: "
    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_balance ; Cargar dirección del mensaje de solicitud de saldo
    int 21h ; Mostrar mensaje de solicitud de saldo
    
    ; Leer saldo
    call leer_numero ; Leer el saldo ingresado por el usuario, resultado en AX
    mov cx, ax ; Guardar saldo en CX
    
    ; Llamar crear_cuenta con validaciones
    mov ax, bx ; AX = ID
    xor dx, dx ; DX = parte alta del ID (en este caso, siempre 0)
    mov di, offset nameBuffer ; DI = buffer del nombre
    call crear_cuenta ; Intentar crear la cuenta, resultado en CF y AL para el tipo de error si lo hay
    jc crear_fallido ; Si la creación de la cuenta falló, saltar a manejo de errores
    
    ; Éxito: imprimir mensaje
    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_success ; Cargar dirección del mensaje de éxito
    int 21h ; Mostrar mensaje de éxito
    jmp crear_fin ; Salir del procedimiento
    
crear_fallido:
    ; Determinar cuál fue el error
    cmp al, 1 ; Verificar si el error fue por máximo de cuentas alcanzado
    je mostrar_error_max ; Si el error fue por máximo de cuentas alcanzado, mostrar mensaje de error correspondiente
    cmp al, 3 ; Verificar si el error fue por saldo negativo
    je mostrar_error_balance ; Si el error fue por saldo negativo, mostrar mensaje de error correspondiente

mostrar_error_id: ; Si el error fue por ID duplicado, mostrar mensaje de error correspondiente
    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_error_id ; Cargar dirección del mensaje de error por ID duplicado
    int 21h ; Mostrar mensaje de error por ID duplicado
    jmp fin_error ; Salir del procedimiento después de mostrar el mensaje de error

mostrar_error_max: ; Si el error fue por máximo de cuentas alcanzado, mostrar mensaje de error correspondiente
    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_error_max ; Cargar dirección del mensaje de error por máximo de cuentas alcanzado
    int 21h ; Mostrar mensaje de error por máximo de cuentas alcanzado
    jmp fin_error ; Salir del procedimiento después de mostrar el mensaje de error

mostrar_error_balance: ; Si el error fue por saldo negativo, mostrar mensaje de error correspondiente
    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_error_balance ; Cargar dirección del mensaje de error por saldo negativo
    int 21h ; Mostrar mensaje de error por saldo negativo

fin_error: ; Salir del procedimiento después de mostrar el mensaje de error

; Restaurar registros y retornar
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
procesar_consultar_saldo proc ; Guardar registros usados
    push ax ; Guardar registros usados
    push bx ; Guardar registros usados
    push cx ; contador de cuentas
    push dx ; parte alta del ID
    
    ; Imprimir "Ingrese ID: "
    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_query_id ; Cargar dirección del mensaje de solicitud de ID para consulta
    int 21h ; Mostrar mensaje de solicitud de ID para consulta
    
    ; Leer ID
    call leer_numero ; Leer el ID ingresado por el usuario, resultado en AX
    xor dx, dx ; DX = parte alta del ID (en este caso, siempre 0)

    ; Buscar and consultar
    call consultar_saldo ; Buscar la cuenta por ID y obtener el saldo, resultado en AX y CF
    jc consultar_fallido ; Si no se encontró la cuenta, saltar a manejo de error
    
    ; Éxito: mostrar saldo
    push ax ; Guardar el saldo para imprimir después del mensaje
    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_current_balance ; Cargar dirección del mensaje de saldo actual
    int 21h ; Mostrar mensaje de saldo actual
    pop ax ; Recuperar el saldo para imprimir

    call imprimir_numero ; Imprimir el saldo actual

    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_account_active ; Cargar dirección del mensaje de cuenta activa
    int 21h ; Mostrar mensaje de cuenta activa
    jmp consultar_fin ; Salir del procedimiento después de mostrar el saldo
    
consultar_fallido: ; Si no se encontró la cuenta, mostrar mensaje de error correspondiente
    mov ah, 09h ; Función 09h = imprimir cadena
    mov dx, offset msg_error_not_found ; Cargar dirección del mensaje de error por cuenta no encontrada
    int 21h ; Mostrar mensaje de error por cuenta no encontrada
    
; Restaurar registros y retornar
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