FILES := depacketizer.vhd
TB    := tb.vhd

GHDL := ghdl
GHDL_FLAGS := --std=08
WAVE_FILE := waveform.ghw
GTKW_FILE := waveform.gtkw

all: analyze elaborate run view

analyze:
	$(GHDL) -a $(GHDL_FLAGS) $(FILES) $(TB)

elaborate:
	$(GHDL) -e $(GHDL_FLAGS) tb

run:
	$(GHDL) -r $(GHDL_FLAGS) tb --wave=$(WAVE_FILE)

view:
	gtkwave $(WAVE_FILE) $(GTKW_FILE)

save-gtkwave:
	@echo "Save your GTKWave settings as $(GTKW_FILE) manually after opening it."