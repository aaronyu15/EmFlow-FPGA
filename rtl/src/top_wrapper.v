// Copyright (c) 2026 Aaron Yu
// SPDX-License-Identifier: MIT

`timescale 1 ps / 1 ps

module top_wrapper (
  input ccam5_csi_rx_clk_n,
  input ccam5_csi_rx_clk_p,
  input [1:0]ccam5_csi_rx_data_n,
  input [1:0]ccam5_csi_rx_data_p,
  inout ccam5_i2c_scl_io,
  inout ccam5_i2c_sda_io,
  output [0:0]fan_en_b,
  output [1:0]gpio_generic_tri_o,
  output [7:0]gpio_rtl_tri_o
);

  wire ccam5_i2c_scl_i;
  wire ccam5_i2c_scl_o;
  wire ccam5_i2c_scl_t;
  wire ccam5_i2c_sda_i;
  wire ccam5_i2c_sda_o;
  wire ccam5_i2c_sda_t;

  IOBUF ccam5_i2c_scl_iobuf
       (.I(ccam5_i2c_scl_o),
        .IO(ccam5_i2c_scl_io),
        .O(ccam5_i2c_scl_i),
        .T(ccam5_i2c_scl_t));
  IOBUF ccam5_i2c_sda_iobuf
       (.I(ccam5_i2c_sda_o),
        .IO(ccam5_i2c_sda_io),
        .O(ccam5_i2c_sda_i),
        .T(ccam5_i2c_sda_t));
  kv260 kv260_i
       (.ccam5_csi_rx_clk_n(ccam5_csi_rx_clk_n),
        .ccam5_csi_rx_clk_p(ccam5_csi_rx_clk_p),
        .ccam5_csi_rx_data_n(ccam5_csi_rx_data_n),
        .ccam5_csi_rx_data_p(ccam5_csi_rx_data_p),
        .ccam5_i2c_scl_i(ccam5_i2c_scl_i),
        .ccam5_i2c_scl_o(ccam5_i2c_scl_o),
        .ccam5_i2c_scl_t(ccam5_i2c_scl_t),
        .ccam5_i2c_sda_i(ccam5_i2c_sda_i),
        .ccam5_i2c_sda_o(ccam5_i2c_sda_o),
        .ccam5_i2c_sda_t(ccam5_i2c_sda_t),
        .fan_en_b(fan_en_b),
        .gpio_generic_tri_o(gpio_generic_tri_o),
        .gpio_rtl_tri_o(gpio_rtl_tri_o));
endmodule
