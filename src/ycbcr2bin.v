module ycbcr2bin(
    input           clk         ,
    input           rst_n       ,
    
    input           din_sop     ,
    input           din_eop     ,
    input           din_vld     ,

    input   [1:0]   color_sel   ,//颜色选择接口
    input           en_color    ,

    input   [7:0]   Y           ,//灰度输入
    input   [7:0]   Cb          ,//灰度输入
    input   [7:0]   Cr          ,//灰度输入

    output          dout_sop    ,
    output          dout_eop    ,
    output          dout_vld    ,
    output          dout         //二值输出  
);

//信号定义
reg             binary      ;
reg             binary_sop  ;
reg             binary_eop  ;
reg             binary_vld  ;

always  @(posedge clk or negedge rst_n)begin
    if(~rst_n)begin
        binary     <= 0 ;
        binary_sop <= 0 ;
        binary_eop <= 0 ;
        binary_vld <= 0 ;
    end
    else begin
        if (en_color) begin
            // 当en_color为高时，计算四种颜色的二值相或
            binary <= ((Cr > 150 && Cb < 120 )  //  红色
                    || (Y  > 120 && Cb < 90  )  //  黄色
                    || (Cb > 150 && Y  < 100 )  //  蓝色
                    || (Y  < 45  && Cb < 150 )); //  黑色
        end
        else begin
            case (color_sel)
                0: binary     <= (Cr > 150 && Cb < 120 );  //  红色
                1: binary     <= (Y  > 120 && Cb < 90  );  //  黄色
                2: binary     <= (Cb > 150 && Y  < 100 );  //  蓝色
                3: binary     <= (Y  < 45  && Cb < 150 );  //  黑色
                default: 
                    binary     <=  0;
            endcase
        end
        binary_sop <= din_sop ;
        binary_eop <= din_eop ;
        binary_vld <= din_vld ;
    end
end


// 颜色阈值参数（可根据实际调整）
// 红色：Cr > 150 && Cb < 120 
// 黄色：Y  > 150 && Cb < 90    
// 蓝色：Cb > 150 && Y  < 100 
// 黑色：Y  < 45  && Cb < 160 

   assign dout_sop = binary_sop; 
   assign dout_eop = binary_eop;
   assign dout_vld = binary_vld;
   assign dout     = binary;


endmodule 