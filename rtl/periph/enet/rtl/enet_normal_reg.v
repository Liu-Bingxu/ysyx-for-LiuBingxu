module enet_normal_reg(
    input               clk,
    input               rst_n,

    input               eir_wen,
    input               eimr_wen,
    input               rdar_wen,
    input               tdar_wen,
    input               ecr_wen,
    input               tcr_wen,
    input               rcr_wen,
    input               palr_wen,
    input               paur_wen,
    input               opd_wen,
    input               ialr_wen,
    input               iaur_wen,
    input               galr_wen,
    input               gaur_wen,
    input               rdsr_wen,
    input               tdsr_wen,
    input               rsfl_wen,
    input               rsem_wen,
    input               rafl_wen,
    input               raem_wen,
    input               tfwr_wen,
    input               tsem_wen,
    input               tafl_wen,
    input               taem_wen,
    input               tipg_wen,
    input               ftrl_wen,
    output              write_success,

    input               rdar_ren,
    input               tdar_ren,
    input               tcr_ren,
    input               rcr_ren,
    output              read_done,

    input  [11:0]       reg_addr,
    input  [31:0]       reg_wdata,

    input               Tx_out_full,
    output              Tx_out_wen,
    output [44:0]       Tx_out_data_in,

    input               Tx_in_empty,
    output              Tx_in_ren,
    input  [43:0]       Tx_in_data_out,

    input               Rx_out_full,
    output              Rx_out_wen,
    output [44:0]       Rx_out_data_in,

    input               Rx_in_empty,
    output              Rx_in_ren,
    input  [43:0]       Rx_in_data_out,

    output              babr,
    output              babt,
    output              gra,
    // output              rxf,
    // output              txf,
    output              rxf_in,
    output              txf_in,
    output              eberr,
    output              lc,
    output              rl,
    output              un,
    output              plr,
    output [31:0]       eimr,
    output [31:0]       tcr,
    output [31:0]       tdar,
    output [31:0]       rcr,
    output [31:0]       rdar,
    output [31:0]       palr,
    output [31:0]       paur,
    output [31:0]       opd,
    output [31:0]       ialr,
    output [31:0]       iaur,
    output [31:0]       galr,
    output [31:0]       gaur,
    output [31:0]       rdsr,
    output [31:0]       tdsr,
    output [31:0]       rsfl,
    output [31:0]       rsem,
    output [31:0]       rafl,
    output [31:0]       raem,
    output [31:0]       tfwr,
    output [31:0]       tsem,
    output [31:0]       tafl,
    output [31:0]       taem,
    output [31:0]       tipg,
    output [31:0]       ftrl
);

wire tdar_wen_s = tdar_wen & (!Tx_out_full);
wire rdar_wen_s = rdar_wen & (!Rx_out_full);
wire ecr_wen_s  = ecr_wen  & (!Tx_out_full) & (!Rx_out_full);
wire tcr_wen_s  = tcr_wen  & (!Tx_out_full);
wire rcr_wen_s  = rcr_wen  & (!Rx_out_full);
wire palr_wen_u = palr_wen & (!Tx_out_full) & (!Rx_out_full);
wire paur_wen_u = paur_wen & (!Tx_out_full) & (!Rx_out_full);
wire opd_wen_u  = opd_wen  & (!Tx_out_full);
wire ialr_wen_u = ialr_wen & (!Rx_out_full);
wire iaur_wen_u = iaur_wen & (!Rx_out_full);
wire galr_wen_u = galr_wen & (!Rx_out_full);
wire gaur_wen_u = gaur_wen & (!Rx_out_full);
wire rdsr_wen_u = rdsr_wen & (!Rx_out_full);
wire tdsr_wen_u = tdsr_wen & (!Tx_out_full);
wire rsfl_wen_u = rsfl_wen & (!Rx_out_full);
wire rsem_wen_u = rsem_wen & (!Rx_out_full);
wire rafl_wen_u = rafl_wen & (!Rx_out_full);
wire raem_wen_u = raem_wen & (!Rx_out_full);
wire tfwr_wen_u = tfwr_wen & (!Tx_out_full);
wire tsem_wen_u = tsem_wen & (!Tx_out_full);
wire tafl_wen_u = tafl_wen & (!Tx_out_full);
wire taem_wen_u = taem_wen & (!Tx_out_full);
wire tipg_wen_u = tipg_wen & (!Tx_out_full);
wire ftrl_wen_u = ftrl_wen & (!Rx_out_full);

