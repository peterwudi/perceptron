
module fullAdder(
	input		x, y, cin,
	output	s, cout
);

assign s 	= x ^ y ^ cin;
assign cout	= (x & y) | (x & cin) | (y & cin);

endmodule

module halfAdder(
	input		x, y,
	output	s, cout
);

assign s		= x ^ y;
assign cout	= x & y;

endmodule

module wallace_3bit_12(
	input		[35:0] 	op,
	output	[6:0]		res
);

// Even if 7x12 = 84, so bit 6 is at most one, no need to have an
// adder for bit 6 then.

// Naming: s<stage>_<bit>_<adderNumber>

wire	[3:0]	s1_res 	[2:0];
wire	[3:0]	s1_cout	[2:0];

// Stage 1
fullAdder s1_0_0 (.x(op[0]),	.y(op[3]),	.cin(op[6]),	.s(s1_res[0][0]),	.cout(s1_cout[0][0]));
fullAdder s1_0_1 (.x(op[9]),	.y(op[12]),	.cin(op[15]),	.s(s1_res[0][1]),	.cout(s1_cout[0][1]));
fullAdder s1_0_2 (.x(op[18]),	.y(op[21]),	.cin(op[24]),	.s(s1_res[0][2]),	.cout(s1_cout[0][2]));
fullAdder s1_0_3 (.x(op[27]),	.y(op[30]),	.cin(op[33]),	.s(s1_res[0][3]),	.cout(s1_cout[0][3]));	

fullAdder s1_1_0 (.x(op[1]),	.y(op[4]),	.cin(op[7]),	.s(s1_res[1][0]),	.cout(s1_cout[1][0]));
fullAdder s1_1_1 (.x(op[10]),	.y(op[13]),	.cin(op[16]),	.s(s1_res[1][1]),	.cout(s1_cout[1][1]));
fullAdder s1_1_2 (.x(op[19]),	.y(op[22]),	.cin(op[25]),	.s(s1_res[1][2]),	.cout(s1_cout[1][2]));
fullAdder s1_1_3 (.x(op[28]),	.y(op[31]),	.cin(op[34]),	.s(s1_res[1][3]),	.cout(s1_cout[1][3]));

fullAdder s1_2_0 (.x(op[2]),	.y(op[5]),	.cin(op[8]),	.s(s1_res[2][0]),	.cout(s1_cout[2][0]));
fullAdder s1_2_1 (.x(op[11]),	.y(op[14]),	.cin(op[17]),	.s(s1_res[2][1]),	.cout(s1_cout[2][1]));
fullAdder s1_2_2 (.x(op[20]),	.y(op[23]),	.cin(op[26]),	.s(s1_res[2][2]),	.cout(s1_cout[2][2]));
fullAdder s1_2_3 (.x(op[29]),	.y(op[32]),	.cin(op[35]),	.s(s1_res[2][3]),	.cout(s1_cout[2][3]));

// Stage 2
wire	[2:0]	s2_res 	[3:0];
wire	[2:0]	s2_cout	[3:0];

halfAdder s2_0_0 (.x(s1_res[0][0]),		.y(s1_res[0][1]), 								.s(s2_res[0][0]),	.cout(s2_cout[0][0]));
halfAdder s2_0_1 (.x(s1_res[0][2]),		.y(s1_res[0][3]), 								.s(s2_res[0][1]),	.cout(s2_cout[0][1]));

fullAdder s2_1_0 (.x(s1_res[1][0]),		.y(s1_res[1][1]),		.cin(s1_res[1][2]),	.s(s2_res[1][0]), .cout(s2_cout[1][0]));
fullAdder s2_1_1 (.x(s1_res[1][3]),		.y(s1_cout[0][0]),	.cin(s1_cout[0][1]),	.s(s2_res[1][1]), .cout(s2_cout[1][1]));
halfAdder s2_1_2 (.x(s1_cout[0][2]),	.y(s1_cout[0][3]),								.s(s2_res[1][2]), .cout(s2_cout[1][2]));

