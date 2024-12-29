// RV32I Fetch Unit
// 2 cycle pipeline
module fetch (
    input         clk_i,
    input         rst_i,
    output [31:0] mem_addr_o, 
    input  [31:0] mem_data_i,
    input         decode_ready_i,
    output [31:0] instr_o,
    output [31:0] instr_pc_o,
    output        instr_valid_o
    // TODO: Add misprediction interface
    );

// NOTE: Add stall mechanism or start with rst high for memory to initialize

logic [31:0] pc_req = 32'b0; // PC to be fetched from memory
logic [31:0] pc_fetch = 32'b0; // PC of currently fetched instruction
logic [31:0] pc_fetch_q = 32'b0; // PC of currently fetched instruction
logic [31:0] instr_fetch; // Currently fetched instruction
logic [31:0] mem_data_q; // Holds instruction in the case of a stall later down the pipeline
logic [6:0]  opcode_fetch;
logic        flush = 1'b0; // Flush fetched instruction

typedef enum { FETCHING, STALLED_CLEAN, STALLED_DIRTY, DIRTY } fetch_state_t;

fetch_state_t state = FETCHING;

assign instr_fetch = (state == STALLED_CLEAN || state == STALLED_DIRTY) ? mem_data_q : mem_data_i;
assign opcode_fetch = instr_fetch[6:0];


assign mem_addr_o = pc_req;
assign instr_o = instr_fetch;
assign instr_pc_o = pc_fetch;
assign instr_valid_o = state == FETCHING && !flush; // TODO: Really, actually check if this is true

logic        branch_take;
logic [31:0] branch_target;
logic        branch_hit; 
logic        branch_hit_q;

// TODO: Add assert about pc_req and pc_fetch not being the same


always_ff@(posedge clk_i) begin
    if(rst_i) begin
        pc_req <= 1'b0;
        pc_fetch <= 1'b0;
        state <= FETCHING; // Maybe start in stalled state? Add reset for the other registers
    end
    else begin
        unique case(state)
            FETCHING: begin
                mem_data_q <= mem_data_i;
                pc_fetch_q <= pc_fetch;
                if(decode_ready_i) begin
                    branch_hit_q <= branch_hit;
                    pc_fetch <= pc_req;
                    if(flush) begin
                        state <= DIRTY;
                        pc_req <= pc_fetch_q + 4; // Recover the PC from the delayed version
                    end
                    else begin
                        if(branch_hit)
                            pc_req <= branch_target;
                        else
                            pc_req <= pc_req + 4;
                    end
                end
                else begin
                    if(flush)
                        state <= STALLED_DIRTY;
                    else
                        state <= STALLED_CLEAN;
                end
            end
            DIRTY: begin
                mem_data_q <= mem_data_i;
                pc_fetch_q <= pc_fetch;
                branch_hit_q <= branch_hit;
                pc_fetch <= pc_req;
                if(decode_ready_i) begin
                    if(flush) begin // Verify this behaviour
                        state <= DIRTY;
                        pc_req <= pc_fetch_q + 4; // Recover the PC from the delayed version
                    end
                    else begin
                        state <= FETCHING;
                        if(branch_hit)
                            pc_req <= branch_target;
                        else
                            pc_req <= pc_req + 4;
                    end
                end
                else begin
                    state <= STALLED_CLEAN;
                    if(branch_hit)
                        pc_req <= branch_target;
                    else
                        pc_req <= pc_req + 4;
                end
            end
            STALLED_CLEAN: begin
                if(decode_ready_i) begin
                    state <= FETCHING;
                    mem_data_q <= mem_data_i;
                    pc_fetch_q <= pc_fetch;
                    branch_hit_q <= branch_hit;
                    pc_fetch <= pc_req;
                    if(flush) begin
                        state <= DIRTY;
                        pc_req <= pc_fetch_q + 4; // Recover the PC from the delayed version
                    end
                    else begin
                        if(branch_hit)
                            pc_req <= branch_target;
                        else
                            pc_req <= pc_req + 4;
                    end
                end
            end
            STALLED_DIRTY: begin // On this state valid should be low until
                mem_data_q <= mem_data_i;
                pc_fetch_q <= pc_fetch;
                branch_hit_q <= branch_hit;
                pc_fetch <= pc_req;
                if(decode_ready_i)
                    state <= FETCHING;
                else
                    state <= STALLED_CLEAN;
            end
        endcase
    end
end

always_comb begin
    unique case(opcode_fetch)
        7'b1100011: begin // B-type
            flush = 1'b0;
        end
        7'b1101111: begin // J-type (jal)
            $error("jal not implemented");
        end
        7'b1100111: begin // J-type (jalr)
            $error("jal not implemented");
        end
        default: begin // R-type, I-type, S-type, U-type
            if(branch_hit_q) // If branch was taken and instruction isn't actually a branch, squash the instruction
                flush = 1'b1;
            else
                flush = 1'b0;
        end
    endcase 
end

branch_predict main_predictor(
    .clk_i(clk_i),
    .rst_i(rst_i),
    .pc_i(pc_req),
    .branch_take_o(branch_take),
    .branch_target_o(branch_target),
    .hit_o(branch_hit)
);

endmodule
