component fir_shift_reg is
    port(
        clk_i: in std_logic;
        rst_i: in std_logic;
        clk_en_i: in std_logic;
        wr_data_i: in std_logic_vector(11 downto 0);
        rd_data_o: out std_logic_vector(11 downto 0)
    );
end component;

__: fir_shift_reg port map(
    clk_i=>,
    rst_i=>,
    clk_en_i=>,
    wr_data_i=>,
    rd_data_o=>
);