fullAdder s2_2_0 (.x(s1_res[2][0]),		.y(s1_res[2][1]),		.cin(s1_res[2][2]),	.s(s2_res[2][0]), .cout(s2_cout[2][0]));
fullAdder s2_2_1 (.x(s1_res[2][3]),		.y(s1_cout[1][0]),	.cin(s1_cout[1][1]),	.s(s2_res[2][1]), .cout(s2_cout[2][1]));
halfAdder s2_2_2 (.x(s1_cout[1][2]),	.y(s1_cout[1][3]),								.s(s2_res[2][2]), .cout(s2_cout[2][2]));

halfAdder s2_3_0 (.x(s1_cout[2][0]),	.y(s1_cout[2][1]), 								.s(s2_res[3][0]),	.cout(s2_cout[3][0]));
halfAdder s2_3_1 (.x(s1_cout[2][2]),	.y(s1_cout[2][3]), 								.s(s2_res[3][1]),	.cout(s2_cout[3][1]));

// Stage 3
wire	[1:0]	s3_res 	[4:0];
wire	[1:0]	s3_cout	[4:0];

halfAdder s3_0_0 (.x(s2_res[0][0]),		.y(s2_res[0][1]), 								.s(s3_res[0][0]),	.cout(s3_cout[0][0]));

fullAdder s3_1_0 (.x(s2_res[1][0]),		.y(s2_res[1][1]),		.cin(s2_res[1][2]),	.s(s3_res[1][0]), .cout(s3_cout[1][0]));
halfAdder s3_1_1 (.x(s2_cout[0][0]),	.y(s2_cout[0][1]),								.s(s3_res[1][1]), .cout(s3_cout[1][1]));

fullAdder s3_2_0 (.x(s2_res[2][0]),		.y(s2_res[2][1]),		.cin(s2_res[2][2]),	.s(s3_res[2][0]), .cout(s3_cout[2][0]));
fullAdder s3_2_1 (.x(s2_cout[1][0]),	.y(s2_cout[1][1]),	.cin(s2_cout[1][2]),	.s(s3_res[2][1]), .cout(s3_cout[2][1]));

fullAdder s3_3_0 (.x(s2_res[3][0]),		.y(s2_res[3][1]),		.cin(s2_cout[2][0]),	.s(s3_res[3][0]), .cout(s3_cout[3][0]));
halfAdder s3_3_1 (.x(s2_cout[2][1]),	.y(s2_cout[2][2]),								.s(s3_res[3][1]), .cout(s3_cout[3][1]));

halfAdder s3_4_0 (.x(s2_cout[3][0]),	.y(s2_cout[3][1]), 								.s(s3_res[4][0]),	.cout(s3_cout[4][0]));


// Stage 4
wire	[1:0]	s4_res 	[5:0];
wire	[1:0]	s4_cout	[5:0];

// Bit 0 done

fullAdder s4_1_0 (.x(s3_res[1][0]),		.y(s3_res[1][1]),		.cin(s3_cout[0][0]),	.s(s4_res[1][0]), .cout(s4_cout[1][0]));

halfAdder s4_2_0 (.x(s3_res[2][0]),		.y(s3_res[2][1]), 								.s(s4_res[2][0]),	.cout(s4_cout[2][0]));
halfAdder s4_2_1 (.x(s3_cout[1][0]),	.y(s3_cout[1][1]), 								.s(s4_res[2][1]),	.cout(s4_cout[2][1]));

halfAdder s4_3_0 (.x(s3_res[3][0]),		.y(s3_res[3][1]), 								.s(s4_res[3][0]),	.cout(s4_cout[3][0]));
halfAdder s4_3_1 (.x(s3_cout[2][0]),	.y(s3_cout[2][1]), 								.s(s4_res[3][1]),	.cout(s4_cout[3][1]));

fullAdder s4_4_0 (.x(s3_res[4][0]),		.y(s3_cout[3][0]),	.cin(s3_cout[3][1]),	.s(s4_res[4][0]), .cout(s4_cout[4][0]));

assign s4_res[5][0] = s3_cout[4][0];

