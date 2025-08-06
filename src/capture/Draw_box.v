`define ZHANLIAN_THRESHOLD 5000   // 粘连
`define SQUARE_THRESHOLD   3450   // 正方形面积阈值
`define CIRCLE_THRESHOLD   2600   // 圆形面积阈值
`define HEXAGON_THRESHOLD  2000   // 正六边形面积阈值 2200
`define TRIANGLE_THRESHOLD 1300   // 三角形面积阈值

module Draw_box
(
    input               clk            ,
    input               rst_n          ,
    
    input               din            ,
    input               din_sop        ,
    input               din_eop        ,
    input               din_vld        ,  
    
    input               black_en       ,//有效区 
    input               effect_en      ,//有效区  
    input   [44:0]      target_pos     ,
    input   [44:0]      target_pos_1   ,
    input               sobel          ,	 
    input   [10:0]      x_cnt          ,
    input   [10:0]      y_cnt          ,
    input               en_color       ,
    input   [1:0 ]      color_in       ,

    output  reg [15:0]  dout           ,
    output              dout_sop       ,
    output              dout_eop       ,
    output              dout_vld       ,

    output reg [3:0]    shape_out      , //0 正方形 1 圆形 2 正六边形 3 三角形
	
    output reg [8:0]    X_center_ji    ,
    output reg [8:0]    Y_center_ji    ,
    output              tx_pin         ,// 串口发送
    output reg          detect_finish  ,// 数据有效
	output reg          zhanlian       ,// 粘连标志
    output reg [15:0]    Box_theta_out
);
//--------------------- 时序控制 ---------------------
reg     [1:0]    sop, eop, vld;
reg              din_r        ; // 输入信号同步寄存器
reg     [10:0]   x_cnt_r      ;
reg     [10:0]   y_cnt_r      ;

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) {sop, eop, vld} <= 0;
    else begin
        sop     <= {sop[0], din_sop};
        eop     <= {eop[0], din_eop};
        vld     <= {vld[0], din_vld};
        din_r   <= din;
        x_cnt_r <= x_cnt; 
        y_cnt_r <= y_cnt;
    end
end
assign dout_sop = sop[1];
assign dout_eop = eop[1];
assign dout_vld = vld[1];




//--------------------- 边界区域检测 ---------------------
wire [10:0] X_center = ((target_pos[10:0 ] + target_pos[32:22]) >> 1);  //(xmin + xmax) /2
wire [10:0] Y_center = ((target_pos[21:11] + target_pos[43:33]) >> 1);  //(ymin + ymax) /2

//--------------------- 矩形框内判断 ---------------------
wire Inside_box  =  (x_cnt_r >= target_pos[10:0 ] && x_cnt_r <= target_pos[32:22]) &&
                    (y_cnt_r >= target_pos[21:11] && y_cnt_r <= target_pos[43:33]);


// 新增计数器
reg [15:0] inside_box_count;

//--------------------- 输出处理 ---------------------
wire sobel_dot =(((x_cnt_r > target_pos[10:0]-11'd20 && x_cnt_r < target_pos[32:22]+11'd20) &&(y_cnt_r > target_pos[21:11]-11'd20 && y_cnt_r < target_pos[43:33]+11'd20))&&
sobel);

reg [21:0] sobel_top_spot;
reg [21:0] sobel_bottom_spot;

always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        sobel_top_spot <= {11'd0, 11'd0};
        sobel_bottom_spot <= {11'd0, 11'd1200};
    end 
	
	    else if(eop[1]) begin
        // 帧结束时重置边缘点，准备下一帧检测
        sobel_top_spot <= {11'd0, 11'd0};
        sobel_bottom_spot <= {11'd0, 11'd1200};
		end
	else if(sobel_dot)begin
		sobel_top_spot<=(y_cnt_r >= sobel_top_spot[10:0])?{x_cnt_r,y_cnt_r}:sobel_top_spot;
		sobel_bottom_spot<=(y_cnt_r <= sobel_bottom_spot[10:0])?{x_cnt_r,y_cnt_r}:sobel_bottom_spot;		
	end
	
end	


wire  [21:0]left_JiaoDian;   //左角点
wire  [21:0]Right_JiaoDian;  //右角点
wire  [21:0]Top_JiaoDian;    //上角点
wire  [21:0]bottom_JiaoDian; //下角点

assign left_JiaoDian={target_pos[10:0],target_pos_1[10:0]};
assign Right_JiaoDian={target_pos[32:22],target_pos_1[32:22]};
assign Top_JiaoDian={ target_pos_1[21:11],target_pos[21:11]};
assign bottom_JiaoDian={target_pos_1[43:33],target_pos[43:33]};
wire Boundary_areas = (
    // 上下边框
    ((y_cnt_r == target_pos[21:11] || y_cnt_r == target_pos[43:33]) && (x_cnt_r > target_pos[10:0 ] && x_cnt_r < target_pos[32:22])) ||
    // 左右边框
    ((x_cnt_r == target_pos[10:0 ] || x_cnt_r == target_pos[32:22]) && (y_cnt_r > target_pos[21:11] && y_cnt_r < target_pos[43:33])) ||
    // 中心十字标记
    (y_cnt_r == Y_center) || (x_cnt_r == X_center)
);


wire sobel_test = ((x_cnt_r < sobel_top_spot[21:11] + 11'd5 && x_cnt_r > sobel_top_spot[21:11] && y_cnt_r <sobel_top_spot[10:0] + 11'd4 && y_cnt_r >sobel_top_spot[10:0])||
                  (x_cnt_r < sobel_bottom_spot[21:11]+ 11'd5&&x_cnt_r > sobel_bottom_spot[21:11]&&y_cnt_r<sobel_bottom_spot[10:0]+11'd4&&y_cnt_r>sobel_bottom_spot[10:0]));

wire JiaoDian = ((x_cnt_r < target_pos[10:0] + 11'd5 && x_cnt_r > target_pos[10:0] && y_cnt_r <target_pos_1[10:0] + 11'd4 && y_cnt_r >target_pos_1[10:0])||
                 (x_cnt_r < target_pos[32:22]+ 11'd5&&x_cnt_r > target_pos[32:22]&&y_cnt_r<target_pos_1[32:22]+11'd4&&y_cnt_r>target_pos_1[32:22])||
                 (x_cnt_r < target_pos_1[21:11]+ 11'd5&&x_cnt_r > target_pos_1[21:11]&&y_cnt_r<target_pos[21:11]+11'd4&&y_cnt_r>target_pos[21:11])||
                 (x_cnt_r < target_pos_1[43:33]+ 11'd5&&x_cnt_r > target_pos_1[43:33]&&y_cnt_r<target_pos[43:33]+11'd4&&y_cnt_r>target_pos[43:33])               

);



// 合并后的时序逻辑块处理输出和颜色计数
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        dout             <= 16'd0;
        shape_out        <= 4'd5 ;
        inside_box_count <= 'd0  ;
        zhanlian         <= 1'b0 ;
    end 
    else begin
        if (vld[1]) begin
            if (black_en) begin
                dout <= 16'h0ff0;
            end 
            else if (effect_en) begin
                dout <= 16'h07ff;
            end 
            else if (Boundary_areas) begin
                dout <= 16'hF800;
            end 				
            else if (JiaoDian) begin
                dout <= 16'h001f;
            end 
				else if (sobel_dot) begin
                dout <= 16'hffe0;
            end 
				else if (sobel_test) begin
                dout <= 16'hF800;
            end 
            else if (Inside_box && din_r && !en_color) begin
                inside_box_count <= inside_box_count + 1;
                case (color_in)
                    'd0: dout <= 16'hf800;
                    'd1: dout <= 16'hffe0;
                    'd2: dout <= 16'h001f;
                    'd3: dout <= 16'h0007;
                endcase
            end 
            else begin
                dout <= din_r ? 16'hFFFF : 16'h0000;
            end
        end
        if (eop[1]) begin // 一帧结束
            // 根据像素点个数判断图形
            if (inside_box_count >= `ZHANLIAN_THRESHOLD) begin
                zhanlian  <= 1'b1; //粘连
                shape_out <= 4'd5;
            end
            else if (inside_box_count >= `SQUARE_THRESHOLD) begin
                shape_out <= 4'd1; // 正方形
                zhanlian  <= 1'b0; 
            end  
            else if (inside_box_count >= `CIRCLE_THRESHOLD) begin
                shape_out <= 4'd4; // 圆形
                zhanlian  <= 1'b0; 
            end
            else if (inside_box_count >= `HEXAGON_THRESHOLD) begin
                shape_out <= 4'd2; // 正六边形
                zhanlian  <= 1'b0; 
            end  
            else if (inside_box_count >= `TRIANGLE_THRESHOLD) begin
                shape_out <= 4'd8; // 三角形
                zhanlian  <= 1'b0; 
            end 
            else
                shape_out <= 4'd5;
            //清零    
            inside_box_count <= 0;
        end
    end