assign write_success =  tdar_wen_s | rdar_wen_s | ecr_wen_s | tcr_wen_s | rcr_wen_s | 
                        palr_wen_u | paur_wen_u | opd_wen_u | ialr_wen_u | iaur_wen_u |
                        galr_wen_u | gaur_wen_u | rdsr_wen_u | tdsr_wen_u | rsfl_wen_u |
                        rsem_wen_u | rafl_wen_u | raem_wen_u | tfwr_wen_u | tsem_wen_u | 
                        tafl_wen_u | taem_wen_u | tipg_wen_u | ftrl_wen_u;

reg  Tx_wen_r;
reg  Tx_wait;
reg  [44:0] Tx_out_data_in_reg;
wire Tx_send =  tdar_wen_s | ecr_wen_s | tcr_wen_s | 
                palr_wen_u | paur_wen_u | opd_wen_u |
                tdsr_wen_u | tfwr_wen_u | tsem_wen_u | 
                tafl_wen_u | taem_wen_u | tipg_wen_u;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        Tx_wen_r <= 1'b0;
        Tx_wait  <= 1'b0;
    end
    else if(Tx_wait)begin
        if(read_done)begin
            Tx_wait  <= 1'b0;
        end
        if(!Tx_out_full)begin
            Tx_wen_r <= 1'b0;
        end
    end
    else if(Tx_send)begin
        Tx_wen_r <= 1'b1;
        Tx_wait  <= 1'b0;
    end
    else if(tcr_ren | tdar_ren)begin
        Tx_wen_r <= 1'b1;
        Tx_wait  <= 1'b1;
    end
    else if(Tx_wen_r)begin
        Tx_wen_r <= 1'b0;
    end
end
always @(posedge clk) begin
    if(Tx_send | tcr_ren | tdar_ren)begin
        Tx_out_data_in_reg  <= {reg_wdata, reg_addr, (tcr_ren | tdar_ren)};
    end
end
assign Tx_out_wen = Tx_wen_r;

