// Company: INSTITUTO DE PLASMAS E FUSAO NUCLEAR
// Engineer: BBC
//
// Create Date:
// Project Name:
// Design Name:
// Module Name:
// Target Devices:
// Tool versions:  Vivado 2018.3
//
//-----------------------------------------------------------------------------
// Project    : Series-7 Integrated Block for PCI Express
// File       : PIO_EP_SHAPI_REGS.v
// Version    : 3.3
//--
//-- Description: Endpoint Memory Access Unit. This module provides access functions
//--              to the Endpoint memory aperture.
//--
//--              Read Access: Module returns data for the specifed address and
//--              byte enables selected.
//--
//--              Write Access: Module accepts data, byte enables and updates
//--              data when write enable is asserted. Modules signals write busy
//--              when data write is in progress.
//--
//--------------------------------------------------------------------------------
// Copyright 2015 - 2019 IPFN-Instituto Superior Tecnico, Portugal
// Creation Date  2019-04-29
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
`timescale 1ps/1ps
`include "shapi_stdrt_dev_inc.vh"

(* DowngradeIPIdentifiedWarnings = "yes" *)
module PIO_EP_SHAPI_REGS  #(
  parameter TCQ = 1
) (

  clk,
  rst_n,

  // Read Access

  rd_addr,     // I [10:0]  Read Address
  rd_be,       // I [3:0]   Read Byte Enable
  rd_data,     // O [31:0]  Read Data

  // Write Access

  wr_addr,     // I [10:0]  Write Address
  wr_be,       // I [7:0]   Write Byte Enable
  wr_data,     // I [31:0]  Write Data
  wr_en,       // I         Write Enable
  wr_busy,      // O         Write Controller Busy

  status_reg,     // I
  control_reg,    // O
  dma_compl_acq,  // O
  //dma_status,     // I
  dma_size, // O
  dma_host_addr     // O

);

  input            clk;
  input            rst_n;

  //  Read Port

  input  [10:0]    rd_addr;
  input  [3:0]     rd_be;
  output [31:0]    rd_data;

  //  Write Port

  input  [10:0]    wr_addr;
  input  [7:0]     wr_be;
  input  [31:0]    wr_data;
  input            wr_en;
  output           wr_busy;

