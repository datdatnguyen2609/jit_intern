module bcd2led7seg_tb_simple;

    // Inputs
    reg clk;
    reg rst;
    reg [15:0] sw;
    
    // Outputs
    wire [7:0] seg_out;
    wire [4:0] anode;
    wire [2:0] anode_off;
    
    // Instantiate the Unit Under Test (UUT)
    bcd2led7seg uut (
        .clk(clk), 
        .rst(rst), 
        .sw(sw), 
        .seg_out(seg_out), 
        .anode(anode),
        .anode_off(anode_off)
    );

    // Generate clock - 100MHz
    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 10ns period = 100MHz
    end

    initial begin
        rst = 1'b1;
        #10;
        rst = 1'b0;
        #10;
        sw = 16'h0000;
        #1_000_000_000;
        sw = 16'hfffe;
        #1_000_000_000;
        $finish;
    end
endmodule