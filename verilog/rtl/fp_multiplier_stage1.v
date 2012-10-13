// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

`include "instruction_format.h"

//
// First stage of floating point multiplier pipeline
// - Compute result exponent
// - Detect zero result
//

module fp_multiplier_stage1
	#(parameter EXPONENT_WIDTH = 8, 
	parameter SIGNIFICAND_WIDTH = 23,
	parameter TOTAL_WIDTH = 1 + EXPONENT_WIDTH + SIGNIFICAND_WIDTH,
	parameter SIGNIFICAND_PRODUCT_WIDTH = (SIGNIFICAND_WIDTH + 1) * 2)

	(input										clk,
	input [5:0]									operation_i,
	input [TOTAL_WIDTH - 1:0]					operand1_i,
	input [TOTAL_WIDTH - 1:0]					operand2_i,
	output reg[31:0]							mul1_muliplicand = 0,
	output reg[31:0]							mul1_multiplier = 0,
	output reg[EXPONENT_WIDTH - 1:0] 			mul1_exponent = 0,
	output reg									mul1_sign = 0);

	reg 										sign1 = 0;
	reg[EXPONENT_WIDTH - 1:0] 					exponent1 = 0;
	reg 										sign2 = 0;
	reg[EXPONENT_WIDTH - 1:0] 					exponent2 = 0;

	reg[EXPONENT_WIDTH - 1:0] 					result_exponent = 0;

	// Check for zero explicitly, since a leading 1 is otherwise 
	// assumed for the significand
	wire is_zero_nxt = operation_i == `OP_ITOF
		?	operand2_i == 0
		:	operand1_i == 0 || operand2_i == 0;

	// Multiplicand
	always @*
	begin
		if (operation_i == `OP_ITOF)
		begin
			// Dummy multiply by 1.0
			sign1 = 0;
			exponent1 = 127;
			mul1_muliplicand = { 1'b1, 23'd0 };
		end
		else
		begin
			sign1 = operand1_i[31];
			exponent1 = operand1_i[30:23];
			mul1_muliplicand = { 1'b1, operand1_i[22:0] };
		end
	end
	
	always @*
	begin
		if (operation_i == `OP_ITOF)
		begin
			// Convert to unnormalized float for multiplication
			sign2 = operand2_i[31];
			exponent2 = 127 + 23;
			if (sign2)
				mul1_multiplier = (operand2_i ^ {32{1'b1}}) + 1;
			else
				mul1_multiplier = operand2_i;
		end
		else if (is_zero_nxt)
		begin
			// If we know the result will be zero, just set the second operand
			// to ensure the result will be zero.
			sign2 = 0;
			exponent2 = 0;
			mul1_multiplier = 0;
		end
		else
		begin
			sign2 = operand2_i[31];
			exponent2 = operand2_i[30:23];
			mul1_multiplier = { 1'b1, operand2_i[22:0] };
		end
	end

	wire result_sign = sign1 ^ sign2;
	
	// Unbias the exponents so we can add them in two's complement.
	wire[EXPONENT_WIDTH - 1:0] unbiased_exponent1 = { ~exponent1[EXPONENT_WIDTH - 1], 
			exponent1[EXPONENT_WIDTH - 2:0] };
	wire[EXPONENT_WIDTH - 1:0] unbiased_exponent2 = { ~exponent2[EXPONENT_WIDTH - 1], 
			exponent2[EXPONENT_WIDTH - 2:0] };

	// The result exponent is simply the sum of the two exponents
	wire[EXPONENT_WIDTH - 1:0] unbiased_result_exponent = unbiased_exponent1 + unbiased_exponent2;

	// Re-bias the result exponent.  Note that we subtract the significand width
	// here because of the multiplication.
	always @*
	begin
		if (is_zero_nxt)
			result_exponent = 0;
		else
			result_exponent = { ~unbiased_result_exponent[EXPONENT_WIDTH - 1], 
				unbiased_result_exponent[EXPONENT_WIDTH - 2:0] } + 1;
	end
	
	always @(posedge clk)
	begin
		mul1_exponent				<= #1 result_exponent;
		mul1_sign 					<= #1 result_sign;
	end
endmodule
