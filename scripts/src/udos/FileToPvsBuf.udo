/*
FileToPvsBuf - Writes an audio file to a pvs buffer

DESCRIPTION
Writes an audio file in the first k-cycle to a pvs buffer. The buffer is written with pvsbuffer and can be read with pvsread.
This Opcode accepts either Mono or Stereo files as input (from a stereo file, just the first channel is used).

SYNTAX
ibuf, ilen, ktim FileToPvsBuf Sfile, ifftsize, ioverlap, iwinsize, iwinshape

INITIALIZATION
ibuf - variable of the buffer (the value is generated by pvsbuffer)
ilen - length of Sfile (as FileToPvsBuf queries the file length, it puts it out)
Sfile - audio file name in double quotes
ifftsize - fftsize (see Csound manual under pvsanal)
ioverlap - overlap in samples (see Csound manual under pvsanal)
iwinsize - window size (see Csound manual under pvsanal)
iwinshape - 0=Hamming, 1=von-Hann (see Csound manual under pvsanal)

PERFORMANCE
ktim - current time of writing the buffer

CREDITS
joachim heintz 2009
*/

opcode FileToPvsBuf, iik, Siiii
;;writes an audio file at the first k-cycle to a fft-buffer (via pvsbuffer)
;;from a stereo file, just the first channel is used
Sfile, ifftsize, ioverlap, iwinsize, iwinshape xin
ktimek		timeinstk
if ktimek == 1 then
ilen		filelen	Sfile
ichn		filenchnls	Sfile
kcycles	=		ilen * kr; number of k-cycles to write the fft-buffer
kcount		init		0
if ichn == 1 then
loop1:
ain		soundin	Sfile
fftin		pvsanal	ain, ifftsize, ioverlap, iwinsize, iwinshape
ibuf, ktim	pvsbuffer	fftin, ilen + (ifftsize / sr)
		loop_lt	kcount, 1, kcycles, loop1
else
loop2:
ain, ano	soundin	Sfile
fftin		pvsanal	ain, ifftsize, ioverlap, iwinsize, iwinshape
ibuf, ktim	pvsbuffer	fftin, ilen + (ifftsize / sr)
		loop_lt	kcount, 1, kcycles, loop2
endif
		xout		ibuf, ilen, ktim
endif
endop
 