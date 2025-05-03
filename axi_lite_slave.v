/*
    awprot, arprot - not supported
    wr_data - can be saved on posedge front of aclk when have wr_enable signal
    rdata - mast be prepared for read sequence
*/
module axi_lite_slave (
            // Outputs
        rresp, rvalid,   // Read data channel
        rlast, rid,
        arready,                // Read address channel
        awready,                // Write address channel
        wready,                 // Write data channel
        bid, bresp, bvalid,     // Write response channel

        rd_addr,
        wr_addr,
        rd_addr_match,
        wr_addr_match,
        wr_data,
        wr_enable,
            // Inputes
        aclk, aresetn,                  // Global
        araddr, arvalid,                // Read address channel
        arid,
        rready,                         // Read data channel
        awaddr, awid, awvalid,          // Write address channel
        wdata, wstrb, wvalid,           // Write data channel
        bready,                         // Write response channel
        );

    parameter SIDW  = 12; // ID Width
    parameter SAW   = 32; // Address Bus Width
    parameter SDW   = 32; // Data Bus Width

    //########
    // Inputs
    //########

    // Global signals
    input               aclk;
    input               aresetn;

    //#######################
    //# Read address channel
    //#######################
    input [SAW-1:0]     araddr;
    input               arvalid;
    input [SIDW-1:0]    arid;

    //####################
    //# Read data channel
    //####################
    input               rready;
    
    //########################
    //# Write address channel
    //########################
    input [SAW-1:0]     awaddr;
    input [SIDW-1:0]    awid;
    input               awvalid;

    //#####################
    //# Write data channel
    //#####################
    input [SDW-1:0]     wdata;
    input [3:0]         wstrb;
    input               wvalid;

    //#########################
    //# Write response channel
    //#########################
    input               bready;


    //##########
    //# Outputs
    //##########

    //#######################
    //# Read address channel
    //#######################
    output              arready;

    //####################
    //# Read data channel
    //####################
    output [1:0]        rresp;
    output              rvalid;
    output              rlast;
    output [SIDW-1:0]   rid;

    //########################
    //# Write address channel
    //########################
    output              awready;

    //#####################
    //# Write data channel
    //#####################
    output              wready;

    //#########################
    //# Write response channel
    //#########################
    output [SIDW-1:0]   bid; //response ID tag
    output [1:0]        bresp;
    output              bvalid;

    //######################
    //# Write enable signal
    //######################
    output [SAW-1:0]    rd_addr;
    output [SAW-1:0]    wr_addr;
    output              rd_addr_match;
    output              wr_addr_match;
    output [SDW-1:0]    wr_data;
    output              wr_enable;


    //#######
    //# Regs
    //#######
    reg [SAW-1:0]       rd_addr;
    reg [SAW-1:0]       wr_addr;
    reg [SDW-1:0]       wr_data;
    reg                 wr_enable;

    reg [SIDW-1:0]      r_rid;
    reg [SIDW-1:0]      r_bid;
    reg                 r_arready;
    reg                 r_awready;
    reg                 r_wready;
    reg                 r_rvalid;
    reg                 r_bvalid;


    //------ Set ready signals for r/w address and write operation -------------
    always @ (posedge aclk)
    begin
        if (arvalid)
            r_arready <= 1'b1;
        else
            r_arready <= 1'b0;

        if (awvalid)
            r_awready <= 1'b1;
        else
            r_awready <= 1'b0;

        if (wvalid)
            r_wready <= 1'b1;
        else
            r_wready <= 1'b0;
    end

    assign arready = r_arready & arvalid;
    assign awready = r_awready & awvalid;
    assign wready = r_wready & wvalid;


    //------ Set read operation signals ----------------------------------------
    always @ (posedge aclk)
    begin
        if (aresetn == 0)
            r_rvalid <= 1'b0;
        else if (arvalid & arready)
            r_rvalid <= 1'b1;
        else if (rready)
            r_rvalid <= 1'b0;
        else;
    end

    assign rresp[1:0] = rd_addr_match ? 2'b00 : 2'b11; // Ok or Decode error
    assign rid[SIDW-1:0] = r_rid[SIDW-1:0];
    assign rvalid = r_rvalid;
    assign rlast = 1'b1; // All bursts are defined to be of length 1

    //------ Set write response signals ----------------------------------------
    always @ (posedge aclk)
    begin
        if (aresetn == 0)
            r_bvalid <= 1'b0;
        else if (wvalid & wready)
            r_bvalid <= 1'b1;
        else if (bready)
            r_bvalid <= 1'b0;
        else;
    end

    assign bresp[1:0] = wr_addr_match ? 2'b00 : 2'b11; // Ok or Decode error
    assign bid[SIDW-1:0] = r_bid[SIDW-1:0];
    assign bvalid = r_bvalid;

    //------ Get data (addresses and data to be written) -----------------------
    always @ (negedge aclk)
    begin
        if (awvalid & awready)
        begin
            wr_addr[SAW-1:0] <= awaddr[SAW-1:0];
            r_bid[SIDW-1:0] <= awid[SIDW-1:0];
        end

        if (arvalid & arready)
        begin
            rd_addr[SAW-1:0] <= araddr[SAW-1:0];
            r_rid[SIDW-1:0] <= arid[SIDW-1:0];
        end

        if (wvalid & wready)
        begin : write_sequens
            integer b_index;
            for (b_index = 0; b_index <= (SAW/8) - 1; b_index = b_index+1)
                if (wstrb[b_index] == 1)
                    wr_data[(b_index*8) +: 8] <= wdata[(b_index*8) +: 8];
            wr_enable <= 1'b1;
        end // write_sequens
        else
            wr_enable <= 1'b0; // Only one posedge pulse of aclk for save data
    end

    //------ Match of the requested and assigned address -----------------------
    assign  rd_addr_match =
                (rd_addr[31:8] == {`CONFIG_REGS_ID, `MM_UPR, 4'b0000, `MM_CFG});

    assign  wr_addr_match =
                (wr_addr[31:8] == {`CONFIG_REGS_ID, `MM_UPR, 4'b0000, `MM_CFG});
    

endmodule // axi_lite_slave
