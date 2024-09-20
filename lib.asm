%define SYS_READ 0
%define SYS_WRITE 1
%define SYS_EXIT 60

%define STD_IN 0
%define STD_OUT 1
%define ST_ERR 2

section .text
    
; Принимает код возврата и завершает текущий процесс
exit:
    ; код возвратаи так уже в rdi как аргумент
    mov rax, SYS_EXIT; 
    syscall

; Принимает указатель на нуль-терминированную строку, возвращает её длину
string_length:
    xor rax, rax                ; Очистить rax
    .loop:
        cmp byte[rdi+rax], `\0`
        je .end
        inc rax
        jmp .loop
     .end:
        ret

; Принимает указатель на нуль-терминированную строку, выводит её в stdout
print_string:
    xor rax, rax                ; Сбрасываем фла
    push rdi
    call string_length
    mov rdx, rax
    pop rsi
    mov rdi, STD_OUT            ; то положим его на стек, и получим через rsp
    mov rax, SYS_WRITE
    syscall
    ret

; Переводит строку (выводит символ с кодом `\n`)
print_newline:
    mov rdi, `\n`

; Принимает код символа и выводит его в stdout
print_char:
    push rdi                    ; Тк в rdi лежит код символа, а нам надо *char_buf 
    mov rdi, STD_OUT            ; то положим его на стек, и получим через rsp
    mov rax, SYS_WRITE
    mov rsi, rsp ;
    mov rdx, 1                  ; Тк выводим chat, то длинна 1 байт
    syscall
    pop rdi
    ret

; Выводит беззнаковое 8-байтовое число в десятичном формате 
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint:
    sub rsp, 24                 ;
    
    mov byte[rsp+21], `\0`      ;Тк максимальное 8-байтовое число имеет 20 цифр, то мы 21 кладем нуль-терминатор
    mov rcx, 20                 ;Соответственно rcх=20, чтобы класть символы в обратном порядке(для корректного вывода)
                                ;Если класть в нормальном(увеличивая rcx) то строка будет в обратном порядке
    mov r10, 10                 
    mov rax, rdi                
    .loop:
        mov rsi, rax
        xor rdx, rdx
        div r10
        test rax, rax
        je .output
        add dl, '0'             ;Получаем символ из цифры
        mov byte[rsp+rcx], dl
        dec rcx
        jmp .loop
    .output:
      
      add sil, '0'              ;Получаем символ
      mov byte[rsp+rcx], sil
      lea rdi, [rsp+rcx]
      call print_string
    .end:
        add rsp, 24
        ret
        
; Выводит знаковое 8-байтовое число в десятичном формате 
print_int:
    push rdi
    cmp rdi, 0
    jge .positive
    mov rdi, '-'
    call print_char
    mov rdi, qword[rsp]         ; Можно было сделать pop, но тогда проблемы с выравниванием
    neg rdi
  .positive:
    call print_uint
    pop rax
    ret

; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе
string_equals:
    ;rdi - 1 строка
    ;rsi - 2 строка
    xor rax, rax                ; Очистим rax
    .loop:
        xor rcx, rcx            ; Очистим его на всякий случай
        mov cl, byte[rdi+rax]
        cmp cl, byte[rsi+rax]
        jne .not
        
        test rcx, rcx           ; Если rcx==0, то оба символа нулевые, т.е строки закончились
        je .yes
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
    mov rax, SYS_READ
    mov rdi, STD_IN
    syscall
    pop rax
    ret

; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел ' ', табуляция `\t` и перевод строки `\n`.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор
read_word:
    push r12
    push r13
    push r14
    
    mov r12, rdi                ; Сохраняем адрес буфера
    mov r13, rsi                ; Сохраняем размер буфера
    xor r14, r14                ; Очищаем счетчик символов
      
    
    .whitespace_skip:           ; Сначала пропускаем пробелы
        call read_char
        cmp al, ' '             ; Проверка на пробел
        je .whitespace_skip     ;
        cmp al, `\t`            ; Проверка на табуляцию
        je .whitespace_skip     ;
        cmp al, `\n`            ; Проверка на перевод строки
        je .whitespace_skip     ;

    .non_space_loop:
        cmp r13, r14
        jb .fail
        
        mov byte[r12+r14], al
        cmp al, `\0`
        je .success 
        inc r14                 ; Возможно после поставить
        call read_char
        
        cmp al, ' '             ; Проверка на пробел
        je .space_symbol        ;
        cmp al, `\t`            ; Проверка на табуляцию
        je .space_symbol        ;
        cmp al, `\n`            ; Проверка на перевод строки
        je .space_symbol        ;
        jmp .non_space
        .space_symbol:
            mov al, `\0`
        .non_space:
            jmp .non_space_loop
    .fail:
        mov rax, 0
        jmp .end
    .success:
        mov rax, r12
        mov rdx, r14
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
    xor rax, rax		    ; Регистр для числа
    xor rcx, rcx		    ; Буфер
    xor r8, r8                  ; Длинна данного числа (Число обозначает сдвиг относительно указателя)     
    mov r11, 10
	.loop:
	    xor rcx, rcx         ; Обнуление буффера
  	    mov cl, [rdi+r8]	    ; Чтение цифры [rdi+rdx]
	    cmp cl, '9'          ; Если больше '9', то выход
	    ja .end
	    sub rcx, '0'         ; Перевод из ASCII в число
           jb .end
	    mul r11              ; Умножаем прошлое число x10
	    add rax, rcx	    ; Получаем новое число rax = rax * 10 + rcx
	    inc r8               ; Увеличиваем длину числа
	    jmp .loop
	.end:
           mov rdx, r8
 	    ret

; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был) 
; rdx = 0 если число прочитать не удалось
parse_int:
    sub rsp, 8
    cmp byte[rdi], '-'
    je .negative
    cmp byte[rdi], '+'
    je .positive
    call parse_uint
    jmp .end
    .positive:
        inc rdi
        call parse_uint
        inc rdx
        jmp .end
    .negative:
        inc rdi
        call parse_uint
        inc rdx
        neg rax
    .end:
        add rsp, 8
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
        mov rax, 0;
        jmp .end
    .success:
        mov byte[rsi+rax], `\0`
    .end:
        ret

