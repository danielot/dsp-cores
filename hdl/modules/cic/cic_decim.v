//-----------------------------------------------------------------------------
// Title      : CIC decimator with dynamically-adjustable decimator
// Project    :
//-----------------------------------------------------------------------------
// File       : cic_decim.v
// Author     : danielot  <daniel.tavares@lnls.br>
// Company    :
// Created    : 2016-05-03
// Last update: 2016-05-03
// Platform   :
// Standard   : VHDL'93/02
//-----------------------------------------------------------------------------
// Description: CIC decimator with dinamically adjustable decimation rate
//-----------------------------------------------------------------------------
// Copyright (c) 2016
//-----------------------------------------------------------------------------
// Revisions  :
// Date        Version  Author  Description
// 2016-05-03  1.0      danielot  Created
//-----------------------------------------------------------------------------
//
// Design based on code available on GNU Radio


// The CIC has a valid signal (act) pipeline that signals when the data is
// filling integrator and comb pipelines. When the decimation strobe
// comes (act_out_i), the data in the last integrator register is sampled
// to the comb stage. However, to allow the decimation strobe to happen in
// a different clock period from the valid input signal, the valid signal
// in the last register is marked as invalid during the decimation. The
// sampling only happens when this register is valid, avoiding data corruption
// from occasional spurious decimation strobes.


module cic_decim
  #(
    parameter DATAIN_WIDTH = 16,
    parameter DATAOUT_WIDTH = DATAIN_WIDTH,
    parameter M = 2,
    parameter N = 5,
    parameter MAXRATE = 64,
    parameter bitgrowth = 35 //N*log2(M*MAXRATE)
    )
   (
    input                      clk_i,
    input                      rst_i,
    input                      en_i,
    input [DATAIN_WIDTH-1:0]   data_i,
    output [DATAOUT_WIDTH-1:0] data_o,
    input                      act_i,
    input                      act_out_i,
    output                     val_o
    );

   wire [DATAIN_WIDTH+bitgrowth-1:0] datain_extended;
   reg [DATAIN_WIDTH+bitgrowth-1:0]  integrator [0:N-1];
   reg [DATAIN_WIDTH+bitgrowth-1:0]  diffdelay [0:N-1][0:M-1];
   reg [DATAIN_WIDTH+bitgrowth-1:0]  pipe [0:N-1];
   reg [DATAIN_WIDTH+bitgrowth-1:0]  sampler =  {{1'b0}};
   reg                               val_reg0 =  {{1'b0}};
   reg                               act_int [0:N-1];
   reg                               act_samp;
   reg                               act_comb [0:N-1];

   integer                           i,j;

   assign datain_extended = {{(bitgrowth){data_i[DATAIN_WIDTH-1]}},data_i};

   // Integrator sections
   always @(posedge clk_i)
     if (rst_i)
       for (i=0; i<N; i=i+1) begin
         integrator[i] <= {{1'b0}};
         act_int[i] <= {{1'b0}};
       end

     else if (en_i) begin
       if (act_i) begin
         integrator[0] <= integrator[0] + datain_extended;
         act_int[0] <= 1'b1;

         for (i=1; i<N; i=i+1) begin
           integrator[i] <= integrator[i] + integrator[i-1];
           act_int[i] <= act_int[i-1];
         end
       end
       else begin
         // Clear the act_int flag only when the COMB section acknowledges it
         if (act_out_i) begin
           act_int[N-1] <= 1'b0;
         end
       end
     end

   // Comb sections
   always @(posedge clk_i) begin
     if (rst_i) begin
       sampler <= {{1'b0}};

       for (i=0; i<N; i=i+1) begin
         pipe[i] <= {{1'b0}};
         act_comb[i] <= {{1'b0}};

         for (j=0; j<M; j=j+1)
           diffdelay[i][j] <= {{1'b0}};
       end
       act_samp <= 1'b0;
       val_reg0 <= 1'b0;
     end
     else begin
       if (en_i) begin
         if (act_out_i && act_int[N-1]) begin
            sampler <= integrator[N-1];
            act_samp <= 1'b1;

            diffdelay[0][0] <= sampler;

            for (j=1; j<M; j=j+1)
              diffdelay[0][j] <= diffdelay[0][j-1];

            pipe[0] <= sampler - diffdelay[0][M-1];
            act_comb[0] <= act_samp;

            for (i=1; i<N; i=i+1) begin
              diffdelay[i][0] <= pipe[i-1];

              for (j=1; j<M; j=j+1)
                diffdelay[i][j] <= diffdelay[i][j-1];

              pipe[i] <= pipe[i-1] - diffdelay[i][M-1];
              act_comb[i] <= act_comb[i-1];
            end

            if(N==1)
              val_reg0 <= act_samp;
            else
              val_reg0 <= act_comb[N-2]; //same as act_comb[N-1]

         end // if (act_out_i)
         else begin
           val_reg0 <= 1'b0;
         end // else: !if(act_out_i)
       end // if (en_i)
     end // else: !if(rst_i)
   end // always @ (posedge clk_i)

   generate
     if (DATAIN_WIDTH+bitgrowth-DATAOUT_WIDTH >= 0)
       assign data_o = pipe[N-1][DATAIN_WIDTH+bitgrowth-1:DATAIN_WIDTH+bitgrowth-DATAOUT_WIDTH];
     else
       assign data_o = {{(DATAOUT_WIDTH-(DATAIN_WIDTH+bitgrowth)){pipe[N-1][DATAIN_WIDTH+bitgrowth-1]}}, pipe[N-1]};
   endgenerate

   assign val_o = val_reg0;

endmodule
