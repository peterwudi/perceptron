`include "header.v"
`include "soin_header.v"

module insnCache(
	input						clk,
	input		[31:0]		insnMem_data_w,
	input		[31:0]		fetch_bpredictor_PC,
	input		[7:0]			insnMem_addr_w,
	input 					insnMem_wren,
	output	[31:0]		fetch_bpredictor_inst
);

insnMem insnMem(
	.clock(clk),
	.data(insnMem_data_w),
	.rdaddress(fetch_bpredictor_PC[9:2]),		// using PC[9:2]!
	.wraddress(insnMem_addr_w),
	.wren(insnMem_wren),
	.q(fetch_bpredictor_inst)
);

endmodule


module soin_bpredictor_decode(
	input	[31:0]						inst,
	output	reg							is_branch,
	output	reg							is_cond,
	output	reg							is_ind,
	output	reg							is_call,
	output	reg							is_ret,
	output	reg							is_16,
	output	reg							is_26,
	
	output	reg	[1:0]					is_p_mux,
	output	reg							is_p_uncond,
	output	reg							is_p_ret,
	output	reg							is_p_call
	
);

wire	[5:0]							inst_opcode;
wire	[5:0]							inst_opcode_x_h;

assign inst_opcode						= inst[`BITS_F_OP];
assign inst_opcode_x_h					= inst[`BITS_F_OPXH];

always@( * )
begin
	case (inst_opcode)
		6'h26: begin is_branch			= 1; end
		6'h0e: begin is_branch			= 1; end
		6'h2e: begin is_branch			= 1; end
		6'h16: begin is_branch			= 1; end
		6'h36: begin is_branch			= 1; end
		6'h1e: begin is_branch			= 1; end
		6'h06: begin is_branch			= 1; end
		6'h00: begin is_branch			= 1; end
		6'h01: begin is_branch			= 1; end
		6'h3a:
		begin
			case(inst_opcode_x_h)
				6'h1d: begin is_branch	= 1; end
				6'h01: begin is_branch	= 1; end
				6'h0d: begin is_branch	= 1; end
				6'h05: begin is_branch	= 1; end
				default: begin is_branch= 0; end
			endcase
		end
		default: begin is_branch		= 0; end
	endcase
end

always@( * )
begin
	case (inst_opcode)
		6'h0e: begin is_cond			= 1; end
		6'h16: begin is_cond			= 1; end
		6'h1e: begin is_cond			= 1; end
		6'h26: begin is_cond			= 1; end
		6'h2e: begin is_cond			= 1; end
		6'h36: begin is_cond			= 1; end

		default: begin is_cond			= 0; end
	endcase
end

always@( * )
	is_ind								= inst_opcode == 6'h3A;

