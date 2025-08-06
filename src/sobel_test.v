`define SOBEL_THRESH 24'd770

module sobel_test (
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
    output wire                 post_video_data,
    output wire [9:0]           post_video_xpos,
    output wire [9:0]           post_video_ypos
);

    // 3x3邻域像素值
    wire [7:0] matrix_p11, matrix_p12, matrix_p13;
    wire [7:0] matrix_p21, matrix_p22, matrix_p23;
    wire [7:0] matrix_p31, matrix_p32, matrix_p33;
    wire matrix_vsync, matrix_hsync, matrix_de;
    wire [9:0] matrix_xpos, matrix_ypos;

    // Sobel计算变量
    reg signed [11:0] sobel_gx;
    reg signed [11:0] sobel_gy;
    reg [22:0] gx_square;
    reg [22:0] gy_square;
    reg [23:0] gradient;

    // 3x3邻域生成模块 (8位像素)
    matrix_generate3x3_8bits u_matrix_generate3x3_sobel(
        .video_pclk             (video_pclk       ),
        .sys_rst_n              (sys_rst_n        ),
        .pre_video_vsync        (pre_video_vsync  ),
        .pre_video_hsync        (pre_video_hsync  ),
        .pre_video_de           (pre_video_de     ),
        .pre_video_data         (pre_video_data   ),
        .pre_video_xpos         (pre_video_xpos   ),
        .pre_video_ypos         (pre_video_ypos   ),
        .post_video_vsync       (matrix_vsync     ),
        .post_video_hsync       (matrix_hsync     ),
        .post_video_de          (matrix_de        ),
        .post_video_xpos        (matrix_xpos      ),
        .post_video_ypos        (matrix_ypos      ),
        .post_matrix_p11        (matrix_p11       ),
        .post_matrix_p12        (matrix_p12       ),
        .post_matrix_p13        (matrix_p13       ),
        .post_matrix_p21        (matrix_p21       ),
        .post_matrix_p22        (matrix_p22       ),
        .post_matrix_p23        (matrix_p23       ),
        .post_matrix_p31        (matrix_p31       ),
        .post_matrix_p32        (matrix_p32       ),
        .post_matrix_p33        (matrix_p33       )
    );


    // Sobel 核心计算
    always @(posedge video_pclk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            sobel_gx        <= 12'd0;
            sobel_gy        <= 12'd0;
            gx_square       <=  23'b0;
            gy_square       <=  23'b0;
            gradient        <=  24'b0;
        end
        else begin
            // Gx = (P13 + 2*P23 + P33) - (P11 + 2*P21 + P31)
            sobel_gx <=
                (matrix_p13 + (matrix_p23 << 1) + matrix_p33) -
                (matrix_p11 + (matrix_p21 << 1) + matrix_p31);

            // Gy = (P31 + 2*P32 + P33) - (P11 + 2*P12 + P13)
            sobel_gy <=
                (matrix_p31 + (matrix_p32 << 1) + matrix_p33) -
                (matrix_p11 + (matrix_p12 << 1) + matrix_p13);

            gx_square   <=  sobel_gx * sobel_gx;
            gy_square   <=  sobel_gy * sobel_gy;
            gradient    <=  gx_square + gy_square;
        end
    end

    // 根据梯度阈值筛选有效边沿像素输出
    reg                     post_data;
    always @(posedge video_pclk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            post_data       <=  1'b0;
        end
        else begin
            if(gradient >= `SOBEL_THRESH) begin
                post_data     <=  1'b1;
            end
            else begin
                post_data     <=  1'b0;
            end
        end
    end

    // 同步打拍
    reg     [3:0]           vsync_r;
    reg     [3:0]           hsync_r;
    reg     [3:0]           de_r;
    reg     [39:0]          xpos_r;
    reg     [39:0]          ypos_r;
    always @(posedge video_pclk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            vsync_r         <=  4'b0;
            hsync_r         <=  4'b0;
            de_r            <=  4'b0;
            xpos_r          <=  40'b0;
            ypos_r          <=  40'b0;
        end
        else begin
            vsync_r         <=  {vsync_r[2:0], matrix_vsync};
            hsync_r         <=  {hsync_r[2:0], matrix_hsync};
            de_r            <=  {de_r[2:0], matrix_de};
            xpos_r          <=  {xpos_r[29:0], matrix_xpos};
            ypos_r          <=  {ypos_r[29:0], matrix_ypos};
        end
    end

    assign                  post_video_data =   post_data;
    assign                  post_video_vsync=   vsync_r[3];
    assign                  post_video_hsync=   hsync_r[3];
    assign                  post_video_de   =   de_r[3];
    assign                  post_video_xpos =   xpos_r[39:30];
    assign                  post_video_ypos =   ypos_r[39:30];


endmodule