//DMA port
  input  		[31:0]  status_reg;
  output 		[31:0]  control_reg;
  output                dma_compl_acq;
  //input  		[7:0]  dma_status;
  output 		[20:0]  dma_size;
  output     	[31:0]  dma_host_addr;

  localparam PIO_MEM_ACCESS_WR_RST   = 3'b000;
  localparam PIO_MEM_ACCESS_WR_WAIT  = 3'b001;
  localparam PIO_MEM_ACCESS_WR_READ  = 3'b010;
  localparam PIO_MEM_ACCESS_WR_WRITE = 3'b100;

  wire   [31:0]     rd_data;

  reg   [31:0]      rd_data_raw_o;

  wire             wr_busy;
  reg              write_en;
  reg   [31:0]     post_wr_data;
  wire   [31:0]     w_pre_wr_data;

  reg   [2:0]      wr_mem_state;

  reg   [31:0]     pre_wr_data;

  wire  [7:0]      w_pre_wr_data_b0;
  wire  [7:0]      w_pre_wr_data_b1;
  wire  [7:0]      w_pre_wr_data_b2;
  wire  [7:0]      w_pre_wr_data_b3;

  wire  [7:0]      w_wr_data_b0;
  wire  [7:0]      w_wr_data_b1;
  wire  [7:0]      w_wr_data_b2;
  wire  [7:0]      w_wr_data_b3;

  reg   [31:0]     dev_scratch_reg;

  //#### MODULE REGISTERS ######//
  wire [63:0] mod_name = `MOD_DMA_NAME;

    reg [31:30]  mod_control_r = 2'h0;
    wire   mod_soft_rst_control = mod_control_r[`MOD_CNTRL_SFT_RST_BIT];       //offset_addr 0x2c
    wire   mod_full_rst_control = mod_control_r[`MOD_CNTRL_FULL_RST_BIT];       //offset_addr 0x2c

    //reg [31:0]  mod_interrupt_mask_r  = 32'h0;
    reg [31:0]  mod_interrupt_flag_clear_r  = 32'h0;
    wire        mod_soft_rst_status = 1'b0;                       //offset_addr 0x28
    wire        mod_full_rst_status = 1'b0;                       //offset_addr 0x28

    reg [31:0]  mod_interrupt_mask_r  = 32'h0;
    wire [31:0] mod_interrupt_flag       = 32'h0; //mod1_interrupt_mask;                //offset_addr 0x34
    wire [31:0] mod_interrupt_active     = 32'h0;     //offset_addr 0x38


    reg   [31:0]      control_r;
  reg   [20:0]     dma_size_r;
  reg   [31:0]     dma_address_regs[0:7]; // array of  32-bit registers

  reg   [31:0]  dma_host_addr_r;
  assign dma_host_addr = dma_host_addr_r;

  assign dma_size = dma_size_r;
  assign control_reg =  control_r;


  // Memory Write Process
 //  Extract current data bytes. These need to be swizzled

  assign w_pre_wr_data_b3 = pre_wr_data[31:24];
  assign w_pre_wr_data_b2 = pre_wr_data[23:16];
  assign w_pre_wr_data_b1 = pre_wr_data[15:08];
  assign w_pre_wr_data_b0 = pre_wr_data[07:00];

  //  Extract new data bytes from payload
  //  TLP Payload format :
  //    data[31:0] = { byte[0] (lowest addr), byte[2], byte[1], byte[3] }

  assign w_wr_data_b3 = wr_data[07:00];
  assign w_wr_data_b2 = wr_data[15:08];
  assign w_wr_data_b1 = wr_data[23:16];
  assign w_wr_data_b0 = wr_data[31:24];

  always @(posedge clk) begin

    if ( !rst_n )
    begin

      pre_wr_data <= #TCQ 32'b0;
      post_wr_data <= #TCQ 32'b0;
      pre_wr_data <= #TCQ 32'b0;
      write_en   <= #TCQ 1'b0;

      wr_mem_state <= #TCQ PIO_MEM_ACCESS_WR_RST;

    end // if !rst_n
    else
    begin

      case ( wr_mem_state )

        PIO_MEM_ACCESS_WR_RST : begin

          if (wr_en)
          begin // read state
            wr_mem_state <= #TCQ PIO_MEM_ACCESS_WR_WAIT; //Pipelining happens in RAM's internal output reg.
          end
          else
          begin
            write_en <= #TCQ 1'b0;
            wr_mem_state <= #TCQ PIO_MEM_ACCESS_WR_RST;
          end
        end // PIO_MEM_ACCESS_WR_RST

        PIO_MEM_ACCESS_WR_WAIT : begin

          write_en <= #TCQ 1'b0;
          wr_mem_state <= #TCQ PIO_MEM_ACCESS_WR_READ ;

        end // PIO_MEM_ACCESS_WR_WAIT

        PIO_MEM_ACCESS_WR_READ : begin

            // Now save the selected BRAM B port data out

            pre_wr_data <= #TCQ w_pre_wr_data;
            write_en <= #TCQ 1'b0;
            wr_mem_state <= #TCQ PIO_MEM_ACCESS_WR_WRITE;

        end // PIO_MEM_ACCESS_WR_READ

        PIO_MEM_ACCESS_WR_WRITE : begin

          //Merge new enabled data and write target BlockRAM location

          post_wr_data <= #TCQ {{wr_be[3] ? w_wr_data_b3 : w_pre_wr_data_b3},
                               {wr_be[2] ? w_wr_data_b2 : w_pre_wr_data_b2},
                               {wr_be[1] ? w_wr_data_b1 : w_pre_wr_data_b1},
                               {wr_be[0] ? w_wr_data_b0 : w_pre_wr_data_b0}};
          write_en     <= #TCQ 1'b1;
          wr_mem_state <= #TCQ PIO_MEM_ACCESS_WR_RST;

        end // PIO_MEM_ACCESS_WR_WRITE

        default : begin
          // default case stmt
          wr_mem_state <= #TCQ PIO_MEM_ACCESS_WR_RST;
        end // default

      endcase // case (wr_mem_state)
    end // if rst_n
  end

//#### STANDARD DEVICE  ######//
wire        dev_endian_status = 1'b0;        //offset_addr 0x28 '0' – little-endian format.
wire        dev_rtm_status = 1'b0;           //offset_addr 0x28
wire        dev_soft_rst_status = 1'b0;      //offset_addr 0x28
wire        dev_full_rst_status = 1'b0;      //offset_addr 0x28

//#### STANDARD DEVICE REGISTERS ######//
reg  [31:0] dev_interrupt_mask_r ;   // pcie_regs_r[12];          //offset_addr 0x30
wire [31:0] dev_interrupt_flag    = dev_interrupt_mask_r;       //offset_addr 0x34
reg  [31:0] dev_interrupt_active_r; // = 32'h0;                    //offset_addr 0x38
reg  [31:0] dev_scratch_reg_r  ;//      = 32'h0;          //offset_addr 0x3c

reg  [31:0] dev_control_r        = 32'h0;  //offset_addr 0x2c
wire  dev_endian_control   = dev_control_r[`DEV_CNTRL_ENDIAN_BIT];
wire  dev_soft_rst_control = dev_control_r[`DEV_CNTRL_SFT_RST_BIT];
wire  dev_full_rst_control = dev_control_r[`DEV_CNTRL_FULL_RST_BIT];

