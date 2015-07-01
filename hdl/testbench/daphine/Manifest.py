action = "simulation"
target = "xilinx"
vcom_opt = "-2008"

syn_device = "xc7a200t"
sim_tool = "modelsim"
top_module = "daphine_tb"

modules = {"local" : ["../../",  "../../ip_cores/general-cores/"]}

files = ["daphine_tb.vhd"]

machine_pkg = "uvx_130M"