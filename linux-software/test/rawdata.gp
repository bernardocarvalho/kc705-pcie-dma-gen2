#!/usr/bin/env gnuplot
#
#
clear
# set term png
set term png enhanced font '/usr/share/fonts/liberation/LiberationSans-Regular.ttf' 12
set output 'acqDataRaw.png'

#set xlabel 'Time (s)'
set xlabel 'Samp'
#set xlabel 'mSec'
#set ylabel 'Amp (V)'
set ylabel 'Amp (LSB)'
set title 'KC705 DMA data'

dfile='data.bin'

sampl_freq = 2000000.0
sampl_per = 0.0000005
scaleY= 1.0
#scaleY= 0.0001729
plot_dec =11
# 200
firstl = 1
endl = 1e5

plot dfile binary format='%32int32' every plot_dec::firstl:0:endl  using ($0*1):(($1)*scaleY) with lines lt 1 lw 1  title 'ch0', \
     dfile binary format='%32int16' every plot_dec::firstl:0:endl  using ($0*1):(($2)*scaleY) with lines lt 2 lw 1  title 'Ch1'
     #dfile binary format='%4int16' every plot_dec::firstl:0:endl  using ($0*1):(($3)*scaleY) with lines lt 3 lw 1  title 'Ch6', \
     #dfile binary format='%4int16' every plot_dec::firstl:0:endl  using ($0*1):(($4)*scaleY) with lines lt 4 lw 1  title 'Ch7'

set term x11
#set term wxt
replot
pause -1 "Hit return to continue"
