`timescale 1ns/1ps
`include "../defines.vh"
module tb_top();
	reg clk;
	reg rst_n;
	reg Key_Signal;
	wire uart_tx;
	reg uart_rx;

	reg [7:0] uart_rx_get [0:16384];
	// initial begin
	// 	// $readmemh("C:/Sparity_SCNN_Design/SW/Python_Project/Sparsity_SCNN_Acceleration/SNN/DVS_Gesture_P32/P32_T8/uart_send.txt",uart_rx_get);
	// 	// $readmemh("C:/Python_Project/SNN_FPL/ST/model_preprocess/Config_files/uart_send.txt", uart_rx_get); 
	// end
     wire success = inst_accelerator_top.cal_finish;
//     wire arest_n = inst_accelerator_top.arest_n;
//    wire success = inst_accelerator_top.inst_sim_top.inst_PE_cal_controller.state == 4;//6
//    wire success_0 = inst_accelerator_top.inst_sim_top.read_from_buffer_0;
	/////**  clk Generate **/////
	initial begin
		clk = 0;
	end

	always #(2.5) clk = ~clk;
	integer i;
	/////**  rst_n Generate **/////
	initial begin
		rst_n = 0;
		 Key_Signal = 1;
		#100;
		rst_n = 1;
		#100;
		
          @(posedge clk)begin
            Key_Signal <= 0;
          end
    
          @(posedge clk)begin
            Key_Signal <= 1;
          end
        
          @(posedge success)begin
			#100;
                  $finish;
          end
		 @(posedge clk)begin
            for(i=0;i<12288;i=i+1)begin
                uart_tx_byte(uart_rx_get[i]);
            end
            uart_tx_byte(4);
        end
		// @(posedge clk)begin
		// 	Key_Signal <= 0;
		// end

		// @(posedge clk)begin
		// 	Key_Signal <= 1;
		// end
		
		@(posedge success)begin
		        $finish;
		end

		@(posedge clk)begin
            for(i=0;i<3072;i=i+1)begin
                uart_tx_byte(uart_rx_get[i]);
            end
        end
		
		@(posedge success)begin
		      $finish;
		end
		// @(posedge clk)begin
		// 	Key_Signal <= 0;
		// end

		// @(posedge clk)begin
		// 	Key_Signal <= 1;
		// end
	end
	/////**  Function Signal define **/////
		///ddr port
	wire			RD_START;
	wire	[31:0]	RD_ADRS;
	wire	[31:0]	RD_LEN; 
	wire	[2 :0]	RD_SIZE;

	wire			RD_READY;
	wire			RD_FIFO_WE;
	wire	[255:0]	RD_FIFO_DATA;
	wire			RD_DONE;
	wire			RD_LAST;
    wire				WR_START;
	wire	[31:0]		WR_ADRS;
	wire	[31 :0]		WR_LEN;
	wire				WR_READY;
	wire				WR_FIFO_RE;
	wire	[255:0]		WR_FIFO_DATA;
	wire				WR_DONE;
	wire	[2:0]		WR_SIZE;
	wire	[31:0]		WR_STRB ;
	//////////////////////////////////////

	/////**  Top Module  **/////
