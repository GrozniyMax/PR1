section .text
    
; Принимает код возврата и завершает текущий процесс
exit:
    ; sys_exit
    ; код возвратаи так уже в rdi как аргумент
    mov rax, 60; 
    syscall
    ret 

; Принимает указатель на нуль-терминированную строку, возвращает её длину
string_length:
    xor rax, rax; Очистить rax
    .loop:
        cmp byte[rdi+rax], 0
        je .end
        inc rax
        jmp .loop
     .end:
        ret

; Принимает указатель на нуль-терминированную строку, выводит её в stdout
print_string:
    xor rax, rax    ; Очищаем rax для работы с ним
    
    mov rdx, rdi    ;   
    .loop:
        cmp byte[rdx+rax], 0
        je .end
        
        push rdx
        push rax 
        xor rdi, rdi    ;
        mov dil, byte[rdx+rax]
        
        sub rsp, 8
        call print_char
        add rsp, 8
        
        pop rax
        pop rdx
        inc rax
        jmp .loop
     .end:
        
        ret

; Принимает код символа и выводит его в stdout
print_char:
    push rsp
    push rdi
    mov rax, 1; 
    mov rdi, 1;
    mov rsi, rsp ;
    mov rdx, 1;  Тк выводим chat, то длинна 1 байт
    syscall
    
    xor rax, rax
    pop rdi
    pop rsp
    ret

; Переводит строку (выводит символ с кодом 0xA)
print_newline:
    mov rdi, 0xA; Заносим \n в rdi
    call print_char
    ret

; Выводит беззнаковое 8-байтовое число в десятичном формате 
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint:
    push rsp
    sub rsp, 8
    push 0              ;Стоп символ для вывода, чтобы потом не мучаться с счетчиком
    push rdi
    mov rax, rdi
    xor rcx, rcx
    xor rsi, rsi
    .loop:
        pop rax         ;
        xor rdx, rdx    ;
        mov rbx, 10     ;
        mov rsi, rax    ;    
        div rbx         ;
        cmp eax, 0      ;
        je .output
        add dl, '0'
        push rdx
        push rax        ;
        inc rcx
        jmp .loop
    .output:
      .first_number:
        add sil, '0'
        mov rdi, rsi

        sub rsp, 8
        call print_char
        add rsp, 8
      
      .others:
        .even:
            pop rdi             ; Четная цифра, если считать с 1 и от 1
            cmp rdi, 0          ; Здесь не требуется выравнивания
            je .end
            
            call print_char
            
        .odd:
            pop rdi             ; Нечетная по номеру цифра
            cmp rdi, 0          ; Здесь требуется выравнивание
            je .end
            
            sub rsp, 8
            call print_char
            add rsp, 8
            
            
            jmp .others
    .end:
        add rsp, 8
        ret

; Выводит знаковое 8-байтовое число в десятичном формате 
print_int:
    sub rsp, 8
    cmp rdi, 0
    jge .positive
    push rdi
    mov rdi, '-'
    
    sub rsp, 8
    call print_char
    add rsp, 8
    
    pop rdi
    neg rdi
  .positive:
    
    call print_uint
    
    
    add rsp, 8
    ret

; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе
string_equals:

    push rdi                    ; Сохраняем указатель1
    push rsi                    ; Сохраняем указатель2
      
    xor rax, rax                ; Очистить rax
    
    sub rsp, 8                  ;Выравнивание стека
    call string_length          ;
    add rsp, 8                  ;Выравнивание стека
    
    mov rsi, rax                ; Сохраняем длинну 1 строки
    
    pop rdi                     ; Достаем указатель2 -> rdi
    
    
    call string_length          ; длинна строки2->rax
    
    
    cmp rax, rsi                ; Сравниваем строки по длинне
    jne .wrong_len
    pop rsi                     ;Указатель1->rsi
    .loop:
        cmp rax, -1             ; В rax  лежит длинна строки и мы начнем сравнивать с конца, чтобы ее нигде не хранить
        je .yes                 ; Если  rax==-1 то мы прошли всю строку
        mov r9b, byte[rsi+rax]  ;записываем символ из строки2->r9. Так, как почему, то я не могу сделать cmp byte[], byte[]
        cmp r9b, byte[rdi+rax]
        jne .not
        dec rax
        jmp .loop
    .yes:
        mov rax, 1
        jmp .end
    .not:
        mov rax, 0
        jmp .end
    .wrong_len:
        
        pop rdi
        mov rax, 0
        jmp .end
    .end:
        ret

; Читает один символ из stdin и возвращает его. Возвращает 0 если достигнут конец потока
read_char:
    
    push 0          

    mov rdx, 1
    mov rsi, rsp   

    mov rax, 0
    mov rdi, 0
    syscall

    pop rax        
    ret

; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел 0x20, табуляция 0x9 и перевод строки 0xA.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор

read_word:
    
    xor rax, rax                ;
    xor rdx, rdx                ;

    dec rsi
    cmp rsi, 0                  ;
    jle .small_buff                  ;Проверяем наличие буфера
    
    push rdx
    push rdi                    ;Сохраняем адрес буфера
    push rsi                    ;Сохраняем размер буфера
    
    .whitespace_skip:
        xor r9, r9
        call read_char
        
        cmp rax, 0              ; Проверка на  ctrl+d
        je .small_buff
        cmp rax, 0x20           ; Проверка на пробел
        je .whitespace_skip     ;
        cmp rax, 0x9            ; Проверка на табуляцию
        je .whitespace_skip     ;
        cmp rax, 0xA            ; Проверка на перевод строки
        je .whitespace_skip     ;
     
    .first_letter:
        pop rsi                 ;Достаем размер буфера
        pop rdi                 ;Достаем адрес буфера
        pop rdx                 ;
        
        mov byte[rdi+rdx], al      ;Сохраняем символ
        inc rdx                 ;
        cmp rdx, rsi            ;
        je .try_last            ;При совпадении счетчика и размера буфера выходим
        push rdx                ;Сохраняем состояние 
        push rdi                ;
        push rsi                ;
        
    .others_loop:
        xor r9, r9
        call read_char
    
        pop rsi                 ;Достаем размер буфера
        pop rdi                 ;Достаем адрес буфера
        pop rdx
        
        cmp rax, 0              ; Проверка на  ctrl+d
        je .success
        cmp rax, 0x20           ; Проверка на пробел
        je .success                 ;
        cmp rax, 0x9            ; Проверка на табуляцию
        je .success                 ;
        cmp rax, 0xA            ; Проверка на перевод строки
        je .success                 ;
        
        mov byte[rdi+rdx], al   ;Сохраняем символ
        inc rdx                 ;
        cmp rdx, rsi            ;
        je .try_last             ;При совпадении счетчика и размера буфера выходим
        
        push rdx                ;Сохраняем состояние 
        push rdi                ;
        push rsi                ;
        
        jmp .others_loop
    .try_last:
        xor r9, r9
        call read_char
        cmp rax, 0              ; Проверка на  ctrl+d
        je .success
        cmp rax, 0x20           ; Проверка на пробел
        je .success                 ;
        cmp rax, 0x9            ; Проверка на табуляцию
        je .success                 ;
        cmp rax, 0xA            ; Проверка на перевод строки
        je .success                 ;
        jmp .small_buff
        
    .small_buff:
        mov rax, 0
        jmp .end
    .success:
        mov rax, rdi;
        mov byte[rdi+rdx], 0      ;Добавляем нуль терминатор
    .end:
        ret
 

; Принимает указатель на строку, пытается
; прочитать из её начала беззнаковое число.
; Возвращает в rax: число, rdx : его длину в символах
; rdx = 0 если число прочитать не удалось
parse_uint:
    
    xor rdx, rdx                ;
    xor rax, rax                ;
    xor r9, r9                  ;
    xor rbx, rbx
    
    cmp byte[rdi+rdx], 0        ;
    je .end                     ;
    cmp byte[rdi+rdx], '9'      ; Если код символа > '9', то это уже не цифра
    jg .error                   ;
    mov r9b, byte[rdi+rdx]      ;
    sub r9b, '0'                ; Если код символа < '0', то это уже не цифра
    jl .error                   ;
    add rax, r9                 ;
    inc rdx
    
    mov r8, 10                  ;

    .loop:
        cmp byte[rdi+rdx], 0    ;
        je .end                 ;
        cmp byte[rdi+rdx], '9'  ; Если код символа > '9', то это уже не цифра
        jg .end
        xor r9, r9              ;Очистим r9               
        mov r9b, byte[rdi+rdx]  ;
        sub r9b, '0'            ; Если код символа < '0', то это уже не цифра
        jl .end                 ;
        imul r9, r8             ;
        add rax, r9             ;
        imul r8, 10             ;
        inc rdx
        jmp .loop
     .error:
        mov rdx, 0;
        ret
     .end:
        ret




; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был) 
; rdx = 0 если число прочитать не удалось
parse_int:
    
    cmp byte[rdi], '-'
    je .negative
    
    call parse_uint
    jmp .end
    .negative:
        inc rdi
        
        call parse_uint
        
        neg rax
        inc rdx
    .end:
        
        ret

; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0
string_copy:
    
    push rsi                ; сохраняем указатель на буфер
    push rdi                ; сохраняем указатель на строку
    push rdx                ; сохраняем длину буфера
    
    
    call string_length
    
    pop rdx
    cmp rdx, rax;
    jl .error
    pop rdi
    pop rsi
    push rax                ; Длинну строки на стек
    xor rax, rax            ; Очистить rax
    
    .loop:
        cmp byte[rdi+rax], 0            ; проверка на стоп-символ
        je .end
        mov r8b, byte[rdi+rax]
        mov byte[rsi+rax], r8b
        inc rax
        jmp .loop
    .end:
        mov byte[rsi+rax+1], 0;
        
        pop rax
        add rsp, 8          ;Выравнивание стека
        ret
    .error:
        mov al, 0;
        ret
