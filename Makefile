.PHONY: test smoke rtl clean

test:
	python -m pytest -q

smoke:
	python scripts/run_smoke.py

rtl:
	mkdir -p build
	iverilog -g2012 -s tb_chiplettrust -o build/chiplettrust_tb \
		rtl/common/chiplettrust_pkg.sv \
		rtl/security/lifecycle_ctrl.sv \
		rtl/security/measurement_bank.sv \
		rtl/security/attestation_engine.sv \
		rtl/security/chiplet_endpoint.sv \
		rtl/manager/chiplet_manager.sv \
		rtl/top/chiplettrust_top.sv \
		tb/tb_chiplettrust.sv
	vvp build/chiplettrust_tb
	iverilog -g2012 -s tb_replay_guard -o build/replay_guard_tb \
		rtl/security/replay_guard.sv \
		tb/tb_replay_guard.sv
	vvp build/replay_guard_tb

clean:
	rm -rf build .pytest_cache __pycache__ model/__pycache__ tests/__pycache__