end


//---------------------角度判定逻辑————————————————————---

//上0 下1 左2 右3
wire [10:0]x_length;	//x轴边框	
wire [10:0]y_length;  //y轴边框
wire [10:0]top_botton_dot_x = (Top_JiaoDian[21:11] + bottom_JiaoDian[21:11]) >> 1;
wire [10:0]left_right_dot_x = (left_JiaoDian[21:11] + Right_JiaoDian[21:11]) >> 1;
wire [10:0]top_botton_dot_y = (Top_JiaoDian[10:0] + bottom_JiaoDian[10:0]) >> 1;
wire [10:0]left_right_dot_y = (left_JiaoDian[10:0] + Right_JiaoDian[10:0]) >> 1;


assign x_length = target_pos[32:22] - target_pos[10:0 ];																								 
assign y_length = target_pos[43:33] - target_pos[21:11];

reg [1:0]zj_dot_pos;

always@(*)
begin
	if(!rst_n)
		zj_dot_pos = 0;
	else if(shape_out==8)begin
		if(x_length > y_length + 1)
			begin
				if(Y_center >= left_right_dot_y + 1)
				zj_dot_pos = 1;
				else if(Y_center <= left_right_dot_y - 1)
				zj_dot_pos = 0;
			end
		else if(y_length > x_length + 1)
		begin
				if(X_center >= top_botton_dot_x + 1)
				zj_dot_pos = 3;
				else if(X_center <= top_botton_dot_x - 1)
				zj_dot_pos = 2;
		end
	end
