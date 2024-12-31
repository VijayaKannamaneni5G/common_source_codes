`include "pdschrx.svh"

module pdsch_dmrs #(
    //! Number of bits to represent output. 2 bits per layer are enough
    //! but this can be 8 for AXIS
    parameter int DW_OUT = 2
    //! maximum number of unique ports supported. 4 to indicates ports (0 to 3) are supported
) (
    //! System Clock
    input clk,
    //! Reset - Negedge triggered
    input reset_n,

    //! @virtualbus param @dir in AXIS bus for input data
    //! input data - axis port
    input [$bits(pdschrx_dmrsgen_t) - 1:0] param_tdata,
    //! input valid - axis port
    input param_tvalid,
    //! input ready - axis port
    output param_tready,  //! @end
    //! @virtualbus m_tdata @dir out AXIS bus for DMRS to Modulation Removal
    //! data output - axis port
    output [DW_OUT - 1:0] m_tdata,
    //! valid output - axis port
    output m_tvalid,
    //! tlast output - axis port
    output m_tlast,
    //! ready output axis port
    input m_tready //! @end
   
);
    //! number of bits to represent the input config
    localparam int DW_PARAM = $bits(pdschrx_dmrsgen_t);
    //! Starting value for this lfsr at Nc = 1600
    localparam [30:0] X1_INIT = 31'b1011110010010000101100001000000;

    //! input data internal variables
    logic param_tvalid_i;
    logic [DW_PARAM - 1:0] param_tdata_i;
    logic param_tready_i;
    pdschrx_dmrsgen_t rd_param;

    //! output data internal variable
    logic [DW_OUT - 1:0] m_tdata_i;
    logic m_tvalid_i;
    logic m_tlast_i;
    logic m_tready_i;

  
    //! temporary/intermediate dmrs value. This is r(2n + k) in 3GPP terms
    logic [1:0] dmrs_temp;
  
    logic [30:0] lfsr_x1;
    logic [30:0] lfsr_x2, cinit_out;
    //! counter for counting dmrs length. Fix the bit width later
    logic [15:0] count;

    //! signal to indicate if both the slave are ready
    logic slaves_ready;
    
    localparam int START_PRB  = 10 ;
    
    enum reg [1:0] {
        RD_PARAM,
        COMPUTE_CINIT,
      //  CDM_0,
          CDM
    }
        state, next;

    get_x2init inst_gencinit (
        .cinit_in (rd_param.cinit),
        .cinit_out(cinit_out)
    );
    //! half buffer for config
    halfbuffer #(
        .DW(DW_PARAM)
    ) inst_param (
        .clk(clk),
        .reset_n(reset_n),
        .s_tvalid(param_tvalid),
        .s_tready(param_tready),
        .s_tdata(param_tdata),
        .m_tvalid(param_tvalid_i),
        .m_tready(param_tready_i),
        .m_tdata(param_tdata_i)
    );

    //! skid buffer for output port
    skidbuffer #(
        .DW(DW_OUT + 1)
    ) inst_out (
        .clock(clk),
        .reset(~reset_n),
        .input_tvalid(m_tvalid_i),
        .input_tready(m_tready_i),
        .input_tdata({m_tdata_i, m_tlast_i}),
        .output_tvalid(m_tvalid),
        .output_tready(m_tready),
        .output_tdata({m_tdata, m_tlast})
    );

    // State transition
    //! Sequential block for present-state FSM logic
    always @(posedge clk) begin : PRESENT_STATE_FSM
        if (!reset_n) begin
            state <= RD_PARAM;
        end else begin
            state <= next;
        end
    end

    //! Combinational block for next-state FSM logic
    always_comb begin : next_FSM
        next = RD_PARAM;
        case (state)
            RD_PARAM: begin
                //! go to next state once valid config is received
                if (param_tvalid_i) begin
                    next = COMPUTE_CINIT;
                end else begin
                    next = RD_PARAM;
                end
            end
            COMPUTE_CINIT: begin
                //! go to next state un-conditionally
                next = CDM;
            end
            CDM: begin
                //! when last dmrs is generated, go to init state
                //! else go the CDM_0 for reasons similar to CDM_0 to CDM_1 transition
                if (slaves_ready && count == rd_param.length_dmrs - 1) next = RD_PARAM;
               // else if (slaves_ready || count < rd_param.offset) next = CDM_0;
                else next = CDM;
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            //! reset the counter on reset
            //! no other register are required to be under reset?
            //! can count also be removed?
            count <= 0;
        end else begin
            case (state)
                RD_PARAM: begin
                    if (param_tvalid_i) begin
                        rd_param <= param_tdata_i;
                    end
                    // resetting counters
                    count <= 0;//START_PRB;
                end
                COMPUTE_CINIT: begin
                    lfsr_x1 <= X1_INIT;
                    lfsr_x2 <= cinit_out;
                end 
                CDM: begin
                    if (slaves_ready || count < rd_param.offset) begin
                        lfsr_x1 <= {
                            (lfsr_x1[4] ^ lfsr_x1[1]), (lfsr_x1[3] ^ lfsr_x1[0]), lfsr_x1[30:2]
                        };
                        lfsr_x2 <= {
                            (lfsr_x2[4] ^ lfsr_x2[3] ^ lfsr_x2[2] ^ lfsr_x2[1]),
                            (lfsr_x2[3] ^ lfsr_x2[2] ^ lfsr_x2[1] ^ lfsr_x2[0]),
                            lfsr_x2[30:2]
                        };
                        count <= count + 1;
                    end
                end
            endcase
        end
    end

    assign slaves_ready = m_tready_i ;

    always_comb begin
            m_tvalid_i  = count >= rd_param.offset && (state == CDM);

        //! read param when in RD_PARAM state
        param_tready_i = (state == RD_PARAM);
         m_tlast_i = (count == rd_param.length_dmrs - 1) ; 

        //! computing r(k)
        dmrs_temp[0] = lfsr_x1[0] ^ lfsr_x2[0];
        dmrs_temp[1] = lfsr_x1[1] ^ lfsr_x2[1];
        m_tdata_i = dmrs_temp; 

    end

endmodule


//! function to compute the cinit_1600 from the input cinit
//  logic [30:0] get_x2init(input logic [30:0] cinit_in);
module get_x2init (
    input  logic [30:0] cinit_in,
    output logic [30:0] cinit_out
);

    always_comb begin
        cinit_out[0] = cinit_in[23] ^ cinit_in[20] ^ cinit_in[19] ^ cinit_in[16] ^ cinit_in[12] ^ cinit_in[8] ^ cinit_in[3] ^ cinit_in[2] ^ cinit_in[1];
        cinit_out[1] = cinit_in[24] ^ cinit_in[21] ^ cinit_in[20] ^ cinit_in[17] ^ cinit_in[13] ^ cinit_in[9] ^ cinit_in[4] ^ cinit_in[3] ^ cinit_in[2];
        cinit_out[2] = cinit_in[25] ^ cinit_in[22] ^ cinit_in[21] ^ cinit_in[18] ^ cinit_in[14] ^ cinit_in[10] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3];
        cinit_out[3] = cinit_in[26] ^ cinit_in[23] ^ cinit_in[22] ^ cinit_in[19] ^ cinit_in[15] ^ cinit_in[11] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4];
        cinit_out[4] = cinit_in[27] ^ cinit_in[24] ^ cinit_in[23] ^ cinit_in[20] ^ cinit_in[16] ^ cinit_in[12] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5];
        cinit_out[5] = cinit_in[28] ^ cinit_in[25] ^ cinit_in[24] ^ cinit_in[21] ^ cinit_in[17] ^ cinit_in[13] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6];
        cinit_out[6] = cinit_in[29] ^ cinit_in[26] ^ cinit_in[25] ^ cinit_in[22] ^ cinit_in[18] ^ cinit_in[14] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7];
        cinit_out[7] = cinit_in[30] ^ cinit_in[27] ^ cinit_in[26] ^ cinit_in[23] ^ cinit_in[19] ^ cinit_in[15] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[8];
        cinit_out[8] = cinit_in[28] ^ cinit_in[27] ^ cinit_in[24] ^ cinit_in[20] ^ cinit_in[16] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[3] ^ cinit_in[2] ^ cinit_in[1] ^ cinit_in[0];
        cinit_out[9] = cinit_in[29] ^ cinit_in[28] ^ cinit_in[25] ^ cinit_in[21] ^ cinit_in[17] ^ cinit_in[12] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[4] ^ cinit_in[3] ^ cinit_in[2] ^ cinit_in[1];
        cinit_out[10] = cinit_in[30] ^ cinit_in[29] ^ cinit_in[26] ^ cinit_in[22] ^ cinit_in[18] ^ cinit_in[13] ^ cinit_in[12] ^ cinit_in[11] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3] ^ cinit_in[2];
        cinit_out[11] = cinit_in[30] ^ cinit_in[27] ^ cinit_in[23] ^ cinit_in[19] ^ cinit_in[14] ^ cinit_in[13] ^ cinit_in[12] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[2] ^ cinit_in[1] ^ cinit_in[0];
        cinit_out[12] = cinit_in[28] ^ cinit_in[24] ^ cinit_in[20] ^ cinit_in[15] ^ cinit_in[14] ^ cinit_in[13] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[0];
        cinit_out[13] = cinit_in[29] ^ cinit_in[25] ^ cinit_in[21] ^ cinit_in[16] ^ cinit_in[15] ^ cinit_in[14] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[1];
        cinit_out[14] = cinit_in[30] ^ cinit_in[26] ^ cinit_in[22] ^ cinit_in[17] ^ cinit_in[16] ^ cinit_in[15] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[2];
        cinit_out[15] = cinit_in[27] ^ cinit_in[23] ^ cinit_in[18] ^ cinit_in[17] ^ cinit_in[16] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[2] ^ cinit_in[1] ^ cinit_in[0];
        cinit_out[16] = cinit_in[28] ^ cinit_in[24] ^ cinit_in[19] ^ cinit_in[18] ^ cinit_in[17] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[3] ^ cinit_in[2] ^ cinit_in[1];
        cinit_out[17] = cinit_in[29] ^ cinit_in[25] ^ cinit_in[20] ^ cinit_in[19] ^ cinit_in[18] ^ cinit_in[12] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[4] ^ cinit_in[3] ^ cinit_in[2];
        cinit_out[18] = cinit_in[30] ^ cinit_in[26] ^ cinit_in[21] ^ cinit_in[20] ^ cinit_in[19] ^ cinit_in[13] ^ cinit_in[12] ^ cinit_in[11] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3];
        cinit_out[19] = cinit_in[27] ^ cinit_in[22] ^ cinit_in[21] ^ cinit_in[20] ^ cinit_in[14] ^ cinit_in[13] ^ cinit_in[12] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3] ^ cinit_in[2] ^ cinit_in[1] ^ cinit_in[0];
        cinit_out[20] = cinit_in[28] ^ cinit_in[23] ^ cinit_in[22] ^ cinit_in[21] ^ cinit_in[15] ^ cinit_in[14] ^ cinit_in[13] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3] ^ cinit_in[2] ^ cinit_in[1];
        cinit_out[21] = cinit_in[29] ^ cinit_in[24] ^ cinit_in[23] ^ cinit_in[22] ^ cinit_in[16] ^ cinit_in[15] ^ cinit_in[14] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3] ^ cinit_in[2];
        cinit_out[22] = cinit_in[30] ^ cinit_in[25] ^ cinit_in[24] ^ cinit_in[23] ^ cinit_in[17] ^ cinit_in[16] ^ cinit_in[15] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3];
        cinit_out[23] = cinit_in[26] ^ cinit_in[25] ^ cinit_in[24] ^ cinit_in[18] ^ cinit_in[17] ^ cinit_in[16] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3] ^ cinit_in[2] ^ cinit_in[1] ^ cinit_in[0];
        cinit_out[24] = cinit_in[27] ^ cinit_in[26] ^ cinit_in[25] ^ cinit_in[19] ^ cinit_in[18] ^ cinit_in[17] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3] ^ cinit_in[2] ^ cinit_in[1];
        cinit_out[25] = cinit_in[28] ^ cinit_in[27] ^ cinit_in[26] ^ cinit_in[20] ^ cinit_in[19] ^ cinit_in[18] ^ cinit_in[12] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3] ^ cinit_in[2];
        cinit_out[26] = cinit_in[29] ^ cinit_in[28] ^ cinit_in[27] ^ cinit_in[21] ^ cinit_in[20] ^ cinit_in[19] ^ cinit_in[13] ^ cinit_in[12] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4] ^ cinit_in[3];
        cinit_out[27] = cinit_in[30] ^ cinit_in[29] ^ cinit_in[28] ^ cinit_in[22] ^ cinit_in[21] ^ cinit_in[20] ^ cinit_in[14] ^ cinit_in[13] ^ cinit_in[12] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[4];
        cinit_out[28] = cinit_in[30] ^ cinit_in[29] ^ cinit_in[23] ^ cinit_in[22] ^ cinit_in[21] ^ cinit_in[15] ^ cinit_in[14] ^ cinit_in[13] ^ cinit_in[12] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[5] ^ cinit_in[3] ^ cinit_in[2] ^ cinit_in[1] ^ cinit_in[0];
        cinit_out[29] = cinit_in[30] ^ cinit_in[24] ^ cinit_in[23] ^ cinit_in[22] ^ cinit_in[16] ^ cinit_in[15] ^ cinit_in[14] ^ cinit_in[13] ^ cinit_in[12] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[6] ^ cinit_in[4] ^ cinit_in[0];
        cinit_out[30] = cinit_in[25] ^ cinit_in[24] ^ cinit_in[23] ^ cinit_in[17] ^ cinit_in[16] ^ cinit_in[15] ^ cinit_in[14] ^ cinit_in[13] ^ cinit_in[12] ^ cinit_in[11] ^ cinit_in[10] ^ cinit_in[9] ^ cinit_in[8] ^ cinit_in[7] ^ cinit_in[5] ^ cinit_in[3] ^ cinit_in[2] ^ cinit_in[0];
    end

endmodule