// Stage 5
wire	[1:0]	s5_res 	[5:0];
wire	[1:0]	s5_cout	[5:0];

// Bits 0-1 done

fullAdder s5_2_0 (.x(s4_res[2][0]),		.y(s4_res[2][1]),		.cin(s4_cout[1][0]),	.s(s5_res[2][0]), .cout(s5_cout[2][0]));

halfAdder s5_3_0 (.x(s4_res[3][0]),		.y(s4_res[3][1]), 								.s(s5_res[3][0]),	.cout(s5_cout[3][0]));
halfAdder s5_3_1 (.x(s4_cout[2][0]),	.y(s4_cout[2][1]), 								.s(s5_res[3][1]),	.cout(s5_cout[3][1]));

fullAdder s5_4_0 (.x(s4_res[4][0]),		.y(s4_cout[3][0]),	.cin(s4_cout[3][1]),	.s(s5_res[4][0]), .cout(s5_cout[4][0]));

halfAdder s5_5_0 (.x(s4_res[5][0]),		.y(s4_cout[4][0]), 								.s(s5_res[5][0]),	.cout(s5_cout[5][0]));

// Stage 6
wire	[5:0]	s6_res;
wire	[5:0] s6_cout;

// Bits 0-2 done

fullAdder s6_3_0 (.x(s5_res[3][0]),		.y(s5_res[3][1]),		.cin(s5_cout[2][0]),	.s(s6_res[3]), .cout(s6_cout[3]));

fullAdder s6_4_0 (.x(s5_res[4][0]),		.y(s5_cout[3][0]),	.cin(s5_cout[3][1]),	.s(s6_res[4]), .cout(s6_cout[4]));

halfAdder s6_5_0 (.x(s5_res[5][0]),		.y(s5_cout[4][0]), 								.s(s6_res[5]),	.cout(s6_cout[5]));

// Stage 7 with a 2-bit adder in the end
//wire	[6:0] s7_res;
//assign s7_res[6:4] = {s6_res[5], s6_res[4]} + {s6_cout[4], s6_cout[3]};

//assign res = {s5_cout[5][0]|s6_cout[5]|s7_res[6], s7_res[5:4], s6_res[3], s5_res[2][0], s4_res[1][0], s3_res[0][0]};

//assign res =  s5_cout[5][0] | s6_cout[5] | (s6_res[5]&s6_cout[4]) | (s6_res[5]&s6_res[4]&s6_cout[3]) | (s6_res[4]&s6_cout[4]&s6_cout[3]);