end
			



reg  signed [10:0] H_Length;       // 水平长度（x方向差值）
reg  signed [10:0] V_Length;       // 垂直长度（y方向差值）
reg  signed [9:0]         x;       // CORDIC模块输入X
reg  signed [9:0]         y;       // CORDIC模块输入Y
wire signed [8:0]     theta;       // CORDIC计算输出角度
wire            theta_valid;       // CORDIC计算完成标志
reg   [7:0]       		age;       //最终输出的角度


always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		H_Length<=0;
		V_Length<=0;
		x<=0;
		y<=0;
	end
	else if (shape_out==1)begin  //正方形 
		/*
		正方形逻辑为找到色域的上下角点，求得夹角，最大为135°
		实际角度为求得角度-45	
		*/
		H_Length<=Top_JiaoDian[21:11] - bottom_JiaoDian[21:11];
		V_Length<=Top_JiaoDian[10:0] - bottom_JiaoDian[10:0];
		x<=H_Length[10:1];
		y<=V_Length[10:1];
	end
	
   else if(shape_out==4)begin//圆形
		/*
		圆形逻辑为找到边缘域的上下角点，求得夹角，最大为135°
		实际角度为求得角度-45		
		*/
		H_Length<=sobel_top_spot[21:11] - sobel_bottom_spot[21:11];
		V_Length<=sobel_top_spot[10:0] - sobel_bottom_spot[10:0];
		x<=H_Length[10:1];
		y<=V_Length[10:1];
	end
	
   else if(shape_out==2)begin//六边形
		/*
		六边形逻辑为找到边缘域的上下角点，求得夹角，最大为135°
		实际角度为求得角度-45		
		*/
		H_Length<=sobel_top_spot[21:11] - sobel_bottom_spot[21:11];
		V_Length<=sobel_top_spot[10:0] - sobel_bottom_spot[10:0];
		x<=H_Length[10:1];
		y<=V_Length[10:1];
	end
	
	   else if(shape_out==8)begin//三角形
		/*
		三角形逻辑为先找到直角点，上0 下1 左2 右3  利用直角点得到角度  目标位置为直角点转为左下角点		
		*/
		
		/*直角点为上角点 计算色域的上角点和右角点的夹角 */
		if(zj_dot_pos==0)begin
		H_Length<=Top_JiaoDian[21:11] - Right_JiaoDian[21:11];
		V_Length<=Top_JiaoDian[10:0] - Right_JiaoDian[10:0];
		x<=H_Length[10:1];
		y<=V_Length[10:1];
		end
		/*直角点为下角点 计算色域的右和下角点的夹角，转成后直角点在右上角在计算角度上加90°即可 */
		else if(zj_dot_pos==1)begin
		H_Length<=Right_JiaoDian[21:11] - bottom_JiaoDian[21:11];
		V_Length<=Right_JiaoDian[10:0] - bottom_JiaoDian[10:0];
		x<=H_Length[10:1];
		y<=V_Length[10:1];		
		end
		/*直角点为左角点 计算色域的右和右角点的夹角，转成后直角点在右上角在计算角度上减45即可 */
		else if(zj_dot_pos==2)begin
		H_Length<=Top_JiaoDian[21:11] - bottom_JiaoDian[21:11];
		V_Length<=Top_JiaoDian[10:0] - bottom_JiaoDian[10:0];
		x<=H_Length[10:1];
		y<=V_Length[10:1];		
		end
		/*直角点为右角点 计算色域的右和右角点的夹角，转成后直角点在右上角，无需加任何角度 */
		else if(zj_dot_pos==3)begin
		H_Length<=Right_JiaoDian[21:11] - bottom_JiaoDian[21:11];
		V_Length<=Right_JiaoDian[10:0] - bottom_JiaoDian[10:0];
		x<=H_Length[10:1];
		y<=V_Length[10:1];		
		end
	end
	
