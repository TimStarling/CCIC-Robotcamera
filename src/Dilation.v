/************** 注释 ***********

膨胀算法
使用按位与操作符|检测全1窗口

*******************************/
module Dilation(
    input           clk     ,
    input           rst_n   ,
    input           din     ,//输入二值图像
    input           din_sop ,
    input           din_eop ,
    input           din_vld ,

    output          dout    ,
    output          dout_sop,
    output          dout_eop,
    output          dout_vld 
);

//信号定义
    wire            taps0   ; 
    wire            taps1   ; 
    wire            taps2   ; 

    reg             line0_0 ;
    reg             line0_1 ;
    reg             line0_2 ;

    reg             line1_0 ;
    reg             line1_1 ;
    reg             line1_2 ;

    reg             line2_0 ;
    reg             line2_1 ;
    reg             line2_2 ;
    
    reg     [1:0]       sop ;      
    reg     [1:0]       eop ;
    reg     [1:0]       vld ;

    reg             Dilation ;

//缓存3行

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

//缓存3列   第一级流水
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            line0_0 <= 0;line0_1 <= 0;line0_2 <= 0;
            line1_0 <= 0;line1_1 <= 0;line1_2 <= 0;
            line2_0 <= 0;line2_1 <= 0;line2_2 <= 0;
        end
        else if(vld[0])begin
            line0_0 <= taps0;line0_1 <= line0_0;line0_2 <= line0_1;
            line1_0 <= taps1;line1_1 <= line1_0;line1_2 <= line1_1;
            line2_0 <= taps2;line2_1 <= line2_0;line2_2 <= line2_1;
        end
    end

//x0_sum    第二级流水
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            Dilation <= 0;
        end
        else if(vld[1])begin
            Dilation <={line0_0 | line0_1 | line0_2|
                        line1_0 | line1_1 | line1_2|
                        line2_0 | line2_1 | line2_2};
        end
    end    

//打拍
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            sop <= 0;
            eop <= 0;
            vld <= 0;
        end
        else begin
            sop <= {sop[0],din_sop};
            eop <= {eop[0],din_eop};
            vld <= {vld[0],din_vld};
        end
    end

    assign  dout     = Dilation;
    assign  dout_sop = sop[1];
    assign  dout_eop = eop[1];
    assign  dout_vld = vld[1];

endmodule 

