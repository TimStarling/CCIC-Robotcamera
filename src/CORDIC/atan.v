module atan (
    input  wire                 sys_clk,
    input  wire                 sys_rst_n,

    input                       en,
    input  wire signed [9:0]    X,
    input  wire signed [9:0]    Y,

    output reg                  valid,
    output reg  signed [8:0]    deg
);


    // 旋转角度表，乘以2^16量化
    reg     [24:0]              rot[15:0];
    initial begin
        rot[0]      = 25'd2949120 ;     //45.0000度*2^16
        rot[1]      = 25'd1740992 ;     //26.5651度*2^16
        rot[2]      = 25'd919872  ;     //14.0362度*2^16
        rot[3]      = 25'd466944  ;     //7.1250度*2^16
        rot[4]      = 25'd234368  ;     //3.5763度*2^16
        rot[5]      = 25'd117312  ;     //1.7899度*2^16
        rot[6]      = 25'd58688   ;     //0.8952度*2^16
        rot[7]      = 25'd29312   ;     //0.4476度*2^16
        rot[8]      = 25'd14656   ;     //0.2238度*2^16
        rot[9]      = 25'd7360    ;     //0.1119度*2^16
        rot[10]     = 25'd3648    ;     //0.0560度*2^16
        rot[11]     = 25'd1856    ;     //0.0280度*2^16
        rot[12]     = 25'd896     ;     //0.0140度*2^16
        rot[13]     = 25'd448     ;     //0.0070度*2^16
        rot[14]     = 25'd256     ;     //0.0035度*2^16
        rot[15]     = 25'd128     ;     //0.0018度*2^16
    end

    /*
        // 迭代公式
        x_{i+1} = x_i - d_i(2^{-i}y_i)
        y_{i+1} = y_i + d_i(2^{-i}x_i)
        z_{i+1} = z_i - d_i \theta_i
    */

    reg     signed [15:0]       xi;
    reg     signed [15:0]       yi;
    reg     signed [24:0]       z_rot;
    reg     [1:0]               quadrant;

    // 旋转方向，为yi的符号位，yi负则逆时针，正则顺时针
    wire                        di;
    assign                      di  =   ~yi[15];

    // 状态机
    reg     [3:0]               cnt;
    reg     [2:0]               state;
    localparam                  IDLE    =   3'b001;
    localparam                  ITERATE =   3'b010;
    localparam                  STOP    =   3'b100;

    // 状态跳转逻辑
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            state               <=  IDLE;
        end
        else begin
            case(state)
            IDLE: begin
                state           <=  en ? ITERATE : IDLE;
            end
            // 十六轮迭代
            ITERATE: begin
                state           <=  (cnt >= 4'd15) ? STOP : ITERATE;
            end
            STOP: begin
                state           <=  IDLE;
            end
            default: begin
                state           <=  state;   
            end
            endcase
        end
    end

    // 迭代计数
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            cnt                 <=  4'b0;
        end
        else if(state == ITERATE) begin
            if(cnt >= 4'd15) begin
                cnt             <=  4'b0;
            end
            else begin
                cnt             <=  cnt + 1'b1;
            end
        end
        else begin
            cnt                 <=  4'b0;
        end
    end

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            xi                  <=  16'b0;
            yi                  <=  16'b0;
            z_rot               <=  25'b0;
            quadrant            <=  2'b0;
            valid               <=  1'b0;
        end
        else begin
            case(state)
            IDLE: begin
                if(en) begin
                    //  预处理，转化到I、IV象限，同时记录原始象限信息
                    xi          <=  X[9] ? ($unsigned(~X + 1'b1)) : X;
                    yi          <=  Y;
                    quadrant    <=  {X[9], Y[9]};
                end
                else begin
                    xi          <=  16'b0;
                    yi          <=  16'b0;
                    quadrant    <=  2'b0;
                end
                z_rot           <=  25'b0;
                valid           <=  1'b0;
            end
            // 旋转迭代
            ITERATE: begin
                // x_{i+1} = x_i - d_i(2^{-i}y_i)
                // y_{i+1} = y_i + d_i(2^{-i}x_i)
                // z_{i+1} = z_i - d_i \theta_i
                if(di)begin
                    xi          <= xi + (yi>>>cnt);
                    yi          <= yi - (xi>>>cnt);
                    z_rot       <= z_rot  + rot[cnt];
                end
                else begin
                    xi          <= xi - (yi>>>cnt);
                    yi          <= yi + (xi>>>cnt);
                    z_rot       <= z_rot  - rot[cnt];
                end
                quadrant        <=  quadrant;
                valid           <=  1'b0;
            end
            STOP: begin
                xi              <=  16'b0;
                yi              <=  16'b0;
                quadrant        <=  quadrant;
                z_rot           <=  z_rot;
                // 迭代完成，拉高有效标志
                valid           <=  1'b1;
            end
            default: begin
                xi              <=  16'b0;
                yi              <=  16'b0;
                quadrant        <=  2'b0;
                z_rot           <=  25'b0;
                valid           <=  1'b0;
            end
            endcase
        end
    end

    // 根据原始象限做后处理
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            deg                 <=  9'b0;
        end
        else if(state == STOP) begin
            case(quadrant)
                // Ⅰ象限
                2'b00: begin
                    deg         <=  z_rot[24:16];   // 反量化，除以2^16，取高16位
                end
                // Ⅳ象限
                2'b01: begin
                    deg         <=  z_rot[24:16];
                end
                // Ⅱ象限
                2'b10: begin
                    deg         <=  9'd180 - z_rot[24:16];
                end
                // Ⅲ象限
                2'b11: begin
                    deg         <=  -9'd180 - z_rot[24:16];
                end
            endcase
        end
        else begin
            deg                 <=  deg;
        end
    end

endmodule //atan2