end


    // 实例化CORDIC反正切模块
    atan u_atan(
        .sys_clk    (clk        ),
        .sys_rst_n  (rst_n      ),
        .en         (eop        ),
        .X          (x          ),
        .Y          (y          ),
        .valid      (theta_valid),
        .deg        (theta      )
    );
	 
reg    age_vilid;
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		age<=0;
		age_vilid<=0;

	end
	else if(shape_out==1&&bottom_JiaoDian[10:0]<=left_JiaoDian[10:0]+'d10)begin
	age <=0;	
	Box_theta_out<=0;
	end
	else if(shape_out==1&&theta_valid&&bottom_JiaoDian[10:0]>=left_JiaoDian[10:0]+'d10)begin
	age <=theta[8]?8'd255 - theta[7:0] + 1-'d45:theta[7:0]-'d45;
	Box_theta_out<=theta[8]?8'd255 - theta[7:0] + 1-'d45:theta[7:0]-'d45;
	age_vilid<=1;
	end
	else if(shape_out==4&&theta_valid)begin
	age <=theta[8]?8'd255 - theta[7:0] + 1-'d45:theta[7:0]-'d45;
	Box_theta_out<='d90-age;
	age_vilid<=1;
	
	end
	else if(shape_out==2&&theta_valid)begin
	age <=theta[8]?8'd255 - theta[7:0] + 1-'d45:theta[7:0]-'d45;
	Box_theta_out<='d90-age;
	age_vilid<=1;
	
	end
	
	else if(shape_out==8&&theta_valid&&zj_dot_pos==0)begin//上角点
	Box_theta_out<=theta[8]?8'd255 - theta[7:0]+'d90 + 1:theta[7:0]+'d90;
	age_vilid<=1;
	
	end

		else if(shape_out==8&&theta_valid&&zj_dot_pos==1)begin//下角点
	Box_theta_out<=theta[8]?8'd255 - theta[7:0] + 1:theta[7:0] ;
	age_vilid<=1;
	
	end
			else if(shape_out==8&&theta_valid&&zj_dot_pos==2)begin
	Box_theta_out<=theta[8]?8'd255 - theta[7:0]-'d45+'d270 + 1:theta[7:0]-'d45++ 'd270 ;
	age_vilid<=1;
	
	end
	
			else if(shape_out==8&&theta_valid&&zj_dot_pos==3)begin
	Box_theta_out<=theta[8]?8'd255 - theta[7:0] + 1+'d90:theta[7:0]+'d90 ;
	age_vilid<=1;
	
	end
	
	else begin
	age_vilid<=0;
	end


end


//--------------------- 坐标转换逻辑 ---------------------
reg [10:0] X_center_reg;
reg [10:0] Y_center_reg;
reg [31:0] x_numerator;
reg [31:0] y_numerator;

//常数定义（根据位宽调整）
localparam DIV600_FACTOR = 18'd1095;  // 438 * 2.5
localparam DIV40_FACTOR  = 18'd4095;  // 1638 * 2.5

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        X_center_reg <= 'd0;
        Y_center_reg <= 'd0;
        X_center_ji  <= 'd0;
        Y_center_ji  <= 'd0;
        x_numerator  <= 'd0;
        y_numerator  <= 'd0;
        detect_finish<= 'b0;
    end 
    else if(target_pos != 'b0) //数据有效
        begin
        // 寄存原始中心坐标
        X_center_reg <= X_center;
        Y_center_reg <= Y_center;
        
        // 第一级：计算分子
        x_numerator <= 106 * (940 + 60 - X_center_reg);  //60偏移量
        y_numerator <= (Y_center_reg - 160) * 7;
        
        // 第二级：乘法与移位
        X_center_ji <= (x_numerator * DIV600_FACTOR) >> 18;
        Y_center_ji <= (y_numerator * DIV40_FACTOR)  >> 16; 

        if(X_center_ji>256) X_center_ji<=255;
		if(Y_center_ji>175) Y_center_ji<=174;
        detect_finish <= 1'b1;          //识别完成目标有效
    end
    else begin
        detect_finish <= 1'b0;
    end
end



//   //计算水平和垂直长度
//   wire signed [10:0] H_Length;  // 水平长度（x方向差值）
//   wire signed [10:0] V_Length;  // 垂直长度（y方向差值）
//  
//    
//		
//   wire     signed [9:0] x;       // CORDIC模块输入X
//   wire     signed [9:0] y;       // CORDIC模块输入Y
//	 wire    signed [8:0] theta;   // CORDIC计算输出角度
//   wire                theta_valid; // CORDIC计算完成标志
//	 wire signed [8:0]age;
//
//  assign H_Length = sobel_bottom_spot[21:11] - sobel_top_spot[21:11];
//  assign V_Length = sobel_bottom_spot[10:0] - sobel_top_spot[10:0];    
//	assign x=H_Length[10:1];
//	assign y=V_Length[10:1];
//	assign age =theta[8]?8'd255 - theta[7:0] + 1:theta[7:0];
//	 
//    // 实例化CORDIC反正切模块
//    atan u_atan(
//        .sys_clk    (clk        ),
//        .sys_rst_n  (rst_n      ),
//        .en         (eop        ),
//        .X          (x          ),
//        .Y          (y          ),
//        .valid      (theta_valid),
//        .deg        (theta      )
//    );
//	
//wire [10:0]x_length;	//x轴边框	
//wire [10:0]y_length;  //y轴边框
//wire [10:0]top_botton_dot_x = (Top_JiaoDian[21:11] + bottom_JiaoDian[21:11]) >> 1;
//wire [10:0]left_right_dot_x = (left_JiaoDian[21:11] + Right_JiaoDian[21:11]) >> 1;
//wire [10:0]top_botton_dot_y = (Top_JiaoDian[10:0] + bottom_JiaoDian[10:0]) >> 1;
//wire [10:0]left_right_dot_y = (left_JiaoDian[10:0] + Right_JiaoDian[10:0]) >> 1;
//
//
//assign x_length = target_pos[32:22] - target_pos[10:0 ];																								 
//assign y_length = target_pos[43:33] - target_pos[21:11];
//
//reg [1:0]zj_dot_pos;
//
//always@(*)
//begin
//	if(!rst_n)
//		zj_dot_pos = 0;
//	else begin
//		if(x_length > y_length + 1)
//			begin
//				if(Y_center >= left_right_dot_y + 1)
//				zj_dot_pos = 1;
//				else if(Y_center <= left_right_dot_y - 1)
//				zj_dot_pos = 0;
//			end
//		else if(y_length > x_length + 1)
//		begin
//				if(X_center >= top_botton_dot_x + 1)
//				zj_dot_pos = 3;
//				else if(X_center <= top_botton_dot_x - 1)
//				zj_dot_pos = 2;
//		end
//	end
//end
//																									
//uart_tx#
//(
//	.CLK_FRE(84),
//	.BAUD_RATE(115200)
//) uart_tx_inst
//(
///*input      */.clk                        (clk                      ),
///*input      */.rst_n                      (rst_n                    ),
///*input[7:0] */.tx_data                    (zj_dot_pos              ),
///*input      */.tx_data_valid              (eop                      ),  //高电平发送
///*output reg */.tx_data_ready              (tx_data_ready            ),  //高电平空闲
///*output     */.tx_pin                     (tx_pin                   )
//);
// //--------------------- 新增UART发送逻辑（按协议帧发送）---------------------

reg [3:0] color_r;
always@(posedge clk or negedge rst_n)begin
	if(!rst_n)begin
		color_r<=0;
	end
	else if(color_in==0)begin//红色
		color_r<=4'd1;
	end
	
	else if(color_in==1)begin//黄色
		color_r<=4'd2;
	end
	
	else if(color_in==2)begin//蓝色
		color_r<=4'd4;
	end
	
	else if(color_in==3)begin//黑色
		color_r<=4'd8;
	end
end

// UART实例化（参数按实际需求调整）
uart_tx#
(
	.CLK_FRE(84),
	.BAUD_RATE(115200)
) uart_tx_inst
(
/*input      */.clk                        (clk                      ),
/*input      */.rst_n                      (rst_n                    ),
/*input[7:0] */.tx_data                    (tx_data                  ),
/*input      */.tx_data_valid              (tx_data_valid            ),  //高电平发送
/*output reg */.tx_data_ready              (tx_data_ready            ),  //高电平空闲
/*output     */.tx_pin                     (tx_pin                   )
);

reg[7:0]      tx_data;
reg[7:0]      tx_buf [0:8];  // 存储协议帧（9字节：帧头+数据+帧尾）
reg           tx_data_valid;
wire          tx_data_ready;
reg[3:0]      state;          // 状态机状态
reg[3:0]      send_cnt;       // 发送字节计数器（0~8）
reg[15:0]     x_coord;        // 16位x坐标（替换原count1_r）
reg[7:0]      y_coord;        // 8位y坐标（替换原count2_r）

reg[15:0]     angle_coord;    // 16位角度（替换原count5_r）


// 状态定义
localparam S_IDLE    = 4'd0;   // 空闲状态
localparam S_LOAD    = 4'd1;   // 加载协议帧数据
localparam S_SEND    = 4'd2;   // 发送数据状态
localparam S_WAIT    = 4'd3;   // 发送完成等待

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        tx_data       <= 8'd0;
        state         <= S_IDLE;
        send_cnt      <= 4'd0;
        tx_data_valid <= 1'b0;
        
        // 初始化协议帧缓冲区
        tx_buf[0] <= 8'hFF;     // 帧头
        tx_buf[1] <= 8'd0;
        tx_buf[2] <= 8'd0;
        tx_buf[3] <= 8'd0;
        tx_buf[4] <= 8'd0;
        tx_buf[5] <= 8'd0;
        tx_buf[6] <= 8'd0;
        tx_buf[7] <= 8'd0;
        tx_buf[8] <= 8'hFF;     // 帧尾
        
        // 示例数据（实际需替换为真实数据源）

    end
    else
    case(state)
        S_IDLE:
            begin
                // 检测触发信号（如外部触发或自设条件）
                if (eop[1]) begin
                    state <= S_LOAD;
                end
            end
            
        S_LOAD:
            begin
                // 按协议格式填充缓冲区
                tx_buf[0] <= 8'hff;                    // 帧头
                tx_buf[1] <= X_center_ji[8];            // x高8位
                tx_buf[2] <= X_center_ji[7:0];             // x低8位
                tx_buf[3] <= Y_center_ji[7:0];                  // y坐标
                tx_buf[4] <= shape_out;                    // 形状
                tx_buf[5] <= color_r;                    // 颜色
                tx_buf[6] <= Box_theta_out[15:8];        // 角度高8位
                tx_buf[7] <= Box_theta_out[7:0];         // 角度低8位
                tx_buf[8] <= 8'hFF;                    // 帧尾
                
                state <= S_SEND;
                send_cnt <= 4'd0;
                tx_data_valid <= 1'b0;
            end
            
        S_SEND:
            begin
                if (tx_data_ready && !tx_data_valid) begin
                    // 从缓冲区取数据发送
                    tx_data <= tx_buf[send_cnt];
                    tx_data_valid <= 1'b1;
                end
                else if (tx_data_ready && tx_data_valid) begin
                    tx_data_valid <= 1'b0;
                    send_cnt <= send_cnt + 1'b1;
                    // 发送完9字节后进入等待状态
                    if (send_cnt == 4'd8) begin
                        state <= S_WAIT;
                    end
                end
            end
            
        S_WAIT:
            begin
                // 发送完成后等待（可设置等待时间或直接回Idle）
                state <= S_IDLE;  // 简化处理，直接回到空闲状态
            end
            
        default:
            state <= S_IDLE;
    endcase
end



endmodule    