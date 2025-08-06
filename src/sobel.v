/************** 注释 ***********

Sobel算子模板系数：

y                 x
-1 0 1           1 2 1
-2 0 2           0 0 0
-1 0 1           -1 -2 -1

g = |x_g| + |y_g|

*******************************/
module sobel(
    input           clk     ,
    input           rst_n   ,
    input   [7:0]   din     ,//输入8位亮度图像
    input           din_sop ,
    input           din_eop ,
    input           din_vld ,

    output          dout    ,
    output          dout_sop,
    output          dout_eop,
    output          dout_vld 
);

// 内部参数定义
localparam DATA_WIDTH    = 8;
localparam X_COEFF_MAX   = 2;  // X方向最大系数值
localparam Y_COEFF_MAX   = 2;  // Y方向最大系数值
// 拓展位宽，增加计算精度
localparam SUM_WIDTH     = DATA_WIDTH + $clog2(X_COEFF_MAX*2+1) + 2; // 8+2+2=12
localparam ABS_WIDTH     = SUM_WIDTH;
localparam GRAD_WIDTH    = ABS_WIDTH + 2; // 绝对值相加可能的最大位宽，再增加2位
localparam THRESHOLD     = 13'd50; // 调整阈值以匹配更高的位宽

// 信号定义
wire    [DATA_WIDTH-1:0]  taps0; 
wire    [DATA_WIDTH-1:0]  taps1; 
wire    [DATA_WIDTH-1:0]  taps2; 

reg     [DATA_WIDTH-1:0]  line0_0;
reg     [DATA_WIDTH-1:0]  line0_1;
reg     [DATA_WIDTH-1:0]  line0_2;

reg     [DATA_WIDTH-1:0]  line1_0;
reg     [DATA_WIDTH-1:0]  line1_1;
reg     [DATA_WIDTH-1:0]  line1_2;

reg     [DATA_WIDTH-1:0]  line2_0;
reg     [DATA_WIDTH-1:0]  line2_1;
reg     [DATA_WIDTH-1:0]  line2_2;
    
reg     [3:0]             sop;
reg     [3:0]             eop;
reg     [3:0]             vld;
    
reg     [SUM_WIDTH-1:0]   x0_sum;  // 卷积和
reg     [SUM_WIDTH-1:0]   x2_sum;
reg     [SUM_WIDTH-1:0]   y0_sum;
reg     [SUM_WIDTH-1:0]   y2_sum;

reg     [SUM_WIDTH-1:0]   x_conv;  // 完整卷积结果
reg     [SUM_WIDTH-1:0]   y_conv;

reg     [ABS_WIDTH-1:0]   x_abs;   // 绝对值
reg     [ABS_WIDTH-1:0]   y_abs;
    
reg     [GRAD_WIDTH-1:0]  g;       // 梯度值

// 缓存3行
sobel_line_buf	sobel_line_buf_inst (
	.aclr       (~rst_n     ),
	.clken      (din_vld    ),
	.clock      (clk        ),
	.shiftin    (din        ),
	.shiftout   (           ),
	.taps0x     (taps0      ),
	.taps1x     (taps1      ),
	.taps2x     (taps2      )
	);

// 缓存3列 - 第一级流水
always  @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        line0_0 <= {DATA_WIDTH{1'b0}}; 
        line0_1 <= {DATA_WIDTH{1'b0}}; 
        line0_2 <= {DATA_WIDTH{1'b0}};
        line1_0 <= {DATA_WIDTH{1'b0}}; 
        line1_1 <= {DATA_WIDTH{1'b0}}; 
        line1_2 <= {DATA_WIDTH{1'b0}};
        line2_0 <= {DATA_WIDTH{1'b0}}; 
        line2_1 <= {DATA_WIDTH{1'b0}}; 
        line2_2 <= {DATA_WIDTH{1'b0}};
    end
    else if(vld[0]) begin
        line0_0 <= taps0; line0_1 <= line0_0; line0_2 <= line0_1;
        line1_0 <= taps1; line1_1 <= line1_0; line1_2 <= line1_1;
        line2_0 <= taps2; line2_1 <= line2_0; line2_2 <= line2_1;
    end
end

// 第二级流水 - 计算完整卷积和
always  @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        x0_sum <= {SUM_WIDTH{1'b0}};
        x2_sum <= {SUM_WIDTH{1'b0}};
        y0_sum <= {SUM_WIDTH{1'b0}};
        y2_sum <= {SUM_WIDTH{1'b0}};
        x_conv <= {SUM_WIDTH{1'b0}};
        y_conv <= {SUM_WIDTH{1'b0}};
    end
    else if(vld[1]) begin
        // X方向卷积计算：[1 2 1]
        x0_sum <= line0_0 + (line0_1 << 1) + line0_2;
        x2_sum <= line2_0 + (line2_1 << 1) + line2_2;
        // Y方向卷积计算：[1 2 1]^T
        y0_sum <= line0_0 + (line1_0 << 1) + line2_0;
        y2_sum <= line0_2 + (line1_2 << 1) + line2_2;
        
        // 完整Sobel卷积计算
        x_conv <= x0_sum - x2_sum;
        y_conv <= y0_sum - y2_sum;
    end
end    

// 第3级流水 - 计算x、y方向梯度绝对值
always  @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        x_abs <= {ABS_WIDTH{1'b0}};
        y_abs <= {ABS_WIDTH{1'b0}};
    end
    else if(vld[2]) begin
        x_abs <= (x_conv[SUM_WIDTH-1] == 1'b1) ? (~x_conv + 1'b1) : x_conv;
        y_abs <= (y_conv[SUM_WIDTH-1] == 1'b1) ? (~y_conv + 1'b1) : y_conv;
    end
end

// 第4级流水 - 计算梯度
always  @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        g <= {GRAD_WIDTH{1'b0}};
    end
    else if(vld[3]) begin
        g <= x_abs + y_abs; // 绝对值之和近似平方和开根号
    end
end

// 打拍控制信号
always  @(posedge clk or negedge rst_n) begin
    if(~rst_n) begin
        sop <= 4'd0;
        eop <= 4'd0;
        vld <= 4'd0;
    end
    else begin
        sop <= {sop[2:0], din_sop};
        eop <= {eop[2:0], din_eop};
        vld <= {vld[2:0], din_vld};
    end
end

// 阈值比较 - 使用优化后的阈值
assign  dout     = g >= THRESHOLD;
assign  dout_sop = sop[3];
assign  dout_eop = eop[3];
assign  dout_vld = vld[3];

endmodule    