// Carry look-ahead
assign res =  {s5_cout[5][0] | s6_cout[5] | ((s6_res[5]|s6_cout[4]) &s6_res[4]&s6_cout[3]) | (&s6_cout[4]&s6_cout[5]), 6'b0};

endmodule



module wallace_4bit_12(
	input		[47:0] 	op,
	output	[7:0]		res
);

// Even if 15x12 = 180, so bit 7 is at most one, no need to have an
// adder for bit 7 then.

// Naming: s<stage>_<bit>_<adderNumber>

wire	[3:0]	s1_res 	[3:0];
wire	[3:0]	s1_cout	[3:0];

// Stage 1
fullAdder s1_0_0 (.x(op[0]),	.y(op[4]),	.cin(op[8]),	.s(s1_res[0][0]),	.cout(s1_cout[0][0]));
fullAdder s1_0_1 (.x(op[12]),	.y(op[16]),	.cin(op[20]),	.s(s1_res[0][1]),	.cout(s1_cout[0][1]));
fullAdder s1_0_2 (.x(op[24]),	.y(op[28]),	.cin(op[32]),	.s(s1_res[0][2]),	.cout(s1_cout[0][2]));
fullAdder s1_0_3 (.x(op[36]),	.y(op[40]),	.cin(op[44]),	.s(s1_res[0][3]),	.cout(s1_cout[0][3]));	

fullAdder s1_1_0 (.x(op[1]),	.y(op[5]),	.cin(op[9]),	.s(s1_res[1][0]),	.cout(s1_cout[1][0]));
fullAdder s1_1_1 (.x(op[13]),	.y(op[17]),	.cin(op[21]),	.s(s1_res[1][1]),	.cout(s1_cout[1][1]));
fullAdder s1_1_2 (.x(op[25]),	.y(op[29]),	.cin(op[33]),	.s(s1_res[1][2]),	.cout(s1_cout[1][2]));
fullAdder s1_1_3 (.x(op[37]),	.y(op[41]),	.cin(op[45]),	.s(s1_res[1][3]),	.cout(s1_cout[1][3]));

fullAdder s1_2_0 (.x(op[2]),	.y(op[6]),	.cin(op[10]),	.s(s1_res[2][0]),	.cout(s1_cout[2][0]));
fullAdder s1_2_1 (.x(op[14]),	.y(op[18]),	.cin(op[22]),	.s(s1_res[2][1]),	.cout(s1_cout[2][1]));
fullAdder s1_2_2 (.x(op[26]),	.y(op[30]),	.cin(op[34]),	.s(s1_res[2][2]),	.cout(s1_cout[2][2]));
fullAdder s1_2_3 (.x(op[38]),	.y(op[42]),	.cin(op[46]),	.s(s1_res[2][3]),	.cout(s1_cout[2][3]));

fullAdder s1_3_0 (.x(op[3]),	.y(op[7]),	.cin(op[11]),	.s(s1_res[3][0]),	.cout(s1_cout[3][0]));
fullAdder s1_3_1 (.x(op[15]),	.y(op[19]),	.cin(op[23]),	.s(s1_res[3][1]),	.cout(s1_cout[3][1]));
fullAdder s1_3_2 (.x(op[27]),	.y(op[31]),	.cin(op[35]),	.s(s1_res[3][2]),	.cout(s1_cout[3][2]));
fullAdder s1_3_3 (.x(op[39]),	.y(op[43]),	.cin(op[47]),	.s(s1_res[3][3]),	.cout(s1_cout[3][3]));


// Stage 2
wire	[2:0]	s2_res 	[4:0];
wire	[2:0]	s2_cout	[4:0];

halfAdder s2_0_0 (.x(s1_res[0][0]),		.y(s1_res[0][1]), 								.s(s2_res[0][0]),	.cout(s2_cout[0][0]));
halfAdder s2_0_1 (.x(s1_res[0][2]),		.y(s1_res[0][3]), 								.s(s2_res[0][1]),	.cout(s2_cout[0][1]));

fullAdder s2_1_0 (.x(s1_res[1][0]),		.y(s1_res[1][1]),		.cin(s1_res[1][2]),	.s(s2_res[1][0]), .cout(s2_cout[1][0]));
fullAdder s2_1_1 (.x(s1_res[1][3]),		.y(s1_cout[0][0]),	.cin(s1_cout[0][1]),	.s(s2_res[1][1]), .cout(s2_cout[1][1]));
halfAdder s2_1_2 (.x(s1_cout[0][2]),	.y(s1_cout[0][3]),								.s(s2_res[1][2]), .cout(s2_cout[1][2]));

fullAdder s2_2_0 (.x(s1_res[2][0]),		.y(s1_res[2][1]),		.cin(s1_res[2][2]),	.s(s2_res[2][0]), .cout(s2_cout[2][0]));
fullAdder s2_2_1 (.x(s1_res[2][3]),		.y(s1_cout[1][0]),	.cin(s1_cout[1][1]),	.s(s2_res[2][1]), .cout(s2_cout[2][1]));
halfAdder s2_2_2 (.x(s1_cout[1][2]),	.y(s1_cout[1][3]),								.s(s2_res[2][2]), .cout(s2_cout[2][2]));

fullAdder s2_3_0 (.x(s1_res[3][0]),		.y(s1_res[3][1]),		.cin(s1_res[3][2]),	.s(s2_res[3][0]), .cout(s2_cout[3][0]));
fullAdder s2_3_1 (.x(s1_res[3][3]),		.y(s1_cout[2][0]),	.cin(s1_cout[2][1]),	.s(s2_res[3][1]), .cout(s2_cout[3][1]));
halfAdder s2_3_2 (.x(s1_cout[2][2]),	.y(s1_cout[2][3]),								.s(s2_res[3][2]), .cout(s2_cout[3][2]));

halfAdder s2_4_0 (.x(s1_cout[3][0]),	.y(s1_cout[3][1]), 								.s(s2_res[4][0]),	.cout(s2_cout[4][0]));
halfAdder s2_4_1 (.x(s1_cout[3][2]),	.y(s1_cout[3][3]), 								.s(s2_res[4][1]),	.cout(s2_cout[4][1]));


// Stage 3
wire	[1:0]	s3_res 	[5:0];
wire	[1:0]	s3_cout	[5:0];

halfAdder s3_0_0 (.x(s2_res[0][0]),		.y(s2_res[0][1]), 								.s(s3_res[0][0]),	.cout(s3_cout[0][0]));

fullAdder s3_1_0 (.x(s2_res[1][0]),		.y(s2_res[1][1]),		.cin(s2_res[1][2]),	.s(s3_res[1][0]), .cout(s3_cout[1][0]));
halfAdder s3_1_1 (.x(s2_cout[0][0]),	.y(s2_cout[0][1]),								.s(s3_res[1][1]), .cout(s3_cout[1][1]));

fullAdder s3_2_0 (.x(s2_res[2][0]),		.y(s2_res[2][1]),		.cin(s2_res[2][2]),	.s(s3_res[2][0]), .cout(s3_cout[2][0]));
fullAdder s3_2_1 (.x(s2_cout[1][0]),	.y(s2_cout[1][1]),	.cin(s2_cout[1][2]),	.s(s3_res[2][1]), .cout(s3_cout[2][1]));

fullAdder s3_3_0 (.x(s2_res[3][0]),		.y(s2_res[3][1]),		.cin(s2_res[3][2]),	.s(s3_res[3][0]), .cout(s3_cout[3][0]));
fullAdder s3_3_1 (.x(s2_cout[2][0]),	.y(s2_cout[2][1]),	.cin(s2_cout[2][2]),	.s(s3_res[3][1]), .cout(s3_cout[3][1]));

fullAdder s3_4_0 (.x(s2_res[4][0]),		.y(s2_res[4][1]),		.cin(s2_cout[3][0]),	.s(s3_res[4][0]), .cout(s3_cout[4][0]));
halfAdder s3_4_1 (.x(s2_cout[3][1]),	.y(s2_cout[3][2]),								.s(s3_res[4][1]), .cout(s3_cout[4][1]));

halfAdder s3_5_0 (.x(s2_cout[4][0]),	.y(s2_cout[4][1]), 								.s(s3_res[5][0]),	.cout(s3_cout[5][0]));


// Stage 4
wire	[1:0]	s4_res 	[6:0];
wire	[1:0]	s4_cout	[6:0];

// Bit 0 done

fullAdder s4_1_0 (.x(s3_res[1][0]),		.y(s3_res[1][1]),		.cin(s3_cout[0][0]),	.s(s4_res[1][0]), .cout(s4_cout[1][0]));

halfAdder s4_2_0 (.x(s3_res[2][0]),		.y(s3_res[2][1]), 								.s(s4_res[2][0]),	.cout(s4_cout[2][0]));
halfAdder s4_2_1 (.x(s3_cout[1][0]),	.y(s3_cout[1][1]), 								.s(s4_res[2][1]),	.cout(s4_cout[2][1]));

halfAdder s4_3_0 (.x(s3_res[3][0]),		.y(s3_res[3][1]), 								.s(s4_res[3][0]),	.cout(s4_cout[3][0]));
halfAdder s4_3_1 (.x(s3_cout[2][0]),	.y(s3_cout[2][1]), 								.s(s4_res[3][1]),	.cout(s4_cout[3][1]));

halfAdder s4_4_0 (.x(s3_res[4][0]),		.y(s3_res[4][1]), 								.s(s4_res[4][0]),	.cout(s4_cout[4][0]));
halfAdder s4_4_1 (.x(s3_cout[3][0]),	.y(s3_cout[3][1]), 								.s(s4_res[4][1]),	.cout(s4_cout[4][1]));

fullAdder s4_5_0 (.x(s3_res[5][0]),		.y(s3_cout[4][0]),	.cin(s3_cout[4][1]),	.s(s4_res[5][0]), .cout(s4_cout[5][0]));

assign s4_res[6][0] = s3_cout[5][0];

// Stage 5
wire	[1:0]	s5_res 	[6:0];
wire	[1:0]	s5_cout	[6:0];

// Bits 0-1 done

fullAdder s5_2_0 (.x(s4_res[2][0]),		.y(s4_res[2][1]),		.cin(s4_cout[1][0]),	.s(s5_res[2][0]), .cout(s5_cout[2][0]));

halfAdder s5_3_0 (.x(s4_res[3][0]),		.y(s4_res[3][1]), 								.s(s5_res[3][0]),	.cout(s5_cout[3][0]));
halfAdder s5_3_1 (.x(s4_cout[2][0]),	.y(s4_cout[2][1]), 								.s(s5_res[3][1]),	.cout(s5_cout[3][1]));

halfAdder s5_4_0 (.x(s4_res[4][0]),		.y(s4_res[4][1]), 								.s(s5_res[4][0]),	.cout(s5_cout[4][0]));
halfAdder s5_4_1 (.x(s4_cout[3][0]),	.y(s4_cout[3][1]), 								.s(s5_res[4][1]),	.cout(s5_cout[4][1]));

fullAdder s5_5_0 (.x(s4_res[5][0]),		.y(s4_cout[4][0]),	.cin(s4_cout[4][1]),	.s(s5_res[5][0]), .cout(s5_cout[5][0]));

halfAdder s5_6_0 (.x(s4_res[6][0]),		.y(s4_cout[5][0]), 								.s(s5_res[6][0]),	.cout(s5_cout[6][0]));

// Stage 6
wire	[1:0]	s6_res	[6:0];
wire	[1:0] s6_cout	[6:0];

// Bits 0-2 done

fullAdder s6_3_0 (.x(s5_res[3][0]),		.y(s5_res[3][1]),		.cin(s5_cout[2][0]),	.s(s6_res[3][0]), .cout(s6_cout[3][0]));

halfAdder s6_4_0 (.x(s5_res[4][0]),		.y(s5_res[4][1]), 								.s(s6_res[4][0]),	.cout(s6_cout[4][0]));
halfAdder s6_4_1 (.x(s5_cout[3][0]),	.y(s5_cout[3][1]), 								.s(s6_res[4][1]),	.cout(s6_cout[4][1]));

fullAdder s6_5_0 (.x(s5_res[5][0]),		.y(s5_cout[4][0]),	.cin(s5_cout[4][1]),	.s(s6_res[5][0]), .cout(s6_cout[5][0]));

halfAdder s6_6_0 (.x(s5_res[6][0]),		.y(s5_cout[5][0]), 								.s(s6_res[6][0]),	.cout(s6_cout[6][0]));

// Stage 7
wire	[6:0] s7_res;
wire	[6:0] s7_cout;

// Bits 0-3 done
fullAdder s7_4_0 (.x(s6_res[4][0]),		.y(s6_res[4][1]),		.cin(s6_cout[3][0]),	.s(s7_res[4]), .cout(s7_cout[4]));

fullAdder s7_5_0 (.x(s6_res[5][0]),		.y(s6_cout[4][0]),	.cin(s6_cout[4][1]),	.s(s7_res[5]), .cout(s7_cout[5]));

halfAdder s7_6_0 (.x(s6_res[6]),			.y(s6_cout[5]),									.s(s7_res[6]),	.cout(s7_cout[6]));

// Stage 8
// Carry look-ahead
assign res = {s5_cout[6][0] | s6_cout[6][0] | s7_cout[6] | ((s7_res[6]|s7_cout[5]) &s7_res[5]&s7_cout[4]) | (&s7_cout[5]&s7_cout[6]), 7'b0};

endmodule


