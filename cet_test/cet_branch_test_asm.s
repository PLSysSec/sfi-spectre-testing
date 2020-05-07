	.text
	.p2align 4
	.globl	indirect_call
	.type	indirect_call, @function
indirect_call:
.LFB42:
	.cfi_startproc
	endbr64
	ret
	.cfi_endproc

	.text
	.globl	main
	.type	main, @function
main:
	.cfi_startproc
	endbr64
	leaq	4+indirect_call(%rip), %rdx
	call	*%rdx
	movl	$0, %eax
	ret
	.cfi_endproc

// Magic incantation for enabling CET
	.section	.note.gnu.property,"a"
	.align 8
	.long	 1f - 0f
	.long	 4f - 1f
	.long	 5
0:
	.string	 "GNU"
1:
	.align 8
	.long	 0xc0000002
	.long	 3f - 2f
2:
	.long	 0x3
3:
	.align 8
4:
