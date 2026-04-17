/*
 * Copyright (c) 2026 Bastiaan van der Plaat
 *
 * SPDX-License-Identifier: MIT
 */

// RV32I multi-cycle CPU
// No CSR/trap support; ECALL/EBREAK/FENCE treated as NOPs.
// Misaligned accesses are not trapped.
module cpu(
    input wire clk,
    input wire rst,

    // Memory bus: drive addr/data/control in one cycle,
    // response (mem_rdata) available next cycle
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    input wire [31:0] mem_rdata,
    output reg mem_we,
    output reg mem_re,
    output reg [3:0] mem_wstrb
);

    // CPU states (6 states, most instructions 5 cycles, loads/stores 6)
    localparam STATE_FETCH     = 3'd0, // Drive bus with PC
               STATE_DECODE    = 3'd1, // Capture instruction from bus
               STATE_REGREAD   = 3'd2, // Read register file
               STATE_EXECUTE   = 3'd3, // ALU / branch / address calc
               STATE_MEMORY    = 3'd4, // Load/store bus response
               STATE_WRITEBACK = 3'd5; // Write register file, update PC

    // Opcodes
    localparam OP_LUI    = 7'b0110111,
               OP_AUIPC  = 7'b0010111,
               OP_JAL    = 7'b1101111,
               OP_JALR   = 7'b1100111,
               OP_BRANCH = 7'b1100011,
               OP_LOAD   = 7'b0000011,
               OP_STORE  = 7'b0100011,
               OP_IMM    = 7'b0010011,
               OP_REG    = 7'b0110011,
               OP_FENCE  = 7'b0001111,
               OP_SYSTEM = 7'b1110011;

    // ALU operations
    localparam ALU_ADD  = 4'd0,
               ALU_SUB  = 4'd1,
               ALU_SLL  = 4'd2,
               ALU_SLT  = 4'd3,
               ALU_SLTU = 4'd4,
               ALU_XOR  = 4'd5,
               ALU_SRL  = 4'd6,
               ALU_SRA  = 4'd7,
               ALU_OR   = 4'd8,
               ALU_AND  = 4'd9;

    // Registers
    reg [31:0] pc;
    reg [31:0] regs [0:31];
    reg [2:0] state;

    // Instruction register and decoded fields
    reg [31:0] instr;
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    // Immediates (combinational from instr)
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    wire [31:0] imm_u = {instr[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // Registered operands from REGREAD stage
    reg [31:0] rs1_val, rs2_val;

    // ALU - fully combinational, driven by rs1_val/rs2_val and instruction
    reg [31:0] alu_a, alu_b;
    reg [3:0] alu_op;
    reg [31:0] alu_result;

    // ALU input/op selection (combinational from instruction + register values)
    always @(*) begin
        alu_a = rs1_val;
        alu_b = 32'b0;
        alu_op = ALU_ADD;

        case (opcode)
            OP_IMM: begin
                alu_b = imm_i;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    3'b001: alu_op = ALU_SLL;
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    default: alu_op = ALU_ADD;
                endcase
            end
            OP_REG: begin
                alu_b = rs2_val;
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: alu_op = ALU_ADD;
                endcase
            end
            OP_LOAD: begin
                alu_b = imm_i;
            end
            OP_STORE: begin
                alu_b = imm_s;
            end
            default: ;
        endcase
    end

    // ALU computation (combinational)
    always @(*) begin
        case (alu_op)
            ALU_ADD:  alu_result = alu_a + alu_b;
            ALU_SUB:  alu_result = alu_a - alu_b;
            ALU_SLL:  alu_result = alu_a << alu_b[4:0];
            ALU_SLT:  alu_result = {31'b0, $signed(alu_a) < $signed(alu_b)};
            ALU_SLTU: alu_result = {31'b0, alu_a < alu_b};
            ALU_XOR:  alu_result = alu_a ^ alu_b;
            ALU_SRL:  alu_result = alu_a >> alu_b[4:0];
            ALU_SRA:  alu_result = $signed(alu_a) >>> alu_b[4:0];
            ALU_OR:   alu_result = alu_a | alu_b;
            ALU_AND:  alu_result = alu_a & alu_b;
            default:  alu_result = 32'b0;
        endcase
    end

    // Branch comparison (combinational from rs1_val/rs2_val)
    reg branch_taken;
    always @(*) begin
        case (funct3)
            3'b000:  branch_taken = (rs1_val == rs2_val);                   // BEQ
            3'b001:  branch_taken = (rs1_val != rs2_val);                   // BNE
            3'b100:  branch_taken = ($signed(rs1_val) < $signed(rs2_val));  // BLT
            3'b101:  branch_taken = ($signed(rs1_val) >= $signed(rs2_val)); // BGE
            3'b110:  branch_taken = (rs1_val < rs2_val);                    // BLTU
            3'b111:  branch_taken = (rs1_val >= rs2_val);                   // BGEU
            default: branch_taken = 0;
        endcase
    end

    // Execution state
    reg [31:0] exec_result;
    reg [31:0] next_pc;
    reg write_rd;
    reg [31:0] eff_addr; // saved effective address for load byte selection

    // Load data selection from word-aligned read (combinational)
    reg [31:0] load_result;
    always @(*) begin
        case (funct3)
            3'b000: begin // LB
                case (eff_addr[1:0])
                    2'b00: load_result = {{24{mem_rdata[7]}},  mem_rdata[7:0]};
                    2'b01: load_result = {{24{mem_rdata[15]}}, mem_rdata[15:8]};
                    2'b10: load_result = {{24{mem_rdata[23]}}, mem_rdata[23:16]};
                    2'b11: load_result = {{24{mem_rdata[31]}}, mem_rdata[31:24]};
                endcase
            end
            3'b001: begin // LH
                if (eff_addr[1])
                    load_result = {{16{mem_rdata[31]}}, mem_rdata[31:16]};
                else
                    load_result = {{16{mem_rdata[15]}}, mem_rdata[15:0]};
            end
            3'b010: load_result = mem_rdata; // LW
            3'b100: begin // LBU
                case (eff_addr[1:0])
                    2'b00: load_result = {24'b0, mem_rdata[7:0]};
                    2'b01: load_result = {24'b0, mem_rdata[15:8]};
                    2'b10: load_result = {24'b0, mem_rdata[23:16]};
                    2'b11: load_result = {24'b0, mem_rdata[31:24]};
                endcase
            end
            3'b101: begin // LHU
                if (eff_addr[1])
                    load_result = {16'b0, mem_rdata[31:16]};
                else
                    load_result = {16'b0, mem_rdata[15:0]};
            end
            default: load_result = mem_rdata;
        endcase
    end

    // Main state machine
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            pc <= 32'h00000000;
            state <= STATE_FETCH;
            mem_we <= 0;
            mem_re <= 0;
            mem_wstrb <= 4'b0000;
            mem_addr <= 32'b0;
            mem_wdata <= 32'b0;
            instr <= 32'b0;
            rs1_val <= 32'b0;
            rs2_val <= 32'b0;
            write_rd <= 0;
            next_pc <= 32'b0;
            exec_result <= 32'b0;
            eff_addr <= 32'b0;
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else begin
            case (state)
                // Drive address bus with PC, request instruction read
                STATE_FETCH: begin
                    mem_addr <= pc;
                    mem_re <= 1;
                    mem_we <= 0;
                    mem_wstrb <= 4'b0000;
                    state <= STATE_DECODE;
                end

                // Capture instruction (bus responds 1 cycle after request)
                STATE_DECODE: begin
                    instr <= mem_rdata;
                    mem_re <= 0;
                    state <= STATE_REGREAD;
                end

                // Read register file (instr is now stable, so rs1/rs2 fields valid)
                STATE_REGREAD: begin
                    rs1_val <= (rs1 == 5'd0) ? 32'b0 : regs[rs1];
                    rs2_val <= (rs2 == 5'd0) ? 32'b0 : regs[rs2];
                    state <= STATE_EXECUTE;
                end

                // Execute: rs1_val/rs2_val are now stable, ALU result is
                // available combinationally via alu_result
                STATE_EXECUTE: begin
                    write_rd <= 0;
                    next_pc <= pc + 4;

                    case (opcode)
                        OP_LUI: begin
                            exec_result <= imm_u;
                            write_rd <= 1;
                            state <= STATE_WRITEBACK;
                        end

                        OP_AUIPC: begin
                            exec_result <= pc + imm_u;
                            write_rd <= 1;
                            state <= STATE_WRITEBACK;
                        end

                        OP_JAL: begin
                            exec_result <= pc + 4;
                            next_pc <= pc + imm_j;
                            write_rd <= 1;
                            state <= STATE_WRITEBACK;
                        end

                        OP_JALR: begin
                            exec_result <= pc + 4;
                            next_pc <= (rs1_val + imm_i) & ~32'h1;
                            write_rd <= 1;
                            state <= STATE_WRITEBACK;
                        end

                        OP_BRANCH: begin
                            if (branch_taken)
                                next_pc <= pc + imm_b;
                            state <= STATE_WRITEBACK;
                        end

                        OP_LOAD: begin
                            // alu_result = rs1_val + imm_i (address)
                            mem_addr <= alu_result;
                            eff_addr <= alu_result;
                            mem_re <= 1;
                            state <= STATE_MEMORY;
                        end

                        OP_STORE: begin
                            // alu_result = rs1_val + imm_s (address)
                            mem_addr <= alu_result;
                            mem_we <= 1;
                            case (funct3)
                                3'b000: begin // SB
                                    mem_wdata <= {4{rs2_val[7:0]}};
                                    mem_wstrb <= 4'b0001 << alu_result[1:0];
                                end
                                3'b001: begin // SH
                                    mem_wdata <= {2{rs2_val[15:0]}};
                                    mem_wstrb <= alu_result[1] ? 4'b1100 : 4'b0011;
                                end
                                3'b010: begin // SW
                                    mem_wdata <= rs2_val;
                                    mem_wstrb <= 4'b1111;
                                end
                                default: begin
                                    mem_wdata <= rs2_val;
                                    mem_wstrb <= 4'b1111;
                                end
                            endcase
                            state <= STATE_MEMORY;
                        end

                        OP_IMM, OP_REG: begin
                            // alu_result is valid combinationally
                            exec_result <= alu_result;
                            write_rd <= 1;
                            state <= STATE_WRITEBACK;
                        end

                        OP_FENCE, OP_SYSTEM: begin
                            state <= STATE_WRITEBACK;
                        end

                        default: begin
                            state <= STATE_WRITEBACK;
                        end
                    endcase
                end

                // Memory response: data available 1 cycle after request
                STATE_MEMORY: begin
                    mem_re <= 0;
                    mem_we <= 0;
                    mem_wstrb <= 4'b0000;

                    if (opcode == OP_LOAD) begin
                        exec_result <= load_result;
                        write_rd <= 1;
                    end

                    state <= STATE_WRITEBACK;
                end

                // Write result to register file, update PC
                STATE_WRITEBACK: begin
                    if (write_rd && rd != 5'd0)
                        regs[rd] <= exec_result;
                    pc <= next_pc;
                    state <= STATE_FETCH;
                end
            endcase
        end
    end
endmodule
