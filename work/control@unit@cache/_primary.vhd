library verilog;
use verilog.vl_types.all;
entity controlUnitCache is
    port(
        clk             : in     vl_logic;
        rst_b           : in     vl_logic;
        cin             : in     vl_logic_vector(1 downto 0);
        cout            : out    vl_logic_vector(1 downto 0)
    );
end controlUnitCache;
