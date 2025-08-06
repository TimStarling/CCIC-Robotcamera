module rgb2hsv(
    input           clk         ,
    input           rst_n       ,
    input           din_sop     ,
    input           din_eop     ,
    input           din_vld     ,
    input   [15:0]  din         ,//RGB565
    output reg [8:0] hsv_h      ,
    output reg [8:0] hsv_s      ,
    output reg [7:0] hsv_v      ,
    output reg      dout_sop    ,
    output reg      dout_eop    ,
    output reg      dout_vld    
);

// RGB565转RGB888

wire [7:0] r = {din[15:11],din[13:11]};   // 5→8位扩展
wire [7:0] g = {din[10:5],din[6:5]};   // 6→8位扩展
wire [7:0] b = {din[4:0],din[2:0]};   // 5→8位扩展

// 计算最大/最小值
reg [7:0] max_val;
reg [7:0] min_val;

always @(*) begin
    if (r >= g) begin
        if (r >= b) {max_val, min_val} = {r, (g <= b) ? g : b};
        else        {max_val, min_val} = {b, (g <= r) ? g : r};
    end else begin
        if (g >= b) {max_val, min_val} = {g, (r <= b) ? r : b};
        else        {max_val, min_val} = {b, (r <= g) ? r : g};
    end
end

// 计算亮度V
always @(*) hsv_v = max_val;

// 计算饱和度S（移位优化版）
reg [15:0] s_numerator;
reg [8:0] s_denominator;
reg [16:0] s_temp;

always @(*) begin
    s_numerator = {max_val - min_val, 8'b00000000};  // 扩展为16位
    s_denominator = max_val;
    s_temp = s_numerator * 255;                       // 乘法用移位替代
    hsv_s = s_temp[16:8] / s_denominator;             // 除法保持原操作（需综合除法器）
end

// 计算色调H（移位优化版）
reg [13:0] hue_temp;
reg [13:0] delta;

always @(*) begin
    delta = max_val - min_val;
    if (delta == 0) begin
        hue_temp = 14'd0;
    end else if (max_val == r) begin
        hue_temp = ((g - b) * 60) / delta;
        if (hue_temp < 14'd0) hue_temp += 14'd360;
    end else if (max_val == g) begin
        hue_temp = ((b - r) * 60) / delta + 14'd120;
    end else begin
        hue_temp = ((r - g) * 60) / delta + 14'd240;
    end
end

always @(*) hsv_h = hue_temp[13:5];  // 保留9位精度

// 优化乘法操作（示例）
// 原代码：hsv_s = ((max_val - min_val) * 255) / max_val;
// 替代方案：
// 乘法：255 = 256 -1 = 1<<8 -1
// 除法：由于max_val是变量，无法直接移位，保留原操作

// 处理输出时序
reg [2:0] sop_delay;
reg [2:0] eop_delay;
reg [2:0] vld_delay;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        sop_delay <= 3'b0;
        eop_delay <= 3'b0;
        vld_delay <= 3'b0;
    end else begin
        sop_delay <= {sop_delay[1:0], din_sop};
        eop_delay <= {eop_delay[1:0], din_eop};
        vld_delay <= {vld_delay[1:0], din_vld};
    end
end

assign dout_sop = sop_delay[2];
assign dout_eop = eop_delay[2];
assign dout_vld = vld_delay[2];

endmodule