//////////////////////////////////////////////////////////////////////////////////
// Company: IPFN-IST
// Engineer: BBC
//
// Create Date: 05/02/2019 07:21:01 PM
// Design Name:
// Module Name: data_producer
// Project Name:
// Target Devices: kintex-7
// Tool Versions:   Vivado 2018.3
// Description:
//
// Dependencies:
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Copyright 2015 - 2017 IPFN-Instituto Superior Tecnico, Portugal
// Creation Date  2017-11-09
//
// Licensed under the EUPL, Version 1.2 or - as soon they
// will be approved by the European Commission - subsequent
// versions of the EUPL (the "Licence");
// You may not use this work except in compliance with the
// Licence.
// You may obtain a copy of the Licence at:
//
// https://joinup.ec.europa.eu/software/page/eupl
//
// Unless required by applicable law or agreed to in
// writing, software distributed under the Licence is
// distributed on an "AS IS" basis,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied.
// See the Licence for the specific language governing
// permissions and limitations under the Licence.
//
//
//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps
`include "dma_fields.vh"

module data_producer #(
    parameter C_DATA_WIDTH = 64,            // RX/TX interface data width

    parameter TCQ        = 1
)(
    // pcie Core
    //input         pcie_user_clk,
    //input         pcie_user_rst_n,
    //DMA input data channel
    //input          data_clk,
    input clk_100,
    input [5:0] clk_100_cnt,
    output [C_DATA_WIDTH-1:0]  adc_data,
    output     data_en,
    input      ack_en
);


    //wire  [63:0] rd_DMA_data=64'h01234567_89ABCDEF; // Fow now

    reg  data_en_r;
    assign data_en = data_en_r;
    reg [22:0] cnt_data_r;
    reg [C_DATA_WIDTH-1:0]  adc_data_r;
    assign adc_data = adc_data_r;
    //
    //assign  dma_data_tx<=64'h5050A0A0A0A05050; //testing PC
    // Swap data here
    always @ (posedge clk_100) // begin
        if (!ack_en) begin
            cnt_data_r <=  0;
            adc_data_r <= 0;
            data_en_r  <= 0;

        end
        else
            case (clk_100_cnt)
                6'h0: begin
                    data_en_r  <= 1'b1;
                    adc_data_r <= {8'h1, cnt_data_r, 1'b1, 8'h0, cnt_data_r, 1'b0};
                end
                6'h1: adc_data_r <= {8'h3, cnt_data_r, 1'b1, 8'h2, cnt_data_r, 1'b0};
                6'h2: adc_data_r <= {8'h5, cnt_data_r, 1'b1, 8'h4, cnt_data_r, 1'b0};
                6'h3: adc_data_r <= {8'h7, cnt_data_r, 1'b1, 8'h6, cnt_data_r, 1'b0};
                6'h4: adc_data_r <= {8'h9, cnt_data_r, 1'b1, 8'h8, cnt_data_r, 1'b0};
                6'h5: adc_data_r <= {8'hB, cnt_data_r, 1'b1, 8'hA, cnt_data_r, 1'b0};
                6'h6: adc_data_r <= {8'hD, cnt_data_r, 1'b1, 8'hC, cnt_data_r, 1'b0};
                6'h7: adc_data_r <= {8'hF, cnt_data_r, 1'b1, 8'hE, cnt_data_r, 1'b0};
                6'h8: adc_data_r <= {8'h11, cnt_data_r, 1'b1, 8'h10, cnt_data_r, 1'b0};
                6'h9: adc_data_r <= {8'h13, cnt_data_r, 1'b1, 8'h12, cnt_data_r, 1'b0};
                6'hA: adc_data_r <= {8'h15, cnt_data_r, 1'b1, 8'h14, cnt_data_r, 1'b0};
                6'hB: adc_data_r <= {8'h17, cnt_data_r, 1'b1, 8'h16, cnt_data_r, 1'b0};
                6'hC: adc_data_r <= {8'h19, cnt_data_r, 1'b1, 8'h18, cnt_data_r, 1'b0};
                6'hD: adc_data_r <= {8'h1B, cnt_data_r, 1'b1, 8'h1A, cnt_data_r, 1'b0};
                6'hE: adc_data_r <= {8'h1D, cnt_data_r, 1'b1, 8'h1C, cnt_data_r, 1'b0};
                6'hF: begin
                    data_en_r  <= 1'b0;
                    adc_data_r <= {8'h1F, cnt_data_r, 1'b1, 8'h1E, cnt_data_r, 1'b0};
                end
                6'h10: cnt_data_r  <= cnt_data_r + 1;
                default: adc_data_r <= 0;
            endcase

    //wire  [C_DATA_WIDTH-1:0] data_64b = {cnt_data_r, 1'b1, cnt_data_r, 1'b0};

    //assign  dma_data = data_64b;
    //############## DMA data FIFO #########################//


endmodule // data_producer
