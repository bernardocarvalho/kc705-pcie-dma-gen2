//////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Company: INSTITUTO DOS PLASMAS E FUSAO NUCLEAR
// Engineer:  BBC
//
// Project Name:   W7X ATCA DAQ
// Design Name:    ATCA W7X_STREAM_DAQ FIRMWARE
// Module Name:    system_clocks
// Target Devices: XC4VFX60-11FF1152 or XC4VFX100-11FF1152
//
//Description:
//
// Copyright 2015 - 2015 IPFN-Instituto Superior Tecnico, Portugal
// Creation Date  2015-09-10
//
// Licensed under the EUPL, Version 1.1 or - as soon they
// will be approved by the European Commission - subsequent
// versions of the EUPL (the "Licence");

// You may not use this work except in compliance with the
// Licence.
// You may obtain a copy of the Licence at:
//
// http://ec.europa.eu/idabc/eupl
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
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////
// check XDMA/Vivado/2018.2/kc705-xdma-axi4-stream-adc/hdl/design/system_clocks.v for BUFGCE
`timescale 1ns/1ps

module system_clocks (
    input  clk_200,
    output locked,
    output clk_100,
    output [5:0] clk_100_cnt,
    output clk_16,
    output data_clk,
    //	output internal_clk_4MHz125,
    output ADCs_word_sync,
    output ADCs_start_conv_out, // delay 50ns
    output clk_2mhz_utdc  // sync with ADCs_word_sync but duty cycle = 50%
);

    ///////////////////////////////////////////////////////////    PLL -> 2mhz generator //////////////////////////////////////////
    reg [5:0] counter = 6'd0;
    assign clk_100_cnt = counter;

    reg start_conv_n= 1'b1;
    reg clk_out_r= 1'b1;

    reg word_sync_n= 1'b1;
    wire  clk_200_fb, clk_100_o, clk_16_o, data_clk_o;

    MMCME2_BASE #(
        .BANDWIDTH("OPTIMIZED"),   // Jitter programming (OPTIMIZED, HIGH, LOW)
        .CLKFBOUT_MULT_F(4.0),     // Multiply value for all CLKOUT (2.000-64.000).
        .CLKFBOUT_PHASE(0.0),      // Phase offset in degrees of CLKFB (-360.000-360.000).
        .CLKIN1_PERIOD(5.0),       // Input clock period in ns to ps resolution 200 MHz).
        // CLKOUT0_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
        .CLKOUT0_DIVIDE_F(8.0),    // Divide amount for CLKOUT0 (1.000-128.000). 100 Mhz
        //      .CLKOUT0_DIVIDE(8),   //100 Mhz
        .CLKOUT1_DIVIDE(50),  // 16 MHz
        .CLKOUT2_DIVIDE(128), // 6.25 MHz
        .CLKOUT3_DIVIDE(40),
        .CLKOUT4_DIVIDE(1),
        .CLKOUT5_DIVIDE(1),
        .CLKOUT6_DIVIDE(1),
        // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.01-0.99).
        .CLKOUT0_DUTY_CYCLE(0.5),
        .CLKOUT1_DUTY_CYCLE(0.5),
        .CLKOUT2_DUTY_CYCLE(0.5),
        .CLKOUT3_DUTY_CYCLE(0.5),
        .CLKOUT4_DUTY_CYCLE(0.5),
        .CLKOUT5_DUTY_CYCLE(0.5),
        .CLKOUT6_DUTY_CYCLE(0.5),
        // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
        .CLKOUT0_PHASE(0.0),
        .CLKOUT1_PHASE(0.0),
        .CLKOUT2_PHASE(0.0),
        .CLKOUT3_PHASE(0.0),
        .CLKOUT4_PHASE(0.0),
        .CLKOUT5_PHASE(0.0),
        .CLKOUT6_PHASE(0.0),
        .CLKOUT4_CASCADE("FALSE"), // Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
        .DIVCLK_DIVIDE(1),         // Master division value (1-106)
        .REF_JITTER1(0.0),         // Reference input jitter in UI (0.000-0.999).
        .STARTUP_WAIT("FALSE")     // Delays DONE until MMCM is locked (FALSE, TRUE)
    )
    MMCME2_BASE_200_osc (
        // Clock Outputs: 1-bit (each) output: User configurable clock outputs
        .CLKOUT0(clk_100_o),     // 1-bit output: CLKOUT0
        .CLKOUT0B(),              // 1-bit output: Inverted CLKOUT0
        .CLKOUT1(clk_16_o),     // 1-bit output: CLKOUT1
        .CLKOUT1B(),             // 1-bit output: Inverted CLKOUT1
        .CLKOUT2(data_clk_o),     // 1-bit output: CLKOUT2
        .CLKOUT2B(),   // 1-bit output: Inverted CLKOUT2
        .CLKOUT3(),     // 1-bit output: CLKOUT3
        .CLKOUT3B(),   // 1-bit output: Inverted CLKOUT3
        .CLKOUT4(),     // 1-bit output: CLKOUT4
        .CLKOUT5(),     // 1-bit output: CLKOUT5
        .CLKOUT6(),     // 1-bit output: CLKOUT6
        // Feedback Clocks: 1-bit (each) output: Clock feedback ports
        .CLKFBOUT(clk_200_fb),   // 1-bit output: Feedback clock
        .CLKFBOUTB(), // 1-bit output: Inverted CLKFBOUT
        // Status Ports: 1-bit (each) output: MMCM status ports
        .LOCKED(locked),       // 1-bit output: LOCK
        // Clock Inputs: 1-bit (each) input: Clock input
        .CLKIN1(clk_200),       // 1-bit input: Clock
        // Control Ports: 1-bit (each) input: MMCM control ports
        .PWRDWN(1'b0),       // 1-bit input: Power-down
        .RST(1'b0),             // 1-bit input: Reset
        // Feedback Clocks: 1-bit (each) input: Clock feedback ports
        .CLKFBIN(clk_200_fb)      // 1-bit input: Feedback clock
    );

    BUFG BUFG_100 (
        .O(clk_100), // 1-bit output: Clock output
        .I(clk_100_o)  // 1-bit input: Clock input
    );
    BUFG BUFG_16 (
        .O(clk_16), // 1-bit output: Clock output
        .I(clk_16_o)  // 1-bit input: Clock input
    );
    BUFG BUFG_data (
        .O(data_clk), // 1-bit output: Clock output
        .I(data_clk_o)  // 1-bit input: Clock input
    );

    always @ (posedge clk_100 )
    begin
        counter <= counter + 1;

        if(counter == 6'd17)
            clk_out_r <= 1'b0;
        else if(counter == 6'd33)
            word_sync_n <= 1'b0;
        else if(counter == 6'd38)
            word_sync_n <= 1'b1;
        else if(counter == 6'd43)
        begin
            start_conv_n <= 1'b0;
            clk_out_r <= 1'b1;
        end
        else if(counter == 6'd49) // - divide by 50 -> 2MSMS
        begin
            start_conv_n <= 1'b1;
            counter <= 0;
        end
    end

    assign clk_2mhz_utdc  = clk_out_r;
    assign ADCs_word_sync = word_sync_n;
    assign ADCs_start_conv_out = start_conv_n; // delay 50ns

    //	reg [2:0] start_conv_dly = 3'b111;
    //	reg clk_2MHz_dly1=1'b1;
    //	reg clk_2MHz_dly2=1'b1;
    //
    //	always @ (posedge PLL_clk_100MHz)
    //	begin
    //		 clk_2MHz_dly1 <= ATCA_2MHz_clock;
    //		 clk_2MHz_dly2 <= clk_2MHz_dly1;
    //		 start_conv_dly[2:1] <= start_conv_dly[1:0];
    //		 start_conv_dly[0]   <= clk_2MHz_dly2 | ~clk_2MHz_dly1; // detect rising transition with a low pulse
    //	end
    //
    //	//wire signal_to_sync;
    //	//wire dcmout;
    //
    //	//BUFG dcminput (
    //	//	.O(signal_to_sync),
    //	//	.I(start_conv_dly[0])
    //	//);
    //
    //	//BUFG globalsyncclk (
    //	//	.O(ADCs_start_conv), // Clock buffer output
    //	//	.I(dcmout) // Clock buffer input (connect directly to top-level port)
    //	//);
    //
    //	//DCM_BASE adcsyncclk (
    //	//	.CLKIN(signal_to_sync),
    //	//	.CLKFB(ADCs_start_conv),
    //	//	.CLK0(dcmout),
    //	//	.RST(1'b0)
    //	//	);
    //	assign ADCs_word_sync		=start_conv_dly[0];
    //	assign ADCs_start_conv_out = start_conv_dly[2]; // delay 50ns

endmodule // system_clocks