wire tdar_wen_u         = (!Tx_in_empty) & (Tx_in_data_out[11:0] == 12'h14);
wire tcr_wen_u          = (!Tx_in_empty) & (Tx_in_data_out[11:0] == 12'hC4);
assign Tx_out_data_in   = Tx_out_data_in_reg;
assign Tx_in_ren        = 1'b1;
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_tdar(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(tdar_wen_u         ),
    .data_in  	(Tx_in_data_out[36] ),
    .data_out 	(tdar[24]           )
);
assign {tdar[31:25], tdar[23:0]} = 31'h0;
FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_tcr(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(tcr_wen_u              ),
    .data_in  	(Tx_in_data_out[43:12]  ),
    .data_out 	(tcr                    )
);

reg  Rx_wen_r;
reg  Rx_wait;
reg  [44:0] Rx_out_data_in_reg;
wire Rx_send =  rdar_wen_s | ecr_wen_s | rcr_wen_s | 
                palr_wen_u | paur_wen_u | ialr_wen_u | iaur_wen_u |
                galr_wen_u | gaur_wen_u | rdsr_wen_u | rsfl_wen_u |
                rsem_wen_u | rafl_wen_u | raem_wen_u | ftrl_wen_u;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        Rx_wen_r <= 1'b0;
        Rx_wait  <= 1'b0;
    end
    else if(Rx_wait)begin
        if(read_done)begin
            Rx_wait  <= 1'b0;
        end
        if(!Rx_out_full)begin
            Rx_wen_r <= 1'b0;
        end
    end
    else if(Rx_send)begin
        Rx_wen_r <= 1'b1;
        Rx_wait  <= 1'b0;
    end
    else if(rcr_ren | rdar_ren)begin
        Rx_wen_r <= 1'b1;
        Rx_wait  <= 1'b1;
    end
    else if(Rx_wen_r)begin
        Rx_wen_r <= 1'b0;
    end
end
always @(posedge clk) begin
    if(Rx_send | rcr_ren | rdar_ren)begin
        Rx_out_data_in_reg <= {reg_wdata, reg_addr, (rcr_ren | rdar_ren)};
    end
end
assign Rx_out_wen       = Rx_wen_r;
wire rdar_wen_u         = (!Rx_in_empty) & (Rx_in_data_out[11:0] == 12'h10);
wire rcr_wen_u          = (!Rx_in_empty) & (Rx_in_data_out[11:0] == 12'h84);
assign Rx_out_data_in   = Rx_out_data_in_reg;
assign Rx_in_ren        = 1'b1;
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_rdar(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(rdar_wen_u         ),
    .data_in  	(Rx_in_data_out[36] ),
    .data_out 	(rdar[24]           )
);
assign {rdar[31:25], rdar[23:0]} = 31'h0;
FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_rcr(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(rcr_wen_u              ),
    .data_in  	(Rx_in_data_out[43:12]  ),
    .data_out 	(rcr                    )
);

wire t_eir_wen_u   = (!Tx_in_empty) & (Tx_in_data_out[11:0] == 12'h4);
wire r_eir_wen_u   = (!Rx_in_empty) & (Rx_in_data_out[11:0] == 12'h4);

wire babr_in = (r_eir_wen_u & Rx_in_data_out[42]) ? 1'b1 : ((eir_wen & reg_wdata[30]) ? 1'b0 : babr);
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_eir_babr(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(r_eir_wen_u | eir_wen  ),
    .data_in  	(babr_in                ),
    .data_out 	(babr                   )
);
wire babt_in = (t_eir_wen_u & Tx_in_data_out[41]) ? 1'b1 : ((eir_wen & reg_wdata[29]) ? 1'b0 : babt);
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_eir_babt(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(t_eir_wen_u | eir_wen  ),
    .data_in  	(babt_in                ),
    .data_out 	(babt                   )
);
wire gra_in = (t_eir_wen_u & Tx_in_data_out[40]) ? 1'b1 : ((eir_wen & reg_wdata[28]) ? 1'b0 : gra);
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_eir_gra(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(t_eir_wen_u | eir_wen  ),
    .data_in  	(gra_in                 ),
    .data_out 	(gra                    )
);
assign rxf_in = (r_eir_wen_u & Rx_in_data_out[37]) ? 1'b1 : 1'b0;
// FF_D_with_wen #(
//     .DATA_LEN 	(1  ),
//     .RST_DATA 	(0  ))
// u_eir_rxf(
//     .clk      	(clk                    ),
//     .rst_n    	(rst_n                  ),
//     .wen      	(r_eir_wen_u | eir_wen  ),
//     .data_in  	(rxf_in                 ),
//     .data_out 	(rxf                    )
// );
assign txf_in = (t_eir_wen_u & Tx_in_data_out[39]) ? 1'b1 : 1'b0;
// FF_D_with_wen #(
//     .DATA_LEN 	(1  ),
//     .RST_DATA 	(0  ))
// u_eir_txf(
//     .clk      	(clk                    ),
//     .rst_n    	(rst_n                  ),
//     .wen      	(t_eir_wen_u | eir_wen  ),
//     .data_in  	(txf_in                 ),
//     .data_out 	(txf                    )
// );
wire eberr_in = (t_eir_wen_u & Tx_in_data_out[34]) ? 1'b1 : ((r_eir_wen_u & Rx_in_data_out[34]) ? 1'b1 : ((eir_wen & reg_wdata[22]) ? 1'b0 : eberr));
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_eir_eberr(
    .clk      	(clk                                 ),
    .rst_n    	(rst_n                               ),
    .wen      	(t_eir_wen_u | r_eir_wen_u | eir_wen ),
    .data_in  	(eberr_in                            ),
    .data_out 	(eberr                               )
);
wire lc_in = (t_eir_wen_u & Tx_in_data_out[33]) ? 1'b1 : ((eir_wen & reg_wdata[21]) ? 1'b0 : lc);
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_eir_lc(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(t_eir_wen_u | eir_wen  ),
    .data_in  	(lc_in                  ),
    .data_out 	(lc                     )
);
wire rl_in = (t_eir_wen_u & Tx_in_data_out[32]) ? 1'b1 : ((eir_wen & reg_wdata[20]) ? 1'b0 : rl);
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_eir_rl(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(t_eir_wen_u | eir_wen  ),
    .data_in  	(rl_in                  ),
    .data_out 	(rl                     )
);
wire un_in = (t_eir_wen_u & Tx_in_data_out[31]) ? 1'b1 : ((eir_wen & reg_wdata[19]) ? 1'b0 : un);
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_eir_un(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(t_eir_wen_u | eir_wen  ),
    .data_in  	(un_in                  ),
    .data_out 	(un                     )
);
wire plr_in = (r_eir_wen_u & Rx_in_data_out[30]) ? 1'b1 : ((eir_wen & reg_wdata[18]) ? 1'b0 : plr);
FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_eir_plr(
    .clk      	(clk                    ),
    .rst_n    	(rst_n                  ),
    .wen      	(t_eir_wen_u | eir_wen  ),
    .data_in  	(plr_in                 ),
    .data_out 	(plr                    )
);

