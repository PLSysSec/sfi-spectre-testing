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
