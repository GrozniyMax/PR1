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
    sub rsp, 32         ;Добавим в конце, чтобы даже шанса на поломку стека не было
    push rbx
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
      mov al, cl
      mov cl, 2
      div cl
      cmp ah, 0
      je .odd_number_digits     ;Количество цифр напрямую влияет на необходимость выравнивания
                                ;Нечетное количество цифр учитывая первую
      xor rax, rax
      xor rcx, rcx
       .even_number_digits:     ;Четное количество цифр учитывая первую
            .first_number_even:
            add sil, '0'
        
            mov rdi, rsi
            
            call print_char
            xor rsi, rsi
            .others_even:
                .even_even:
                pop rdi             ; Четная цифра, если считать с 1 и от 1
                cmp rdi, 0          ; Здесь не требуется выравнивания
                je .end
            
                sub rsp, 8
                call print_char
                add rsp, 8
            
                .odd_even:
                pop rdi             ; Нечетная по номеру цифра
                cmp rdi, 0          ; Здесь требуется выравнивание
                je .end

                call print_char

                jmp .others_even
       .odd_number_digits:          ;Нечетное количество цифр учитывая первую
            .first_number_odd:
            add sil, '0'
        
            mov rdi, rsi
            sub rsp, 8
            call print_char
            add rsp, 8
            .others_odd:
                .even_odd:
                pop rdi             ; Четная цифра, если считать с 1 и от 1
                cmp rdi, 0          ; Здесь не требуется выравнивания
                je .end
            
                
                call print_char
                
            
                .odd_odd:
                pop rdi             ; Нечетная по номеру цифра
                cmp rdi, 0          ; Здесь требуется выравнивание
                je .end
                sub rsp, 8
                call print_char
                add rsp, 8
                jmp .others_odd
    .end:
        pop rbx
        add rsp, 32
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
    ;rdi - 1 строка
    ;rsi - 2 строка
    xor rax, rax           ;Очистим rax
    .loop:
        xor rcx, rcx       ;Очистим его на всякий случай
        mov cl, byte[rdi+rax]
        add cl, byte[rsi+rax]
        
        cmp rcx, 0;        ;Если rcx==0, то оба символа нулевые, т.е строки закончились
        je .yes
        
        mov cl, byte[rdi+rax]
        cmp cl, byte[rsi+rax]
        jne .not
        
        inc rax
        jmp .loop
    .yes:
        mov rax, 1
        jmp .end
    .not:
        mov rax, 0
        jmp .end
    .end:
        ret
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
    
    
    push rdi                    ;Сохраняем адрес буфера
    push rsi                    ;Сохраняем размер буфера
    
    .whitespace_skip:
        
        sub rsp, 8
        call read_char
        add rsp, 8
        
        cmp rax, 0              ; Проверка на  ctrl+d
        je .empty_word
        cmp rax, 0x20           ; Проверка на пробел
        je .whitespace_skip     ;
        cmp rax, 0x9            ; Проверка на табуляцию
        je .whitespace_skip     ;
        cmp rax, 0xA            ; Проверка на перевод строки
        je .whitespace_skip     ;
     
    .first_letter:
        pop rsi                 ;Достаем размер буфера
        pop rdi                 ;Достаем адрес буфера
        
        mov byte[rdi], al      ;Сохраняем символ
        cmp rsi, 1
        je .try_last
        mov rdx, 1
        push rdx                ;Сохраняем состояние 
        push rdi                ;
        push rsi                ;
        
    .others_loop:
        
        call read_char
    
        cmp rax, 0              ; Проверка на  ctrl+d
        je .success
        cmp rax, 0x20           ; Проверка на пробел
        je .success             ;
        cmp rax, 0x9            ; Проверка на табуляцию
        je .success             ;
        cmp rax, 0xA            ; Проверка на перевод строки
        je .success             ;
        
        pop rsi                 ;Достаем размер буфера
        pop rdi                 ;Достаем адрес буфера
        pop rdx
        
        mov byte[rdi+rdx], al   ;Сохраняем символ
        inc rdx                 ;
        cmp rdx, rsi            ;
        je .try_last             ;При совпадении счетчика и размера буфера выходим
        
        push rdx                ;Сохраняем состояние 
        push rdi                ;
        push rsi                ;
        
        jmp .others_loop
    .try_last:
        push rdx                ;Сохраняем состояние 
        push rdi                ;
        push rsi                ;
        call read_char
        cmp rax, 0              ; Проверка на  ctrl+d
        je .success
        cmp rax, 0x20           ; Проверка на пробел
        je .success             ;
        cmp rax, 0x9            ; Проверка на табуляцию
        je .success             ;
        cmp rax, 0xA            ; Проверка на перевод строки
        je .success             ;
        
    .small_buff:
        pop rsi                 ;Достаем размер буфера
        pop rdi                 ;Достаем адрес буфера
        pop rdx
        mov rax, 0
        jmp .end
    .success:
        pop rsi                 ;Достаем размер буфера
        pop rdi                 ;Достаем адрес буфера
        pop rdx
        mov byte[rdi+rdx], 0 ;Добавляем нуль терминатор
        mov rax, rdi;
        jmp .end 
    .empty_word:
        pop rsi                 ;Достаем размер буфера
        pop rdi                 ;Достаем адрес буфера
        mov rax, rdi
        mov rdx, 0   
    .end:
        ret

; Принимает указатель на строку, пытается
; прочитать из её начала беззнаковое число.
; Возвращает в rax: число, rdx : его длину в символах
; rdx = 0 если число прочитать не удалось
parse_uint:
    xor rax, rax		    ;   Регистр для числа
	xor rdx, rdx		    ;   Длинна данного числа (Число обозначает сдвиг относительно указателя)
	xor rcx, rcx		    ;   Буфер

	.loop:
	    xor rcx, rcx        ; Обнуление буффера
  	    mov cl, [rdi+rdx]	; Чтение цифры [rdi+rdx]
	    cmp cl, '0'		    ; Если меньше '0', то выход
	    jb .end 
	    cmp cl, '9'         ; Если больше '9', то выход
	    ja .end
	    sub rcx, '0'		; Перевод из ASCII в число

	    mov r11, 10		    ;
	    push rdx            ;
	    mul r11             ; Умножаем прошлое число x10
	    pop rdx             ;

	    add rax, rcx	    ; Получаем новое число rax = rax * 10 + rcx
	    inc rdx             ; Увеличиваем длину числа
	    jmp .loop
	
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
    sub rsp, 8
    call parse_uint
    add rsp, 8
    jmp .end
    .negative:
        inc rdi
        
        sub rsp, 8
        call parse_uint
        add rsp, 8
        
        neg rax
        inc rdx
    .end:
        ret

; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0
string_copy:
    xor rax, rax
    ;rsi указатель на буфер
    ;rdi указатель на строку
    ;rdx длину буфера
    .loop:
        cmp byte[rdi + rax], 0
        je .success
        cmp rdx, 1          ; c 1 тк , надо доп место для нуль-терминатора
        jle .overflow
        xor r9b, r9b
        mov r9b, byte[rdi+rax]
        mov byte[rsi+rax], r9b
        inc rax
        dec rdx
        jmp .loop
    .overflow:
        mov rax, 0;
        jmp .end
    .success:
        mov byte[rsi+rax], 0
    .end:
        ret




    

