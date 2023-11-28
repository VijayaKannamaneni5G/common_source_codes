//************************************************************************************************//
/*
* Copyright (c) 2016-2019, WiSig Networks Pvt Ltd. All rights reserved.
* www.wisig.com
*
* All information contained herein is property of WiSig Networks Pvt Ltd.
* unless otherwise explicitly mentioned.
*
* The intellectual and technical concepts in this file are proprietary
* to WiSig Networks and may be covered by granted or in process national
* and international patents and are protect by trade secrets and
* copyright law.
*
* Redistribution and use in source and binary forms of the content in
* this file, with or without modification are not permitted unless
* permission is explicitly granted by WiSig Networks.
*
* General Information:
* --------------
* when both addra and addrb are same, old data is returned on doutb 
*
* Change List
* --------------
* Date (dd/mm/yy)    	  Author 		        Description of Change
* ------------------------------------------------------------------
* 26-01-2021		      Nikhil				Initial Version
*/
//************************************************************************************************//
`timescale 1ns/1ps

module sdp_bram #(
        //! address width
        parameter ADDR_WIDTH = 11,
        //! data width
        parameter DATA_WIDTH = 32
    )
    (
        //! clock
        input clk,
        //! enable
        input ena,
        //! write enable
        input wea,
        //! write address
        input [ADDR_WIDTH - 1:0] addra,
        //! write data
        input [DATA_WIDTH - 1:0] dina,
        //! read enable
        input enb,
        //! read address
        input [ADDR_WIDTH - 1:0] addrb, 
        //! read data output
        output [DATA_WIDTH - 1:0] doutb
    );
    
    //! computing depth based on the number of address bits
    localparam DEPTH = (1 << ADDR_WIDTH);
    
    //! ram/memory
    //! TODO: add pragma
    reg [DATA_WIDTH - 1:0] ram [DEPTH - 1:0];
    reg [DATA_WIDTH - 1:0] doutb_reg;
    
    integer i;
    //! turn on initiailisation
    //! NOTE: there is no reset on memory
	 generate 
	 
		if(DEPTH < 131072) begin
		 initial begin
			  for(i = 0; i < DEPTH; i = i + 1) begin
					ram[i] = 0;
			  end
		 end		
		end
	 endgenerate

	initial begin
		doutb_reg = 0;
	end
    
    //! read/write block
    always @(posedge clk) begin
        //! writing into the bram. wea can probably be removed
        if (ena) begin
            if (wea)
                ram[addra] <= dina;
        end
        
        //! reading from the bram
        if(enb) begin
            doutb_reg <= ram[addrb];
        end
    end
    
    assign doutb = doutb_reg;
endmodule

// code for pipelined sdp_bram. Currently not used anywhere in the code but will be required to meet
// timing if the depth is high

////************************************************************************************************//
///*
//* Copyright (c) 2016-2019, WiSig Networks Pvt Ltd. All rights reserved.
//* www.wisig.com
//*
//* All information contained herein is property of WiSig Networks Pvt Ltd.
//* unless otherwise explicitly mentioned.
//*
//* The intellectual and technical concepts in this file are proprietary
//* to WiSig Networks and may be covered by granted or in process national
//* and international patents and are protect by trade secrets and
//* copyright law.
//*
//* Redistribution and use in source and binary forms of the content in
//* this file, with or without modification are not permitted unless
//* permission is explicitly granted by WiSig Networks.
//*
//* General Information:
//* --------------
//* when both addra and addrb are same, old data is returned on doutb 
//*
//* Change List
//* --------------
//* Date (dd/mm/yy)    	  Author 		        Description of Change
//* ------------------------------------------------------------------
//* 26-01-2021		      Nikhil				Initial Version
//*/
////************************************************************************************************//
//`timescale 1ns/1ps

//module sdp_bram #(
//        parameter ADDR_WIDTH = 32'd11,
//        parameter DATA_WIDTH = 32'd16,
//        parameter PIPE_DEPTH = 4 // 1 is the minimum number of FFs required
//    )
//    (
//        input clk,
//        input ena,
//        input wea,
//        input [ADDR_WIDTH - 1:0] addra,
//        input [DATA_WIDTH - 1:0] dina,
//        input enb,
//        input [ADDR_WIDTH - 1:0] addrb, 
//        output [DATA_WIDTH - 1:0] doutb
//    );
    
//    localparam DEPTH = (1 << ADDR_WIDTH);
    
//    reg [DATA_WIDTH - 1:0] ram [DEPTH - 1:0];
    
//    reg ena_d, wea_d, enb_d;
//    reg [ADDR_WIDTH - 1:0] addra_d, addrb_d;
//    reg [DATA_WIDTH - 1:0] dina_d;

//    // output reg
//    reg [DATA_WIDTH - 1:0] doutb_reg [PIPE_DEPTH - 1:0];
    
//    integer i;
//    initial begin
//        //! removing init value as the intel tool does not allow loop trip count more than 5000
//        // for(i = 0; i < DEPTH; i = i + 1) begin
//        //     ram[i] = 0;
//        // end
//        for(i = 0; i < PIPE_DEPTH; i = i + 1) begin
//            doutb_reg[i] = 0;
//        end
//    end

//generate 
//    if(DEPTH < 2048) begin
//        initial begin
//         for(i = 0; i < DEPTH; i = i + 1) begin
//             ram[i] = 0;
//         end
//        end
//    end
//endgenerate

//    always @(posedge clk) begin
//        ena_d <= ena;
//        enb_d <= enb;
//        wea_d <= wea;
//        addra_d <= addra;
//        addrb_d <= addrb;
//        dina_d <= dina;
//    end

//    always @(posedge clk) begin
//        if (ena_d) begin
//            if (wea_d)
//                ram[addra_d] <= dina_d;
//        end
        
//        if(enb_d) begin
//            doutb_reg[0] <= ram[addrb_d];
//        end
//        //! is enb required on _d register?
//    end

//    genvar pipe_i;
//    generate 
//        /* shift register */
//        for(pipe_i = 0; pipe_i < (PIPE_DEPTH - 1); pipe_i = pipe_i + 1) begin
//            always @(posedge clk) begin
//                doutb_reg[pipe_i + 1] <= doutb_reg[pipe_i];
//            end
//        end
//    endgenerate

//    assign doutb = doutb_reg[PIPE_DEPTH - 1];
//endmodule
