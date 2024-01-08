
  //************************************************************************************************//
/*
* Copyright (c) 2016-2022, WiSig Networks Pvt Ltd. All rights reserved.
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
* ----------------------
*  
* Change List
* --------------
* Date (dd/mm/yy)       Author                 Description of Change
* ------------------------------------------------------------------
* 24-11-2023            vijaya                  initial version 
* 
*
/************************************************************************************************/ 
`timescale 1ns/1ps

module bram_stream_1 #(
		parameter  string file1     =   "/home/wisig/Downloads/imag_1.mem",
        parameter ADDR_WIDTH = 32'd19,
        parameter DATA_WIDTH = 32'd16,
        parameter PIPE_DEPTH = 4, // 1 is the minimum number of FFs required
        parameter DEPTH = 491520
    )
    (
        input clk,   
        input areset ,      
        output logic [DATA_WIDTH - 1:0] data_out ,
        output logic valid ,
        input logic ready 
    );
      
    reg [DATA_WIDTH - 1:0] doutb_reg = 0;
    logic                    valid_1;  
	reg						en = 1'b1; 	 
    reg [DATA_WIDTH - 1:0] ram [DEPTH - 1:0];
    reg [ADDR_WIDTH - 1:0] addrb  = 'd0; 

    generate 
            initial begin
                $readmemh(file1, ram);
            end
    endgenerate


    always_ff @(posedge clk) begin
        if (ready && valid) begin
           doutb_reg[DATA_WIDTH-1:0] <= ram[addrb];
        end
    end


    // read address increment
    always_ff @(posedge clk) begin
        if (areset) begin
            addrb <= 'd0;
        end else begin
            if (ready) begin
                addrb <= addrb == (DEPTH - 1) ? 'd0 : addrb + 1;
            end else begin
                addrb <= addrb;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (areset) begin
            valid_1 <= 0;
        end else begin
            valid_1 <= 1;
        end
    end 

    assign valid = valid_1  ;  
    assign data_out = doutb_reg ; 

    endmodule
