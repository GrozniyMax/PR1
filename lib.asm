%define SYS_READ 0
%define SYS_WRITE 1
%define SYS_EXIT 60

%define STD_IN 0
%define STD_OUT 1
%define ST_ERR 2

%define NULL_TERMINATOR 0
%define NEW_LINE_SMBL 0xA

section .text
    
; Принимает код возврата и завершает текущий процесс
exit:
    ; sys_exit
    ; код возвратаи так уже в rdi как аргумент
    mov rax, SYS_EXIT; 
    syscall
    ret 

; Принимает указатель на нуль-терминированную строку, возвращает её длину
string_length:
    xor rax, rax; Очистить rax
    .loop:
        cmp byte[rdi+rax], NULL_TERMINATOR
        je .end
        inc rax
        jmp .loop
     .end:
        ret

; Принимает указатель на нуль-терминированную строку, выводит её в stdout
print_string:
    push rdi
    call string_length
    mov rdx, rax
    pop rsi
    mov rdi, STD_OUT    ;то положим его на стек, и получим через rsp
    mov rax, SYS_WRITE
    syscall
    ret

; Переводит строку (выводит символ с кодом 0xA)
print_newline:
    mov rdi, NEW_LINE_SMBL; Заносим '\n' в rdi

; Принимает код символа и выводит его в stdout
print_char:
    push rdi            ;Тк в rdi лежит код символа, а нам надо *char_buf 
    mov rdi, STD_OUT    ;то положим его на стек, и получим через rsp
    mov rax, SYS_WRITE
    mov rsi, rsp ;
    mov rdx, 1;  Тк выводим chat, то длинна 1 байт
    syscall
    pop rdi
    ret

; Выводит беззнаковое 8-байтовое число в десятичном формате 
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint:
    push NULL_TERMINATOR;Стоп символ для вывода, чтобы потом не мучаться с счетчиком в выводе
    
    xor rcx, rcx
    mov r10, 10
    mov rax, rdi
    .loop:
        mov rsi, rax
        xor rdx, rdx
        div r10
        cmp rax, 0;
        je .output
        add dl, '0'
        push rdx
        inc rcx
        jmp .loop
    .output:
      xor rax, rax
      xor rcx, rcx
      
      add sil, '0'              ;Получаем символ
      push rsi                  ;Первая цифра -> в стек
      .print_loop:
        pop rdi
        cmp rdi, NULL_TERMINATOR;
        je .end

        mov rax, rsp            ; Поскольку в стеке буквы, то он постоянно меняется, поскольку я не выделяю на нем место
        mov rcx, 16             ; Сложно предугадать выравнивание, что
        div rcx                 ; Не плодить много кода, который отличается только
        cmp rdx, 0              ; Выравниванием перед вызовом
        je .not_align           ; Удобнее сделать так
        .aling:                             
            sub rsp, 8
            call print_char
            add rsp, 8
            jmp .print_loop
        .not_align:
            call print_char
            jmp .print_loop
          .end:
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
    xor rax, rax                    ;Очистим rax
    .loop:
        xor rcx, rcx                ;Очистим его на всякий случай
        mov cl, byte[rdi+rax]
        
        
        cmp cl, byte[rsi+rax]
        jne .not
        
        test rcx, rcx               ;Если rcx==0, то оба символа нулевые, т.е строки закончились
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
    push r12        ;Сохраняем callee-saved регистры
    push r13
    push r14
    
    push 0          

    mov rdx, 1
    mov rsi, rsp   

    mov rax, 0
    mov rdi, 0
    syscall

    pop rax
    
    pop r14         ;Востанавливаем callee-saved регистр
    pop r13
    pop r12        
    ret

; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел 0x20, табуляция 0x9 и перевод строки 0xA.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор
read_word:
    push r12
    push r13
    push r14
    
    dec rsi                     ; Здесь jle тк после вычитания из буфера, могло получиться отрицательное число
    cmp rsi, 0                  ;
    jle .small_buff             ;Проверяем наличие буфера
    
    mov r12, rdi                ;Сохраняем адрес буфера
    mov r13, rsi                ;Сохраняем размер буфера
    xor r14, r14                ;Очищаем счетчик символов
    
    .whitespace_skip:
        call read_char
        cmp rax, 0x20           ; Проверка на пробел
        je .whitespace_skip     ;
        cmp rax, 0x9            ; Проверка на табуляцию
        je .whitespace_skip     ;
        cmp rax, 0xA            ; Проверка на перевод строки
        je .whitespace_skip     ;
        cmp rax, NULL_TERMINATOR; Проверка на  ctrl+d
        je .empty_word
    .first_letter:
        mov byte[r12], al      ;Сохраняем символ
        cmp r13, 1
        je .try_last
        mov r14, 1
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
        mov byte[r12+r14], al   ; Сохраняем символ
        inc r14                 ;
        cmp r14, r13            ;
        je .try_last            ; При совпадении счетчика и размера буфера выходим
        jmp .others_loop
    .try_last:
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
        mov byte[r12], NULL_TERMINATOR      ;Добавляем нуль терминатор
        mov rax, 0
        jmp .end
    .success:
        mov rdx, r14
        mov byte[r12+r14], NULL_TERMINATOR  ;Добавляем нуль терминатор
        mov rax, r12;
        jmp .end 
    .empty_word:
        mov rax, r12
        mov rdx, 0
    .end:
        pop r14
        pop r13
        pop r12 
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
    cmp byte[rdi], '+'
    je .positive
    sub rsp, 8
    call parse_uint
    add rsp, 8
    jmp .end
    
    .positive:
        inc rdi
        sub rsp, 8
        call parse_uint
        add rsp, 8
        inc rdx
        jmp .end
    .negative:
        inc rdi
        sub rsp, 8
        call parse_uint
        add rsp, 8
        inc rdx
        neg rax
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
        cmp rdx, 1              ; c 1 тк , надо доп место для нуль-терминатора
        jb .overflow 
        cmp byte[rdi + rax], 0
        je .success       
        mov r9b, byte[rdi+rax]
        mov byte[rsi+rax], r9b
        inc rax
        dec rdx
        jmp .loop
    .overflow:
        mov rax, NULL_TERMINATOR;
        jmp .end
    .success:
        mov byte[rsi+rax], NULL_TERMINATOR
    .end:
        ret



