* unexpand - expand out fields from line
*
* Itagaki Fumihiko 26-Dec-93  Create.
* 1.0
*
* Usage: unexpand [ -aBCZ ] [ -t tab[,...] ] [ -tab[,...] ] [ -- ] [ <�t�@�C��> ] ...

.include doscall.h
.include chrcode.h

.xref DecodeHUPAIR
.xref isdigit
.xref issjis
.xref atou
.xref strlen
.xref strchr
.xref strfor1
.xref strip_excessive_slashes
.xref divul

DEFAULT_TABSTOP	equ	8

STACKSIZE	equ	2048

INPBUF_SIZE_MAX_TO_OUTPUT_TO_COOKED	equ	8192
OUTBUF_SIZE	equ	8192

CTRLD	equ	$04
CTRLZ	equ	$1A

FLAG_a		equ	0	*  -a
FLAG_B		equ	1	*  -B
FLAG_C		equ	2	*  -C
FLAG_Z		equ	3	*  -Z
FLAG_convert	equ	4
FLAG_eof	equ	5


.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	bss_top(pc),a6
		lea	stack_bottom(a6),a7		*  A7 := �X�^�b�N�̒�
		lea	$10(a0),a0			*  A0 : PDB�A�h���X
		move.l	a7,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
		move.l	#-1,stdin(a6)
	*
	*  �������ъi�[�G���A���m�ۂ���
	*
		lea	1(a2),a0			*  A0 := �R�}���h���C���̕�����̐擪�A�h���X
		bsr	strlen				*  D0.L := �R�}���h���C���̕�����̒���
		addq.l	#1,d0
		bsr	malloc
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := �������ъi�[�G���A�̐擪�A�h���X
	*
	*  �������f�R�[�h���C���߂���
	*
		moveq	#0,d6				*  D6.W : �G���[�E�R�[�h
		bsr	DecodeHUPAIR			*  �������f�R�[�h����
		movea.l	a1,a0				*  A0 : �����|�C���^
		move.l	d0,d7				*  D7.L : �����J�E���^
		moveq	#0,d5				*  D5.L : �t���O

		*  �Ƃ肠���� tablist �ɍő僁���������蓖�ĂĂ���
		move.l	#$00ffffff,d0
		bsr	malloc
		sub.l	#$81000000,d0
		move.l	d0,d3				*  D3.L : tablist�̗e��
		subq.l	#4,d3
		blo	insufficient_memory

		bsr	malloc
		bmi	insufficient_memory

		move.l	d0,tablist(a6)
		movea.l	d0,a1				*  A1 : tablist�|�C���^
		moveq	#0,d4				*  D4.L : tabstop�̐�
		clr.l	tabstop(a6)
decode_opt_loop1:
		tst.l	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a0)
		bne	decode_opt_done

		tst.b	1(a0)
		beq	decode_opt_done

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0),d0
		bsr	isdigit
		beq	parse_tablist

		addq.l	#1,a0
		cmp.b	#'-',d0
		bne	decode_opt_loop2

		tst.b	(a0)+
		beq	decode_opt_done

		subq.l	#1,a0
decode_opt_loop2:
		cmp.b	#'t',d0
		beq	parse_tablist

		moveq	#FLAG_a,d1
		cmp.b	#'a',d0
		beq	set_option

		cmp.b	#'B',d0
		beq	option_B_found

		cmp.b	#'C',d0
		beq	option_C_found

		moveq	#FLAG_Z,d1
		cmp.b	#'Z',d0
		beq	set_option

		moveq	#1,d1
		tst.b	(a0)
		beq	bad_option_1

		bsr	issjis
		bne	bad_option_1

		moveq	#2,d1
bad_option_1:
		move.l	d1,-(a7)
		pea	-1(a0)
		move.w	#2,-(a7)
		lea	msg_illegal_option(pc),a0
		bsr	werror_myname_and_msg
		DOS	_WRITE
		lea	10(a7),a7
usage:
		lea	msg_usage(pc),a0
werror_exit_1:
		bsr	werror
exit_1:
		moveq	#1,d6
		bra	exit_program

parse_tablist:
		tst.b	(a0)
		bne	parse_tablist_loop

		subq.l	#1,d7
		bcs	too_few_args

		addq.l	#1,a0
parse_tablist_loop:
		bsr	atou
		bne	bad_tablist

		subq.l	#4,d3
		bcs	insufficient_memory

		move.l	d1,(a1)+
		beq	bad_tablist

		cmp.l	tabstop(a6),d1
		bls	bad_tablist

		move.l	d1,tabstop(a6)
		addq.l	#1,d4
		move.b	(a0)+,d0
		cmp.b	#',',d0
		beq	parse_tablist_loop

		tst.b	d0
		bne	bad_tablist

		clr.l	(a1)
		bra	decode_opt_loop1

too_few_args:
		lea	msg_too_few_args(pc),a0
werror_usage:
		bsr	werror_myname_and_msg
		bra	usage

bad_tablist:
		lea	msg_bad_tablist(pc),a0
		bra	werror_usage

option_B_found:
		bclr	#FLAG_C,d5
		bset	#FLAG_B,d5
		bra	set_option_done

option_C_found:
		bclr	#FLAG_B,d5
		bset	#FLAG_C,d5
		bra	set_option_done

set_option:
		bset	d1,d5
set_option_done:
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_opt_done:
		*  tablist �� fix ����
		movea.l	tablist(a6),a2
		subq.l	#1,d4
		blo	set_default_tabstop
		beq	free_tablist

		clr.l	(a1)+
		move.l	a1,d0
		sub.l	a2,d0
		move.l	d0,-(a7)
		move.l	a2,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
		clr.l	tabstop(a6)
		bra	tablist_ok

set_default_tabstop:
		move.l	#DEFAULT_TABSTOP,tabstop(a6)
free_tablist:
		move.l	a2,-(a7)
		DOS	_MFREE
		addq.l	#4,a7
tablist_ok:
		moveq	#1,d0				*  �o�͂�
		bsr	is_chrdev			*  �L�����N�^�E�f�o�C�X���H
		seq	do_buffering(a6)
		beq	input_max			*  -- block device

		*  character device
		btst	#5,d0				*  '0':cooked  '1':raw
		bne	input_max

		*  cooked character device
		move.l	#INPBUF_SIZE_MAX_TO_OUTPUT_TO_COOKED,d0
		btst	#FLAG_B,d5
		bne	inpbufsize_ok

		bset	#FLAG_C,d5			*  ���s��ϊ�����
		bra	inpbufsize_ok

input_max:
		move.l	#$00ffffff,d0
inpbufsize_ok:
		move.l	d0,inpbuf_size(a6)
		*  �o�̓o�b�t�@���m�ۂ���
		tst.b	do_buffering(a6)
		beq	outbuf_ok

		move.l	#OUTBUF_SIZE,d0
		move.l	d0,outbuf_free(a6)
		bsr	malloc
		bmi	insufficient_memory

		move.l	d0,outbuf_top(a6)
		move.l	d0,outbuf_ptr(a6)
outbuf_ok:
		*  ���̓o�b�t�@���m�ۂ���
		move.l	inpbuf_size(a6),d0
		bsr	malloc
		bpl	inpbuf_ok

		sub.l	#$81000000,d0
		move.l	d0,inpbuf_size(a6)
		bsr	malloc
		bmi	insufficient_memory
inpbuf_ok:
		move.l	d0,inpbuf_top(a6)
	*
	*  �W�����͂�؂�ւ���
	*
		clr.w	-(a7)				*  �W�����͂�
		DOS	_DUP				*  ���������n���h��������͂��C
		addq.l	#2,a7
		move.l	d0,stdin(a6)
		bmi	start_do_files

		clr.w	-(a7)
		DOS	_CLOSE				*  �W�����͂̓N���[�Y����D
		addq.l	#2,a7				*  �������Ȃ��� ^C �� ^S �������Ȃ�
start_do_files:
	*
	*  �J�n
	*
		tst.l	d7
		beq	do_stdin
for_file_loop:
		subq.l	#1,d7
		movea.l	a0,a1
		bsr	strfor1
		exg	a0,a1
		cmpi.b	#'-',(a0)
		bne	do_file

		tst.b	1(a0)
		bne	do_file
do_stdin:
		lea	msg_stdin(pc),a0
		move.l	stdin(a6),d2
		bmi	open_file_failure

		bsr	unexpand_one
		bra	for_file_continue

do_file:
		bsr	strip_excessive_slashes
		clr.w	-(a7)
		move.l	a0,-(a7)
		DOS	_OPEN
		addq.l	#6,a7
		move.l	d0,d2
		bmi	open_file_failure

		bsr	unexpand_one
		move.w	d2,-(a7)
		DOS	_CLOSE
		addq.l	#2,a7
for_file_continue:
		movea.l	a1,a0
		tst.l	d7
		bne	for_file_loop

		bsr	flush_outbuf
exit_program:
		move.l	stdin(a6),d0
		bmi	exit_program_1

		clr.w	-(a7)				*  �W�����͂�
		move.w	d0,-(a7)			*  ����
		DOS	_DUP2				*  �߂��D
		DOS	_CLOSE				*  �����̓N���[�Y����D
exit_program_1:
		move.w	d6,-(a7)
		DOS	_EXIT2

open_file_failure:
		bsr	werror_myname_and_msg
		lea	msg_open_fail(pc),a0
		bsr	werror
		moveq	#2,d6
		bra	for_file_continue
****************************************************************
* unexpand_one
****************************************************************
unexpand_one:
		btst	#FLAG_Z,d5
		sne	terminate_by_ctrlz(a6)
		sf	terminate_by_ctrld(a6)
		move.w	d2,d0
		bsr	is_chrdev
		beq	unexpand_one_start		*  -- �u���b�N�E�f�o�C�X

		btst	#5,d0				*  '0':cooked  '1':raw
		bne	unexpand_one_start

		st	terminate_by_ctrlz(a6)
		st	terminate_by_ctrld(a6)
unexpand_one_start:
		bclr	#FLAG_eof,d5
		moveq	#0,d3
unexpand_one_loop1:
		bset	#FLAG_convert,d5
		clr.b	lastchar(a6)
		clr.l	num_pending_space(a6)
unexpand_one_loop2:
		moveq	#0,d4				*  D4.L : location counter
unexpand_one_loop3:
		movea.l	tablist(a6),a2			*  A2 : tablist pointer
		movea.l	a2,a4				*  A4 : tablist pointer for flush
unexpand_one_loop4:
		subq.l	#1,d3
		bcc	unexpand_one_1

		btst	#FLAG_eof,d5
		bne	unexpand_one_eof

		movea.l	inpbuf_top(a6),a3
		move.l	inpbuf_size(a6),-(a7)
		move.l	a3,-(a7)
		move.w	d2,-(a7)
		DOS	_READ
		lea	10(a7),a7
		move.l	d0,d3
		bmi	read_fail

		tst.b	terminate_by_ctrlz(a6)
		beq	trunc_ctrlz_done

		moveq	#CTRLZ,d0
		bsr	trunc
trunc_ctrlz_done:
		tst.b	terminate_by_ctrld(a6)
		beq	trunc_ctrld_done

		moveq	#CTRLD,d0
		bsr	trunc
trunc_ctrld_done:
		subq.l	#1,d3
		bcs	unexpand_one_eof
unexpand_one_1:
		move.b	(a3)+,d0
		move.b	lastchar(a6),d1
		move.b	d0,lastchar(a6)
		btst	#FLAG_convert,d5
		beq	unexpand_one_2

		cmp.b	#HT,d0
		beq	unexpand_one_ht

		cmp.b	#' ',d0
		beq	unexpand_one_space
unexpand_one_2:
		bsr	flush_pendings
		cmp.b	#LF,d0
		beq	unexpand_one_lf

		btst	#FLAG_convert,d5
		beq	unexpand_one_putc

		cmp.b	#BS,d0
		beq	unexpand_one_bs

		cmp.b	#CR,d0
		beq	unexpand_one_cr

		btst	#FLAG_a,d5
		bne	unexpand_one_putc

		bclr	#FLAG_convert,d5
unexpand_one_putc:
		bsr	putc
		addq.l	#1,d4
		bra	unexpand_one_loop4

unexpand_one_bs:
		bsr	putc
		tst.l	d4
		beq	unexpand_one_bs_1

		subq.l	#1,d4
unexpand_one_bs_1:
		bra	unexpand_one_loop3

unexpand_one_cr:
		bsr	putc
		bra	unexpand_one_loop2

unexpand_one_unexpand_ht_nomore:
		bclr	#FLAG_convert,d5
		moveq	#HT,d0
		bra	unexpand_one_2

unexpand_one_ht:
		move.l	tabstop(a6),d1
		bne	unexpand_one_simple_tabstop
unexpand_one_search_next_tabstop:
		move.l	(a2),d0
		beq	unexpand_one_unexpand_ht_nomore

		addq.l	#4,a2
		cmp.l	d4,d0
		bls	unexpand_one_search_next_tabstop

		sub.l	d4,d0
		bra	unexpand_one_unexpand_ht

unexpand_one_simple_tabstop:
		move.l	d4,d0
		bsr	divul
		move.l	tabstop(a6),d0
		sub.l	d1,d0
unexpand_one_unexpand_ht:
		add.l	d0,num_pending_space(a6)
		add.l	d0,d4
		bra	unexpand_one_loop4

unexpand_one_space:
		moveq	#1,d0
		bra	unexpand_one_unexpand_ht

unexpand_one_lf:
		btst	#FLAG_C,d5
		beq	unexpand_one_lf_1

		cmp.b	#CR,d1
		beq	unexpand_one_lf_1

		move.l	d0,-(a7)
		moveq	#CR,d0
		bsr	putc
		move.l	(a7)+,d0
unexpand_one_lf_1:
		bsr	putc
		bra	unexpand_one_loop1

unexpand_one_eof:
flush_pendings:
		move.l	num_pending_space(a6),d1
		beq	flush_pendings_return

		move.l	d0,-(a7)
		cmp.l	#1,d1
		beq	flush_pendings_last_2

		sub.l	d1,d4
flush_pendings_loop:
		move.l	tabstop(a6),d1
		bne	flush_pendings_simple_tabstop

		movea.l	a4,a5
flush_pendings_search_next_tabstop:
		move.l	(a4),d0
		beq	flush_pendings_no_next_tabstop

		cmp.l	d4,d0
		bhi	flush_pendings_search_next_ok

		movea.l	a4,a5
		addq.l	#4,a4
		bra	flush_pendings_search_next_tabstop

flush_pendings_search_next_ok:
		sub.l	d4,d0
		bra	flush_pendings_1

flush_pendings_simple_tabstop:
		move.l	d4,d0
		bsr	divul
		move.l	tabstop(a6),d0
		sub.l	d1,d0
flush_pendings_1:
		cmp.l	num_pending_space(a6),d0
		bhi	flush_pendings_last

		move.l	d0,d1
		moveq	#HT,d0
		bsr	putc
		add.l	d1,d4
		sub.l	d1,num_pending_space(a6)
		bne	flush_pendings_loop
		bra	flush_pendings_done

flush_pendings_last:
		movea.l	a5,a4
flush_pendings_no_next_tabstop:
		move.l	num_pending_space(a6),d1
		add.l	d1,d4
flush_pendings_last_2:
		moveq	#' ',d0
flush_pendings_last_loop:
		bsr	putc
		subq.l	#1,d1
		bne	flush_pendings_last_loop

		clr.l	num_pending_space(a6)
flush_pendings_done:
		move.l	(a7)+,d0
flush_pendings_return:
		rts
*****************************************************************
trunc:
		movem.l	d1/a0,-(a7)
		move.l	d3,d1
		beq	trunc_done

		movea.l	a3,a0
trunc_find_loop:
		cmp.b	(a0)+,d0
		beq	trunc_found

		subq.l	#1,d1
		bne	trunc_find_loop
		bra	trunc_done

trunc_found:
		move.l	a0,d3
		subq.l	#1,d3
		sub.l	a3,d3
		bset	#FLAG_eof,d5
trunc_done:
		movem.l	(a7)+,d1/a0
		rts
*****************************************************************
putc:
		movem.l	d0/a0,-(a7)
		tst.b	do_buffering(a6)
		bne	putc_buffering

		move.w	d0,-(a7)
		move.l	#1,-(a7)
		pea	5(a7)
		move.w	#1,-(a7)
		DOS	_WRITE
		lea	12(a7),a7
		cmp.l	#1,d0
		bne	write_fail
		bra	putc_done

putc_buffering:
		tst.l	outbuf_free(a6)
		bne	putc_buffering_1

		bsr	flush_outbuf
putc_buffering_1:
		movea.l	outbuf_ptr(a6),a0
		move.b	d0,(a0)+
		move.l	a0,outbuf_ptr(a6)
		subq.l	#1,outbuf_free(a6)
putc_done:
		movem.l	(a7)+,d0/a0
		rts
*****************************************************************
flush_outbuf:
		move.l	d0,-(a7)
		tst.b	do_buffering(a6)
		beq	flush_return

		move.l	#OUTBUF_SIZE,d0
		sub.l	outbuf_free(a6),d0
		beq	flush_return

		move.l	d0,-(a7)
		move.l	outbuf_top(a6),-(a7)
		move.w	#1,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	write_fail

		cmp.l	-4(a7),d0
		blo	write_fail

		move.l	outbuf_top(a6),d0
		move.l	d0,outbuf_ptr(a6)
		move.l	#OUTBUF_SIZE,d0
		move.l	d0,outbuf_free(a6)
flush_return:
		move.l	(a7)+,d0
		rts
*****************************************************************
insufficient_memory:
		bsr	werror_myname
		lea	msg_no_memory(pc),a0
		bra	werror_exit_3
*****************************************************************
read_fail:
		bsr	werror_myname_and_msg
		lea	msg_read_fail(pc),a0
		bra	werror_exit_3
*****************************************************************
write_fail:
		lea	msg_write_fail(pc),a0
werror_exit_3:
		bsr	werror
		moveq	#3,d6
		bra	exit_program
*****************************************************************
werror_myname:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		rts
*****************************************************************
werror_myname_and_msg:
		bsr	werror_myname
werror:
		movem.l	d0/a1,-(a7)
		movea.l	a0,a1
werror_1:
		tst.b	(a1)+
		bne	werror_1

		subq.l	#1,a1
		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		movem.l	(a7)+,d0/a1
		rts
*****************************************************************
is_chrdev:
		move.w	d0,-(a7)
		clr.w	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		tst.l	d0
		bpl	is_chrdev_1

		moveq	#0,d0
is_chrdev_1:
		btst	#7,d0
		rts
*****************************************************************
malloc:
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## unexpand 1.0 ##  Copyright(C)1993 by Itagaki Fumihiko',0

msg_myname:		dc.b	'unexpand: ',0
msg_no_memory:		dc.b	'������������܂���',CR,LF,0
msg_open_fail:		dc.b	': �I�[�v���ł��܂���',CR,LF,0
msg_read_fail:		dc.b	': ���̓G���[',CR,LF,0
msg_write_fail:		dc.b	'unexpand: �o�̓G���[',CR,LF,0
msg_stdin:		dc.b	'- �W������ -',0
msg_illegal_option:	dc.b	'�s���ȃI�v�V���� -- ',0
msg_too_few_args:	dc.b	'����������܂���',0
msg_bad_tablist:	dc.b	'�^�u�X�g�b�v�̃��X�g���s���ł�',0
msg_usage:		dc.b	CR,LF
	dc.b	'�g�p�@:  unexpand [-aBCZ] [-t <tab>[,...]] [-<tab>[,...]] [--] [<�t�@�C��>] ...',CR,LF,0
*****************************************************************
.bss
.even
bss_top:

.offset 0
stdin:			ds.l	1
inpbuf_top:		ds.l	1
inpbuf_size:		ds.l	1
outbuf_top:		ds.l	1
outbuf_ptr:		ds.l	1
outbuf_free:		ds.l	1
tabstop:		ds.l	1
tablist:		ds.l	1
num_pending_space:	ds.l	1
do_buffering:		ds.b	1
terminate_by_ctrlz:	ds.b	1
terminate_by_ctrld:	ds.b	1
lastchar:		ds.b	1

.even
			ds.b	STACKSIZE
.even
stack_bottom:

.bss
		ds.b	stack_bottom
*****************************************************************

.end start
