/************** 注释    ****************

灰度转换：RGB888-->Gray

gray = R*0.299 + G*0.587 + B*0.114
        =  （306 * R + 601 * G + 117 * B）/1024;

Y=0.299R+0.587G+0.114B
Cb=128− 0.1687R−0.3313G+0.5B  =128 - ( 173 * R + 339 * G - 512 * B )/1024
Cr=128+ 0.5R−0.4187G−0.0813B  =128 + ( 512 * R - 429 * G - 83 * B  )/1024

****************************************/

module rgb2ycbcr(

    input           clk         ,
    input           rst_n       ,
    
    input           din_sop     ,
    input           din_eop     ,
    input           din_vld     ,
    input   [15:0]  din         ,//RGB565

    output          dout_sop    ,
    output          dout_eop    ,
    output          dout_vld    ,
    
    output  [7:0]   Y_dout      ,
    output  [7:0]   Cb_dout     ,
    output  [7:0]   Cr_dout         //灰度输出
);

//信号定义
    reg     [7:0]       data_r  ;
    reg     [7:0]       data_g  ;
    reg     [7:0]       data_b  ;
    
    reg     [17:0]      Y_r ; //Y
    reg     [17:0]      Y_g ;
    reg     [17:0]      Y_b ;
    reg     [19:0]      Y   ;

    reg     [17:0]      Cb_r ;//Cb
    reg     [17:0]      Cb_g ;
    reg     [17:0]      Cb_b ;
    reg     [19:0]      Cb   ;

    reg     [17:0]      Cr_r ;//Cr
    reg     [17:0]      Cr_g ;
    reg     [17:0]      Cr_b ;
    reg     [19:0]      Cr   ;

    reg     [1:0]       sop     ;      
    reg     [1:0]       eop     ;
    reg     [1:0]       vld     ;

//扩展    RGB565-->RGB888
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            data_r <= 0;
            data_g <= 0;
            data_b <= 0;
        end
        else if(din_vld)begin
            data_r <= {din[15:11],din[13:11]};      //带补偿的  r5,r4,r3,r2,r1, r3,r2,r1
            data_g <= {din[10:5],din[6:5]}   ;
            data_b <= {din[4:0],din[2:0]}    ;
        end
    end

//加权   
    //第一拍
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            Y_r <= 0;
            Y_g <= 0;
            Y_b <= 0;

            Cb_r <= 0;
            Cb_g <= 0;
            Cb_b <= 0;

            Cr_r <= 0;
            Cr_g <= 0;
            Cr_b <= 0;
        end
        else if(vld[0])begin
            Y_r <= data_r * 10'd306;
            Y_g <= data_g * 10'd601;
            Y_b <= data_b * 10'd117;

            Cb_r <= data_r * 10'd173;
            Cb_g <= data_g * 10'd339;
            Cb_b <= data_b * 10'd512;

            Cr_r <= data_r * 10'd512;
            Cr_g <= data_g * 10'd429;
            Cr_b <= data_b * 10'd83;
        end
    end
    
    //第二拍
    always  @(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            Y <= 0;
            Cb <= 0;
            Cr <= 0;
        end
        else if(vld[1])begin
            Y <= Y_r + Y_g + Y_b;
            Cb <= Cb_b - Cb_r - Cb_g ;
            Cr <= Cr_r - Cr_g - Cr_b;
        end
    end

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

//输出
    assign Y_dout = Y[10 +:8];    //取平均
    assign Cb_dout =8'd128 + Cb[10 +:8];    //取平均
    assign Cr_dout =8'd128 + Cr[10 +:8];    //取平均

    assign dout_sop = sop[1];
    assign dout_eop = eop[1];
    assign dout_vld = vld[1];


endmodule 