assign read_done =  (tdar_ren & tdar_wen_u ) | 
                    (tcr_ren  & tcr_wen_u  ) |
                    (rdar_ren & rdar_wen_u ) |
                    (rcr_ren  & rcr_wen_u  );

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_eimr(
    .clk      	(clk       ),
    .rst_n    	(rst_n     ),
    .wen      	(eimr_wen  ),
    .data_in  	(reg_wdata ),
    .data_out 	(eimr      )
);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_palr(
    .clk      	(clk       ),
    .rst_n    	(rst_n     ),
    .wen      	(palr_wen_u),
    .data_in  	(reg_wdata ),
    .data_out 	(palr      )
);

wire [15:0] paur_u16;
FF_D_with_wen #(
    .DATA_LEN 	(16 ),
    .RST_DATA 	(0  ))
u_paur(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(paur_wen_u         ),
    .data_in  	(reg_wdata[31:16]   ),
    .data_out 	(paur_u16           )
);
assign paur = {paur_u16, 16'h8808};

wire [15:0] opd_l16;
FF_D_with_wen #(
    .DATA_LEN 	(16 ),
    .RST_DATA 	(0  ))
u_opd(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(opd_wen_u          ),
    .data_in  	(reg_wdata[15:0]    ),
    .data_out 	(opd_l16            )
);
assign opd = {16'h0001, opd_l16};

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_ialr(
    .clk      	(clk       ),
    .rst_n    	(rst_n     ),
    .wen      	(ialr_wen_u),
    .data_in  	(reg_wdata ),
    .data_out 	(ialr      )
);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_iaur(
    .clk      	(clk       ),
    .rst_n    	(rst_n     ),
    .wen      	(iaur_wen_u),
    .data_in  	(reg_wdata ),
    .data_out 	(iaur      )
);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_galr(
    .clk      	(clk       ),
    .rst_n    	(rst_n     ),
    .wen      	(galr_wen_u),
    .data_in  	(reg_wdata ),
    .data_out 	(galr      )
);

FF_D_with_wen #(
    .DATA_LEN 	(32 ),
    .RST_DATA 	(0  ))
u_gaur(
    .clk      	(clk       ),
    .rst_n    	(rst_n     ),
    .wen      	(gaur_wen_u),
    .data_in  	(reg_wdata ),
    .data_out 	(gaur      )
);

FF_D_with_wen #(
    .DATA_LEN 	(29 ),
    .RST_DATA 	(0  ))
u_rdsr(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(rdsr_wen_u         ),
    .data_in  	(reg_wdata[31:3]    ),
    .data_out 	(rdsr[31:3]         )
);
assign rdsr[2:0] = 3'h0;


FF_D_with_wen #(
    .DATA_LEN 	(29 ),
    .RST_DATA 	(0  ))
u_tdsr(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(tdsr_wen_u         ),
    .data_in  	(reg_wdata[31:3]    ),
    .data_out 	(tdsr[31:3]         )
);
assign tdsr[2:0] = 3'h0;

FF_D_with_wen #(
    .DATA_LEN 	(8  ),
    .RST_DATA 	(0  ))
u_rsfl(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(rsfl_wen_u         ),
    .data_in  	(reg_wdata[7:0]     ),
    .data_out 	(rsfl[7:0]          )
);
assign rsfl[31:8] = 24'h0;

