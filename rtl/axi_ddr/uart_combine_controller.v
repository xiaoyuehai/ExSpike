// -----------------------------------------------------------------------------
// Copyright (c) 2025-2026 All rights reserved
// -----------------------------------------------------------------------------
// Author : Yuehai Chen yuehai.chen@rug.nl
// File   : axi_ddr/uart_combine_controller.v
// Create : 2025-12-01 10:00:00
// Revise : 2025-12-01 10:00:00
// Editor : vscode, tab size (4)
// Description: UART combine controller for host interface.
// -----------------------------------------------------------------------------

`include "../defines.vh"
module UART_COMBINE_CONTROLLER(
	input wire				clk,
	input wire				rst_n,
	input wire				uart_rx,
	input wire             one_nn_cal_success,
	(* mark_debug="true" *)output wire	[1023:0]	uart_combine_data,
	(* mark_debug="true" *)output wire				uart_combine_data_valid,
	(* mark_debug="true" *)output wire	[15:0]		uart_combine_w_addr,
    output reg              [7:0] uart_time_step,
	output wire 				cal_interrupt_uart

);
	wire	[7:0]	rx_data;
	wire			po_flag;
	reg		[1023:0]combine_data;
	reg		[7:0]	counter;
	reg		[15:0]	combine_addr;
	reg				combine_addr_w;
    reg wait_time_step;
	input_uart_r inst_input_uart_r (
		.sclk(clk), 
		.s_rst_n(rst_n), 
		.rx(uart_rx), 
		.rx_data(rx_data), 
		.po_flag(po_flag));

	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			combine_data <= 0;
		end
		else if(one_nn_cal_success || uart_combine_data_valid)begin
		    combine_data <= 0;
		end
		else if(po_flag && wait_time_step == 1'b0)begin
			// combine_data[7:0] <= rx_data;
			combine_data <= {combine_data[0 +: 1016],rx_data};
		end
	end

	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			counter <= 0;
			combine_addr_w <= 0;
		end
		else if(one_nn_cal_success)begin
		    counter <= 0;
			combine_addr_w <= 0;
		end
		else if(po_flag && wait_time_step == 1'b0)begin
			if(counter == 3 - 1)begin
				counter <= 0;
				combine_addr_w <= 1;
			end
			else begin
				counter <= counter + 1;
				combine_addr_w <= 0;
			end
		end
		else begin
			combine_addr_w <= 0;
		end
	end
    reg cal_interrupt_uart_first;
	always@(posedge clk or negedge rst_n)begin
		if(!rst_n)begin
			combine_addr <= 0;
			cal_interrupt_uart_first <= 0;
		end
		else if(one_nn_cal_success)begin
		    combine_addr <= 0;
			cal_interrupt_uart_first <= 0;
		end
		else if(combine_addr_w)begin
			if(combine_addr == 4096 - 1)begin
				combine_addr <= 0;
				cal_interrupt_uart_first <= 1;
			end
			else begin
				combine_addr <= combine_addr + 1;
				cal_interrupt_uart_first <= 0;
			end
		end
		else begin
			cal_interrupt_uart_first <= 0;
		end
	end
	
	
	always@(posedge clk or negedge rst_n)begin
        if(rst_n == 1'b0)begin
            wait_time_step <= 0;
        end
        else if(cal_interrupt_uart_first)begin
            wait_time_step <= 1;
        end
        else if(po_flag)begin
            wait_time_step <= 0;
        end
    end
    
    assign cal_interrupt_uart = wait_time_step & po_flag;
    
	assign uart_combine_w_addr     = combine_addr;
	assign uart_combine_data       = combine_data;
	assign uart_combine_data_valid = combine_addr_w;
	
	always@(posedge clk or negedge rst_n)begin
	   if(rst_n == 1'b0)begin
		`ifdef POWER_ESTIMATION
			uart_time_step <= 1;
		`elsif VGG11_CIFAR10
	       	uart_time_step <= 2;
		`elsif ResNet18_CIFAR10
			uart_time_step <= 2;
		`elsif ST4_CIFAR10
			uart_time_step <= 1;
		`elsif ST2_CIFAR100
			uart_time_step <= 2;
		`elsif SEG_NET
			uart_time_step <= 1;
		`else
			uart_time_step <= 1;
		`endif
	   end
	   else if(wait_time_step && po_flag)begin
	       uart_time_step <= uart_time_step;//rx_data;
	   end
	end

endmodule
 