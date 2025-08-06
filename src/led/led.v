module led(
	input	clk,		// system clock, 50MHz
	input 	rst_n,		// 系统复位信号，低电平有效
	
	output reg [3:0] led	// 4个LED灯
);

// 定义 2us, 2ms, 2s寄存器
reg [6:0] cnt_2us;
reg [9:0] cnt_2ms;
reg [9:0] cnt_2s;

wire add_cnt_2us;
wire end_cnt_2us;
wire add_cnt_2ms;
wire end_cnt_2ms;
wire add_cnt_2s;
wire end_cnt_2s;


// 定义一个标志信号
reg flag;

always @(posedge clk or negedge rst_n)begin 
   if(!rst_n)begin
        cnt_2us <= 'd0;
    end 
    else if(add_cnt_2us)begin 
        if(end_cnt_2us)begin 
            cnt_2us <= 'd0;
        end
        else begin 
            cnt_2us <= cnt_2us + 1'b1;
        end 
    end
end 
assign add_cnt_2us = 1'b1;
assign end_cnt_2us = add_cnt_2us && cnt_2us == 7'd99;

// cnt_2ms: 定义2ms的计数，即计数1000次（0~999）
// 计数方式：每检测到2us后，自加1，计到999次归零，即1000*2us=2ms

always @(posedge clk or negedge rst_n)begin 
   if(!rst_n)begin
        cnt_2ms <= 'd0;
    end 
    else if(add_cnt_2ms)begin 
        if(end_cnt_2ms)begin 
            cnt_2ms <= 'd0;
        end
        else begin 
            cnt_2ms <= cnt_2ms + 1'b1;
        end 
    end
end 
assign add_cnt_2ms = end_cnt_2us;
assign end_cnt_2ms = (cnt_2us == 7'd99)&&(cnt_2ms == 10'd999);

// cnt_2s：定义2s的计数1000次（0~999）
// 计数方式：每检测到2ms后，自加1，计到999次归零，即1000*2ms=2s

always @(posedge clk or negedge rst_n)begin 
   if(!rst_n)begin
        cnt_2s <= 'd0;
    end 
    else if(add_cnt_2s)begin 
        if(end_cnt_2s)begin 
            cnt_2s <= 'd0;
        end
        else begin 
            cnt_2s <= cnt_2s + 1'b1;
        end 
    end
end 
assign add_cnt_2s = end_cnt_2ms;
assign end_cnt_2s = (cnt_2us == 7'd99)&&(cnt_2ms == 10'd999)&&(cnt_2s == 10'd999);

// flag：定义flag信号，检测到2s后，flag信号翻转一次
always@(posedge clk or negedge rst_n)
begin
	if(rst_n==1'b0)
		flag <= 1'b0;
	else if((cnt_2us == 7'd99)&&(cnt_2ms == 10'd999)&&(cnt_2s == 10'd999))
		flag <= ~flag;
	else
		flag <= flag;
end

// led：初始flag为低电平，当cns_2s的计数大于cnt_2ms时，LED亮，否则灭——由灭到亮；
// 2s后，flag为高电平，当cns_2s的计数大于cnt_2ms时，LED灭，否则亮——由亮到灭；

always@(posedge clk or negedge rst_n)
begin
	if(rst_n==1'b0)
		led <= 4'b0000;
	// 由灭到亮
	else if((flag == 1'b0)&&(cnt_2s <= cnt_2ms))
		led <= 4'b0000;
	else if((flag == 1'b0)&&(cnt_2s > cnt_2ms))
		led <= 4'b1111;
	
	// 由亮到灭
	else if((flag == 1'b1)&&(cnt_2s < cnt_2ms))
		led <= 4'b1111;	
	else if((flag == 1'b1)&&(cnt_2s >= cnt_2ms))
		led <= 4'b0000;
	else
		led <= 4'b0000;
end

endmodule


