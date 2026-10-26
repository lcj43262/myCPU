`ifndef MYCPU_HEAD_V
`define MYCPU_HEAD_V

`define BR_BUS_WD       33
`define FS_TO_DS_BUS_WD 65
`define CSR_BUS_WD      82
// Counter reads are completed in WB, independently of the CSR control bus.
`define CNT_OP_WD       2
`define CNT_NONE        2'b00
`define CNT_LOW         2'b01
`define CNT_HIGH        2'b10
`define CNT_ID          2'b11
// {ADEF, INT, BRK, INE, ALE, badv[31:0]}
`define EX_BUS_WD       37
`define DS_TO_ES_BUS_WD (163 + `CSR_BUS_WD + `EX_BUS_WD + `CNT_OP_WD)
`define ES_TO_MS_BUS_WD (74 + `CSR_BUS_WD + `EX_BUS_WD + `CNT_OP_WD)
`define ES_TO_DS_BUS_WD 39
`define MS_TO_DS_BUS_WD 39
`define WS_TO_RF_BUS_WD 38
`define MS_TO_WS_BUS_WD (70 + `CSR_BUS_WD + `EX_BUS_WD + `CNT_OP_WD)
//LoongArch Documentation P103,104
`define CSR_CRMD       14'h0000
`define CSR_PRMD       14'h0001
`define CSR_ECFG       14'h0004
`define CSR_ESTAT      14'h0005
`define CSR_ERA        14'h0006
`define CSR_BADV       14'h0007
`define CSR_EENTRY     14'h000c
`define CSR_SAVE0      14'h0030
`define CSR_SAVE1      14'h0031
`define CSR_SAVE2      14'h0032
`define CSR_SAVE3      14'h0033
`define CSR_TID        14'h0040
`define CSR_TCFG       14'h0041
`define CSR_TVAL       14'h0042
`define CSR_TICLR      14'h0044
`define ECODE_INT      6'h00
`define ECODE_ADEF     6'h08
`define ECODE_ALE      6'h09
`define ECODE_SYS      6'h0b
`define ECODE_BRK      6'h0c
`define ECODE_INE      6'h0d

`endif
