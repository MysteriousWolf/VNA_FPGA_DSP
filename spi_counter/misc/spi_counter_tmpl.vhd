component spi_counter is
    port(
        clk_i: in std_logic;
        clk_en_i: in std_logic;
        aclr_i: in std_logic;
        q_o: out std_logic_vector(4 downto 0)
    );
end component;

__: spi_counter port map(
    clk_i=>,
    clk_en_i=>,
    aclr_i=>,
    q_o=>
);
