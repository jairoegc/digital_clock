`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: UTFSM
// Engineer: Jairo Gonzalez
// 
// Create Date: 05.01.2020 14:17:43
// Design Name: digital_clock
// Module Name: top
// Project Name: digital_clock
// Target Devices: Nexys4 DDR
// Description: digital clock, configurable led alarm
// 
// Dependencies:
//                  * clv_divider.v
//                  * unsigned_to_bcd.v
//                  * bcd_to_ss.v
//                  * display_mux_v
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top(
        input 	logic CLK100MHZ,
        input   logic CPU_RESETN,
        input   logic BTNR,
        input   logic BTNL,
        input   logic [1:0] SW,
        output  logic [15:0] LED,
        output 	logic [7:0] AN,
        output  logic CA,CB,CC,CD,CE,CF,CG,DP
    );

    //Buttons
    //Reset
    logic rst_status;
    logic rst_press;
    logic rst_release;
    PB_Debouncer #(.DELAY(5_000_000)) cpu_reset_debouncer(
        .clk(CLK100MHZ),
        .rst(1'b0),
        .PB(~CPU_RESETN),
        .PB_pressed_status(rst_status),
        .PB_pressed_pulse(rst_press),
        .PB_released_pulse(rst_release)
    );

    //Adjust minutes
    logic BTNR_status;
    logic BTNR_press;
    logic BTNR_release;
    PB_Debouncer #(.DELAY(5_000_000)) BTNR_debouncer(
        .clk(CLK100MHZ),
        .rst(1'b0),
        .PB(BTNR),
        .PB_pressed_status(BTNR_status),
        .PB_pressed_pulse(BTNR_press),
        .PB_released_pulse(BTNR_release)
    );

    logic adj_minutes;
    button_controller BTNR_controller(
        .PB_pressed_status(BTNR_status),
        .PB_pressed_pulse(BTNR_press),
        .PB_released_pulse(BTNR_release),
        .clk(CLK100MHZ),
        .rst(rst_press),
        .button_signal(adj_minutes)
    );

    //Adjust hours
    logic BTNL_status;
    logic BTNL_press;
    logic BTNL_release;
    PB_Debouncer #(.DELAY(5_000_000)) BTNL_debouncer(
        .clk(CLK100MHZ),
        .rst(1'b0),
        .PB(BTNL),
        .PB_pressed_status(BTNL_status),
        .PB_pressed_pulse(BTNL_press),
        .PB_released_pulse(BTNL_release)
    );

    logic adj_hours;
    button_controller BTNL_controller(
        .PB_pressed_status(BTNL_status),
        .PB_pressed_pulse(BTNL_press),
        .PB_released_pulse(BTNL_release),
        .clk(CLK100MHZ),
        .rst(rst_press),
        .button_signal(adj_hours)
    );
    

    //Timer
    logic [23:0] number_timer;
    timer timer_inst (
        .clk(CLK100MHZ),
        .rst(rst_press),
        .start_timer(1'b1),
        .adjust_minutes((~SW[1])&&adj_minutes),
        .adjust_hours((~SW[1])&&adj_hours),
        .o_number(number_timer[23:0])
    );

    //Alarm
    logic [23:0] number_alarm;
    timer alarm_inst(
        .clk(CLK100MHZ),
        .rst(rst_press),
        .start_timer(1'b0),
        .adjust_minutes(SW[1]&&adj_minutes),
        .adjust_hours(SW[1]&&adj_hours),
        .o_number(number_alarm[23:0])
    );

    logic   play_led_alarm = 1'd0;
    always_ff @(posedge CLK100MHZ) begin
        if (rst_press)
            play_led_alarm <= 1'b0;
        else if (number_alarm[23:0]==number_timer[23:0])
            play_led_alarm <= 1'b1;
        else
            play_led_alarm <= 1'b0;
    end
    
    led_alarm led_inst(
        .clk(CLK100MHZ),
        .rst(rst_press),
        .start(play_led_alarm),
        .LED(LED[15:2])
    );

    //Timer mode: Clok vs Alarm
    assign LED[1] = SW[1];

    logic [23:0] number = 24'd0;
    logic [23:0] number_next = 24'd0;
    always_comb begin
        if (SW[1])
            number_next[23:0] = number_alarm[23:0];
        else
            number_next[23:0] = number_timer[23:0];
    end
    always_ff @(posedge CLK100MHZ) begin
        if (rst_press)
            number[23:0] <= 24'd0;
        else    
            number[23:0] <= number_next[23:0];
    end
    
    
    //Time format
    assign LED[0] = SW[0];

    logic [23:0] final_number = 24'd0;
    logic [23:0] final_number_next = 24'd0;
    always_comb begin
        if (SW[0]&&(number[23:0]>='d130000))
            final_number_next[23:0] = number[23:0]-'d120000;
        else if (SW[0]&&(number[23:0]<'d10000))
            final_number_next[23:0] = number[23:0]+'d120000;
        else
            final_number_next[23:0] = number[23:0];
    end
    
    always_ff @(posedge CLK100MHZ) begin
        if (rst_press)
            final_number[23:0] <= 24'd0;
        else
            final_number[23:0] <= final_number_next[23:0];
    end

    // Adapt numbert to BCD format, for display purpose
    logic idle;
    logic [31:0] bcd;
    unsigned_to_bcd u32_to_bcd_inst (
		.clk(CLK100MHZ),
		.trigger(1'b1),
		.in({8'd0,final_number[23:0]}),
		.idle(idle),
		.bcd(bcd[31:0])
	);

     //Display
    logic clk_display;
    clk_divider #(.O_CLK_FREQ(1000)) clk_divider_display (
        .clk_in(CLK100MHZ),
        .reset(rst_press),
        .clk_out(clk_display)
    );

    display_mux display_inst (
        .clk(clk_display),
        .clk_enable(1'b1),
        .bcd({8'hFF,bcd[23:0]}),
        .dots(8'd0),
        .is_negative(1'b0),
        .turn_off(1'b0),
        .ss_value({DP,CG,CF,CE,CD,CC,CB,CA}),
        .ss_select(AN[7:0])
    );

endmodule