FF_D_with_wen #(
    .DATA_LEN 	(5  ),
    .RST_DATA 	(0  ))
u_rsem_stat(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(rsem_wen_u         ),
    .data_in  	(reg_wdata[20:16]   ),
    .data_out 	(rsem[20:16]        )
);
FF_D_with_wen #(
    .DATA_LEN 	(8  ),
    .RST_DATA 	(0  ))
u_rsem_rx(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(rsem_wen_u         ),
    .data_in  	(reg_wdata[7:0]     ),
    .data_out 	(rsem[7:0]          )
);
assign {rsem[31:21], rsem[15:8]} = 19'h0;

wire [7:0] rafl_wdata = (reg_wdata[7:0] > 8'd124) ? 8'd124 : reg_wdata[7:0];
FF_D_with_wen #(
    .DATA_LEN 	(8       ),
    .RST_DATA 	(8'd124  ))
u_rafl(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(rafl_wen_u         ),
    .data_in  	(rafl_wdata         ),
    .data_out 	(rafl[7:0]          )
);
assign rafl[31:8] = 24'h0;

wire [7:0] raem_wdata = (reg_wdata[7:0] < 8'h4) ? 8'h4 : reg_wdata[7:0];
FF_D_with_wen #(
    .DATA_LEN 	(8      ),
    .RST_DATA 	(8'h4   ))
u_raem(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(raem_wen_u         ),
    .data_in  	(raem_wdata         ),
    .data_out 	(raem[7:0]          )
);
assign raem[31:8] = 24'h0;

FF_D_with_wen #(
    .DATA_LEN 	(1  ),
    .RST_DATA 	(0  ))
u_tfwr_strfwd(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(tfwr_wen_u         ),
    .data_in  	(reg_wdata[8]       ),
    .data_out 	(tfwr[8]            )
);
FF_D_with_wen #(
    .DATA_LEN 	(5  ),
    .RST_DATA 	(0  ))
u_tfwr(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(tfwr_wen_u         ),
    .data_in  	(reg_wdata[4:0]     ),
    .data_out 	(tfwr[4:0]          )
);
assign {tfwr[31:9], tfwr[7:5]} = 26'h0;

FF_D_with_wen #(
    .DATA_LEN 	(8  ),
    .RST_DATA 	(0  ))
u_tsem(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(tsem_wen_u         ),
    .data_in  	(reg_wdata[7:0]     ),
    .data_out 	(tsem[7:0]          )
);
assign tsem[31:8] = 24'h0;

wire [7:0] tafl_wdata = (reg_wdata[7:0] > 8'd120) ? 8'd120 : reg_wdata[7:0];
FF_D_with_wen #(
    .DATA_LEN 	(8       ),
    .RST_DATA 	(8'd120  ))
u_tafl(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(tafl_wen_u         ),
    .data_in  	(tafl_wdata         ),
    .data_out 	(tafl[7:0]          )
);
assign tafl[31:8] = 24'h0;

wire [7:0] taem_wdata = (reg_wdata[7:0] < 8'h4) ? 8'h4 : reg_wdata[7:0];
FF_D_with_wen #(
    .DATA_LEN 	(8      ),
    .RST_DATA 	(8'h4   ))
u_taem(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(taem_wen_u         ),
    .data_in  	(taem_wdata         ),
    .data_out 	(taem[7:0]          )
);
assign taem[31:8] = 24'h0;

FF_D_with_wen #(
    .DATA_LEN 	(5       ),
    .RST_DATA 	(5'hC    ))
u_tipg(
    .clk      	(clk               ),
    .rst_n    	(rst_n             ),
    .wen      	(tipg_wen_u        ),
    .data_in  	(reg_wdata[4:0]    ),
    .data_out 	(tipg[4:0]         )
);
assign tipg[31:5] = 27'h0;

FF_D_with_wen #(
    .DATA_LEN 	(14         ),
    .RST_DATA 	(14'h7ff    ))
u_ftrl(
    .clk      	(clk                ),
    .rst_n    	(rst_n              ),
    .wen      	(ftrl_wen_u         ),
    .data_in  	(reg_wdata[13:0]    ),
    .data_out 	(ftrl[13:0]         )
);
assign ftrl[31:14] = 18'h0;


endmodule //enet_normal_reg
