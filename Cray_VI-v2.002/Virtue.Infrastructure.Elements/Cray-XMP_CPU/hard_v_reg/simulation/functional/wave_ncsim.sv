

 
 
 




window new WaveWindow  -name  "Waves for BMG Example Design"
waveform  using  "Waves for BMG Example Design"

      waveform add -signals /hard_v_reg_tb/status
      waveform add -signals /hard_v_reg_tb/hard_v_reg_synth_inst/bmg_port/CLKA
      waveform add -signals /hard_v_reg_tb/hard_v_reg_synth_inst/bmg_port/ADDRA
      waveform add -signals /hard_v_reg_tb/hard_v_reg_synth_inst/bmg_port/DINA
      waveform add -signals /hard_v_reg_tb/hard_v_reg_synth_inst/bmg_port/WEA
      waveform add -signals /hard_v_reg_tb/hard_v_reg_synth_inst/bmg_port/CLKB
      waveform add -signals /hard_v_reg_tb/hard_v_reg_synth_inst/bmg_port/ADDRB
      waveform add -signals /hard_v_reg_tb/hard_v_reg_synth_inst/bmg_port/ENB
      waveform add -signals /hard_v_reg_tb/hard_v_reg_synth_inst/bmg_port/DOUTB

console submit -using simulator -wait no "run"
