//
//-----------------------------------------------------------------------------
// Project    : Series-7 Integrated Block for PCI Express
// File       : PIO_DMA_TX_ENGINE.v
// Version    : 3.3

`timescale 1ps/1ps

(* DowngradeIPIdentifiedWarnings = "yes" *)
module PIO_DMA_TX_ENGINE    #(
  // RX/TX interface data width
  parameter C_DATA_WIDTH = 64,
  parameter TCQ = 1,

  // TSTRB width
  parameter KEEP_WIDTH = C_DATA_WIDTH / 8
)(

  input             clk,
  input             rst_n,

  // AXIS
  input                           s_axis_tx_tready,
  output  reg [C_DATA_WIDTH-1:0]  s_axis_tx_tdata,
  output  reg [KEEP_WIDTH-1:0]    s_axis_tx_tkeep,
  output  reg                     s_axis_tx_tlast,
  output  reg                     s_axis_tx_tvalid,
  output                          tx_src_dsc,

  input                           req_compl,
  input                           req_compl_wd,
  output reg                      compl_done,

  input [2:0]                     req_tc,
  input                           req_td,
  input                           req_ep,
  input [1:0]                     req_attr,
  input [9:0]                     req_len,
  input [15:0]                    req_rid,
  input [7:0]                     req_tag,
  input [7:0]                     req_be,
  input [12:0]                    req_addr,

  output [10:0]                   rd_addr, // Present address and byte enable to memory module
  output [3:0]                    rd_be,
  input  [31:0]                   rd_data,
  input [15:0]                    completer_id,

  input [63:0]                    dma_data,
  input [31:0]					  dma_host_addr,
  input							  dma_start_wr,
  input [9:0]   				  dma_payload_size
);

localparam PIO_CPLD_FMT_TYPE      = 7'b10_01010; // completion with data
localparam PIO_CPL_FMT_TYPE       = 7'b00_01010; // completion without data
localparam PIO_MWR_FMT_TYPE       = 7'b10_00000; // write with data - DMA tx

localparam PIO_TX_RST_STATE       = 3'b000;
localparam PIO_TX_CPLD_QW1_FIRST  = 3'b001;
localparam PIO_TX_CPLD_QW1_TEMP   = 3'b010;
localparam PIO_TX_CPLD_QW1        = 3'b011;

localparam PIO_TX_MWR_QW1         = 3'b100;
localparam PIO_TX_MWR_QW2         = 3'b101;

  // Local registers

  reg [11:0]              byte_count;
  reg [6:0]               lower_addr;

  reg                     req_compl_q;
  reg                     req_compl_wd_q;

  reg                     compl_busy_i;

  reg [7:0]               rd_be_r;

  reg [9:0]     rd_len;
  reg [31:0]    dma_msb_data_r;

  // Local wires

  wire                    compl_wd;
// DMA
	wire [2:0]    req_tc_wr    = 3'b0;
	wire          req_td_wr    = 1'b0;
	wire          req_ep_wr    = 1'b0;
	wire [1:0]    req_attr_wr  = 2'b00;
	wire [9:0]    req_len_wr   = dma_payload_size; //data payload max in DW: 32DW (6 bits)
	wire [7:0]    req_tag_wr   = 8'b00001111;
	wire [3:0]	  last_DW_wr   = 4'b1111;
	wire [3:0]	  first_DW_wr  = 4'b1111;

  // Unused discontinue
  assign tx_src_dsc = 1'b0;

  // Present address and byte enable to memory module

  assign rd_addr = req_addr[12:2];

  always @(posedge clk) begin
    if (!rst_n)
    begin
     rd_be_r <= #TCQ 0;
    end else begin
     rd_be_r <= #TCQ req_be;
    end
  end

  assign rd_be = rd_be_r[3:0];

  // Calculate byte count based on byte enable
  //   PCI express base specification rev 1.1 (page 91)
  // according to last bit and first bit
  always @ (rd_be_r, req_len) begin
    casex (rd_be_r)
      8'b00001xx1 : byte_count = 12'h004;
      8'b000001x1 : byte_count = 12'h003;
      8'b00001x10 : byte_count = 12'h003;
      8'b00000011 : byte_count = 12'h002;
      8'b00000110 : byte_count = 12'h002;
      8'b00001100 : byte_count = 12'h002;
      8'b00000001 : byte_count = 12'h001;
      8'b00000010 : byte_count = 12'h001;
      8'b00000100 : byte_count = 12'h001;
      8'b00001000 : byte_count = 12'h001;
      8'b00000000 : byte_count = 12'h001;
      8'b1xxxxxx1 : byte_count = req_len*3'b100;
      8'b01xxxxx1 : byte_count = req_len*3'b100 - 3'b001;
      8'b001xxxx1 : byte_count = req_len*3'b100 - 3'b010;
      8'b0001xxx1 : byte_count = req_len*3'b100 - 3'b011;
      8'b1xxxxx10 : byte_count = req_len*3'b100 - 3'b001;
      8'b01xxxx10 : byte_count = req_len*3'b100 - 3'b010;
      8'b001xxx10 : byte_count = req_len*3'b100 - 3'b011;
      8'b0001xx10 : byte_count = req_len*3'b100 - 3'b100;
      8'b1xxxx100 : byte_count = req_len*3'b100 - 3'b010;
      8'b01xxx100 : byte_count = req_len*3'b100 - 3'b011;
      8'b001xx100 : byte_count = req_len*3'b100 - 3'b100;
      8'b0001x100 : byte_count = req_len*3'b100 - 3'b101;
      8'b1xxx1000 : byte_count = req_len*3'b100 - 3'b011;
      8'b01xx1000 : byte_count = req_len*3'b100 - 3'b100;
      8'b001x1000 : byte_count = req_len*3'b100 - 3'b101;
      8'b00011000 : byte_count = req_len*3'b100 - 3'b110;
    endcase
  end

  always @ ( posedge clk ) begin
    if (!rst_n )
    begin
      req_compl_q      <= #TCQ 1'b0;
      req_compl_wd_q   <= #TCQ 1'b1;
    end // if !rst_n
    else
    begin
      req_compl_q      <= #TCQ req_compl;
      req_compl_wd_q   <= #TCQ req_compl_wd;
    end // if rst_n
  end

 //Calculate lower address based on byte enable:
    always @ (rd_be_r or req_addr or compl_wd) begin
    casex ({compl_wd, rd_be_r[3:0]})
       5'b1_0000 : lower_addr = {req_addr[6:2], 2'b00};
       5'b1_xxx1 : lower_addr = {req_addr[6:2], 2'b00};
       5'b1_xx10 : lower_addr = {req_addr[6:2], 2'b01};
       5'b1_x100 : lower_addr = {req_addr[6:2], 2'b10};
       5'b1_1000 : lower_addr = {req_addr[6:2], 2'b11};
       5'b0_xxxx : lower_addr = 8'h0;
    endcase // casex ({compl_wd, rd_be_r[3:0]})
    end

  //  Generate Completion with 1 DW Payload / DMA packets

  generate
    if (C_DATA_WIDTH == 64) begin : gen_cpl_64
      reg         [3:0]            state;

      assign compl_wd = req_compl_wd_q;

      always @ ( posedge clk ) begin

        if (!rst_n )
        begin
          s_axis_tx_tlast   <= #TCQ 1'b0;
          s_axis_tx_tvalid  <= #TCQ 1'b0;
          s_axis_tx_tdata   <= #TCQ {C_DATA_WIDTH{1'b0}};
          s_axis_tx_tkeep   <= #TCQ {KEEP_WIDTH{1'b0}};

          compl_done        <= #TCQ 1'b0;
          compl_busy_i      <= #TCQ 1'b0;
          state             <= #TCQ PIO_TX_RST_STATE;
        end // if (!rst_n )
        else
        begin
          compl_done        <= #TCQ 1'b0;
          // -- Generate compl_busy signal...
          if (req_compl_q )
            compl_busy_i <= 1'b1;
          case ( state )
            PIO_TX_RST_STATE : begin

              if (compl_busy_i)
              begin

                s_axis_tx_tdata   <= #TCQ {C_DATA_WIDTH{1'b0}};
                s_axis_tx_tkeep   <= #TCQ 8'hFF;
                s_axis_tx_tlast   <= #TCQ 1'b0;
                s_axis_tx_tvalid  <= #TCQ 1'b0;
                if (s_axis_tx_tready)
                    state             <= #TCQ PIO_TX_CPLD_QW1_FIRST;
                else
                    state             <= #TCQ PIO_TX_RST_STATE;
               end
               else
                  if (dma_start_wr && s_axis_tx_tready) begin
                      s_axis_tx_tlast  <= #TCQ 1'b0;
                      s_axis_tx_tvalid <= #TCQ 1'b1;
                      s_axis_tx_tdata  <= #TCQ {   // Bits - Swap DWORDS for AXI
                          completer_id,
                          req_tag_wr,
                          last_DW_wr,
                          first_DW_wr,
                          {1'b0},
                          PIO_MWR_FMT_TYPE,
                          {1'b0},
                          req_tc_wr,
                          {4'b0},
                          req_td_wr,
                          req_ep_wr,
                          req_attr_wr,
                          {2'b0},
                          req_len_wr
                          };
                          s_axis_tx_tkeep   <= #TCQ 8'hFF;

                          //if (s_axis_tx_tready)
                          state        <= #TCQ PIO_TX_MWR_QW1;
                          //else
                          //	state           <= #TCQ PIO_TX_RST_STATE; // Wait in this state if the PCIe core does not accept the first beat of the packet

                      end // if(dma_start_wr && s_axis_tx_tready)
                  else
                  begin

                      s_axis_tx_tlast   <= #TCQ 1'b0;
                      s_axis_tx_tvalid  <= #TCQ 1'b0;
                      s_axis_tx_tdata   <= #TCQ 64'b0;
                      s_axis_tx_tkeep   <= #TCQ 8'hFF;
                      compl_done        <= #TCQ 1'b0;
                      state             <= #TCQ PIO_TX_RST_STATE;

                  end // if !(compl_busy)
              end // PIO_TX_RST_STATE

            PIO_TX_CPLD_QW1_FIRST : begin
              if (s_axis_tx_tready) begin

                s_axis_tx_tlast  <= #TCQ 1'b0;
                s_axis_tx_tdata  <= #TCQ {                      // Bits
                                      completer_id,             // 16
                                      {3'b0},                   // 3
                                      {1'b0},                   // 1
                                      byte_count,               // 12
                                      {1'b0},                   // 1
                                      (req_compl_wd_q ?
                                      PIO_CPLD_FMT_TYPE :
                                      PIO_CPL_FMT_TYPE),        // 7
                                      {1'b0},                   // 1
                                      req_tc,                   // 3
                                      {4'b0},                   // 4
                                      req_td,                   // 1
                                      req_ep,                   // 1
                                      req_attr,                 // 2
                                      {2'b0},                   // 2
                                      req_len                   // 10
                                      };
                s_axis_tx_tkeep   <= #TCQ 8'hFF;

                state             <= #TCQ PIO_TX_CPLD_QW1_TEMP;
                end
            else
                // Wait in this state if the PCIe core does not accept the first beat of the packet
                state             <= #TCQ PIO_TX_RST_STATE;

               end //PIO_TX_CPLD_QW1_FIRST


            PIO_TX_CPLD_QW1_TEMP : begin
                s_axis_tx_tvalid    <= #TCQ 1'b1;
                state               <= #TCQ PIO_TX_CPLD_QW1;
            end


            PIO_TX_CPLD_QW1 : begin

              if (s_axis_tx_tready)
              begin

                s_axis_tx_tlast  <= #TCQ 1'b1;
                s_axis_tx_tvalid <= #TCQ 1'b1;
                s_axis_tx_tdata  <= #TCQ {        // Bits
                                      rd_data,    // 32
                                      req_rid,    // 16
                                      req_tag,    //  8
                                      {1'b0},     //  1
                                      lower_addr  //  7
                                      };

                // Here we select if the packet has data or
                // not.  The strobe signal will mask data
                // when it is not needed.  No reason to change
                // the data bus.
                if (req_compl_wd_q)
                  s_axis_tx_tkeep <= #TCQ 8'hFF;
                else
                  s_axis_tx_tkeep <= #TCQ 8'h0F;


                compl_done        <= #TCQ 1'b1;
                compl_busy_i      <= #TCQ 1'b0;
                state             <= #TCQ PIO_TX_RST_STATE;

              end // if (s_axis_tx_tready)
              else
                state             <= #TCQ PIO_TX_CPLD_QW1;

            end // PIO_TX_CPLD_QW1
            PIO_TX_MWR_QW1: begin

                if (s_axis_tx_tready) begin
                    s_axis_tx_tlast  <= #TCQ 1'b0;
                    s_axis_tx_tvalid <= #TCQ 1'b1;
                    //s_axis_tx_tdata  <= #TCQ {		// Bits - Swap DWORDS for AXI
                    s_axis_tx_tdata  <= #TCQ {
                        dma_data[31:0],
                        dma_host_addr[31:2],
                        {2'b0}
                        };
                    s_axis_tx_tkeep  <= #TCQ 8'hFF;
                    dma_msb_data_r   <= dma_data[63:32];
                    rd_len	         <= req_len_wr - 1'b1;
                    state            <= #TCQ PIO_TX_MWR_QW2;
                    end
                end // PIO_TX_MWR_QW1

            PIO_TX_MWR_QW2: begin

                if (s_axis_tx_tready) begin
                    s_axis_tx_tvalid <= #TCQ 1'b1;
                    s_axis_tx_tdata  <= #TCQ {
                        dma_data[31:0],
                        dma_msb_data_r
                        };
                    dma_msb_data_r   <= dma_data[63:32];

                    if (rd_len == 10'b1) begin
                        s_axis_tx_tlast  <= #TCQ 1'b1;
                        s_axis_tx_tkeep  <= #TCQ 8'h0F;
                        rd_len	         <= #TCQ 10'b0;
                        compl_done       <= #TCQ 1'b1;
                        state            <= #TCQ PIO_TX_RST_STATE;
                    end
                    else if (rd_len == 10'b0) begin
                        s_axis_tx_tlast  <= #TCQ 1'b1;
                        s_axis_tx_tkeep  <= #TCQ 8'h00;
                        //rd_len	         <= #TCQ 10'b0;
                        compl_done       <= #TCQ 1'b1;
                        state            <= #TCQ PIO_TX_RST_STATE;
                    end
                    else begin
                        s_axis_tx_tlast  <= #TCQ 1'b0;
                        s_axis_tx_tkeep  <= #TCQ 8'hFF;
                        rd_len	         <= #TCQ (rd_len - 2'b10);
                    end
                end  // if (s_axis_tx_tready)
            end // PIO_TX_MWR_QW2

            default : begin
              // case default st_mc
              state             <= #TCQ PIO_TX_RST_STATE;
            end

          endcase
        end // if rst_n
      end
    end
    else if (C_DATA_WIDTH == 128) begin : gen_cpl_128 // NOT IMPLEMENTED !!!
      reg                     hold_state;
      reg                     req_compl_q2;
      reg                     req_compl_wd_q2;

      assign compl_wd = req_compl_wd_q2;

      always @ ( posedge clk ) begin
        if (!rst_n )
        begin
          req_compl_q2      <= #TCQ 1'b0;
          req_compl_wd_q2   <= #TCQ 1'b0;
        end // if (!rst_n )
        else
        begin
          req_compl_q2      <= #TCQ req_compl_q;
          req_compl_wd_q2   <= #TCQ req_compl_wd_q;
        end // if (rst_n )
      end

      always @ ( posedge clk ) begin
        if (!rst_n )
        begin
          s_axis_tx_tlast   <= #TCQ 1'b0;
          s_axis_tx_tvalid  <= #TCQ 1'b0;
          s_axis_tx_tdata   <= #TCQ {C_DATA_WIDTH{1'b0}};
          s_axis_tx_tkeep   <= #TCQ {KEEP_WIDTH{1'b0}};
          compl_done        <= #TCQ 1'b0;
          hold_state        <= #TCQ 1'b0;
        end // if !rst_n
        else
        begin

          if (req_compl_q2 | hold_state)
          begin
            if (s_axis_tx_tready)
            begin

              s_axis_tx_tlast   <= #TCQ 1'b1;
              s_axis_tx_tvalid  <= #TCQ 1'b1;
              s_axis_tx_tdata   <= #TCQ {                   // Bits
                                  rd_data,                  // 32
                                  req_rid,                  // 16
                                  req_tag,                  //  8
                                  {1'b0},                   //  1
                                  lower_addr,               //  7
                                  completer_id,             // 16
                                  {3'b0},                   //  3
                                  {1'b0},                   //  1
                                  byte_count,               // 12
                                  {1'b0},                   //  1
                                  (req_compl_wd_q2 ?
                                  PIO_CPLD_FMT_TYPE :
                                  PIO_CPL_FMT_TYPE),        //  7
                                  {1'b0},                   //  1
                                  req_tc,                   //  3
                                  {4'b0},                   //  4
                                  req_td,                   //  1
                                  req_ep,                   //  1
                                  req_attr,                 //  2
                                  {2'b0},                   //  2
                                  req_len                   // 10
                                  };

              // Here we select if the packet has data or
              // not.  The strobe signal will mask data
              // when it is not needed.  No reason to change
              // the data bus.
              if (req_compl_wd_q2)
                s_axis_tx_tkeep   <= #TCQ 16'hFFFF;
              else
                s_axis_tx_tkeep   <= #TCQ 16'h0FFF;

              compl_done        <= #TCQ 1'b1;
              hold_state        <= #TCQ 1'b0;

            end // if (s_axis_tx_tready)
            else
              hold_state        <= #TCQ 1'b1;

          end // if (req_compl_q2 | hold_state)
          else
          begin

            s_axis_tx_tlast   <= #TCQ 1'b0;
            s_axis_tx_tvalid  <= #TCQ 1'b0;
            s_axis_tx_tdata   <= #TCQ {C_DATA_WIDTH{1'b0}};
            s_axis_tx_tkeep   <= #TCQ {KEEP_WIDTH{1'b1}};
            compl_done        <= #TCQ 1'b0;

          end // if !(req_compl_q2 | hold_state)
        end // if rst_n
      end
    end
  endgenerate

endmodule // PIO_DMA_TX_ENGINE