always@( * )
	is_call								= (inst_opcode == 6'h00) | ((inst_opcode == 6'h3A) & (inst_opcode_x_h == 6'h1D));

always@( * )
	is_ret								= (inst_opcode == 6'h3A) & (inst_opcode_x_h == 6'h05);

always@( * )
	is_26								= (inst_opcode == 6'h00) | (inst_opcode == 6'h01);

always@( * )
	is_16								= (inst_opcode != 6'h3A) & (~is_26);

always@( * )
	is_p_mux							= inst[31:30];

always@( * )
	is_p_uncond							= inst[29];

always@( * )
	is_p_ret							= is_ret;

always@( * )
	is_p_call							= inst[27];
endmodule


module ras(
	input								clk,
	input								reset,

	input	[31:0]					f_PC4,
	input								f_call,
	input								f_ret,

	input								e_recover,
	input	[3:0]						e_recover_index,
	
	output	reg [3:0]			ras_index,
	output	[31:0]				top_addr
);

MLAB_32_4 ras(
	.clock							(clk),
	.address							(ras_index),
	.q									(top_addr),
	.data								(e_recover_index),
	.wren								(f_call)
);

always@(posedge clk)
begin
	if (reset) begin
		ras_index						<= 'b0;
	end
	else if (e_recover) begin
		ras_index						<= e_recover_index;
	end
	else if (f_call) begin
		ras_index						<= ras_index + 4'h1;
	end
	else if (f_ret) begin
		ras_index						<= ras_index - 4'h1;
	end
	else begin
		ras_index						<= 'b0;
	end
end

endmodule



module bpredTop(
	input	wire					clk,
	input wire					insnMem_wren,
	input wire	[31:0]		insnMem_data_w,
	input wire	[7:0]			insnMem_addr_w,
	output reg	[31:0]		fetch_bpredictor_PC,
	
	input							fetch_redirect,
	input	[31:0]				fetch_redirect_PC,

	input							soin_bpredictor_stall,

	output						bpredictor_fetch_p_dir,

	input							execute_bpredictor_update,
	input	[31:0]				execute_bpredictor_PC4,
	input	[31:0]				execute_bpredictor_target,
	input							execute_bpredictor_dir,
	input							execute_bpredictor_miss,
	input							execute_bpredictor_recover_ras,
	input	[3:0]					execute_bpredictor_meta,
	
	input							reset
);

parameter perceptronSize	= 64;
parameter ghrSize				= 8;

/*
fetch_bpredictor_PC is to be used before clock edge
fetch_bpredictor_inst is to be used after clock edge
*/

// RAS
wire	[3:0]							ras_index;
wire	[3:0]							ras_top_addr;

wire									is_branch;
wire									is_cond;
wire									is_ind;
wire									is_call;
wire									is_ret;
wire									is_16;
wire									is_26;

// Predecoding
wire	[1:0]							is_p_mux;
wire									is_p_uncond;
wire									is_p_ret;
wire									is_p_call;

wire	[31:0]						OPERAND_IMM16S;
wire	[31:0]						OPERAND_IMM26;
wire	[31:0]						TARGET_IMM16S;
wire	[31:0]						TARGET_IMM26;

reg	[31:0]						PC4;
reg	[31:0]						PC4_r;
reg	[3:0]							PCH4;

// 8-bit counters per weight, take 3 HOB for computation,
// only use 5 LOB for update.
// 1KB buget -> 12 globle history.
// Use 5 64x20 MLABs. 

// 64 entries for now
wire									up_wen;

localparam hob = 3;
localparam lob = 8 - hob;

wire	[hob*ghrSize-1:0]			lu_hob_data;
reg	[hob*ghrSize-1:0]			lu_hob_data_r;
wire	[hob*ghrSize-1:0]			lu_hob_data_c;
reg	[hob*ghrSize-1:0]			up_hob_data;
reg	[hob*ghrSize-1:0]			up_hob_data_c;

wire	[lob*ghrSize-1:0]			lu_lob_data;
reg	[lob*ghrSize-1:0]			lu_lob_data_r;
reg	[lob*ghrSize-1:0]			up_lob_data;


wire	[31:0]						fetch_bpredictor_inst;

reg	[ghrSize-1:0]				GHR;

ras ras_inst(
	.clk								(clk),
	.reset							(reset),

	.f_PC4							(PC4),
	.f_call							(is_call),
	.f_ret							(is_ret),

	.e_recover						(execute_bpredictor_recover_ras),
	.e_recover_index				(execute_bpredictor_meta),

	.ras_index						(ras_index),
	.top_addr						(ras_top_addr)
);


wire	[31:0] 	execute_bpredictor_PC	= execute_bpredictor_PC4 - 4;

reg	[ghrSize*8-1:0]	execute_bpredictor_data		[1:0];
reg	[ghrSize*8-1:0]	execute_bpredictor_data_c	[1:0];

// HOB table
hobRam hobTable(
	.clock(clk),
	.data(up_hob_data),
	.rdaddress(fetch_bpredictor_PC[7:2]),
	.wraddress(execute_bpredictor_PC[7:2]),
	.wren(up_wen),
	.q(lu_hob_data)
);

// HOB table for compliment
hobRam hobTable_c(
	.clock(clk),
	.data(up_hob_data_c),
	.rdaddress(fetch_bpredictor_PC[7:2]),
	.wraddress(execute_bpredictor_PC[7:2]),
	.wren(up_wen),
	.q(lu_hob_data_c)
);


// LOB table
lobRam lobTable(
	.clock(clk),
	.data(up_lob_data),
	.rdaddress(fetch_bpredictor_PC[7:2]),
	.wraddress(execute_bpredictor_PC[7:2]),
	.wren(up_wen),
	.q(lu_lob_data)
);


// ICache, this is a wrapper so the logic here is not included in area
insnCache iCache(
	.clk(clk),
	.insnMem_data_w(insnMem_data_w),
	.fetch_bpredictor_PC(fetch_bpredictor_PC),		// using PC[9:2]!
	.insnMem_addr_w(insnMem_addr_w),
	.insnMem_wren(insnMem_wren),
	.fetch_bpredictor_inst(fetch_bpredictor_inst)
);

integer j;
initial begin
	fetch_bpredictor_PC <= 32'h0;
	PC4_r <= 0;
	PCH4 = 0;
	PC4 <= 4;
end


//=====================================
// Decoding
//=====================================
soin_bpredictor_decode d_inst(
	.inst								(fetch_bpredictor_inst),

	.is_branch						(is_branch),
	.is_cond							(is_cond),
	.is_ind							(is_ind),
	.is_call							(is_call),
	.is_ret							(is_ret),
	.is_16							(is_16),
	.is_26							(is_26),

	.is_p_mux						(is_p_mux),
	.is_p_uncond					(is_p_uncond),
	.is_p_ret						(is_p_ret),
	.is_p_call						(is_p_call)
);


//=====================================
// Target
//=====================================
assign OPERAND_IMM16S			= {{16{fetch_bpredictor_inst[`BITS_F_IMM16_SIGN]}}, fetch_bpredictor_inst[`BITS_F_IMM16]};
assign OPERAND_IMM26				= {PCH4, fetch_bpredictor_inst[`BITS_F_IMM26], 2'b00};
assign TARGET_IMM16S				= {PC4[31:2] + OPERAND_IMM16S[31:2], 2'b00};
assign TARGET_IMM26				= OPERAND_IMM26;

`define PreDecode

// Output Mux
always@(*)
begin

`ifdef PreDecode

	casex ({fetch_redirect, is_p_mux & {2{is_p_uncond | bpredictor_fetch_p_dir}}})
		3'b1xx:
		begin
			fetch_bpredictor_PC	= fetch_redirect_PC;
		end
		3'b000:
		begin
			fetch_bpredictor_PC	= PC4;
		end
		3'b001:
		begin
			fetch_bpredictor_PC	= ras_top_addr;
		end
		3'b010:
		begin
			fetch_bpredictor_PC	= TARGET_IMM16S;
		end
		3'b011:
		begin
			fetch_bpredictor_PC	= TARGET_IMM26;
		end
		default:
		begin
			fetch_bpredictor_PC	= PC4;
		end
	endcase

`else

	if (fetch_redirect) begin
		fetch_bpredictor_PC = fetch_redirect_PC;
	end
	else if (~bpredictor_fetch_p_dir) begin
		// Not taken or indirect call, the target is not computable
		fetch_bpredictor_PC = PC4;
	end
	else begin
		if (is_ret) begin
			// return, use the stack
			fetch_bpredictor_PC = ras_top_addr;
		end
		else if (is_cond & is_16) begin
			fetch_bpredictor_PC = TARGET_IMM16S;
		end
		else if (is_cond & is_26) begin
			fetch_bpredictor_PC = TARGET_IMM26;
		end
		else begin
			fetch_bpredictor_PC = PC4;
		end
	end
	
`endif
	
end


//=====================================
// Perceptron
//=====================================

wire					perceptronRes;	
wire signed	[5:0]	perceptronSum;

wire signed	[6:0]	perRes_lvl1 [5:0];
wire signed [6:0]	perRes_lvl2 [2:0];

// For 3-bit 8 GHR bits
assign	perceptronRes = ~perceptronSum[5];

// For 3-bit 12 GHR bits
//assign	perceptronRes = ~perceptronSum[6];

// For 4-bit 12 GHR bits
//assign	perceptronRes = ~perceptronSum[7];

// Calculate perceptron
genvar i;

//// Naive solution, 223.41 MHz
//assign perceptronSum =	((GHR[0] == 1) ? lu_hob_data[2:0] : lu_hob_data_c[2:0]) +
//								((GHR[1] == 1) ? lu_hob_data[5:3] : lu_hob_data_c[5:3]) +
//								((GHR[2] == 1) ? lu_hob_data[8:6] : lu_hob_data_c[8:6]) +
//								((GHR[3] == 1) ? lu_hob_data[11:9] : lu_hob_data_c[11:9]) +
//								((GHR[4] == 1) ? lu_hob_data[14:12] : lu_hob_data_c[14:12]) +
//								((GHR[5] == 1) ? lu_hob_data[17:15] : lu_hob_data_c[17:15]) +
//								((GHR[6] == 1) ? lu_hob_data[20:18] : lu_hob_data_c[20:18]) +
//								((GHR[7] == 1) ? lu_hob_data[23:21] : lu_hob_data_c[23:21]) +
//								((GHR[8] == 1) ? lu_hob_data[26:24] : lu_hob_data_c[26:24]) +
//								((GHR[9] == 1) ? lu_hob_data[29:27] : lu_hob_data_c[29:27]) +
//								((GHR[10] == 1) ? lu_hob_data[32:30] : lu_hob_data_c[32:30]) +
//								((GHR[11] == 1) ? lu_hob_data[35:33] : lu_hob_data_c[35:33]);
								

//// 2-to-1 adder reduction tree approach, 
//generate
//	// Calculate negative here. 235.79 MHz (TODO: add 0-extended bits)
////	for (i = 0; i < ghrSize; i = i + 2) begin: per_lvl1
////		per_addsub per_addsub_lvl1(
////			.dataa((GHR[i] == 1) ? lu_hob_data[(i+1)*hob-1:i*hob] : (~lu_hob_data[(i+1)*hob-1:i*hob] + 1)),
////			.datab((GHR[i+1] == 1) ? lu_hob_data[(i+2)*hob-1:(i+1)*hob] : (~lu_hob_data[(i+2)*hob-1:(i+1)*hob]+1)),
////			.result(perRes_lvl1[i/2])
////		);
////	end
//	
//	// Read pre-computed negative, 238.61 MHz
//	for (i = 0; i < ghrSize; i = i + 2) begin: per_lvl1
//		per_addsub per_addsub_lvl1(
//			.dataa((GHR[i] == 1) ? {4'b0,lu_hob_data[(i+1)*hob-1:i*hob]} : {4'b0,lu_hob_data_c[(i+1)*hob-1:i*hob]}),
//			.datab((GHR[i+1] == 1) ? {4'b0,lu_hob_data[(i+2)*hob-1:(i+1)*hob]} : {4'b0,lu_hob_data_c[(i+2)*hob-1:(i+1)*hob]}),
//			.result(perRes_lvl1[i/2])
//		);
//	end
//	
//	for (i = 0; i < 6; i = i + 2) begin: per_lvl2
//		per_addsub per_addsub_lvl2(
//			.dataa(perRes_lvl1[i]),
//			.datab(perRes_lvl1[i+1]),
//			.result(perRes_lvl2[i/2])
//		);
//	end
//	assign	perceptronSum = perRes_lvl2[0] + perRes_lvl2[1] + perRes_lvl2[2];
//endgenerate

// Wallace tree-like structure

// Direct implementation of perceptron calculation
//wire [hob*ghrSize-1:0]	wallaceInput;
//
//generate
//	for (i = 0; i < ghrSize; i = i + 1) begin: wallace
//		// Calculate negative here. 228.99 MHz
//		//assign wallaceInput[(i+1)*hob-1:i*hob] = (GHR[i] == 1) ? lu_hob_data[(i+1)*hob-1:i*hob] : (~lu_hob_data[(i+1)*hob-1:i*hob] + 1);
//		
//		// Read pre-computed negative, 263.78 MHz
//		assign wallaceInput[(i+1)*hob-1:i*hob] = (GHR[i] == 1) ? lu_hob_data[(i+1)*hob-1:i*hob] : lu_hob_data_c[(i+1)*hob-1:i*hob];
//	end
//endgenerate

// A new organization, store -w1+w2 and -w1-w2 instead
reg [hob*ghrSize/2-1:0]	wallaceInput;

generate
	// w0 = -a+b, w1 = -a-b, ~w0 = a-b, ~w1 = a+B
	// g0		g1		output
	// ------------------
	// 0		0		w1
	// 0		1		w0
	// 1		0		~w0
	// 1		1		~w1
	for (i = 0; i < ghrSize; i = i + 2) begin: wallace
		always@(*) begin
			case ({GHR[i], GHR[i+1]})
				2'b00: begin
					wallaceInput[(i/2+1)*hob-1:(i/2)*hob] = lu_hob_data[(i+2)*hob-1:(i+1)*hob];
				end
				2'b01: begin
					wallaceInput[(i/2+1)*hob-1:(i/2)*hob] = lu_hob_data[(i+1)*hob-1:i*hob];
				end
				2'b10: begin
					wallaceInput[(i/2+1)*hob-1:(i/2)*hob] = lu_hob_data_c[(i+1)*hob-1:i*hob];
				end
				2'b11: begin
					wallaceInput[(i/2+1)*hob-1:(i/2)*hob] = lu_hob_data_c[(i+2)*hob-1:(i+1)*hob];
				end
				default: begin
					wallaceInput[(i/2+1)*hob-1:(i/2)*hob] = 8'b0;
				end
			endcase
		end
	end
endgenerate


// 254.71 MHz
//wallace_3bit_12 wallaceTree(
//	.op(wallaceInput),
//	.res(perceptronSum[6:0])
//);

wallace_3bit_8 wallaceTree(
	.op(wallaceInput),
	.res(perceptronSum[5:0])
);

// 233.64 MHz
//wallace_4bit_12 wallaceTree(
//	.op(wallaceInput),
//	.res(perceptronSum[7:0])
//);

//// DSP block approach, 127.91 MHz, not good...
//multAdd multAdd0(
//	.dataa_0(lu_hob_data[2:0]),
//	.dataa_1(lu_hob_data[5:3]),
//	.dataa_2(lu_hob_data[8:6]),
//	.dataa_3(lu_hob_data[11:9]),
//	.datab_0((GHR[0] == 1)? 2'b01: 2'b11),
//	.datab_1((GHR[1] == 1)? 2'b01: 2'b11),
//	.datab_2((GHR[2] == 1)? 2'b01: 2'b11),
//	.datab_3((GHR[3] == 1)? 2'b01: 2'b11),
//	.result(perRes_lvl2[0])
//);
//	
//multAdd multAdd1(
//	.dataa_0(lu_hob_data[14:12]),
//	.dataa_1(lu_hob_data[17:15]),
//	.dataa_2(lu_hob_data[20:18]),
//	.dataa_3(lu_hob_data[23:21]),
//	.datab_0((GHR[4] == 1)? 2'b01: 2'b11),
//	.datab_1((GHR[5] == 1)? 2'b01: 2'b11),
//	.datab_2((GHR[6] == 1)? 2'b01: 2'b11),
//	.datab_3((GHR[7] == 1)? 2'b01: 2'b11),
//	.result(perRes_lvl2[1])
//);
//
//multAdd multAdd2(
//	.dataa_0(lu_hob_data[26:24]),
//	.dataa_1(lu_hob_data[29:27]),
//	.dataa_2(lu_hob_data[32:30]),
//	.dataa_3(lu_hob_data[35:33]),
//	.datab_0((GHR[8] == 1)? 2'b01: 2'b11),
//	.datab_1((GHR[9] == 1)? 2'b01: 2'b11),
//	.datab_2((GHR[10] == 1)? 2'b01: 2'b11),
//	.datab_3((GHR[11] == 1)? 2'b01: 2'b11),
//	.result(perRes_lvl2[2])
//);
//	
//assign	perceptronSum = perRes_lvl2[0] + perRes_lvl2[1] + perRes_lvl2[2];

`ifdef PreDecode
// Predecoding branch direction
assign bpredictor_fetch_p_dir = is_p_uncond | perceptronRes;

`else

// Regurlar branch direction
assign bpredictor_fetch_p_dir	= is_branch & (is_cond | is_ret | is_call) & perceptronRes;

`endif


// Update perceptron
// The update logic should not affect fmax because (1) it has 2 cycles before the branch is resolved,
// and (2) it might not be required to have the update result written back immediately.
generate
	for (i = 0; i < ghrSize; i = i + 1) begin: per_update
		always @(posedge clk) begin
			execute_bpredictor_data[0][(i+1)*8-1:i*8]
				<= {lu_hob_data_r[(i+1)*hob-1:i*hob], lu_lob_data_r[(i+1)*lob-1:i*lob]} - 1;
			execute_bpredictor_data[1][(i+1)*8-1:i*8]
				<= {lu_hob_data_r[(i+1)*hob-1:i*hob], lu_lob_data_r[(i+1)*lob-1:i*lob]} + 1;
			
			execute_bpredictor_data_c[0][(i+1)*8-1:i*8]
				<= 1 - {lu_hob_data_r[(i+1)*hob-1:i*hob], lu_lob_data_r[(i+1)*lob-1:i*lob]};
			execute_bpredictor_data_c[1][(i+1)*8-1:i*8]
				<= -'sd1 - {lu_hob_data_r[(i+1)*hob-1:i*hob], lu_lob_data_r[(i+1)*lob-1:i*lob]};
		end
	end
	
	always @(posedge clk) begin
		lu_hob_data_r	<= lu_hob_data;
		lu_lob_data_r	<= lu_lob_data;
	
		if (execute_bpredictor_miss == 1) begin
			up_hob_data		<= execute_bpredictor_data[0][ghrSize*8-1:ghrSize*8-1-hob*ghrSize+1];
			up_hob_data_c	<= execute_bpredictor_data_c[0][ghrSize*8-1:ghrSize*8-1-hob*ghrSize+1];
			up_lob_data		<= execute_bpredictor_data[0][lob*ghrSize-1:0];
		end
		else begin
			up_hob_data		<= execute_bpredictor_data[1][ghrSize*8-1:ghrSize*8-1-hob*ghrSize+1];
			up_hob_data_c	<= execute_bpredictor_data_c[1][ghrSize*8-1:ghrSize*8-1-hob*ghrSize+1];
			up_lob_data		<= execute_bpredictor_data[1][lob*ghrSize-1:0];
		end
	end
endgenerate

assign up_wen	= reset | (~soin_bpredictor_stall & execute_bpredictor_update);

always@( * )
begin
	PC4					= PC4_r + 4;
end

always@(posedge clk)
begin
	if (reset)
	begin
		GHR							<= 0;
	end
	else
	begin
		PCH4				<= fetch_bpredictor_PC[31:28];
		PC4_r				<= fetch_bpredictor_PC;
		
		if (execute_bpredictor_update) begin
			GHR			<= {GHR[ghrSize-1:0], execute_bpredictor_dir};
		end
	end
end


endmodule
