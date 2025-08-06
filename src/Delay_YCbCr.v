module Delay_YCbCr
#(  
    parameter  DELAY_CNT  =  7     
)
(
    input               clk         ,
    input               rst_n       ,
        
    input   [7:0]       din_Y       ,
    input   [7:0]       din_Cb      ,
    input   [7:0]       din_Cr      ,
    
    output reg [7:0]    dout_Y      ,
    output reg [7:0]    dout_Cb     ,
    output reg [7:0]    dout_Cr     
);

// 信号定义
reg     [7:0]       Y_dly  [DELAY_CNT - 1 :0]; // 5级Y数据寄存器
reg     [7:0]       Cb_dly [DELAY_CNT - 1 :0]; // 5级Cb数据寄存器
reg     [7:0]       Cr_dly [DELAY_CNT - 1 :0]; // 5级Cr数据寄存器

integer i;

// 数据信号打拍（5级流水线）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i = 0; i < DELAY_CNT; i = i + 1) begin
            Y_dly[i]  <= 8'b0;
            Cb_dly[i] <= 8'b0;
            Cr_dly[i] <= 8'b0;
        end
    end 
    else begin
        Y_dly[0]  <= din_Y;
        Cb_dly[0] <= din_Cb;
        Cr_dly[0] <= din_Cr;
        for (i = 1; i < DELAY_CNT; i = i + 1) begin
            Y_dly[i]  <= Y_dly[i-1];
            Cb_dly[i] <= Cb_dly[i-1];
            Cr_dly[i] <= Cr_dly[i-1];
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dout_Y  <= 8'b0;
        dout_Cb <= 8'b0;
        dout_Cr <= 8'b0;
    end else begin
        dout_Y  <= Y_dly [DELAY_CNT - 1];   // 取第最后级寄存器的值
        dout_Cb <= Cb_dly[DELAY_CNT - 1];
        dout_Cr <= Cr_dly[DELAY_CNT - 1];
    end
end

endmodule    