`ifdef POWER_GATE_NETLIST
	EVENT_PROCESSOR_TOP inst_accelerator_top (
`else
	EVENT_PROCESSOR_TOP #(
    .parallel_metric(32),
    .ddr_data_width (256)
	)
	inst_accelerator_top (
`endif
//		.clk_in_p(clk),
//		.clk_in_n(~clk), 
        .clk(clk),
		.rst_n(rst_n), 
		.Key_Signal(Key_Signal),
		.uart_tx(uart_tx),
		.uart_rx(uart_rx),
		.RD_START(RD_START),
		.RD_ADRS(RD_ADRS),
		.RD_LEN(RD_LEN), 
		.RD_SIZE(RD_SIZE),

		.RD_READY(RD_READY),
		.RD_FIFO_WE(RD_FIFO_WE),
		.RD_FIFO_DATA(RD_FIFO_DATA),
		.RD_DONE(RD_DONE),
		.RD_LAST(RD_LAST),

		.target_addr(0),
		`ifndef POWER_ESTIMATION
		.target_w_data(512'b0),
		`endif
		.target_w_en(0)
		/*.WR_START 					 (WR_START),
		.WR_ADRS					 (WR_ADRS),
		.WR_LEN					     (WR_LEN),
		.WR_READY					 (WR_READY),
		.WR_FIFO_RE					 (WR_FIFO_RE),
		.WR_FIFO_DATA				 (WR_FIFO_DATA),
		.WR_DONE					 (WR_DONE),
		.WR_SIZE					 (WR_SIZE),
		.WR_STRB 					 (WR_STRB)*/
	);
	DDR_Read_256bit #(
		.ddr_data_width(256)
	)
	U_DDR_Read_256bit(
        .CLK          ( clk          ),
        .RST_N        ( rst_n          ),
        .RD_START     ( RD_START     ),
        .RD_ADDR      ( RD_ADRS      ),
        .RD_LEN       ( RD_LEN       ),
        .RD_DONE      ( RD_DONE      ),
        .RD_DATA_FIFO ( RD_FIFO_DATA ),
        .RD_FIFO_WE   ( RD_FIFO_WE   )
    );
	
//	initial begin
//		wait(success_0);
//		$dumpfile("E:/CPIPC/test.vcd");
//		$dumpvars();
//	end
//	SCNN_top inst_SCNN_top
//		(
//			.sys_clk_p  (clk),
//			.sys_clk_n  (!clk),
//			.sys_rst    (rst_n),
//			.Key_Signal (Key_Signal)
//		);


	//////////////////////////////////////

	/////**  Logic Part  **/////
	    task uart_tx_byte;
        input [7:0]tx_data;
        begin
            uart_rx = 1;
            #8680;
            uart_rx = 0;
            #8680;
            uart_rx = tx_data[0];
            #8680;
            uart_rx = tx_data[1];
            #8680;
            uart_rx = tx_data[2];
            #8680;
            uart_rx = tx_data[3];
            #8680;
            uart_rx = tx_data[4];
            #8680;
            uart_rx = tx_data[5];
            #8680;
            uart_rx = tx_data[6];
            #8680;
            uart_rx = tx_data[7];
            #8680;
            uart_rx = 1;
            #8680;         
        end
    endtask

	//////////////////////////////////////
	// latency report (disabled for power estimation — SAIF flow only)
`ifndef POWER_ESTIMATION
`ifndef SEG_NET
	`ifdef LATENCY_REPORT
		wire [7:0]        layer_index = inst_accelerator_top.U_LAYER_CTRL.layer_index;
		wire [31:0]       counter_ns  = inst_accelerator_top.U_LAYER_CTRL.counter_ns;
		reg  [7:0]        layer_index_reg;
		integer           latency_fd;
		reg  [1023:0]     latency_file;
	`ifdef ST2_CIFAR100
		integer           figure8_fd;
		reg  [1023:0]     figure8_file;
		reg               figure8_enable;
		wire [63:0]       Weight_cnt      = inst_accelerator_top.U_NEURAL_PROC.U_WEIGHT_TOP.rd_weight_cnt;
		wire [63:0]       Buffer_cnt      = inst_accelerator_top.U_NEURAL_PROC.U_WEIGHT_TOP.buffer_cnt;
		wire [63:0]       Calculation_cnt = inst_accelerator_top.U_NEURAL_PROC.U_WEIGHT_TOP.calculaiton_cnt;
	`endif

		always@(posedge clk)begin
			layer_index_reg <= layer_index;
		end

		wire              record_triger = layer_index_reg != layer_index;

		initial begin
			$sformat(latency_file, "%0s/latency_report_group_%0d.txt", `LATENCY_REPORT_DIR, `GROUP_NUMBER);
			latency_fd = $fopen(latency_file, "w");
			if (latency_fd == 0) begin
				$display("ERROR: cannot open latency report: %0s", latency_file);
				$finish;
			end
			$display("[LATENCY_REPORT] writing to: %0s", latency_file);
			$fdisplay(latency_fd, "layer_index,counter_cycles (1 cycle is 5ns)");

	`ifdef ST2_CIFAR100
			figure8_fd = 0;
			figure8_enable = (`GROUP_NUMBER == 1) || (`GROUP_NUMBER == 2);
			if (figure8_enable) begin
				$sformat(figure8_file, "%0s/figure8_group_%0d.txt", `LATENCY_REPORT_DIR, `GROUP_NUMBER);
				figure8_fd = $fopen(figure8_file, "w");
				if (figure8_fd == 0) begin
					$display("ERROR: cannot open figure8 report: %0s", figure8_file);
					$finish;
				end
				$display("[FIGURE8_REPORT] writing to: %0s", figure8_file);
				$fdisplay(figure8_fd, "layer_index,weight_cnt,buffer_cnt,calculation_cnt");
			end
	`endif
		end

		always@(posedge clk)begin
			if(record_triger)begin
				$fdisplay(latency_fd, "%d,%d", layer_index, counter_ns);
				$fflush(latency_fd);
	`ifdef ST2_CIFAR100
				if (figure8_enable) begin
					$fdisplay(figure8_fd, "%d,%d,%d,%d", layer_index, Weight_cnt, Buffer_cnt, Calculation_cnt);
					$fflush(figure8_fd);
				end
	`endif
			end
		end

		initial begin
			@(posedge success);
			#80;
			if (latency_fd != 0) begin
				$fclose(latency_fd);
				$display("[LATENCY_REPORT] closed: %0s", latency_file);
			end
	`ifdef ST2_CIFAR100
			if (figure8_fd != 0) begin
				$fclose(figure8_fd);
				$display("[FIGURE8_REPORT] closed: %0s", figure8_file);
			end
	`endif
		end
	`endif
`endif
`endif // POWER_ESTIMATION

endmodule