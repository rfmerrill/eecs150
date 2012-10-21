module mt4htf3264hy
(
    input [12:0]  DDR2_A,
    input [1:0]   DDR2_BA,
    input         DDR2_CAS_B,
    input         DDR2_CKE,
    input [1:0]   DDR2_CLK_N,
    input [1:0]   DDR2_CLK_P,
    input         DDR2_CS_B,
    inout [63:0]  DDR2_D,
    input [7:0]   DDR2_DM,
    inout [7:0]   DDR2_DQS_N,
    inout [7:0]   DDR2_DQS_P,
    input         DDR2_ODT,
    input         DDR2_RAS_B,
    input         DDR2_WE_B
);
   ddr2_model u_mem0
   (
       .ck(DDR2_CLK_P[0]),
       .ck_n(DDR2_CLK_N[0]),
       .cke(DDR2_CKE),
       .cs_n(DDR2_CS_B),
       .ras_n(DDR2_RAS_B),
       .cas_n(DDR2_CAS_B),
       .we_n(DDR2_WE_B),
       .dm_rdqs(DDR2_DM[1:0]),
       .ba(DDR2_BA),
       .addr(DDR2_A),
       .dq(DDR2_D[15:0]),
       .dqs(DDR2_DQS_P[1:0]),
       .dqs_n(DDR2_DQS_N[1:0]),
       .rdqs_n( ),
       .odt(DDR2_ODT)
   );
   ddr2_model u_mem1
   (
       .ck(DDR2_CLK_P[0]),
       .ck_n(DDR2_CLK_N[0]),
       .cke(DDR2_CKE),
       .cs_n(DDR2_CS_B),
       .ras_n(DDR2_RAS_B),
       .cas_n(DDR2_CAS_B),
       .we_n(DDR2_WE_B),
       .dm_rdqs(DDR2_DM[3:2]),
       .ba(DDR2_BA),
       .addr(DDR2_A),
       .dq(DDR2_D[31:16]),
       .dqs(DDR2_DQS_P[3:2]),
       .dqs_n(DDR2_DQS_N[3:2]),
       .rdqs_n( ),
       .odt(DDR2_ODT)
   );
   ddr2_model u_mem2
   (
       .ck(DDR2_CLK_P[1]),
       .ck_n(DDR2_CLK_N[1]),
       .cke(DDR2_CKE),
       .cs_n(DDR2_CS_B),
       .ras_n(DDR2_RAS_B),
       .cas_n(DDR2_CAS_B),
       .we_n(DDR2_WE_B),
       .dm_rdqs(DDR2_DM[5:4]),
       .ba(DDR2_BA),
       .addr(DDR2_A),
       .dq(DDR2_D[47:32]),
       .dqs(DDR2_DQS_P[5:4]),
       .dqs_n(DDR2_DQS_N[5:4]),
       .rdqs_n( ),
       .odt(DDR2_ODT)
   );
   ddr2_model u_mem3
   (
       .ck(DDR2_CLK_P[1]),
       .ck_n(DDR2_CLK_N[1]),
       .cke(DDR2_CKE),
       .cs_n(DDR2_CS_B),
       .ras_n(DDR2_RAS_B),
       .cas_n(DDR2_CAS_B),
       .we_n(DDR2_WE_B),
       .dm_rdqs(DDR2_DM[7:6]),
       .ba(DDR2_BA),
       .addr(DDR2_A),
       .dq(DDR2_D[63:48]),
       .dqs(DDR2_DQS_P[7:6]),
       .dqs_n(DDR2_DQS_N[7:6]),
       .rdqs_n( ),
       .odt(DDR2_ODT)
   );
endmodule
