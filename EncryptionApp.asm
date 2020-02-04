masm
model small
.data
	welcome_msg db 9, 9, 9, 'Welcome to the Encryptinator!', 13, 10, '$'
	command_menu db 'Commands menu:', 13, 10,  9, '1 - Encrypt current string', 13, 10, 9, '2 - Decrypt current string', 13, 10, 9, '3 - Save current string state in a file', 13, 10, 9, '4 - Print commands menu', 13, 10, 9, '5 - Exit the program', '$'
	prompt_msg db 'Enter your command: $'
	encrypt_delay_msg db 'Encrypting...$'
	decrypt_delay_msg db 'Decrypting...$'
	save_delay_msg db 'Saving...$'
	save_successful_msg db 'String saved successfully$'
	exit_delay_msg db 'Exiting the program...$'
	decrypted_exception_msg db 'Message is already fully decrypted$'
	encrypted_exception_msg db 'Message already has the strongest encryption$'
	file_exception_msg db 'Oops, something went wrong while working with the file.$'
	invalid_command_msg db 'Invalid command number. Press 4 to see the available commands.$'
	table_for_xor db 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
	crlf db 13, 10, '$'
	in_file db 'in_file.txt', 0
	out_file db 'out_file.txt', 0
	file_content db 201 dup ('$')
	encryption_lvl db 0
	in_file_ref dw ?
	out_file_ref dw ?
	content_size dw ?
	
stack 256

.code
main:
	mov ax, @data
	mov ds, ax
	
	; Open file
	mov ah, 3dh
	xor al, al; Open for reading only
	lea dx, in_file; Load file name
	int 21h
	
	jnc read
	call handleFileException; Carry flag is up -> File could not be read -> Print error message and exit
	
	read:
	mov in_file_ref, ax ; Save the reference name for the file
	mov ah, 3fh
	mov bx, in_file_ref
	mov cx, 200 ; Set number of bytes to read to 200
	lea dx, file_content
	int 21h
	mov content_size, ax ; Number of read bytes are in ax
	jnc close
	call handleFileException
	
	close:
	mov ah, 3eh
	int 21h
	jnc welcome
	call handleFileException

welcome:
	lea dx, welcome_msg
	call printString
print_menu:
	lea dx, command_menu
	call printString
	jmp interpret_commands
	
encrypt:
	cmp encryption_lvl, 3
	jnge prev1
	lea dx, encrypted_exception_msg
	call printString
	jmp interpret_commands
	prev1:
	lea dx, encrypt_delay_msg
	cmp encryption_lvl, 2
	jne prev2
	call delayWithMsg
	call encryptDecryptWithTableXor
	inc encryption_lvl
	jmp interpret_commands
	prev2:
	cmp encryption_lvl, 1
	jne prev3
	call delayWithMsg
	call encryptDecryptWithXor
	inc encryption_lvl
	jmp interpret_commands
	prev3:
	call delayWithMsg
	call encryptWithCharShift
	jmp interpret_commands
	
interpret_commands:
	lea dx, prompt_msg
	call printString
	mov ah, 01h ; Read user's command
	int 21h
	cmp al, '1'
	je encrypt
	cmp al, '2'
	je decrypt
	cmp al, '3'
	je save_current_str
	cmp al, '4'
	je print_menu
	cmp al, '5'
	jne invalid_command
	jmp exit
	
decrypt:
	cmp encryption_lvl, 0
	jnle next1
	lea dx, decrypted_exception_msg
	call printString
	jmp interpret_commands
	next1:
	lea dx, decrypt_delay_msg
	cmp encryption_lvl, 1
	jne next2
	call delayWithMsg
	call decryptWithCharShift
	jmp interpret_commands
	next2:
	cmp encryption_lvl, 2
	jne next3
	call delayWithMsg
	call encryptDecryptWithXor
	dec encryption_lvl
	jmp interpret_commands
	next3:
	call delayWithMsg
	call encryptDecryptWithTableXor
	dec encryption_lvl
	jmp interpret_commands
	
save_current_str:
	lea dx, save_delay_msg
	call delayWithMsg
	; Create new file
	mov ah, 3ch
	xor cx, cx ; Make it standard
	lea dx, out_file
	int 21h
	jnc write_file
	call handleFileException
	
	write_file:
	mov out_file_ref, ax
	mov ah, 40h
	mov bx, out_file_ref
	mov cx, content_size
	lea dx, file_content
	int 21h
	jnc close_file
	call handleFileException
	
	close_file:
	mov ah, 3eh
	int 21h
	jnc saved_successfully
	call handleFileException
	
invalid_command:
	lea dx, invalid_command_msg
	call printString
	jmp interpret_commands
	
saved_successfully:
	lea dx, save_successful_msg
	call printString
	jmp interpret_commands
	
decrypted_exception:
	lea dx, decrypted_exception_msg
	call printString
	jmp interpret_commands

handleFileException proc
	lea dx, file_exception_msg
	call printString
	jmp exit
	ret
handleFileException endp
	
printString proc
	push ax
	push dx
	mov ah, 09h
	lea dx, crlf
	int 21h
	int 21h
	pop dx
	int 21h
	pop ax
	ret
printString endp

decryptWithCharShift proc
	push bx
	push cx
	push dx
	push si
	xor si, si
	mov cx, content_size
	
	d_char_shift_loop:
	mov bh, file_content[si]
	sub bh, 26
	; Check for underflow
	cmp bh, 0
	jge its_in_range_d
	add bh, 128
	its_in_range_d:
	mov file_content[si], bh
	inc si
	loop d_char_shift_loop
	dec encryption_lvl
	lea dx, file_content
	call printString
	pop si
	pop dx
	pop cx
	pop bx
	ret
decryptWithCharShift endp

encryptWithCharShift proc
	push bx
	push cx
	push dx
	push si
	xor si, si
	mov cx, content_size
	
	e_char_shift_loop:
	mov bh, file_content[si]
	add bh, 26
	; Check for overflow
	cmp bh, 128
	jl its_in_range_e
	sub bh, 128
	its_in_range_e:
	mov file_content[si], bh
	inc si
	loop e_char_shift_loop
	inc encryption_lvl
	lea dx, file_content
	call printString
	pop si
	pop dx
	pop cx
	pop bx
	ret
	
encryptWithCharShift endp

encryptDecryptWithXor proc
	push cx
	push dx
	push si
	xor si, si
	mov cx, content_size
	
	basic_xor_loop:
	xor file_content[si], 0c4h ; XOR with a key
	inc si
	loop basic_xor_loop
	lea dx, file_content
	call printString
	pop si
	pop dx
	pop cx
	ret
encryptDecryptWithXor endp

encryptDecryptWithTableXor proc
	push bx
	push cx
	push dx
	push si
	push di
	xor si, si
	xor di, di
	mov cx, content_size
	
	table_xor_loop:
	cmp di, 26
	jne nextIt
	xor di, di
	nextIt:
	mov bh, table_for_xor[di]
	xor file_content[si], bh
	inc si
	inc di
	loop table_xor_loop
	lea dx, file_content
	call printString
	pop di
	pop si
	pop dx
	pop cx
	pop bx
	ret
encryptDecryptWithTableXor endp

delayWithMsg proc
	; Parameter is in dx
	push ax
	push dx
	push cx
	call printString
	mov cx, 0fh
	mov dx, 4240h
	mov ah, 86h
	int 15h
	pop dx
	pop cx
	pop ax
	ret
delayWithMsg endp

exit:
	lea dx, exit_delay_msg
	call delayWithMsg
	mov ah, 4ch
	int 21h
	
end main