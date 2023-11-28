`timescale 1ns/1ps

module sdp_1 #(
		  parameter file1     =   "/home/wisig/Downloads/Vijaya/datagen_gen/v.txt",
        parameter ADDR_WIDTH = 32'd10,
        parameter DATA_WIDTH = 32'd32,
        parameter PIPE_DEPTH = 1 // 1 is the minimum number of FFs required
    )
    (
        input clk,
        input ena,
        input wea,
        input [ADDR_WIDTH - 1:0] addra,
        input [DATA_WIDTH - 1:0] dina,
        input enb,
        input [ADDR_WIDTH - 1:0] addrb, 
        output [DATA_WIDTH - 1:0] doutb
    );
    
    localparam DEPTH = (1 << ADDR_WIDTH);
    
    reg [DATA_WIDTH - 1:0] ram [DEPTH - 1:0];
    
    reg ena_d, wea_d, enb_d;
    reg [ADDR_WIDTH - 1:0] addra_d, addrb_d;
    reg [DATA_WIDTH - 1:0] dina_d;

    // output reg
    reg [DATA_WIDTH - 1:0] doutb_reg [PIPE_DEPTH - 1:0];
    
    integer i;
    initial begin
        //! removing init value as the intel tool does not allow loop trip count more than 5000
        // for(i = 0; i < DEPTH; i = i + 1) begin
        //     ram[i] = 0;
        // end
        for(i = 0; i < PIPE_DEPTH; i = i + 1) begin
            doutb_reg[i] = 0;
        end
    end

generate 
        initial begin
         	 $readmemh(file1, ram);
        end
endgenerate

    always @(posedge clk) begin
        ena_d <= ena;
        enb_d <= enb;
        wea_d <= wea;
        addra_d <= addra;
        addrb_d <= addrb;
        dina_d <= dina;
    end

    always @(posedge clk) begin
        if (ena_d) begin
            if (wea_d)
                ram[addra_d] <= dina_d;
        end
        
        if(enb_d) begin
            doutb_reg[0] <= ram[addrb_d];
        end
        //! is enb required on _d register?
    end

    genvar pipe_i;
    generate 
        /* shift register */
        for(pipe_i = 0; pipe_i < (PIPE_DEPTH - 1); pipe_i = pipe_i + 1) begin
            always @(posedge clk) begin
                doutb_reg[pipe_i + 1] <= doutb_reg[pipe_i];
            end
        end
    endgenerate

    assign doutb = doutb_reg[PIPE_DEPTH - 1];
endmodule