// Write controller busy

  assign wr_busy = wr_en | (wr_mem_state != PIO_MEM_ACCESS_WR_RST);

  assign w_pre_wr_data = 32'h00;
  reg dma_compl_acq_r ; // //DMAC - host acknowledge DMA interrupt
  assign dma_compl_acq = dma_compl_acq_r;

  integer  reg_idx;
  always @(posedge clk) begin

    if ( !rst_n )
    begin
		dev_scratch_reg <= #TCQ 32'hBB;
	    dev_control_r  <= 32'h0;
        control_r     <= #TCQ 32'h00;
		dma_size_r <= #TCQ 0;
		for (reg_idx = 0; reg_idx < 8; reg_idx = reg_idx + 1)
			dma_address_regs[reg_idx] <= 0;
        dma_compl_acq_r <= 1'b0;
    end // if !rst_n
    else
    begin
		if (write_en)
		begin
			//dev_scratch_reg <= post_wr_data;
			case ( wr_addr )
				11'h00F: dev_scratch_reg <= post_wr_data; // BAR 0 regs
                //11'h010: begin
                    //if (post_wr_data[30] == 1'b1 )
                        //dma_compl_acq_r <= 1'b1; //DMAC - host acknowledge DMA interrupt
                    //end
    (`MOD_DMA_REG_OFF + 11'h008): mod_control_r  <= post_wr_data[31:30];
    (`MOD_DMA_REG_OFF + 11'h00A): mod_interrupt_flag_clear_r  <= post_wr_data;
    (`MOD_DMA_REG_OFF + 11'h00B): mod_interrupt_mask_r        <= post_wr_data;
    //(`MOD_DMA_REG_OFF + 11'h009):
    (`MOD_DMA_REG_OFF + 11'h011): control_r      <= post_wr_data;
    (`MOD_DMA_REG_OFF + 11'h012): dma_size_r     <= post_wr_data[20:0]; // DMA Byte Size
				//11'h011: control_r     <= post_wr_data;
				//11'h012: dma_size_r     <= post_wr_data[20:0]; // DMA Byte Size - data_payload in DW

    (`MOD_DMA_REG_OFF +	11'h020): dma_address_regs[0]   <= post_wr_data;
    (`MOD_DMA_REG_OFF +	11'h021): dma_address_regs[1]   <= post_wr_data;
    (`MOD_DMA_REG_OFF +	11'h022): dma_address_regs[2]   <= post_wr_data;
    (`MOD_DMA_REG_OFF +	11'h023): dma_address_regs[3]   <= post_wr_data;
    (`MOD_DMA_REG_OFF +	11'h024): dma_address_regs[4]   <= post_wr_data;
    (`MOD_DMA_REG_OFF +	11'h025): dma_address_regs[5]   <= post_wr_data;
    (`MOD_DMA_REG_OFF +	11'h026): dma_address_regs[6]   <= post_wr_data;
    (`MOD_DMA_REG_OFF +	11'h027): dma_address_regs[7]   <= post_wr_data;
    //(`MOD_DMA_REG_OFF +	//11'h028: dma_address_regs[8]   <= post_wr_data;
				//11'h029: dma_address_regs[9]   <= post_wr_data;
				//11'h02A: dma_address_regs[10]  <= post_wr_data;
				//11'h02B: dma_address_regs[11]  <= post_wr_data;
				//11'h02C: dma_address_regs[12]  <= post_wr_data;
				//11'h02D: dma_address_regs[13]  <= post_wr_data;
				//11'h02E: dma_address_regs[14]  <= post_wr_data;
				//11'h02F: dma_address_regs[15]  <= post_wr_data;
//BAR 1 addresses
 //      11'200 :   <= post_wr_data;
				default : ;
			endcase
        end
        else if(!status_reg[3])
            dma_compl_acq_r <= 1'b0;
	end
end

  // Handle Read byte enables

  assign rd_data = {{rd_be[0] ? rd_data_raw_o[07:00] : 8'h0},
                      {rd_be[1] ? rd_data_raw_o[15:08] : 8'h0},
                      {rd_be[2] ? rd_data_raw_o[23:16] : 8'h0},
                      {rd_be[3] ? rd_data_raw_o[31:24] : 8'h0}};

/*TRANSLATE_OFF and TRANSLATE_ON instructs the Synthesis tool to ignore blocks of code. */
  // synthesis translate_off
  reg  [8*20:1] state_ascii;
  always @(wr_mem_state)
  begin
    case (wr_mem_state)
      PIO_MEM_ACCESS_WR_RST    : state_ascii <= #TCQ "PIO_MEM_WR_RST";
      PIO_MEM_ACCESS_WR_WAIT   : state_ascii <= #TCQ "PIO_MEM_WR_WAIT";
      PIO_MEM_ACCESS_WR_READ   : state_ascii <= #TCQ "PIO_MEM_WR_READ";
      PIO_MEM_ACCESS_WR_WRITE  : state_ascii <= #TCQ "PIO_MEM_WR_WRITE";
      default                  : state_ascii <= #TCQ "PIO MEM STATE ERR";
    endcase
  end
  // synthesis translate_on

//WARNING: [Synth 8-1958] event expressions must result in a singular type [IO_EP_SHAPI_REGS.v:415]
  genvar k;
  always @(rd_addr or dev_scratch_reg or status_reg or control_r or dma_size_r or dma_address_regs[k])
    begin

      case ( rd_addr)

//BAR 1 addresses
       11'h000 : rd_data_raw_o = {`DEV_MAGIC,`DEV_MAJOR, `DEV_MINOR}; // BAR1 access
       11'h001 : rd_data_raw_o = {`DEV_NEXT_ADDR};
       11'h002 : rd_data_raw_o = {`DEV_HW_ID,`DEV_HW_VENDOR};
       11'h003 : rd_data_raw_o = {`DEV_FW_ID,`DEV_FW_VENDOR};
       11'h004 : rd_data_raw_o = {`DEV_FW_MAJOR,`DEV_FW_MINOR,`DEV_FW_PATCH};
       11'h005 : rd_data_raw_o = {`DEV_TSTAMP};
       11'h006 : rd_data_raw_o = {`DEV_NAME1};
       11'h007 : rd_data_raw_o = {`DEV_NAME2};
       11'h008 : rd_data_raw_o = {`DEV_NAME3};
       11'h009 : rd_data_raw_o = {`DEV_FULL_RST_CAPAB,`DEV_SOFT_RST_CAPAB,28'h0,`DEV_RTM_CAPAB,`DEV_ENDIAN_CAPAB}; // ro
       11'h00A : rd_data_raw_o = {dev_full_rst_status,dev_soft_rst_status,28'h0,dev_rtm_status,dev_endian_status};    //SHAPI status
       11'h00B : rd_data_raw_o = {dev_full_rst_control,dev_soft_rst_control,29'h0,dev_endian_control};                //SHAPI dev control

       11'h00F : rd_data_raw_o = dev_scratch_reg;

    (`MOD_DMA_REG_OFF + 11'h000): rd_data_raw_o <= #TCQ {`MOD_DMA_MAGIC,`MOD_DMA_MAJOR,`MOD_DMA_MINOR};
    (`MOD_DMA_REG_OFF + 11'h001): rd_data_raw_o <= #TCQ {`MOD_DMA_NEXT_ADDR};
    (`MOD_DMA_REG_OFF + 11'h002): rd_data_raw_o <= #TCQ {`MOD_DMA_FW_ID,`MOD_DMA_FW_VENDOR};
    (`MOD_DMA_REG_OFF + 11'h003): rd_data_raw_o <= #TCQ {`MOD_DMA_FW_MAJOR,`MOD_DMA_FW_MINOR,`MOD_DMA_FW_PATCH};
    (`MOD_DMA_REG_OFF + 11'h004): rd_data_raw_o <= #TCQ mod_name[31:0];
    (`MOD_DMA_REG_OFF + 11'h005): rd_data_raw_o <= #TCQ mod_name[63:32];
    (`MOD_DMA_REG_OFF + 11'h006): rd_data_raw_o <= #TCQ {`MOD_DMA_FULL_RST_CAPAB,`MOD_DMA_SOFT_RST_CAPAB,28'h0,`MOD_DMA_RTM_CAPAB,`MOD_DMA_MULTI_INT}; // Module Capabilities - ro

    (`MOD_DMA_REG_OFF + 11'h007): rd_data_raw_o <= #TCQ {mod_full_rst_status,  mod_soft_rst_status, 30'h0};  // Module Status - ro
    (`MOD_DMA_REG_OFF + 11'h008): rd_data_raw_o <= #TCQ {mod_full_rst_control, mod_soft_rst_control, 30'h0}; // Module Control rw
    (`MOD_DMA_REG_OFF + 11'h009): rd_data_raw_o <= #TCQ `MOD_DMA_INTERRUPT_ID; // rw
    (`MOD_DMA_REG_OFF + 11'h00A): rd_data_raw_o <= #TCQ  mod_interrupt_flag_clear_r; // rw
    (`MOD_DMA_REG_OFF + 11'h00B): rd_data_raw_o <= #TCQ  mod_interrupt_mask_r; // rw
    (`MOD_DMA_REG_OFF + 11'h00C): rd_data_raw_o <= #TCQ  mod_interrupt_flag; // ro
    (`MOD_DMA_REG_OFF + 11'h00D): rd_data_raw_o <= #TCQ  mod_interrupt_active; // ro
// ....2
    (`MOD_DMA_REG_OFF + 11'h010): rd_data_raw_o <= #TCQ status_reg; // ro
    (`MOD_DMA_REG_OFF + 11'h011): rd_data_raw_o <= #TCQ control_r; // rw
    (`MOD_DMA_REG_OFF + 11'h012): rd_data_raw_o <= #TCQ {11'b0, dma_size_r}; // rw
    (`MOD_DMA_REG_OFF + 11'h013): rd_data_raw_o <= #TCQ {`MOD_DMA_MAX_BYTES} ; // ro
    (`MOD_DMA_REG_OFF + 11'h014): rd_data_raw_o <= #TCQ {`MOD_DMA_TLP_PAYLOAD}; // ro
// ....11
    (`MOD_DMA_REG_OFF + 11'h020): rd_data_raw_o <= #TCQ dma_address_regs[0];// rw

       //11'h011 : rd_data_raw_o = control_r;
       //11'h012 : rd_data_raw_o =
	   //11'h020 : rd_data_raw_o =

//BAR 0 addresses
 //      11'h200 : rd_data_raw_o = ;

        default : rd_data_raw_o = {21'h0,rd_addr};

      endcase // case (rd_addr)
    end //

  wire [2:0] dma_curr_buff  = status_reg[2:0];

  always @(dma_curr_buff or dma_address_regs[k])
    begin
      case ( dma_curr_buff)
        3'b000: dma_host_addr_r = dma_address_regs[0];
        3'b001: dma_host_addr_r = dma_address_regs[1];
        3'b010: dma_host_addr_r = dma_address_regs[2];
        3'b011: dma_host_addr_r = dma_address_regs[3];
        3'b100: dma_host_addr_r = dma_address_regs[4];
        3'b101: dma_host_addr_r = dma_address_regs[5];
        3'b110: dma_host_addr_r = dma_address_regs[6];
        3'b111: dma_host_addr_r = dma_address_regs[7];
      endcase // case (dma_curr_buff)
    end //

endmodule
