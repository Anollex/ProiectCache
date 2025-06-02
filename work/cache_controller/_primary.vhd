library verilog;
use verilog.vl_types.all;
entity cache_controller is
    port(
        clk             : in     vl_logic;
        rst             : in     vl_logic;
        start           : in     vl_logic;
        read_write      : in     vl_logic;
        hit_miss        : in     vl_logic;
        state_out       : out    vl_logic_vector(3 downto 0)
    );
end cache_controller;
