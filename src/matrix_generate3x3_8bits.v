module matrix_generate3x3_8bits (
    input  wire                 video_pclk,
    input  wire                 sys_rst_n,

    input  wire                 pre_video_vsync,
    input  wire                 pre_video_hsync,
    input  wire                 pre_video_de,
    input  wire [7:0]           pre_video_data,
    input  wire [9:0]           pre_video_xpos,
    input  wire [9:0]           pre_video_ypos,

    output wire                 post_video_vsync,
    output wire                 post_video_hsync,
    output wire                 post_video_de,
    output wire [9:0]           post_video_xpos,
    output wire [9:0]           post_video_ypos,
    output reg  [7:0]           post_matrix_p11,    post_matrix_p12,    post_matrix_p13,
    output reg  [7:0]           post_matrix_p21,    post_matrix_p22,    post_matrix_p23,
    output reg  [7:0]           post_matrix_p31,    post_matrix_p32,    post_matrix_p33
);

    // line1 ------> x x x ... x x x --->
    //          ^
    //          |
    //          -----------------------
    //                                |
    // line2 ------> x x x ... x x x --->
    //          ^
    //          |
    //          |
    //          | 
    // line3 --------------------------->

    wire      [7:0]             row1_data;
    wire      [7:0]             row2_data;
    reg       [7:0]             row3_data;
    // 打拍对齐
    always @(posedge video_pclk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            row3_data           <=  8'b0;
        end
        else begin
            row3_data           <=  pre_video_data;
        end
    end
    // 缓冲两行
    shift_ram_8b u_shift_ram_8bits(
        .clken                  (pre_video_de   ),
        .clock                  (video_pclk     ),
        .shiftin                (row3_data      ),
        .shiftout               (               ),
        .taps0x                 (row2_data      ),
        .taps1x                 (row1_data      )
    );
    // 3x3输出
    always @(posedge video_pclk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            {post_matrix_p11, post_matrix_p12, post_matrix_p13}     <=  24'b0;
            {post_matrix_p21, post_matrix_p22, post_matrix_p23}     <=  24'b0;
            {post_matrix_p31, post_matrix_p32, post_matrix_p33}     <=  24'b0;
        end
        else begin
            {post_matrix_p11, post_matrix_p12, post_matrix_p13}     <=  {post_matrix_p12, post_matrix_p13, row1_data};
            {post_matrix_p21, post_matrix_p22, post_matrix_p23}     <=  {post_matrix_p22, post_matrix_p23, row2_data};
            {post_matrix_p31, post_matrix_p32, post_matrix_p33}     <=  {post_matrix_p32, post_matrix_p33, row3_data};
        end
    end

    // 其它信号打拍输出
    reg     [1:0]               vsync_r;
    reg     [1:0]               hsync_r;
    reg     [1:0]               de_r;
    reg     [19:0]              xpos_r;
    reg     [19:0]              ypos_r;
    always @(posedge video_pclk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            vsync_r             <=  2'b0;
            hsync_r             <=  2'b0;
            de_r                <=  2'b0;
            xpos_r              <=  20'b0;
            ypos_r              <=  20'b0;
        end
        else begin
            vsync_r             <=  {vsync_r[0], pre_video_vsync};
            hsync_r             <=  {hsync_r[0], pre_video_hsync};
            de_r                <=  {de_r[0], pre_video_de};
            xpos_r              <=  {xpos_r[9:0], pre_video_xpos};
            ypos_r              <=  {ypos_r[9:0], pre_video_ypos};
        end
    end

    assign                      post_video_vsync    =   vsync_r[1];
    assign                      post_video_hsync    =   hsync_r[1];
    assign                      post_video_de       =   de_r[1];
    assign                      post_video_xpos     =   xpos_r[19:10];
    assign                      post_video_ypos     =   ypos_r[19:10];


endmodule //matrix_generate3x3