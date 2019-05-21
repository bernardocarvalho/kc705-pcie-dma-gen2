//////////////////////////////////////////////////////////////////////////////////
// Company: IPFN-IST
// Engineer: BBC
//
// Create Date: 05/02/2019 07:21:01 PM
// Design Name:
// Module Name: pci_dma_engine
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

module pci_dma_engine #(
    parameter C_DATA_WIDTH = 64,            // RX/TX interface data width

    // Do not override parameters below this line
    parameter KEEP_WIDTH = C_DATA_WIDTH / 8,              // TSTRB width
    parameter TCQ        = 1
)(
    // pcie Core
    input         pcie_user_clk,
    input         pcie_user_rst_n,
    input 		s_axis_tx_tvalid,
    input  [5:0]  tx_buf_av,  //  Transmit Buffers Available
    output        cfg_interrupt,
    input			cfg_interrupt_rdy,

    //registers interface
    input   [30:27]  control_reg,
    output  [7:0]   dma_status,
    input           dma_compl_acq, // No need for MSI irq
    input   [20:0]  dma_size, // MAX size 1 MB = 8k / 4k / 2k TLPs
    input   [31:0]  dma_host_addr,
    //From PIO_RX-engine
    input req_compl_rx,
    input req_compl_wd_rx,
    //PIO_DMA_TX_ENGINE
    output  reg	req_compl_tx,		   //to TX-DMA-engine - start completion
    output  	    req_compl_wd_tx,		   //to TX-DMA-engine - start completion with data - allways 1 (0 for IO read)- not used

    output  reg [5:0]  data_payload_tx,      //to TX-DMA-engine - DMA BYTE SIZE
    output  reg [31:0] host_addr_tx,		   //to TX-DMA-engine - addr_host_out
    output   [C_DATA_WIDTH-1:0] dma_data_tx,         //to TX-DMA-engine - DMA data
    output            tlp_req_o,       //to TX-DMA-engine - Start TLP

    //DMA input data channel
    input                adc_data_clk, 		//I - N
    input      [63:0]    adc_data,  //I -
    input                adc_data_en    //I -
);


    localparam MAX_PAYLOAD  = 8'h20; //32DW / 64 DW / 128 DW

    (* mark_debug="yes" *) wire [15:0]  num_full_tlps;     // 2^15 =  32768 TLPs CHECK Sizes max transfer = 4096Bytes = 1024DW => se max DW in each packet = 32DW => 1024/32 = 32 packets
    wire [20:0] remain;
    wire [8:0] remainder;       // Max 511 Bytes
    assign num_full_tlps    = dma_size[20:0] / MAX_PAYLOAD;  //16384B -> 32 packets of 32DW each or 16QW
    assign remain           = num_full_tlps * MAX_PAYLOAD;
    assign remainder        = (remain < dma_size) ?
                              (dma_size - remain) : 9'b0; // should be 0? check widths
    //assign rem = a % b;
    //assign quot = a / b;

    (* mark_debug="yes" *) wire   dma_payload_not_zero; //Host must define previously data_payload
    assign dma_payload_not_zero = (dma_size != 0)? 1'b1 : 1'b0;

    assign req_compl_wd_tx = 1'b1; //allways read with data (0 for IO read)- not used

    (* mark_debug="yes" *)	reg cfg_interrupt_r;
    assign cfg_interrupt = cfg_interrupt_r;
    (* mark_debug="yes" *)	wire dmae_i = control_reg[`DMAE_BIT]; //
    reg [3:0] DMAE_r;

    (* mark_debug="yes" *) wire DMAiE = control_reg[`DMAiE_BIT]; //

    localparam DMA_SM_TLP_0                 = 3'b000;
    localparam DMA_SM_TLP_1ST_TLP           = 3'b001;
    localparam DMA_SM_TLP_2ND_TLP           = 3'b010;
    localparam DMA_SM_TLP_SEND_QW           = 3'b011;
    localparam DMA_SM_TLP_END               = 3'b100;
    localparam DMA_SM_TLP_END_REQ_COMPL     = 3'b101;
    localparam DMA_SM_REQ_END               = 3'b110;

    //########################## BUILD DMA PACKET ##############################//
    (* mark_debug="yes" *) reg [2:0]  state_rd_wr;
    reg [2:0]  tlp_req_r;
    (* mark_debug="yes" *) wire tlp_req_i;
    assign tlp_req_i = tlp_req_r[2];
    assign tlp_req_o = tlp_req_i;
    //reg [2:0]  half_mem_r;

    reg 	req_compl_flag;
    (* mark_debug="yes" *) reg 	start_dma_flag;
    reg [2:0]	fifo_rd_r; // Delay 2
    (* mark_debug="yes" *)  wire fifo_rd_i = fifo_rd_r[2]; // Delay 2
    //reg 	start_DMA;
    //reg 	DMA_SEL_r;
    (* mark_debug="yes" *) reg [14:0]    tlps2go;
    (* mark_debug="yes" *) reg [6:0]    len_i; // Number of 64 (C_DATA_WIDTH) bit blocks to go
    (* mark_debug="yes" *) reg          dmaC_r;
    reg [2:0] 	dma_current_buffer;
    assign dma_status = {4'b0, dmaC_r, dma_current_buffer};
    //.DMA_SEL           (dma_status[4]),
    //wire fifo_empty_i;
    (* mark_debug="yes" *)  wire fifo_prog_empty_i;

    always @ (posedge pcie_user_clk) begin
        if (!pcie_user_rst_n) begin
            fifo_rd_r 		    <= #TCQ 3'b0;
            DMAE_r              <= 4'h0;
            start_dma_flag	    <= #TCQ 1'b0;
            len_i      	 	    <= #TCQ 0;
            tlp_req_r	        <= #TCQ 3'd0;
            req_compl_tx        <= #TCQ 1'b0;
            tlps2go             <= #TCQ 15'b0;
            data_payload_tx     <= #TCQ 6'b0;
            host_addr_tx        <= #TCQ 32'b0;
            req_compl_flag      <= #TCQ 1'b0;
            dma_current_buffer  <= #TCQ 3'b0;

            state_rd_wr 	    <= #TCQ DMA_SM_TLP_0;
        end
        else begin
            tlp_req_r[2:1] <= tlp_req_r[1:0]; // Shift register for delay
            fifo_rd_r[2:1] <= fifo_rd_r[1:0]; // Shift register for delay TODO check wait states
            DMAE_r <= {DMAE_r[2:0], dmae_i}; // Shift register for delay

            // if (DMA_SEL_r != DMA_SEL) //begin
            //dma_current_buffer <= #TCQ 3'b0;
            //	end
            if(DMAE_r[3:2] == 2'b01) // Detect L->H
                start_dma_flag	    <= #TCQ 1'b1;
            case (state_rd_wr)
                DMA_SM_TLP_0: begin  // waiting for new user DMA request
                    if (req_compl_rx || req_compl_flag) begin // Handle REQ COMPLETION first
                        fifo_rd_r[0] 	<= #TCQ 1'b0;
                        if (tx_buf_av != 6'b0) begin
                            req_compl_tx    <= #TCQ 1'b1;  // To TX_DMA
                            tlp_req_r[0]    <= #TCQ 1'b0;
                            req_compl_flag  <= #TCQ 1'b0;
                            state_rd_wr 	<= #TCQ DMA_SM_TLP_END_REQ_COMPL;
                        end
                        else
                            req_compl_flag 	<= #TCQ 1'b1; // extend to next cycle
                    end
                    else if (start_dma_flag && !fifo_prog_empty_i && dma_payload_not_zero && !s_axis_tx_tvalid) begin 	// New request DMA read   start_DMA && !half_mem_tmp
                        //req_compl_flag	    <= #TCQ req_compl_rx;
                        dma_current_buffer  <= #TCQ dma_current_buffer + 3'b001; //current buffer change
                        state_rd_wr 	    <= #TCQ DMA_SM_TLP_1ST_TLP;
                    end
                    else begin
                        fifo_rd_r[0] 	    <= #TCQ 1'b0;
                        tlp_req_r[0]	    <= #TCQ 1'b0;
                        len_i     		    <= #TCQ 0;
                        data_payload_tx     <= #TCQ 9'b0;
                        req_compl_flag      <= #TCQ 1'b0;

                        //state_rd_wr 	    <= #TCQ DMA_SM_TLP_2ND_TLP;
                    end
                end

                DMA_SM_TLP_1ST_TLP: begin       //Build first packet from same request
                    if (req_compl_rx || req_compl_flag)
                        req_compl_flag	    <= #TCQ 1'b1; // Extend to next cycle

                    if (tx_buf_av != 6'b0) begin
                        start_dma_flag	    <= #TCQ 1'b0;
                        fifo_rd_r[0]       <= #TCQ 1'b1;
                        host_addr_tx 		<= #TCQ dma_host_addr;
                        tlp_req_r[0]	    <= #TCQ 1'b1;

                        if (num_full_tlps == 16'b0) begin  // remainer DW
                            //len_i 				 <= #TCQ remainder[5:0]; //32-bit data
                            len_i 			    <= #TCQ remainder[8:1]; //64-bit data
                            data_payload_tx     <= #TCQ remainder[8:0];
                            tlps2go  		    <= #TCQ 0;
                        end
                        else begin
                            //len_i   				 <= #TCQ data_payload_max;//32-bit data
                            len_i   		    <= #TCQ (MAX_PAYLOAD >> 1); // [8:1];//64-bit data =16
                            data_payload_tx     <= #TCQ MAX_PAYLOAD;
                            tlps2go  		    <= #TCQ num_full_tlps - 1'b1;
                        end
                        state_rd_wr         <= #TCQ DMA_SM_TLP_SEND_QW;
                    end
                end
                DMA_SM_TLP_2ND_TLP: begin // 1      //Build new packet from same request

                    if (req_compl_rx || req_compl_flag)
                        req_compl_flag	    <= #TCQ 1'b1; // Extende to next cycle
                    //req_compl_flag	<= #TCQ req_compl_rx;

                    if (tx_buf_av != 6'b0) begin
                        host_addr_tx <= #TCQ {host_addr_tx +  {MAX_PAYLOAD,2'b0}}; // in DW

                        if (tlps2go != 0 ) begin
                            data_payload_tx     <= #TCQ MAX_PAYLOAD;
                            len_i   		    <= #TCQ (MAX_PAYLOAD >>1); // [8:1];//64-bit data =16
                            tlps2go 			<= #TCQ tlps2go -1'b1;
                            tlp_req_r[0]        <= #TCQ 1'b1;
                            fifo_rd_r[0]        <= #TCQ 1'b1;
                            state_rd_wr 	    <= #TCQ DMA_SM_TLP_SEND_QW;
                        end
                        else begin
                            if ( remainder != 0) begin
                                len_i 				<= #TCQ remainder[8:1]; //64-bit data
                                data_payload_tx     <= #TCQ remainder[8:0];
                                tlp_req_r[0]        <= #TCQ 1'b1;
                                fifo_rd_r[0]        <= #TCQ 1'b1;
                                state_rd_wr         <= #TCQ DMA_SM_TLP_SEND_QW;
                            end
                            else begin //No more TLPs on this request.            npacket == 5'b0 && remainder == 1'b0) begin
                                len_i     			<= #TCQ 8'b1; // ??
                                data_payload_tx 	<= #TCQ 9'b0;
                                tlp_req_r[0]		<= #TCQ 1'b0;
                                fifo_rd_r[0]          <= #TCQ 1'b0;
                                state_rd_wr 		<= #TCQ DMA_SM_REQ_END; //
                            end
                        end
                    end
                    else
                        fifo_rd_r[0] <= #TCQ 1'b0;

                end //DMA_SM_TLP_2ND_TLP
                DMA_SM_TLP_SEND_QW: begin  // 2 Sending QWs from FIFO ...
                    tlp_req_r[0]	    <= #TCQ 1'b0;

                    if (req_compl_rx || req_compl_flag)
                        req_compl_flag	    <= #TCQ 1'b1; // Extend to next cycle
                    //req_compl_flag	<= #TCQ req_compl_rx;

                    if (tx_buf_av != 6'b0) begin
                        if (len_i >= 8'b1) begin
                            fifo_rd_r[0] 		    <= #TCQ 1'b1;
                            len_i     	<= #TCQ (len_i - 1'b1);
                        end else begin
                            len_i    	<= #TCQ 8'b0;
                            state_rd_wr <= #TCQ DMA_SM_TLP_END; // end TLP
                        end
                    end
                    else
                        fifo_rd_r[0] <= #TCQ 1'b0;
                    //rd_en_r[0] 		<= #TCQ 1'b0;
                end
                DMA_SM_TLP_END: begin	//end TLP 3
                    fifo_rd_r[0]        <= #TCQ 1'b0;
                    tlp_req_r[0]        <= #TCQ 1'b0;
                    //req_compl_tx        <= #TCQ 1'b0;

                    if (req_compl_rx || req_compl_flag)
                        req_compl_flag	    <= #TCQ 1'b1; // Extend to next cycle
                    //req_compl_flag	<= #TCQ req_compl_rx;

                    state_rd_wr 	    <= #TCQ DMA_SM_TLP_2ND_TLP;
                end
                DMA_SM_TLP_END_REQ_COMPL: begin  //end read req
                    fifo_rd_r[0]    <= #TCQ 1'b0;
                    tlp_req_r[0]	<= #TCQ 1'b0;
                    req_compl_tx	<= #TCQ 1'b0;

                    state_rd_wr     <= #TCQ DMA_SM_TLP_0;
                end

                DMA_SM_REQ_END: begin //end Request
                    fifo_rd_r[0] <= #TCQ 1'b0;
                    if (req_compl_rx || req_compl_flag)
                        req_compl_flag	    <= #TCQ 1'b1; // Extend to next cycle
                    //if (! DMAE_r[3] )  	// Wait user to disable DMA
                    state_rd_wr     <= #TCQ DMA_SM_TLP_0;
                end
                default :
                    state_rd_wr 	    <= #TCQ DMA_SM_TLP_0;
            endcase
        end
    end

    //############################################################################//
    //########################## DMAiE INTERRUP ENABLE ############################################//
    (* mark_debug="yes" *) reg	[3:0] 	start_interrupt_r;

    //######################## MSI INTERRUPT MODE #########################//
    (* mark_debug="yes" *)  reg  [1:0]  state_irq;

    always @ (posedge pcie_user_clk) //begin
        if (!pcie_user_rst_n) begin
            //count_int        			<= #TCQ 32'b0;
            cfg_interrupt_r  		     <= #TCQ 1'b0;
            dmaC_r 			         <= #TCQ 1'b0;
            state_irq			     <= #TCQ 2'b0;
            start_interrupt_r        <= #TCQ 4'b0;
        end
        else begin
            start_interrupt_r[3:1] <= start_interrupt_r[2:0]; // Shift register for delay
            //if (len_i == 1'b1 && state_rd_wr == DMA_SM_TLP_WAIT_REQ_COMPL)  //new interrupt ! rest
            if ( state_rd_wr == DMA_SM_REQ_END)  //
                start_interrupt_r[0] <= #TCQ 1'b1;
            else
                start_interrupt_r[0] <= #TCQ 1'b0;
            case (state_irq)
                2'b00: //begin
                    if (DMAiE && start_interrupt_r[3]) begin // && (!dmaC_r)) begin
                        cfg_interrupt_r	<= #TCQ 1'b1;
                        dmaC_r		 	<= #TCQ 1'b1;
                        //count_int  		<= #TCQ count_int + 1'b1;
                        state_irq		<= #TCQ 2'b01;
                    end
                2'b01:
                    if (cfg_interrupt_rdy) begin
                        cfg_interrupt_r	<= #TCQ 1'b0;
                        state_irq		<= #TCQ 2'b00;
                    end
                2'b10: //begin TODO needed for MSI irqs?
                    if (!dma_compl_acq) begin
                        dmaC_r 			<= #TCQ 1'b0;
                        state_irq		<= #TCQ 2'b00;
                    end
                default :
                    state_irq 	    <= #TCQ 2'b00;

            endcase
        end
    wire  [63:0] fifo_data_out;
    // Swap data here
    //assign  dma_data_tx = {fifo_data_out[39:32], fifo_data_out[47:40], fifo_data_out[55:48], 8'hBC,
    assign  dma_data_tx = {fifo_data_out[39:32],fifo_data_out[47:40],fifo_data_out[55:48],fifo_data_out[63:56],
        fifo_data_out[7:0], fifo_data_out[15:8], fifo_data_out[23:16], fifo_data_out[31:24]};
    //(* mark_debug="yes" *) wire [7:0]  f_data_out;
    //(* mark_debug="yes" *) wire [7:0]  f_data_in;
    //assign f_data_out = fifo_data_out[7:0];
    //assign f_data_in = dma_data[7:0] ;
    //############## DMA data FIFO #########################//
/*Block RAM Fifo 16384 depth - 128 kB */
    dma_fifo dma_fifo_0 (
        .rst(!pcie_user_rst_n),
        .wr_clk(adc_data_clk),
        .wr_en(adc_data_en),//
        .din(adc_data), // adc_data   r64-b dma_0_data 64'hA0A05052_A0A05051 fifo_0_wrt_data_i
        .rd_clk(pcie_user_clk),
        .rd_en(fifo_rd_i),
        .dout(fifo_data_out),  //64b
        .empty(), //fifo_empty_i
        .full(),
        //.prog_full(),
        .prog_empty_thresh(14'h0100),  // input wire [13 : 0] prog_empty_thresh
        .prog_empty(fifo_prog_empty_i)
    );

endmodule
