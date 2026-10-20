`ifndef MYCPU_HEAD_V
`define MYCPU_HEAD_V

`define BR_BUS_WD       33
`define FS_TO_DS_BUS_WD 64
`define CSR_BUS_WD      82
`define DS_TO_ES_BUS_WD (163 + `CSR_BUS_WD)
`define ES_TO_MS_BUS_WD (74 + `CSR_BUS_WD)
`define ES_TO_DS_BUS_WD 39
`define MS_TO_DS_BUS_WD 39
`define WS_TO_RF_BUS_WD 38
`define MS_TO_WS_BUS_WD (70 + `CSR_BUS_WD)
//LoongArch Documentation P103,104
`define CSR_CRMD       14'h0000
`define CSR_PRMD       14'h0001
`define CSR_ESTAT      14'h0005
`define CSR_ERA        14'h0006
`define CSR_EENTRY     14'h000c
`define CSR_SAVE0      14'h0030
`define CSR_SAVE1      14'h0031
`define CSR_SAVE2      14'h0032
`define CSR_SAVE3      14'h0033
`define ECODE_SYS      6'h0b

`endif
