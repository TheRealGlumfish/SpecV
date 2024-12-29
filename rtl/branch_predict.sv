// 32-bit Local branch predictor and branch target buffer
// NOTE: Only works with 32-bit aligned PC
module branch_predict#(
    parameter local_entries = 128,
    parameter btb_entries = 128 
)(
    input  clk_i,
    input  rst_i,
    // Fetch interface
    input  [31:0] pc_i,
    output branch_take_o,
    output [31:0] branch_target_o,
    output hit_o
    // Branch unit interface
);
    
    localparam local_width = $clog2(local_entries);
    localparam btb_set_width = $clog2(btb_entries);
    localparam btb_tag_width = 32 - btb_set_width - 2;

    // Local predictor
    logic local_taken [local_entries-1:0] = '{default: '0};
    assign branch_take_o = local_taken[pc_i[local_width-1:2]];
    
    // Branch target predictor
    typedef struct packed {
        logic [btb_tag_width-1:0] tag;
        logic [31-2:0]            target_msb;
        logic                     valid;
    } btb_entry;

    logic [btb_set_width-1:0] pc_set;
    logic [btb_tag_width-1:0] pc_tag; 
    logic                     pc_hit;
    btb_entry                 btb_arr [btb_entries-1:0];

    assign pc_set = pc_i[btb_set_width-1:2];
    assign pc_tag = pc_i[31:btb_tag_width+2];
    assign pc_hit = btb_arr[pc_set].tag == pc_tag;
    assign branch_target_o = {btb_arr[pc_set].target_msb, 2'b0};

    assign hit_o = btb_arr[pc_set].valid && pc_hit;

endmodule
