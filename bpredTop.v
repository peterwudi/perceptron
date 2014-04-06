`include "header.v"

module bpredTop(
	input	wire					clk,
	input wire					insnMem_wren,
	input wire	[31:0]		insnMem_data_w,
	input wire	[7:0]			insnMem_addr_w,
	output reg	[31:0]		fetch_bpredictor_PC,

	input							soin_bpredictor_stall,

	output						bpredictor_fetch_p_dir,

	input							execute_bpredictor_update,
	input	[31:0]				execute_bpredictor_PC4,
	input	[31:0]				execute_bpredictor_target,
	input							execute_bpredictor_dir,
	input							execute_bpredictor_miss,
	// Fake thing, implement this later
	input	[95:0]				execute_bpredictor_data,
	
	input	[31:0]				soin_bpredictor_debug_sel,

	input							execute_missPred,
	input							execute_c_r_after_r,	// Call or Return after return
	input							execute_isCall,

	input							reset,
	
	
	output reg [31:0]			bpredictor_soin_debug
);

parameter perceptronSize	= 64;
parameter ghrSize				= 12;

/*
fetch_bpredictor_PC is to be used before clock edge
fetch_bpredictor_inst is to be used after clock edge
*/


reg									branch_is;
reg									target_computable;
reg	[31:0]						computed_target16;
reg	[31:0]						computed_target26;
reg									isIMM16;	// 0 if compute imm16, 1 if imm26

reg	[31:0]						PC4;
reg	[31:0]						PC4_r;
reg	[3:0]							PCH4;

wire	[5:0]							inst_opcode;
wire	[5:0]							inst_opcode_x_h;
wire	[31:0]						OPERAND_IMM16S;
wire	[31:0]						OPERAND_IMM26;

// 8-bit counters per weight, take 3 HOB for computation,
// only use 5 LOB for update.
// 1KB buget -> 12 globle history.
// Use 5 64x20 MLABs. 
//wire	[1:0]						mem_data_w;
//wire	[1:0]						mem_data_r;

reg	[63:0]						lookup_count;
reg	[63:0]						update_count;
reg	[63:0]						miss_count;
reg	[63:0]						hit_count;

// 64 entries for now
wire									up_wen;

localparam hob = 3;
localparam lob = 8 - hob;

wire	[hob*ghrSize-1:0]				lu_hob_data;
wire	[hob*ghrSize-1:0]				lu_hob_data_c;
wire	[hob*ghrSize-1:0]				up_hob_data;
wire	[lob*ghrSize-1:0]				lu_lob_data;
wire	[lob*ghrSize-1:0]				up_lob_data;

wire	[31:0]						fetch_bpredictor_inst;

reg	[8:0]							reset_index;

reg	[ghrSize-1:0]				GHR;

reg									isC_R;	// determines if it is a call or return
reg									isCall;	// determines if it is a call

// RAS
(* ramstyle = "MLAB,no_rw_check" *) 
reg	[31:0]						ras [15:0];

reg	[3:0]							ras_top;
reg									ras_dec;
reg									ras_inc;
reg									ras_exc_inc;
reg									ras_exc_dec;


wire [31:0] execute_bpredictor_PC	= execute_bpredictor_PC4 - 4;

// TODO: This is fake, may need to implement the actual thing
assign	up_hob_data		= execute_bpredictor_data[95:95-hob*ghrSize+1];
assign	up_hob_data_c	= execute_bpredictor_data[85:95-hob*ghrSize+1];	// This is fake
assign	up_lob_data		= execute_bpredictor_data[lob*ghrSize-1:0];


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


//=====================================
// Predecoding
//=====================================
assign inst_opcode		= fetch_bpredictor_inst[5:0];
assign inst_opcode_x_h	= fetch_bpredictor_inst[16:11];
assign OPERAND_IMM16S	= {{16{fetch_bpredictor_inst[21]}}, fetch_bpredictor_inst[21:6]};
assign OPERAND_IMM26		= {PCH4, fetch_bpredictor_inst[31:6], 2'b00};

// Instruction Memory
insnMem insnMem(
	.clock(clk),
	.data(insnMem_data_w),
	.rdaddress(fetch_bpredictor_PC[9:2]),		// using PC[9:2]!
	.wraddress(insnMem_addr_w),
	.wren(insnMem_wren),
	.q(fetch_bpredictor_inst)
);

integer j;

initial begin
	fetch_bpredictor_PC <= 32'h0;
	computed_target16 = 0;
	computed_target26 = 0;
	PC4_r <= 0;
	PCH4 = 0;
	PC4 <= 4;
	
	branch_is <= 0;
	isCall <= 0;
	ras_top <= 0;
	
	GHR <= 'b1;
	
	for (j = 0; j < 16; j = j + 1)
	begin
		ras[j] <= 32'b0;
	end
end


always@( * )
begin
	case (inst_opcode)
		6'h26, 6'h0e, 6'h2e, 6'h16, 6'h36,
		6'h1e, 6'h06, 6'h01: begin
			branch_is			= 1;
		end
		6'h00 : begin
			branch_is			= 1;
		end
		6'h3a:
		begin
			case(inst_opcode_x_h)
				6'h1d: begin
					branch_is	= 1;
				end
				6'h01: begin
					branch_is	= 1;
				end
				6'h0d: begin
					branch_is	= 1;
				end
				6'h05: begin
					branch_is	= 1;
				end
				default: begin branch_is= 0;
				end
			endcase
		end
		default: begin branch_is		= 0;
							isC_R				= 0;
		end
	endcase
	target_computable = branch_is & (inst_opcode < 6'h3a);
	isIMM16	= (inst_opcode <= 6'h01) ? 0 : 1;
	isC_R		= (branch_is && (inst_opcode == 6'h00 || ((inst_opcode == 6'h3a) && (inst_opcode_x_h != 6'h0d)))) ? 1 : 0;
	isCall	= (branch_is && (inst_opcode == 6'h00 || ((inst_opcode == 6'h3a) && (inst_opcode_x_h == 6'h1d)))) ? 1 : 0;
end

/*
always@( * )
begin
	case (inst_opcode)
		6'h00: begin target_computable	= 1;
			isIMM16 = 0;
		end
		6'h01: begin target_computable	= 1;
			isIMM16 = 0;
		end
		6'h3a: begin target_computable	= 0; end
		default: begin target_computable	= 1;
			isIMM16 = 1;
		end
	endcase
end
*/

always@( * )
begin
	computed_target16	= PC4 + OPERAND_IMM16S;
	computed_target26 = OPERAND_IMM26;
end

always @( * )
begin
	if (isC_R) begin
		if (isCall) begin
			// Push PC+4 on RAS
			ras_inc		 <= 1;
			ras_dec		 <= 0;
		end
		else begin
			// Pop RAS
			ras_dec		 <= 1;
			ras_inc		 <= 0;
		end
	end
	else begin
		ras_inc		<= 0;
		ras_dec		<= 0;
	end

	case ({execute_missPred, execute_c_r_after_r, execute_isCall})
		3'b110: begin
			if (isC_R && isCall) begin
				ras_exc_inc <= 0;
				ras_exc_dec <= 1;
			end
			else begin
				ras_exc_inc <= 1;
				ras_exc_dec <= 0;
			end
		end
		3'b111: begin
			if (isC_R && isCall) begin
				ras_exc_inc <= 0;
				ras_exc_dec <= 1;
			end
			else begin
				ras_exc_inc <= 1;
				ras_exc_dec <= 0;
			end
		end
		default: begin
			ras_exc_inc <= 0;
			ras_exc_dec <= 0;
		end
	endcase
end

// Output Mux
always@(*)
begin
	if (~bpredictor_fetch_p_dir) begin
		// Not taken or indirect call, the target is not computable
		fetch_bpredictor_PC = PC4;
	end
	else begin
		if (isC_R & ~isCall) begin
			// return, use the stack
			fetch_bpredictor_PC = ras[ras_top+1];
		end
		else if (target_computable & isIMM16) begin
			fetch_bpredictor_PC = computed_target16;
		end
		else if (target_computable & ~isIMM16) begin
			fetch_bpredictor_PC = computed_target26;
		end
	end
end


//=====================================
// Perceptron
//=====================================

wire					perceptronRes;	
wire signed	[9:0]	perceptronSum;

wire signed	[6:0]	perRes_lvl1 [5:0];
wire signed [6:0]	perRes_lvl2 [2:0];

// For 3-bit
assign	perceptronRes = ~perceptronSum[6];

// For 4-bit
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
wire [hob*ghrSize-1:0]	wallaceInput;

generate
	for (i = 0; i < ghrSize; i = i + 1) begin: wallace
		// Calculate negative here. 228.99 MHz
		//assign wallaceInput[(i+1)*hob-1:i*hob] = (GHR[i] == 1) ? lu_hob_data[(i+1)*hob-1:i*hob] : (~lu_hob_data[(i+1)*hob-1:i*hob] + 1);
		
		// Read pre-computed negative, 263.78 MHz
		assign wallaceInput[(i+1)*hob-1:i*hob] = (GHR[i] == 1) ? lu_hob_data[(i+1)*hob-1:i*hob] : lu_hob_data_c[(i+1)*hob-1:i*hob];
	end
endgenerate

// 254.71 MHz
wallace_3bit_12 wallaceTree(
	.op(wallaceInput),
	.res(perceptronSum[6:0])
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


// Branch direction
assign bpredictor_fetch_p_dir	= branch_is & (target_computable | (isC_R & ~isCall)) ? perceptronRes : 1'b0;

// Update perceptron
// Do this later
//wire execute_bpredictor_update;

// TODO: this is the old thing, which assumes that the update logic is somewhere else.
// It might not be trivial for perceptron, but (1) it has 2 cycles before the branch is resolved,
// and (2) it might not be required to have the update result written back immediately. So I don't
// think it's going to be a big problem.
assign up_wen	= reset | (~soin_bpredictor_stall & execute_bpredictor_update);



always@( * )
begin
	//SPEED
	PC4									= PC4_r + 4;

	case (soin_bpredictor_debug_sel[1:0])
		2'b00: bpredictor_soin_debug	= lookup_count[31:0];
		2'b01: bpredictor_soin_debug	= update_count[31:0];
		2'b10: bpredictor_soin_debug	= miss_count[31:0];
		2'b11: bpredictor_soin_debug	= hit_count[31:0];
		default: bpredictor_soin_debug	= -1;
	endcase
end

always@(posedge clk) begin
	if (reset) begin
		lookup_count		<= 0;
		update_count		<= 0;
		miss_count			<= 0;
		hit_count			<= 0;
		GHR					<= 'b0;
		
		if (reset) begin
			reset_index		<= reset_index + 1;
		end
		else begin
			PCH4				<= fetch_bpredictor_PC[31:28];
			PC4_r				<= fetch_bpredictor_PC;
		
			GHR				<= {execute_bpredictor_dir, GHR[ghrSize-1:1]};
		
			//RAS
			if (isC_R && isCall)
			begin
				ras[ras_top] <= PC4;
			end

			if (ras_exc_inc) begin
				ras_top <= ras_top + 1;
			end
			else if (ras_exc_dec) begin
				ras_top <= ras_top - 1;
			end
			else if (ras_inc) begin
				ras_top <= ras_top + 1;
			end
			else if (ras_dec) begin
				ras_top <= ras_top - 1;
			end
			
			if (!soin_bpredictor_stall) begin
				lookup_count				<= lookup_count + 1;
			end
			
			if (execute_bpredictor_update) begin
				update_count			<= update_count + 1;
				miss_count				<= miss_count + execute_bpredictor_miss;
				hit_count				<= hit_count + (execute_bpredictor_miss ? 0 : 1'b1);
			end
		end
	end
end

endmodule
